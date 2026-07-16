#!/usr/bin/env bash
# UAT: Proximity Feature — Cross-App E2E (4 scenarios) on two iOS simulators.
#
# Drives the real caregiver + parent apps through the proximity-gated lifecycle with
# PROXIMITY_CHECK_ENABLED=true. Location + permission control is done OUTSIDE the YAML via
# sim-helpers.sh; the orchestrator sequences background Maestro processes and coordinates
# with the backend API (admin overrides, booking/session assertions).
#
# Requires:
#   - 2 sims booted: bijoux-parent ($PARENT_UDID), bijoux-care ($CAREGIVER_UDID)
#   - both apps built + installed with proximity changes (#18 caregiver; #20 parent)
#   - backend running at $BACKEND_URL with PROXIMITY_CHECK_ENABLED=true + seed data
#   - Redis running (proximity TTL); MATCHING_LOCATION_STALENESS_SEC permissive
#
# Usage:
#   ./scripts/cross-app-proximity-e2e.sh --scenario=1   # happy path
#   ./scripts/cross-app-proximity-e2e.sh --scenario=2   # drift → admin override → retry
#   ./scripts/cross-app-proximity-e2e.sh --scenario=3   # one-party delayed
#   ./scripts/cross-app-proximity-e2e.sh --scenario=4   # permission denial
#   ./scripts/cross-app-proximity-e2e.sh --all          # all four sequentially (default)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/config/environment.sh"
source "$ROOT_DIR/scripts/lib/api-helpers.sh"
source "$ROOT_DIR/scripts/lib/admin-api-helpers.sh"
source "$ROOT_DIR/scripts/lib/sim-helpers.sh"

# ─── Validate prerequisites ──────────────────────────────────
[[ -z "$PARENT_UDID" ]] && echo "ERROR: PARENT_UDID not set (boot bijoux-parent)" >&2 && exit 1
[[ -z "$CAREGIVER_UDID" ]] && echo "ERROR: CAREGIVER_UDID not set (boot bijoux-care)" >&2 && exit 1

mkdir -p "$ROOT_DIR/results/cross-app"

FAILURES=0
STEP=0

step()  { STEP=$((STEP + 1)); echo ""; echo "═══ STEP $STEP: $1 ═══"; }
pass()  { echo "  ✓ PASS: $1"; }
fail()  { echo "  ✗ FAIL: $1"; FAILURES=$((FAILURES + 1)); }
assert_eq() {
  local label="$1" actual="$2" expected="$3"
  if [[ "$actual" == "$expected" ]]; then
    pass "$label (got: $actual)"
  else
    fail "$label (expected: $expected, got: $actual)"
  fi
}

# ─── Caregiver eligibility setup (shared by all scenarios) ───────────────────
# Sets Maria online, stamps her matching location at the booking address, and refreshes
# her BG check so the matching adapter treats her as eligible. Mirrors the working setup
# proven by proximity-api-preflight.sh.
setup_caregiver_eligibility() {
  api_cleanup_sessions "$CAREGIVER_TOKEN" "$PARENT_TOKEN"
  api_cancel_active_bookings "$PARENT_TOKEN" > /dev/null 2>&1
  api_reset_daily_limits

  # Other caregivers offline so only Maria is dispatched.
  local emma_token
  emma_token=$(api_login "$CAREGIVER_EMAIL" "$CAREGIVER_PASSWORD" 2>/dev/null) || true
  [[ -n "$emma_token" && "$emma_token" != "None" ]] && api_set_online "$emma_token" "false" 2>/dev/null || true

  api_set_online "$CAREGIVER_TOKEN" "true"
  # #26 matching-location freshness: matching reads CaregiverProfile.latitude/longitude +
  # locationUpdatedAt, written by PUT /location/matching {lat,lng}.
  curl -s -X PUT "$BACKEND_URL/location/matching" \
    -H "Content-Type: application/json" -H "Authorization: Bearer $CAREGIVER_TOKEN" \
    -d "{\"lat\":$TEST_LAT,\"lng\":$TEST_LNG}" > /dev/null 2>&1

  local cg_profile_id
  cg_profile_id=$(curl -s -H "Authorization: Bearer $CAREGIVER_TOKEN" \
    "$BACKEND_URL/profile/caregiver" 2>/dev/null \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('profile',{}).get('id',''))" 2>/dev/null)
  if [[ -n "$cg_profile_id" ]]; then
    curl -s -X PUT "$BACKEND_URL/trust/caregivers/$cg_profile_id/bg-status" \
      -H "Content-Type: application/json" -H "Authorization: Bearer $ADMIN_TOKEN" \
      -d '{"status":"clear"}' > /dev/null 2>&1
    curl -s -X PUT "$BACKEND_URL/trust/caregivers/$cg_profile_id/idv-status" \
      -H "Content-Type: application/json" -H "Authorization: Bearer $ADMIN_TOKEN" \
      -d '{"status":"approved"}' > /dev/null 2>&1
    # Refresh the latest BG check expiry (seed checks may have expired) so the matching
    # adapter's "latest must be clear and not expired" gate passes. Test-data prep only.
    docker exec bijoux-postgres psql -U bijoux -d bijoux_dev -c \
      "UPDATE background_checks SET expires_at = NOW() + INTERVAL '365 days', status='clear' \
       WHERE caregiver_profile_id='${cg_profile_id}' \
       AND completed_at = (SELECT MAX(completed_at) FROM background_checks WHERE caregiver_profile_id='${cg_profile_id}');" \
      > /dev/null 2>&1
  fi
}

