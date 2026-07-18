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
# PHASE 3: Full lifecycle via UI — both apps as combined flows
#
# Each app runs its ENTIRE lifecycle as a single continuous Maestro process
# to prevent XCTest driver restarts from losing app state:
#   Caregiver: login → online → accept → IOMW → arrive → verify → session → end → complete
#   Parent:    login → book → wait for arrival → verify → session → end → rate → done
#
# Caregiver starts first (background) to be online before parent books.
# Parent starts 20s later. Both continue through session lifecycle concurrently.
# ═══════════════════════════════════════════════════════════════
step "Caregiver: Full lifecycle (login → session complete) [background]"

CG_LOG="$ROOT_DIR/results/cross-app/caregiver-full-lifecycle.log"
maestro test "$ROOT_DIR/flows/caregiver/login-online-accept-session-end.yaml" --device "$CAREGIVER_UDID" \
  > "$CG_LOG" 2>&1 &
CG_PID=$!
echo "  Caregiver flow started (PID: $CG_PID)"

# Give caregiver 20s to login and go online before parent starts
sleep 20

step "Parent: Full lifecycle (login → rate → done) [background]"

P_LOG="$ROOT_DIR/results/cross-app/parent-full-lifecycle.log"
maestro test "$ROOT_DIR/flows/parent/login-book-session-end.yaml" --device "$PARENT_UDID" \
  > "$P_LOG" 2>&1 &
P_PID=$!
echo "  Parent flow started (PID: $P_PID)"

# Poll for an active booking ID (not cancelled/completed from previous runs)
step "Get booking ID from API"
sleep 35
BOOKING_ID=""
for i in $(seq 1 12); do
  BOOKING_ID=$(curl -s -H "Authorization: Bearer $PARENT_TOKEN" \
    "${BACKEND_URL}/bookings?limit=5&sort=-createdAt" 2>/dev/null \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
items = data.get('data', data.get('bookings', []))
for b in items:
    lc = b.get('lifecycle', '')
    if lc not in ('cancelled', 'completed', ''):
        print(b.get('id', ''))
        break
" 2>/dev/null)
  [[ -n "$BOOKING_ID" ]] && break
  sleep 5
done
[[ -n "$BOOKING_ID" ]] && pass "Booking: $BOOKING_ID" || echo "  ⚠ Could not resolve booking ID yet"
[[ -n "$BOOKING_ID" ]] && state_append_booking "$BOOKING_ID" "Sarah" "Maria" "matching"

step "Wait for both lifecycle flows to complete"

CG_OK=true; P_OK=true

if ! wait $CG_PID; then
  echo "  Caregiver lifecycle log:"
  tail -30 "$CG_LOG" 2>/dev/null
  fail "Caregiver full lifecycle"
  CG_OK=false
else
  pass "Caregiver: login → online → accept → IOMW → arrive → verify → session → end → done"
fi

if ! wait $P_PID; then
  echo "  Parent lifecycle log:"
  tail -30 "$P_LOG" 2>/dev/null
  fail "Parent full lifecycle"
  P_OK=false
else
  pass "Parent: login → book → arrival → verify → session → end → rate → done"
fi

[[ "$CG_OK" == "false" || "$P_OK" == "false" ]] && exit 1

step "Resolve booking and session IDs from API"
sleep 3
# After both flows complete, find the most recently completed booking
COMPLETED_BOOKING=$(curl -s -H "Authorization: Bearer $PARENT_TOKEN" \
  "${BACKEND_URL}/bookings?limit=1&sort=-createdAt&lifecycle=completed" 2>/dev/null \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
items = data.get('data', data.get('bookings', []))
if isinstance(items, list) and len(items) > 0:
    print(items[0].get('id', ''))
" 2>/dev/null)
[[ -n "$COMPLETED_BOOKING" ]] && BOOKING_ID="$COMPLETED_BOOKING"
[[ -z "${BOOKING_ID:-}" ]] && BOOKING_ID=$(api_latest_booking_id "$PARENT_TOKEN")
[[ -n "$BOOKING_ID" ]] && pass "Booking: $BOOKING_ID" || fail "No booking found"

SESSION_ID=$(api_session_id "$PARENT_TOKEN" "$BOOKING_ID")
[[ -n "$SESSION_ID" && "$SESSION_ID" != "None" ]] \
  && pass "Session: $SESSION_ID" || { fail "Could not resolve session ID"; }
state_append_session "$SESSION_ID" "$BOOKING_ID" "completed"

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
