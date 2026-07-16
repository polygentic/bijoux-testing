#!/usr/bin/env bash
# UAT: Proximity Feature — API Pre-flight (curl-only, no simulator)
#
# Validates every backend proximity contract shape against a running backend with
# PROXIMITY_CHECK_ENABLED=true. This is the fastest signal that the backend gates
# work, before touching simulators. Uses only curl + python3 + the shared helpers.
#
# Requires: backend running at $BACKEND_URL with seed data and PROXIMITY_CHECK_ENABLED=true.
#           Redis running (proximity TTL). No simulator needed.
#
# Contract shapes verified (from backend main):
#   POST /matching/offers/:id/arrived           → 200 {arrivedAt,bookingId}  | 400 {success:false,status:failed,distanceMeters,thresholdMeters:100}
#   POST /sessions/:id/proximity-check           → 200 {status:waiting|passed,...} | 400 {status:failed,distanceMeters,thresholdMeters:50}
#   POST /admin/matching/offers/:id/arrival-override → 200 {overridden:true} | 403 non-admin | 400 missing reason
#   POST /admin/sessions/:id/proximity-override      → 200 {overridden:true} | 403 non-admin
#
# Usage:
#   SKIP_FLAG_OFF_TEST=true ./scripts/proximity-api-preflight.sh   # skip the manual flag-OFF step
#   ./scripts/proximity-api-preflight.sh                            # prints flag-OFF instructions

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/config/environment.sh"
source "$ROOT_DIR/scripts/lib/api-helpers.sh"
source "$ROOT_DIR/scripts/lib/admin-api-helpers.sh"
source "$ROOT_DIR/scripts/lib/sim-helpers.sh"

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

# ── JSON field extractor (stdin body, dotted-free single key) ──
json_field() {
  local key="$1"
  python3 -c "import sys,json
try:
    print(json.load(sys.stdin).get('$key',''))
except Exception:
    print('')" 2>/dev/null
}