# Resolve the caregiver's active session id from the most recent booking (best-effort).
resolve_session_id() {
  local booking_id="$1"
  api_session_id "$CAREGIVER_TOKEN" "$booking_id"
}

# Re-grant location TCC on a UDID a few times over ~90s. `clearState: true` resets TCC on
# launch and the caregiver app requests permission on-appear at the arrival screen, so a single
# grant right after launch can race the app's own permission read. Periodic re-grants keep the
# permission effective through the arrival window (the app reads authorizationStatus in
# currentFix() at the "I've Arrived" tap). Runs in the background; caller does not wait on it.
periodic_grant_location() {
  local udid="$1" bundle_id="$2" rounds="${3:-9}"
  (
    local i=0
    while [[ $i -lt $rounds ]]; do
      xcrun simctl privacy "$udid" grant location "$bundle_id" 2>/dev/null || true
      sleep 10
      i=$((i + 1))
    done
  ) &
}

# ⚠️ RETAINED-BUT-UNUSED (2026-07-16): all scenarios now use sim_tight_refresh (a tight `simctl
# location set` loop) instead of this `simctl location start` feed. Reason: `set` and `start` are
# MUTUALLY-EXCLUSIVE simctl location modes; running both on one UDID (as the old scenarios did)
# churns the location so neither delivers reliably at the one-shot arrival/handoff moment. A tight
# `set` loop keeps CLLocationManager.location continuously < ~2s old — and `set` is proven to reach
# the app's CLLocationManager (a new `set` coord is picked up by the en-route app's matching report
# within one cadence). Kept here for reference / potential future use; do not re-enable alongside
# sim_tight_refresh.
#
# Keep a CONTINUOUS CoreLocation feed running on a UDID across the whole scenario window.
# `simctl location start` issues periodic updates (1s); this helper re-starts that feed every ~90s.
periodic_start_location() {
  local udid="$1" lat="$2" lng="$3" rounds="${4:-6}"
  (
    local i=0
    while [[ $i -lt $rounds ]]; do
      sim_start_location "$udid" "$lat" "$lng" 12 2>/dev/null || true
      sleep 90
      i=$((i + 1))
    done
  ) &
}

# ═══════════════════════════════════════════════════════════════
# PHASE 1: Authenticate
# ═══════════════════════════════════════════════════════════════
step "Authenticate parent, caregiver (Maria), admin"
PARENT_TOKEN=$(api_login "$PARENT_EMAIL" "$PARENT_PASSWORD")
CAREGIVER_TOKEN=$(api_login "$CAREGIVER_ONLINE_EMAIL" "$CAREGIVER_ONLINE_PASSWORD")
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
[[ -n "$PARENT_TOKEN" && "$PARENT_TOKEN" != "None" ]] && pass "Parent token" || { fail "Parent token"; exit 1; }
[[ -n "$CAREGIVER_TOKEN" && "$CAREGIVER_TOKEN" != "None" ]] && pass "Caregiver token" || { fail "Caregiver token"; exit 1; }
[[ -n "$ADMIN_TOKEN" && "$ADMIN_TOKEN" != "None" ]] && pass "Admin token" || { fail "Admin token"; exit 1; }

