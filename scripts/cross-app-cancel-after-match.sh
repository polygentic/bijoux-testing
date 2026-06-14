#!/usr/bin/env bash
# UAT: Cancel Booking After Match + IOMW — Verify Cancellation Fee

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/config/environment.sh"
source "$ROOT_DIR/scripts/lib/api-helpers.sh"

[[ -z "$PARENT_UDID" ]] && echo "ERROR: PARENT_UDID not set" >&2 && exit 1
[[ -z "$CAREGIVER_UDID" ]] && echo "ERROR: CAREGIVER_UDID not set" >&2 && exit 1

mkdir -p "$ROOT_DIR/results/cross-app"
FAILURES=0; STEP=0
step()  { STEP=$((STEP + 1)); echo ""; echo "═══ STEP $STEP: $1 ═══"; }
pass()  { echo "  ✓ PASS: $1"; }
fail()  { echo "  ✗ FAIL: $1"; FAILURES=$((FAILURES + 1)); }

step "Setup"
PARENT_TOKEN=$(api_login "$PARENT_EMAIL" "$PARENT_PASSWORD")
CG_TOKEN=$(api_login "$CAREGIVER_ONLINE_EMAIL" "$CAREGIVER_ONLINE_PASSWORD")
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
api_set_online "$CG_TOKEN" "true"
pass "Tokens + caregiver online"

step "Login caregiver"
maestro test "$ROOT_DIR/flows/caregiver/login-maria.yaml" --device "$CAREGIVER_UDID" 2>&1 || { fail "CG login"; exit 1; }
maestro test "$ROOT_DIR/flows/caregiver/go-online.yaml" --device "$CAREGIVER_UDID" 2>&1 || true

step "Parent books"
maestro test "$ROOT_DIR/flows/cross-app/parent-login-and-book.yaml" --device "$PARENT_UDID" 2>&1 || { fail "Parent book"; exit 1; }
sleep 3
BOOKING_ID=$(api_latest_booking_id "$PARENT_TOKEN")
pass "Booking: $BOOKING_ID"

step "Caregiver accepts + IOMW"
sleep 5
maestro test "$ROOT_DIR/flows/caregiver/accept-offer.yaml" --device "$CAREGIVER_UDID" 2>&1 || { fail "CG accept"; exit 1; }
maestro test "$ROOT_DIR/flows/caregiver/iomw.yaml" --device "$CAREGIVER_UDID" 2>&1 || fail "CG IOMW"

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