# ── curl a POST, echo 'HTTP_CODE\nBODY' back split ──
# Sets global RESP_CODE and RESP_BODY.
post_json() {
  local url="$1" token="$2" body="$3"
  local raw
  raw=$(curl -s -w $'\n%{http_code}' -X POST "$url" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $token" \
    -d "$body")
  RESP_CODE=$(printf '%s' "$raw" | tail -n1)
  RESP_BODY=$(printf '%s' "$raw" | sed '$d')
}

# ── Release the caregiver from any active work so BOOKING_OVERLAP clears before a new match. ──
# Ends Maria's in_progress/not_started sessions and cancels her active bookings. Any test that
# still needs a session must consume it BEFORE the next setup_matched_offer call.
release_caregiver() {
  # End any active sessions (verify both sides for not_started, then end).
  api_cleanup_sessions "$CAREGIVER_TOKEN" "$PARENT_TOKEN"
  # Cancel any still-active bookings for the parent.
  api_cancel_active_bookings "$PARENT_TOKEN" > /dev/null 2>&1
  # Belt-and-suspenders: clear any overlapping match_offers/bookings directly so the
  # BOOKING_OVERLAP gate (matching adapter) does not exclude Maria on the next cycle.
  docker exec bijoux-postgres psql -U bijoux -d bijoux_dev -c \
    "UPDATE bookings SET lifecycle='cancelled' \
     WHERE lifecycle IN ('created','matching','matched','confirmed','in_progress') \
     AND created_at >= CURRENT_DATE;" > /dev/null 2>&1
  sleep 1
}

# ── Set up one fresh booking → matched → accepted → IOMW. Sets BOOKING_OUT / OFFER_OUT. ──
# Args: <label>. Uses PARENT_TOKEN / CAREGIVER_TOKEN from outer scope.
# Releases the caregiver from prior active work first (clears BOOKING_OVERLAP).
setup_matched_offer() {
  local label="$1"
  release_caregiver
  # Create a booking whose stored lat/lng = the SAME proximity anchor the NEAR/FAR/DRIFT
  # sim coords are derived from ($PROX_ANCHOR_LAT/LNG, i.e. BOOKING_LAT/LNG). The backend
  # arrival/handoff checks compare the caregiver's/parent's coord against the BOOKING's
  # coord, so the booking and the NEAR arrival coord MUST share one anchor or every arrival
  # is ~392 m off (the TEST_LAT/LNG-vs-BOOKING_LAT/LNG gap) and PASS cases fail. This script
  # bypasses the app's client-geocode by sending lat/lng directly, so we set them explicitly
  # to the anchor here (the app path reaches the same anchor via geocoding "100 Congress Ave").
  local booking_resp
  booking_resp=$(curl -s -X POST "$BACKEND_URL/bookings" \
    -H "Content-Type: application/json" -H "Authorization: Bearer $PARENT_TOKEN" \
    -d "{\"type\":\"request_now\",\"address\":\"$TEST_ADDRESS\",\"latitude\":$PROX_ANCHOR_LAT,\"longitude\":$PROX_ANCHOR_LNG,\"durationMinutes\":180,\"numberOfChildren\":1}")
  BOOKING_OUT=$(printf '%s' "$booking_resp" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    b=d.get('booking',d.get('data',d))
    print(b.get('id',''))
except Exception:
    print('')" 2>/dev/null)
  if [[ -z "$BOOKING_OUT" ]]; then
    echo "    setup($label): booking create failed: $(printf '%s' "$booking_resp" | head -c 300)"
    OFFER_OUT=""
    return 1
  fi

  # createBooking leaves the booking at lifecycle=created. Matching is triggered by an
  # explicit POST /matching/start {bookingId} (the parent app does this after booking).
  curl -s -X POST "$BACKEND_URL/matching/start" \
    -H "Content-Type: application/json" -H "Authorization: Bearer $PARENT_TOKEN" \
    -d "{\"bookingId\":\"$BOOKING_OUT\"}" > /dev/null 2>&1

  # Poll for a pending offer to the caregiver (matching engine dispatches automatically).
  OFFER_OUT=""
  local attempt=0
  while [[ $attempt -lt 20 && -z "$OFFER_OUT" ]]; do
    OFFER_OUT=$(curl -s -H "Authorization: Bearer $CAREGIVER_TOKEN" \
      "$BACKEND_URL/matching/offers/pending" 2>/dev/null | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    offers=d.get('offers',d.get('data',[]))
    # GET /matching/offers/pending returns items keyed by 'offerId' (no booking id in payload).
    # Other caregivers are offline and only one booking is active at a time, so the first
    # pending offer is ours.
    if offers:
        print(offers[0].get('offerId', offers[0].get('id','')))
    else:
        print('')
except Exception:
    print('')" 2>/dev/null)
    [[ -n "$OFFER_OUT" ]] && break
    sleep 3
    attempt=$((attempt + 1))
  done
  if [[ -z "$OFFER_OUT" ]]; then
    echo "    setup($label): no pending offer after 60s for booking $BOOKING_OUT"
    return 1
  fi

  # Accept the offer, then send IOMW.
  curl -s -X POST "$BACKEND_URL/matching/offers/$OFFER_OUT/respond" \
    -H "Content-Type: application/json" -H "Authorization: Bearer $CAREGIVER_TOKEN" \
    -d '{"response":"accept"}' > /dev/null 2>&1
  curl -s -X POST "$BACKEND_URL/matching/offers/$OFFER_OUT/on-my-way" \
    -H "Content-Type: application/json" -H "Authorization: Bearer $CAREGIVER_TOKEN" \
    -d '{}' > /dev/null 2>&1
  return 0
}

# ── Start a session for a booking. Echoes session id (from startSession response body). ──
start_session() {
  local booking_id="$1"
  curl -s -X POST "$BACKEND_URL/sessions/start" \
    -H "Content-Type: application/json" -H "Authorization: Bearer $CAREGIVER_TOKEN" \
    -d "{\"bookingId\":\"$booking_id\"}" 2>/dev/null | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    s=d.get('session',d.get('data',d))
    print(s.get('id',''))
except Exception:
    print('')" 2>/dev/null
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
# PHASE 2: Setup — clean state, caregiver online + at address + trusted
# ═══════════════════════════════════════════════════════════════
step "Clean state, set Maria online + location + trust clear/approved"
api_cleanup_sessions "$CAREGIVER_TOKEN" "$PARENT_TOKEN"
api_cancel_active_bookings "$PARENT_TOKEN"
api_reset_daily_limits

# Set other caregivers offline so matching dispatches only to Maria.
EMMA_TOKEN=$(api_login "$CAREGIVER_EMAIL" "$CAREGIVER_PASSWORD" 2>/dev/null) || true
[[ -n "$EMMA_TOKEN" && "$EMMA_TOKEN" != "None" ]] && api_set_online "$EMMA_TOKEN" "false" 2>/dev/null || true

api_set_online "$CAREGIVER_TOKEN" "true"
# #26 matching-location freshness: matching reads CaregiverProfile.latitude/longitude +
# locationUpdatedAt, which are written ONLY by PUT /location/matching {lat,lng}. The legacy
# PUT /profile/caregiver {latitude,longitude} flat body is ignored by the new schema, so we
# stamp the matching location explicitly here.
curl -s -X PUT "$BACKEND_URL/location/matching" \
  -H "Content-Type: application/json" -H "Authorization: Bearer $CAREGIVER_TOKEN" \
  -d "{\"lat\":$TEST_LAT,\"lng\":$TEST_LNG}" > /dev/null 2>&1

CAREGIVER_PROFILE_ID=$(curl -s -H "Authorization: Bearer $CAREGIVER_TOKEN" \
  "$BACKEND_URL/profile/caregiver" 2>/dev/null \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('profile',{}).get('id',''))" 2>/dev/null)
if [[ -n "$CAREGIVER_PROFILE_ID" ]]; then
  curl -s -X PUT "$BACKEND_URL/trust/caregivers/$CAREGIVER_PROFILE_ID/bg-status" \
    -H "Content-Type: application/json" -H "Authorization: Bearer $ADMIN_TOKEN" \
    -d '{"status":"clear"}' > /dev/null 2>&1
  curl -s -X PUT "$BACKEND_URL/trust/caregivers/$CAREGIVER_PROFILE_ID/idv-status" \
    -H "Content-Type: application/json" -H "Authorization: Bearer $ADMIN_TOKEN" \
    -d '{"status":"approved"}' > /dev/null 2>&1
  # The bg-status endpoint updates status only, not expiresAt. Seed BG checks have
  # expiry dates that have since passed, which the matching adapter treats as BG_FAIL
  # (adapters.ts: "latest BackgroundCheck must be clear and not expired"). Refresh the
  # latest check's expiry so the caregiver is matching-eligible. Test-data prep only,
  # same category as api_reset_daily_limits (which also uses docker exec psql).
  docker exec bijoux-postgres psql -U bijoux -d bijoux_dev -c \
    "UPDATE background_checks SET expires_at = NOW() + INTERVAL '365 days', status='clear' \
     WHERE caregiver_profile_id='${CAREGIVER_PROFILE_ID}' \
     AND completed_at = (SELECT MAX(completed_at) FROM background_checks WHERE caregiver_profile_id='${CAREGIVER_PROFILE_ID}');" \
    > /dev/null 2>&1
fi
pass "State cleaned, Maria online + at address + trusted (BG check refreshed)"

# ═══════════════════════════════════════════════════════════════
# TEST 1: Arrival PASS (NEAR coords)
# ═══════════════════════════════════════════════════════════════
step "TEST 1: Arrival PASS — /arrived with NEAR coords → 200 {arrivedAt}"
if setup_matched_offer "T1"; then
  BOOKING_ID="$BOOKING_OUT"; OFFER_ID="$OFFER_OUT"
  post_json "$BACKEND_URL/matching/offers/$OFFER_ID/arrived" "$CAREGIVER_TOKEN" \
    "{\"latitude\":$SIM_LAT_NEAR,\"longitude\":$SIM_LNG_NEAR,\"accuracy\":5.0}"
  assert_eq "Arrival PASS HTTP status" "$RESP_CODE" "200"
  ARRIVED_AT=$(printf '%s' "$RESP_BODY" | json_field arrivedAt)
  [[ -n "$ARRIVED_AT" ]] && pass "arrivedAt present ($ARRIVED_AT)" || fail "arrivedAt missing (body: $RESP_BODY)"
  # Start the session for this booking (needed for TEST 3). arrived does NOT create it.
  SESSION_ID=$(start_session "$BOOKING_ID")
  [[ -n "$SESSION_ID" ]] && pass "Session started ($SESSION_ID)" || fail "Session start failed"
else
  fail "TEST 1 setup (matched offer) failed"
fi

# ═══════════════════════════════════════════════════════════════
# TEST 3: Handoff start PASS (NEAR, two-party cycle) — uses SESSION_ID from TEST 1
# NOTE: runs BEFORE TEST 2 so it consumes TEST 1's session before the next
# setup_matched_offer releases the caregiver (BOOKING_OVERLAP would otherwise block).
# ═══════════════════════════════════════════════════════════════
step "TEST 3: Handoff start PASS — two-party proximity-check phase=start (NEAR)"
if [[ -n "${SESSION_ID:-}" ]]; then
  # Caregiver POSTs first → waiting
  post_json "$BACKEND_URL/sessions/$SESSION_ID/proximity-check" "$CAREGIVER_TOKEN" \
    "{\"latitude\":$SIM_LAT_NEAR,\"longitude\":$SIM_LNG_NEAR,\"accuracy\":5.0,\"phase\":\"start\"}"
  assert_eq "CG first POST HTTP 200" "$RESP_CODE" "200"
  assert_eq "CG first POST = waiting" "$(printf '%s' "$RESP_BODY" | json_field status)" "waiting"

  # Parent POSTs → passed
  post_json "$BACKEND_URL/sessions/$SESSION_ID/proximity-check" "$PARENT_TOKEN" \
    "{\"latitude\":$SIM_LAT_NEAR,\"longitude\":$SIM_LNG_NEAR,\"accuracy\":5.0,\"phase\":\"start\"}"
  assert_eq "Parent POST HTTP 200" "$RESP_CODE" "200"
  assert_eq "Parent POST = passed" "$(printf '%s' "$RESP_BODY" | json_field status)" "passed"

  # Caregiver re-POSTs → idempotency shortcut → passed
  post_json "$BACKEND_URL/sessions/$SESSION_ID/proximity-check" "$CAREGIVER_TOKEN" \
    "{\"latitude\":$SIM_LAT_NEAR,\"longitude\":$SIM_LNG_NEAR,\"accuracy\":5.0,\"phase\":\"start\"}"
  assert_eq "CG re-POST HTTP 200" "$RESP_CODE" "200"
  assert_eq "CG re-POST = passed (idempotency)" "$(printf '%s' "$RESP_BODY" | json_field status)" "passed"

  # verify/start now succeeds
  post_json "$BACKEND_URL/sessions/$SESSION_ID/verify/start" "$CAREGIVER_TOKEN" '{}'
  assert_eq "verify/start HTTP 200 after proximity pass" "$RESP_CODE" "200"
else
  fail "TEST 3 skipped — no SESSION_ID from TEST 1"
fi

# ═══════════════════════════════════════════════════════════════
# TEST 2: Arrival FAIL (FAR coords — new booking/offer)
# Runs after TEST 3 (which consumed TEST 1's session). setup_matched_offer releases
# the caregiver first, so TEST 1's now-consumed session no longer blocks matching.
# ═══════════════════════════════════════════════════════════════
step "TEST 2: Arrival FAIL — /arrived with FAR coords → 400 status=failed thresholdMeters=100"
OFFER_ID2=""
if setup_matched_offer "T2"; then
  BOOKING_ID2="$BOOKING_OUT"; OFFER_ID2="$OFFER_OUT"
  post_json "$BACKEND_URL/matching/offers/$OFFER_ID2/arrived" "$CAREGIVER_TOKEN" \
    "{\"latitude\":$SIM_LAT_FAR,\"longitude\":$SIM_LNG_FAR,\"accuracy\":5.0}"
  assert_eq "Arrival FAIL HTTP status" "$RESP_CODE" "400"
  assert_eq "status=failed" "$(printf '%s' "$RESP_BODY" | json_field status)" "failed"
  assert_eq "thresholdMeters=100" "$(printf '%s' "$RESP_BODY" | json_field thresholdMeters)" "100"
else
  fail "TEST 2 setup (matched offer) failed"
fi

# ═══════════════════════════════════════════════════════════════
# TEST 5: Admin arrival override — uses OFFER_ID2 (the FAR-fail offer). Runs here (right
# after TEST 2) so OFFER_ID2 is consumed before TEST 4's setup_matched_offer releases.
# ═══════════════════════════════════════════════════════════════
step "TEST 5: Admin arrival override → /admin/matching/offers/:id/arrival-override"
if [[ -n "${OFFER_ID2:-}" ]]; then
  post_json "$BACKEND_URL/admin/matching/offers/$OFFER_ID2/arrival-override" "$ADMIN_TOKEN" \
    '{"reason":"UAT preflight arrival override"}'
  assert_eq "Arrival override HTTP 200" "$RESP_CODE" "200"
  assert_eq "overridden=true" "$(printf '%s' "$RESP_BODY" | json_field overridden)" "True"

  # 403 for non-admin
  post_json "$BACKEND_URL/admin/matching/offers/$OFFER_ID2/arrival-override" "$CAREGIVER_TOKEN" \
    '{"reason":"test"}'
  assert_eq "Non-admin arrival override HTTP 403" "$RESP_CODE" "403"

  # Missing reason → 422 VALIDATION_ERROR (backend's Zod-validation contract; the plan
  # anticipated 400 but the real backend returns 422 for schema failures).
  post_json "$BACKEND_URL/admin/matching/offers/$OFFER_ID2/arrival-override" "$ADMIN_TOKEN" '{}'
  assert_eq "Missing reason HTTP 422 (VALIDATION_ERROR)" "$RESP_CODE" "422"
else
  fail "TEST 5 skipped — no OFFER_ID2 from TEST 2"
fi

# ═══════════════════════════════════════════════════════════════
# TEST 4: Handoff FAIL (DRIFT coords) — new booking/offer/session
# ═══════════════════════════════════════════════════════════════
step "TEST 4: Handoff FAIL — CG NEAR then parent DRIFT → 400 status=failed thresholdMeters=50"
SESSION_ID3=""
if setup_matched_offer "T4"; then
  BOOKING_ID3="$BOOKING_OUT"; OFFER_ID3="$OFFER_OUT"
  # Arrival must pass first (caregiver at NEAR), then start the session.
  post_json "$BACKEND_URL/matching/offers/$OFFER_ID3/arrived" "$CAREGIVER_TOKEN" \
    "{\"latitude\":$SIM_LAT_NEAR,\"longitude\":$SIM_LNG_NEAR,\"accuracy\":5.0}"
  assert_eq "T4 arrival PASS (NEAR) HTTP 200" "$RESP_CODE" "200"
  SESSION_ID3=$(start_session "$BOOKING_ID3")
  [[ -n "$SESSION_ID3" ]] && pass "T4 session started ($SESSION_ID3)" || fail "T4 session start failed"

  if [[ -n "$SESSION_ID3" ]]; then
    # Caregiver POSTs NEAR first → 200 waiting (sets caregiver Redis key)
    post_json "$BACKEND_URL/sessions/$SESSION_ID3/proximity-check" "$CAREGIVER_TOKEN" \
      "{\"latitude\":$SIM_LAT_DRIFT_CG,\"longitude\":$SIM_LNG_DRIFT_CG,\"accuracy\":5.0,\"phase\":\"start\"}"
    assert_eq "DRIFT: CG first POST HTTP 200" "$RESP_CODE" "200"
    assert_eq "DRIFT: CG first POST = waiting" "$(printf '%s' "$RESP_BODY" | json_field status)" "waiting"

    # Parent POSTs DRIFT → both keys present, ~89m > 50m → 400 failed
    post_json "$BACKEND_URL/sessions/$SESSION_ID3/proximity-check" "$PARENT_TOKEN" \
      "{\"latitude\":$SIM_LAT_DRIFT_PARENT,\"longitude\":$SIM_LNG_DRIFT_PARENT,\"accuracy\":5.0,\"phase\":\"start\"}"
    assert_eq "DRIFT: parent POST HTTP 400" "$RESP_CODE" "400"
    assert_eq "DRIFT: status=failed" "$(printf '%s' "$RESP_BODY" | json_field status)" "failed"
    assert_eq "DRIFT: thresholdMeters=50" "$(printf '%s' "$RESP_BODY" | json_field thresholdMeters)" "50"

    # verify/start blocked after fail
    post_json "$BACKEND_URL/sessions/$SESSION_ID3/verify/start" "$CAREGIVER_TOKEN" '{}'
    assert_eq "verify/start blocked (HTTP 400)" "$RESP_CODE" "400"
  fi
else
  fail "TEST 4 setup (matched offer) failed"
fi

# ═══════════════════════════════════════════════════════════════
# TEST 6: Admin session proximity override — uses SESSION_ID3 (DRIFT-fail session)
# ═══════════════════════════════════════════════════════════════
step "TEST 6: Admin session proximity override → /admin/sessions/:id/proximity-override (phase=start)"
if [[ -n "${SESSION_ID3:-}" ]]; then
  post_json "$BACKEND_URL/admin/sessions/$SESSION_ID3/proximity-override" "$ADMIN_TOKEN" \
    '{"reason":"UAT drift override","phase":"start"}'
  assert_eq "Session proximity override HTTP 200" "$RESP_CODE" "200"
  assert_eq "overridden=true" "$(printf '%s' "$RESP_BODY" | json_field overridden)" "True"

  # verify/start now succeeds after override
  post_json "$BACKEND_URL/sessions/$SESSION_ID3/verify/start" "$CAREGIVER_TOKEN" '{}'
  assert_eq "verify/start HTTP 200 after override" "$RESP_CODE" "200"

  # 403 for non-admin
  post_json "$BACKEND_URL/admin/sessions/$SESSION_ID3/proximity-override" "$CAREGIVER_TOKEN" \
    '{"reason":"test","phase":"start"}'
  assert_eq "Non-admin session override HTTP 403" "$RESP_CODE" "403"
else
  fail "TEST 6 skipped — no SESSION_ID3 from TEST 4"
fi

# ═══════════════════════════════════════════════════════════════
# TEST 7: Flag OFF regression (manual — requires backend env change)
# ═══════════════════════════════════════════════════════════════
step "TEST 7: Flag OFF regression (MANUAL — requires backend restart with flag OFF)"
if [[ "${SKIP_FLAG_OFF_TEST:-false}" == "true" ]]; then
  echo "  SKIP: SKIP_FLAG_OFF_TEST=true — run manually with flag OFF"
else
  echo "  MANUAL STEP: Set PROXIMITY_CHECK_ENABLED=false, restart backend, then verify:"
  echo "    POST /matching/offers/<id>/arrived with {} → expect 200 (legacy honor-system)"
  echo "    POST /sessions/<id>/verify/start with {} (no proximity) → expect 200"
fi

# ═══════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════
echo ""
echo "═══════════════════════════════════════════════════"
echo "  PROXIMITY API PRE-FLIGHT — RESULTS"
echo "═══════════════════════════════════════════════════"
echo "  Failures: $FAILURES"
echo ""
if [[ $FAILURES -eq 0 ]]; then
  echo "  OVERALL: PASS ✓"
  exit 0
else
  echo "  OVERALL: FAIL ($FAILURES failures)"
  exit 1
fi