# ═══════════════════════════════════════════════════════════════
# PHASE 2: Boot simulators (fresh XCTest driver state — iOS 26.5 stability)
# ═══════════════════════════════════════════════════════════════
step "Boot simulators"
xcrun simctl shutdown "$CAREGIVER_UDID" 2>/dev/null || true
xcrun simctl shutdown "$PARENT_UDID" 2>/dev/null || true
sleep 2
xcrun simctl boot "$CAREGIVER_UDID" 2>/dev/null || true
xcrun simctl boot "$PARENT_UDID" 2>/dev/null || true
sleep 8
pass "Both simulators booted"

# ═══════════════════════════════════════════════════════════════
# SCENARIO 1 — Happy path (both NEAR)
# ═══════════════════════════════════════════════════════════════
run_scenario_1() {
  step "SCENARIO 1: Happy path — both sims NEAR, flag ON"
  setup_caregiver_eligibility

  sim_set_location "$CAREGIVER_UDID" "$SIM_LAT_NEAR" "$SIM_LNG_NEAR"
  sim_set_location "$PARENT_UDID" "$SIM_LAT_NEAR" "$SIM_LNG_NEAR"

  local CG_LOG="$ROOT_DIR/results/cross-app/proximity-s1-cg.log"
  maestro test "$ROOT_DIR/flows/caregiver/proximity-happy-path.yaml" --device "$CAREGIVER_UDID" \
    > "$CG_LOG" 2>&1 &
  local CG_PID=$!
  echo "  Caregiver S1 flow started (PID: $CG_PID)"
  sleep 8
  sim_grant_location "$CAREGIVER_UDID" "$CAREGIVER_BUNDLE_ID"
  periodic_grant_location "$CAREGIVER_UDID" "$CAREGIVER_BUNDLE_ID" 12
  # Tight 2s `set` loop keeps CLLocationManager.location fresh (< ~2s) so the cached-fallback
  # fix's 60s freshness gate accepts it at the one-shot arrival/handoff moment. This is the
  # PROVEN feed (a manual "I've Arrived" tap with this feed running POSTed /arrived → 200,
  # arrived_at set, session created). NOTE: do NOT also run `simctl location start` here — the
  # `start` (continuous) and `set` (tight) modes are mutually exclusive in simctl and interleaving
  # them churns the location so neither delivers reliably at the one-shot moment (see sim-helpers).
  sim_tight_refresh "$CAREGIVER_UDID" "$SIM_LAT_NEAR" "$SIM_LNG_NEAR"

  sleep 20  # let caregiver log in + go online before the parent books

  local P_LOG="$ROOT_DIR/results/cross-app/proximity-s1-p.log"
  maestro test "$ROOT_DIR/flows/parent/proximity-happy-path.yaml" --device "$PARENT_UDID" \
    > "$P_LOG" 2>&1 &
  local P_PID=$!
  echo "  Parent S1 flow started (PID: $P_PID)"
  sleep 5
  sim_grant_location "$PARENT_UDID" "$PARENT_BUNDLE_ID"
  # Parent's handoff proximity-check also does a one-shot fix; keep its location fresh too.
  sim_tight_refresh "$PARENT_UDID" "$SIM_LAT_NEAR" "$SIM_LNG_NEAR"

  wait $CG_PID && pass "Caregiver S1 flow" || { fail "Caregiver S1 flow"; tail -25 "$CG_LOG"; }
  wait $P_PID && pass "Parent S1 flow"    || { fail "Parent S1 flow";    tail -25 "$P_LOG";  }

  sleep 3
  local BOOKING_ID LIFECYCLE
  BOOKING_ID=$(api_latest_booking_id "$PARENT_TOKEN")
  LIFECYCLE=$(api_booking_lifecycle "$PARENT_TOKEN" "$BOOKING_ID")
  assert_eq "S1 booking lifecycle" "$LIFECYCLE" "completed"

  local S1_SESSION_ID
  S1_SESSION_ID=$(resolve_session_id "$BOOKING_ID")
  if [[ -z "$S1_SESSION_ID" ]]; then
    fail "S1: could not resolve session ID"
  else
    assert_eq "S1 session status" "$(api_session_status "$CAREGIVER_TOKEN" "$S1_SESSION_ID")" "completed"
  fi
}

