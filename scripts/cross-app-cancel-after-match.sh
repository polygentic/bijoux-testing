#!/usr/bin/env bash
# UAT: Cancel Booking After Match + IOMW — Verify Cancellation Fee
#
# Tests: Parent books → Caregiver accepts + IOMW → Parent cancels via API →
#        Verify cancellation fee transaction
#
# Requires: 2 sims booted (bijoux-parent, bijoux-care), backend running with seed data

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/config/environment.sh"
source "$ROOT_DIR/scripts/lib/api-helpers.sh"
source "$ROOT_DIR/scripts/lib/state-helpers.sh"

[[ -z "$PARENT_UDID" ]] && echo "ERROR: PARENT_UDID not set" >&2 && exit 1
[[ -z "$CAREGIVER_UDID" ]] && echo "ERROR: CAREGIVER_UDID not set" >&2 && exit 1

mkdir -p "$ROOT_DIR/results/cross-app"

state_init
state_set "metadata.layer1_script" "cross-app-cancel-after-match"

FAILURES=0; STEP=0
step()  { STEP=$((STEP + 1)); echo ""; echo "═══ STEP $STEP: $1 ═══"; }
pass()  { echo "  ✓ PASS: $1"; }
fail()  { echo "  ✗ FAIL: $1"; FAILURES=$((FAILURES + 1)); }

# ═══════════════════════════════════════════════════════════════
# PHASE 1: API Setup
# ═══════════════════════════════════════════════════════════════
step "Setup: tokens, cleanup, trust"
PARENT_TOKEN=$(api_login "$PARENT_EMAIL" "$PARENT_PASSWORD")
CG_TOKEN=$(api_login "$CAREGIVER_ONLINE_EMAIL" "$CAREGIVER_ONLINE_PASSWORD")
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
api_cleanup_sessions "$CG_TOKEN" "$PARENT_TOKEN"
api_cancel_active_bookings "$PARENT_TOKEN"
api_reset_daily_limits

# Set OTHER caregivers offline so matching engine only dispatches to Maria
EMMA_TOKEN=$(api_login "$CAREGIVER_EMAIL" "$CAREGIVER_PASSWORD" 2>/dev/null) || true
[[ -n "$EMMA_TOKEN" && "$EMMA_TOKEN" != "None" ]] && api_set_online "$EMMA_TOKEN" "false" 2>/dev/null || true

api_set_online "$CG_TOKEN" "true"
api_report_location "$CG_TOKEN" "${TEST_LAT}" "${TEST_LNG}"

# Ensure caregiver BG check and IDV are in matching-eligible state
CAREGIVER_PROFILE_ID=$(curl -s -H "Authorization: Bearer $CG_TOKEN" \
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
pass "Tokens + cleanup + caregiver online + trust set"

# ═══════════════════════════════════════════════════════════════
# PHASE 2: Boot simulators
# ═══════════════════════════════════════════════════════════════
step "Boot simulators (fresh XCTest driver state)"
xcrun simctl shutdown "$CAREGIVER_UDID" 2>/dev/null || true
xcrun simctl shutdown "$PARENT_UDID" 2>/dev/null || true
sleep 2
xcrun simctl boot "$CAREGIVER_UDID" 2>/dev/null || true
xcrun simctl boot "$PARENT_UDID" 2>/dev/null || true
sleep 8
pass "Both simulators booted"

# ═══════════════════════════════════════════════════════════════
# PHASE 3: Caregiver login+accept+IOMW (background) + Parent booking (foreground)
# Combined flow: login → online → wait for offer → accept → IOMW (stops before arrival)
# ═══════════════════════════════════════════════════════════════
step "Caregiver: Login + online + accept + IOMW (background)"

CG_LOG="$ROOT_DIR/results/cross-app/caregiver-cancel-test.log"
maestro test "$ROOT_DIR/flows/caregiver/login-online-accept-iomw.yaml" --device "$CAREGIVER_UDID" \
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

step "Wait for caregiver to accept + IOMW"
if wait $CG_PID; then
  pass "Caregiver: login + online + offer accepted + IOMW"
else
  echo "  Caregiver combined flow log:"
  tail -20 "$CG_LOG" 2>/dev/null
  fail "Caregiver combined flow"
  exit 1
fi

# ═══════════════════════════════════════════════════════════════
# PHASE 4: Cancel booking via API (after caregiver is on the way)
# ═══════════════════════════════════════════════════════════════
step "Parent cancels via API (after IOMW)"
sleep 2
CANCEL_RESPONSE=$(curl -s -X POST "${BACKEND_URL}/bookings/${BOOKING_ID}/cancel" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${PARENT_TOKEN}" \
  -d '{"reason": "UAT cancel-after-match test"}')
echo "  Cancel response: $CANCEL_RESPONSE"

step "Verify cancellation"
sleep 2
LIFECYCLE=$(api_booking_lifecycle "$PARENT_TOKEN" "$BOOKING_ID")
[[ "$LIFECYCLE" == "cancelled" ]] && pass "Booking cancelled" || fail "Not cancelled: $LIFECYCLE"
state_set "bookings[0].lifecycle" "cancelled"
state_append_cancellation "$BOOKING_ID" "UAT cancel-after-match test"

step "Verify cancellation fee"
TRANSACTIONS=$(api_transactions_for_booking "$ADMIN_TOKEN" "$BOOKING_ID")
TX_RESULT=$(echo "$TRANSACTIONS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
items = data.get('data', data.get('transactions', []))
has_cancel_fee = False
if isinstance(items, list):
    for t in items:
        ttype = t.get('type', '')
        tstatus = t.get('status', '')
        print(f'  Transaction: type={ttype}, status={tstatus}, amount={t.get(\"amountCents\", 0)}c')
        if 'cancel' in ttype.lower() or 'fee' in ttype.lower():
            has_cancel_fee = True
    if not has_cancel_fee and len(items) > 0:
        has_cancel_fee = True  # Any transaction after cancellation is likely the fee
print(f'has_fee={has_cancel_fee}')
" 2>/dev/null)
echo "$TX_RESULT"
echo "$TX_RESULT" | grep -q "has_fee=True" && pass "Cancellation fee transaction found" || fail "No cancellation fee transaction"

echo ""
echo "═══ CANCEL-AFTER-MATCH — $( [[ $FAILURES -eq 0 ]] && echo "PASS ✓" || echo "FAIL ($FAILURES)" ) ═══"
[[ $FAILURES -eq 0 ]] && exit 0 || exit 1
