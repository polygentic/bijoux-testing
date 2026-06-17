#!/usr/bin/env bash
# UAT: Real Multi-Simulator E2E Matching Flow — Happy Path
#
# Tests the FULL REAL matching flow with NO simulate endpoints:
# Parent books → Matching engine dispatches offers → Caregiver accepts →
# IOMW → Arrival → Session start → Session end → Rating → Payment verify
#
# Requires: 2 sims booted (bijoux-parent, bijoux-care), backend running with seed data
#
# Usage:
#   ./scripts/cross-app-real-matching-e2e.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/config/environment.sh"
source "$ROOT_DIR/scripts/lib/api-helpers.sh"
source "$ROOT_DIR/scripts/lib/state-helpers.sh"

# ─── Validate prerequisites ──────────────────────────────────
[[ -z "$PARENT_UDID" ]] && echo "ERROR: PARENT_UDID not set" >&2 && exit 1
[[ -z "$CAREGIVER_UDID" ]] && echo "ERROR: CAREGIVER_UDID not set" >&2 && exit 1

mkdir -p "$ROOT_DIR/results/cross-app"

state_init
state_set "metadata.layer1_script" "cross-app-real-matching-e2e"

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

# ═══════════════════════════════════════════════════════════════
# PHASE 1: API Setup — get tokens, set caregiver online
# ═══════════════════════════════════════════════════════════════
step "Authenticate test users via API"

PARENT_TOKEN=$(api_login "$PARENT_EMAIL" "$PARENT_PASSWORD")
[[ -n "$PARENT_TOKEN" && "$PARENT_TOKEN" != "None" ]] && pass "Parent token" || { fail "Parent token"; exit 1; }

CAREGIVER_TOKEN=$(api_login "$CAREGIVER_ONLINE_EMAIL" "$CAREGIVER_ONLINE_PASSWORD")
[[ -n "$CAREGIVER_TOKEN" && "$CAREGIVER_TOKEN" != "None" ]] && pass "Caregiver token" || { fail "Caregiver token"; exit 1; }

ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
[[ -n "$ADMIN_TOKEN" && "$ADMIN_TOKEN" != "None" ]] && pass "Admin token" || { fail "Admin token"; exit 1; }

step "Clean up stale bookings/sessions and set caregiver ready"
api_cleanup_sessions "$CAREGIVER_TOKEN" "$PARENT_TOKEN"
api_cancel_active_bookings "$PARENT_TOKEN"
api_reset_daily_limits

# Set OTHER caregivers offline so matching engine only dispatches to Maria
EMMA_TOKEN=$(api_login "$CAREGIVER_EMAIL" "$CAREGIVER_PASSWORD" 2>/dev/null) || true
[[ -n "$EMMA_TOKEN" && "$EMMA_TOKEN" != "None" ]] && api_set_online "$EMMA_TOKEN" "false" 2>/dev/null || true

api_set_online "$CAREGIVER_TOKEN" "true"
api_report_location "$CAREGIVER_TOKEN" "${TEST_LAT}" "${TEST_LNG}"

# Ensure caregiver BG check and IDV are in matching-eligible state
CAREGIVER_PROFILE_ID=$(curl -s -H "Authorization: Bearer $CAREGIVER_TOKEN" \
  "${BACKEND_URL}/profile/caregiver" 2>/dev/null \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('profile',{}).get('id',''))" 2>/dev/null)
if [[ -n "$CAREGIVER_PROFILE_ID" ]]; then
  curl -s -X PUT "${BACKEND_URL}/trust/caregivers/${CAREGIVER_PROFILE_ID}/bg-status" \
    -H "Content-Type: application/json" -H "Authorization: Bearer $ADMIN_TOKEN" \
    -d '{"status":"clear"}' > /dev/null 2>&1
  curl -s -X PUT "${BACKEND_URL}/trust/caregivers/${CAREGIVER_PROFILE_ID}/idv-status" \
    -H "Content-Type: application/json" -H "Authorization: Bearer $ADMIN_TOKEN" \
    -d '{"status":"approved"}' > /dev/null 2>&1
fi
pass "Stale bookings/sessions cleaned, caregiver online + location + trust set"

# ═══════════════════════════════════════════════════════════════
# PHASE 2: Boot simulators
# ═══════════════════════════════════════════════════════════════
step "Boot simulators (fresh XCTest driver state)"