# ═══════════════════════════════════════════════════════════════
# SCENARIO 2 — Drift → admin override → retry
# ═══════════════════════════════════════════════════════════════
run_scenario_2() {
  step "SCENARIO 2: DRIFT → admin override → retry"
  setup_caregiver_eligibility

  sim_set_location "$CAREGIVER_UDID" "$SIM_LAT_DRIFT_CG"     "$SIM_LNG_DRIFT_CG"
  sim_set_location "$PARENT_UDID"    "$SIM_LAT_DRIFT_PARENT" "$SIM_LNG_DRIFT_PARENT"

  local CG_LOG="$ROOT_DIR/results/cross-app/proximity-s2-cg.log"
  maestro test "$ROOT_DIR/flows/caregiver/proximity-drift-override.yaml" --device "$CAREGIVER_UDID" \
    > "$CG_LOG" 2>&1 &
  local CG_PID=$!
  echo "  Caregiver S2 flow started (PID: $CG_PID)"
  sleep 8
  sim_grant_location "$CAREGIVER_UDID" "$CAREGIVER_BUNDLE_ID"
  # CG at NEAR (arrival passes); keep both fixes fresh through arrival + handoff windows via the
  # tight `set` loop (see sim-helpers — do NOT also run `simctl location start`, the modes conflict).
  periodic_grant_location "$CAREGIVER_UDID" "$CAREGIVER_BUNDLE_ID" 12
  sim_tight_refresh "$CAREGIVER_UDID" "$SIM_LAT_DRIFT_CG" "$SIM_LNG_DRIFT_CG"
  sleep 20

  local P_LOG="$ROOT_DIR/results/cross-app/proximity-s2-p.log"
  maestro test "$ROOT_DIR/flows/parent/proximity-drift-override.yaml" --device "$PARENT_UDID" \
    > "$P_LOG" 2>&1 &
  local P_PID=$!
  echo "  Parent S2 flow started (PID: $P_PID)"
  sleep 5
  sim_grant_location "$PARENT_UDID" "$PARENT_BUNDLE_ID"
  # Parent stays at DRIFT (handoff fails until admin override); keep its fix fresh for the check.
  sim_tight_refresh "$PARENT_UDID" "$SIM_LAT_DRIFT_PARENT" "$SIM_LNG_DRIFT_PARENT"

  # Poll for the session id (booking is created by the parent flow), then admin-override the
  # start proximity gate. The caregiver drift flow is waiting on proximity-waiting-label
  # (extendedWaitUntil 120s); the override fires well within that window.
  local S2_SESSION_ID=""
  local poll_attempt=0
  local S2_BOOKING_ID=""
  while [[ $poll_attempt -lt 25 && -z "$S2_SESSION_ID" ]]; do
    sleep 3
    S2_BOOKING_ID=$(api_latest_booking_id "$PARENT_TOKEN")
    if [[ -n "$S2_BOOKING_ID" ]]; then
      S2_SESSION_ID=$(resolve_session_id "$S2_BOOKING_ID")
    fi
    poll_attempt=$((poll_attempt + 1))
  done

  if [[ -n "$S2_SESSION_ID" ]]; then
    local OVERRIDE_RESP OVERRIDE_HTTP
    OVERRIDE_RESP=$(curl -s -w $'\n%{http_code}' -X POST \
      "$BACKEND_URL/admin/sessions/$S2_SESSION_ID/proximity-override" \
      -H "Content-Type: application/json" -H "Authorization: Bearer $ADMIN_TOKEN" \
      -d '{"reason":"UAT S2 drift override","phase":"start"}')
    OVERRIDE_HTTP=$(printf '%s' "$OVERRIDE_RESP" | tail -n1)
    assert_eq "S2 admin override HTTP 200" "$OVERRIDE_HTTP" "200"
    pass "Admin proximity override sent (session $S2_SESSION_ID) — apps should proceed"

    # After the START handoff is overridden, the parties are together for the session. Bring the
    # parent from DRIFT to NEAR so the END-of-session proximity gate passes NATURALLY (the scenario
    # overrides only the START gate; without this the END gate would also fail at 89 m and the
    # session could never complete). Refresh both sims tightly at NEAR through the end window.
    kill_sim_refreshers
    sim_set_location "$PARENT_UDID"    "$SIM_LAT_NEAR" "$SIM_LNG_NEAR"
    sim_set_location "$CAREGIVER_UDID" "$SIM_LAT_NEAR" "$SIM_LNG_NEAR"
    sim_tight_refresh "$CAREGIVER_UDID" "$SIM_LAT_NEAR" "$SIM_LNG_NEAR"
    sim_tight_refresh "$PARENT_UDID"    "$SIM_LAT_NEAR" "$SIM_LNG_NEAR"
  else
    fail "S2: could not resolve session ID after ~75s of polling"
  fi

  wait $CG_PID && pass "Caregiver S2 flow" || { fail "Caregiver S2 flow"; tail -25 "$CG_LOG"; }
  wait $P_PID && pass "Parent S2 flow"    || { fail "Parent S2 flow";    tail -25 "$P_LOG";  }

  sleep 3
  local LIFECYCLE
  LIFECYCLE=$(api_booking_lifecycle "$PARENT_TOKEN" "$(api_latest_booking_id "$PARENT_TOKEN")")
  assert_eq "S2 booking completed after override" "$LIFECYCLE" "completed"
}

# ═══════════════════════════════════════════════════════════════
# SCENARIO 3 — One-party delayed
# ═══════════════════════════════════════════════════════════════
run_scenario_3() {
  step "SCENARIO 3: One-party delayed — caregiver submits first, parent 35s later"
  setup_caregiver_eligibility

  sim_set_location "$CAREGIVER_UDID" "$SIM_LAT_NEAR" "$SIM_LNG_NEAR"
  sim_set_location "$PARENT_UDID"    "$SIM_LAT_NEAR" "$SIM_LNG_NEAR"

  local CG_LOG="$ROOT_DIR/results/cross-app/proximity-s3-cg.log"
  maestro test "$ROOT_DIR/flows/caregiver/proximity-one-party-delay.yaml" --device "$CAREGIVER_UDID" \
    > "$CG_LOG" 2>&1 &
  local CG_PID=$!
  echo "  Caregiver S3 flow started (PID: $CG_PID)"
  sleep 8
  sim_grant_location "$CAREGIVER_UDID" "$CAREGIVER_BUNDLE_ID"
  # Caregiver submits first then polls ~35s for the parent; keep its fix fresh the whole time.
  periodic_grant_location "$CAREGIVER_UDID" "$CAREGIVER_BUNDLE_ID" 15
  sim_tight_refresh "$CAREGIVER_UDID" "$SIM_LAT_NEAR" "$SIM_LNG_NEAR"

  # Parent starts 35s later (caregiver reaches the polling state by then).
  sleep 35
  local P_LOG="$ROOT_DIR/results/cross-app/proximity-s3-p.log"
  maestro test "$ROOT_DIR/flows/parent/proximity-one-party-delay.yaml" --device "$PARENT_UDID" \
    > "$P_LOG" 2>&1 &
  local P_PID=$!
  echo "  Parent S3 flow started (PID: $P_PID)"
  sleep 5
  sim_grant_location "$PARENT_UDID" "$PARENT_BUNDLE_ID"
  sim_tight_refresh "$PARENT_UDID" "$SIM_LAT_NEAR" "$SIM_LNG_NEAR"

  wait $CG_PID && pass "Caregiver S3 flow" || { fail "Caregiver S3 flow"; tail -25 "$CG_LOG"; }
  wait $P_PID && pass "Parent S3 flow"    || { fail "Parent S3 flow";    tail -25 "$P_LOG";  }

  sleep 3
  local LIFECYCLE
  LIFECYCLE=$(api_booking_lifecycle "$PARENT_TOKEN" "$(api_latest_booking_id "$PARENT_TOKEN")")
  assert_eq "S3 booking completed (poll resolved)" "$LIFECYCLE" "completed"
}