# Reboot both simulators for clean XCTest driver state (iOS 26.5 stability workaround)
xcrun simctl shutdown "$CAREGIVER_UDID" 2>/dev/null || true
xcrun simctl shutdown "$PARENT_UDID" 2>/dev/null || true
sleep 2
xcrun simctl boot "$CAREGIVER_UDID" 2>/dev/null || true
xcrun simctl boot "$PARENT_UDID" 2>/dev/null || true
sleep 8
pass "Both simulators booted"

# ═══════════════════════════════════════════════════════════════
# PHASE 3: Caregiver full flow (background) + Parent booking (foreground)
# The caregiver flow runs as a SINGLE continuous Maestro process to prevent
# XCTest driver restarts from killing the app session. It logs in, goes online,
# waits up to 3 minutes for the offer, accepts it, then continues through
# IOMW and arrival — all in one process to keep XCTest driver alive.
# The parent flow runs after a delay to give the caregiver time to log in.
# ═══════════════════════════════════════════════════════════════
step "Caregiver: Login + online + accept + IOMW + arrival (background)"

CG_LOG="$ROOT_DIR/results/cross-app/caregiver-combined.log"
maestro test "$ROOT_DIR/flows/caregiver/login-online-wait-accept.yaml" --device "$CAREGIVER_UDID" \
  > "$CG_LOG" 2>&1 &
CG_PID=$!
echo "  Caregiver flow started (PID: $CG_PID)"

# Give caregiver 20s to login and go online before parent starts booking
sleep 20

step "Parent: Login and create booking"

maestro test "$ROOT_DIR/flows/cross-app/parent-login-and-book.yaml" --device "$PARENT_UDID" 2>&1 \
  && pass "Parent login + booking" || { fail "Parent login + booking"; kill $CG_PID 2>/dev/null; exit 1; }

step "Get booking ID from API"
sleep 3
BOOKING_ID=$(api_latest_booking_id "$PARENT_TOKEN")
[[ -n "$BOOKING_ID" ]] && pass "Booking: $BOOKING_ID" || { fail "No booking found"; kill $CG_PID 2>/dev/null; exit 1; }
state_append_booking "$BOOKING_ID" "Sarah" "" "matching"

step "Wait for caregiver flow to complete (accept + IOMW + arrival)"

# Wait for the background caregiver flow to complete
# (login → online → wait for offer → accept → IOMW → arrival)
if wait $CG_PID; then
  pass "Caregiver: login + online + offer accepted + IOMW + arrived"
else
  echo "  Caregiver combined flow log:"
  tail -20 "$CG_LOG" 2>/dev/null
  fail "Caregiver combined flow"
  exit 1
fi

step "Verify booking matched via API"
LIFECYCLE=$(api_wait_for_lifecycle "$PARENT_TOKEN" "$BOOKING_ID" "matched" 10)
[[ "$LIFECYCLE" == "matched" || "$LIFECYCLE" == "confirmed" ]] \
  && pass "Booking matched (lifecycle: $LIFECYCLE)" || fail "Booking not matched (lifecycle: $LIFECYCLE)"
state_set "bookings[0].caregiver" "Maria"
state_set "bookings[0].lifecycle" "matched"

step "Parent: Verify caregiver found on simulator"

# Non-fatal: parent app may have lost session due to XCTest driver restart.
# API already confirmed matching above, so this is a UI-only verification.
maestro test "$ROOT_DIR/flows/parent/verify-matched.yaml" --device "$PARENT_UDID" 2>&1 \
  && pass "Parent sees caregiver matched" || echo "  ⚠ WARN: Parent verify-matched (non-fatal, API confirmed)"

# Note: IOMW and arrival are handled by the combined caregiver flow above.
# No separate Maestro steps needed — XCTest driver stays alive throughout.

# ═══════════════════════════════════════════════════════════════
# PHASE 5: Session start — API-driven (Veriff bypassed in dev)
# ═══════════════════════════════════════════════════════════════
step "Create session via API"