# ═══════════════════════════════════════════════════════════════
# SCENARIO 4 — Permission denial (caregiver only + parent happy-path booking driver)
# ═══════════════════════════════════════════════════════════════
run_scenario_4() {
  step "SCENARIO 4: Permission denial — caregiver denies location, then grants + retries"
  setup_caregiver_eligibility

  sim_set_location "$CAREGIVER_UDID" "$SIM_LAT_NEAR" "$SIM_LNG_NEAR"
  sim_set_location "$PARENT_UDID"    "$SIM_LAT_NEAR" "$SIM_LNG_NEAR"

  local CG_LOG="$ROOT_DIR/results/cross-app/proximity-s4-cg.log"
  maestro test "$ROOT_DIR/flows/caregiver/proximity-permission-denial.yaml" --device "$CAREGIVER_UDID" \
    > "$CG_LOG" 2>&1 &
  local CG_PID=$!
  echo "  Caregiver S4 flow started (PID: $CG_PID)"
  # Intentionally NO caregiver sim_grant_location here — the flow taps "Don't Allow". The
  # grant (and location re-set) is deferred until the denial screenshot appears (retry below).

  # The caregiver flow blocks waiting for "Accept" — no offer exists unless a booking exists,
  # and the booking is created by the PARENT flow. Launch the parent concurrently (like S1-S3).
  sleep 20
  local P_LOG="$ROOT_DIR/results/cross-app/proximity-s4-p.log"
  maestro test "$ROOT_DIR/flows/parent/proximity-happy-path.yaml" --device "$PARENT_UDID" \
    > "$P_LOG" 2>&1 &
  local P_PID=$!
  echo "  Parent S4 flow started (PID: $P_PID)"
  sleep 5
  sim_grant_location "$PARENT_UDID" "$PARENT_BUNDLE_ID"  # parent grants normally
  sim_tight_refresh "$PARENT_UDID" "$SIM_LAT_NEAR" "$SIM_LNG_NEAR"

  # Poll for the denial screenshot before granting caregiver location (max 180s, 5s interval).
  local denial_screenshot="$ROOT_DIR/results/cross-app/proximity-cg-permission-denied.png"
  rm -f "$denial_screenshot" 2>/dev/null || true
  local poll_denial=0
  while [[ $poll_denial -lt 36 && ! -f "$denial_screenshot" ]]; do
    sleep 5
    poll_denial=$((poll_denial + 1))
  done
  if [[ ! -f "$denial_screenshot" ]]; then
    fail "S4: denial screenshot not found after 180s — caregiver may not have reached the dialog"
  else
    pass "S4: denial screenshot confirmed — granting caregiver location for retry"
  fi

  # Grant caregiver location AND keep the CoreLocation fix fresh so the retry
  # ("Try Again" / "I've Arrived") one-shot currentFix() resolves instead of throwing noFix.
  sim_grant_location "$CAREGIVER_UDID" "$CAREGIVER_BUNDLE_ID"
  sim_tight_refresh "$CAREGIVER_UDID" "$SIM_LAT_NEAR" "$SIM_LNG_NEAR"

  wait $CG_PID && pass "Caregiver S4 flow (denial + retry)" || { fail "Caregiver S4 flow"; tail -25 "$CG_LOG"; }
  wait $P_PID && pass "Parent S4 flow"                      || { fail "Parent S4 flow";    tail -25 "$P_LOG";  }

  # Key assertion: booking NOT in error state (denial was inline, not fatal). Full completion
  # may be limited by the app's retry implementation for this scenario.
  local BOOKING_ID LIFECYCLE
  BOOKING_ID=$(api_latest_booking_id "$PARENT_TOKEN")
  LIFECYCLE=$(api_booking_lifecycle "$PARENT_TOKEN" "$BOOKING_ID")
  if [[ -n "$LIFECYCLE" && "$LIFECYCLE" != "error" ]]; then
    pass "S4 booking lifecycle non-error ($LIFECYCLE)"
  else
    fail "S4 booking lifecycle unexpected ($LIFECYCLE)"
  fi
}

# ═══════════════════════════════════════════════════════════════
# Dispatch + summary
# ═══════════════════════════════════════════════════════════════
SCENARIO="${1:---all}"
case "$SCENARIO" in
  --scenario=1|1) run_scenario_1 ;;
  --scenario=2|2) run_scenario_2 ;;
  --scenario=3|3) run_scenario_3 ;;
  --scenario=4|4) run_scenario_4 ;;
  --all|*)
    run_scenario_1
    run_scenario_2
    run_scenario_3
    run_scenario_4
    ;;
esac

echo ""
echo "══════════════════════════════════════════════════"
echo "  PROXIMITY UAT E2E — RESULTS"
echo "══════════════════════════════════════════════════"
echo "  Scenario: $SCENARIO"
echo "  Failures: $FAILURES"
echo ""
if [[ $FAILURES -eq 0 ]]; then
  echo "  OVERALL: PASS ✓"
  exit 0
else
  echo "  OVERALL: FAIL ($FAILURES failures)"
  exit 1
fi