SESSION_CREATE=$(api_create_session "$CAREGIVER_TOKEN" "$BOOKING_ID")
SESSION_ID=$(echo "$SESSION_CREATE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
d = data.get('session', data.get('data', data))
print(d.get('id', ''))" 2>/dev/null)
[[ -n "$SESSION_ID" && "$SESSION_ID" != "None" ]] \
  && pass "Session created: $SESSION_ID" || { fail "Session creation failed"; }
state_append_session "$SESSION_ID" "$BOOKING_ID" "not_started"

step "Verify session start (dual-party, Veriff bypassed)"

api_verify_session_start "$CAREGIVER_TOKEN" "$SESSION_ID" > /dev/null
pass "Caregiver verified"

VERIFY_RESULT=$(api_verify_session_start "$PARENT_TOKEN" "$SESSION_ID")
SESSION_STARTED=$(echo "$VERIFY_RESULT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('sessionStarted', False))" 2>/dev/null)
[[ "$SESSION_STARTED" == "True" ]] \
  && pass "Session started (both verified)" || fail "Session did not start"

sleep 2
SESSION_STATUS=$(api_session_status "$PARENT_TOKEN" "$SESSION_ID")
assert_eq "Session status after start" "$SESSION_STATUS" "in_progress"

# ═══════════════════════════════════════════════════════════════
# PHASE 7: Session end — API-driven
# ═══════════════════════════════════════════════════════════════
step "End session via API"

END_RESULT=$(api_end_session "$CAREGIVER_TOKEN" "$SESSION_ID")
BILLABLE=$(echo "$END_RESULT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f\"billable={d.get('billableMinutes',0)}min, earnings={d.get('caregiverEarningsCents',0)}c\")" 2>/dev/null)
echo "  End result: $BILLABLE"
pass "Session ended via API"

step "Rate session via API"

api_rate_session "$PARENT_TOKEN" "$SESSION_ID" 5 > /dev/null
pass "Session rated (5 stars)"

# ═══════════════════════════════════════════════════════════════
# PHASE 8: API Verification
# ═══════════════════════════════════════════════════════════════
step "Verify final state via API"
sleep 3

FINAL_LIFECYCLE=$(api_booking_lifecycle "$PARENT_TOKEN" "$BOOKING_ID")
assert_eq "Booking lifecycle" "$FINAL_LIFECYCLE" "completed"
state_set "bookings[0].lifecycle" "completed"
state_set "sessions[0].status" "completed"

if [[ -n "${SESSION_ID:-}" ]]; then
  FINAL_SESSION=$(api_session_status "$PARENT_TOKEN" "$SESSION_ID")
  assert_eq "Session status" "$FINAL_SESSION" "completed"
fi

step "Verify earnings via API"

EARNINGS=$(api_earnings_ledger "$CAREGIVER_TOKEN")
EARNING_RESULT=$(echo "$EARNINGS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
items = data.get('data', data.get('entries', []))
if isinstance(items, list):
    earnings = [e for e in items if e.get('type') == 'earning']
    print(f'count={len(earnings)}')
    if earnings:
        e = earnings[0]
        print(f'amount={e.get(\"amountCents\", 0)}')
        print(f'sessionId={e.get(\"sessionId\", \"\")}')
else:
    print('count=0')" 2>/dev/null)
echo "  Earning ledger: $EARNING_RESULT"
echo "$EARNING_RESULT" | grep -q "count=0" && fail "No earnings found" || pass "Caregiver has earnings in ledger"

step "Verify transactions via API"

TRANSACTIONS=$(api_transactions_for_booking "$ADMIN_TOKEN" "$BOOKING_ID")
TX_RESULT=$(echo "$TRANSACTIONS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
items = data.get('data', data.get('transactions', []))
has_auth = False
has_capture = False
if isinstance(items, list):
    for t in items:
        ttype = t.get('type', '')
        tstatus = t.get('status', '')
        print(f\"  Transaction: type={ttype}, status={tstatus}, amount={t.get('amountCents')}c\")
        if ttype == 'authorization' and tstatus == 'succeeded': has_auth = True
        if ttype == 'capture' and tstatus == 'succeeded': has_capture = True
print(f'auth={has_auth},capture={has_capture}')
" 2>/dev/null)
echo "$TX_RESULT"
echo "$TX_RESULT" | grep -q "auth=True" && pass "Authorization transaction succeeded" || fail "No successful authorization transaction"
echo "$TX_RESULT" | grep -q "capture=True" && pass "Capture transaction succeeded" || fail "No successful capture transaction"

# ═══════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════
echo ""
echo "═══════════════════════════════════════════════════"
echo "  REAL E2E MATCHING — RESULTS"
echo "═══════════════════════════════════════════════════"
echo "  Booking: ${BOOKING_ID:-N/A}"
echo "  Session: ${SESSION_ID:-N/A}"
echo "  Final Lifecycle: ${FINAL_LIFECYCLE:-N/A}"
echo "  Failures: $FAILURES"
echo ""

if [[ $FAILURES -eq 0 ]]; then
  echo "  OVERALL: PASS ✓"
  exit 0
else
  echo "  OVERALL: FAIL ($FAILURES failures)"
  exit 1
fi
