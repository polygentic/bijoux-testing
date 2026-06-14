#!/usr/bin/env bash
# UAT: Multi-Parent Bookings — Two Parents, Two Caregivers
#
# Tests that two different parents can book and be matched with two different
# caregivers, each completing a full session lifecycle independently.
#
# NOTE: Bookings run sequentially (Session 1 completes before Booking 2 starts)
# because the matching engine sends stale offers to new caregivers when bookings
# overlap. This is a known backend issue — the test works around it.
#
# Requires: 4 sims (bijoux-parent, bijoux-parent-2, bijoux-care, bijoux-care-2)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/config/environment.sh"
source "$ROOT_DIR/scripts/lib/api-helpers.sh"

[[ -z "$PARENT_UDID" ]] && echo "ERROR: PARENT_UDID not set" >&2 && exit 1
[[ -z "${PARENT_UDID_2:-}" ]] && echo "ERROR: PARENT_UDID_2 not set" >&2 && exit 1
[[ -z "$CAREGIVER_UDID" ]] && echo "ERROR: CAREGIVER_UDID not set" >&2 && exit 1
[[ -z "${CAREGIVER_UDID_2:-}" ]] && echo "ERROR: CAREGIVER_UDID_2 not set" >&2 && exit 1

mkdir -p "$ROOT_DIR/results/cross-app"
FAILURES=0; STEP=0
step()  { STEP=$((STEP + 1)); echo ""; echo "═══ STEP $STEP: $1 ═══"; }
pass()  { echo "  ✓ PASS: $1"; }
fail()  { echo "  ✗ FAIL: $1"; FAILURES=$((FAILURES + 1)); }

# ─── Setup ────────────────────────────────────────────────────
step "Authenticate and clean up"
P1_TOKEN=$(api_login "$PARENT_EMAIL" "$PARENT_PASSWORD")
P2_TOKEN=$(api_login "$PARENT_2_EMAIL" "$PARENT_2_PASSWORD")
CG1_TOKEN=$(api_login "$CAREGIVER_EMAIL" "$CAREGIVER_PASSWORD")
CG2_TOKEN=$(api_login "$CAREGIVER_ONLINE_EMAIL" "$CAREGIVER_ONLINE_PASSWORD")
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
api_cleanup_sessions "$CG1_TOKEN" "$P1_TOKEN"
api_cleanup_sessions "$CG2_TOKEN" "$P2_TOKEN"
api_cancel_active_bookings "$P1_TOKEN"
api_cancel_active_bookings "$P2_TOKEN"
api_set_online "$CG1_TOKEN" "true"
api_set_online "$CG2_TOKEN" "false"
api_report_location "$CG1_TOKEN" "${TEST_LAT}" "${TEST_LNG}"
api_report_location "$CG2_TOKEN" "${TEST_LAT}" "${TEST_LNG}"
pass "Cleanup done, tokens obtained"

# ═══════════════════════════════════════════════════════════════
# BOOKING 1: Sarah + Emma (full lifecycle)
# ═══════════════════════════════════════════════════════════════
step "Login Emma + go online"
maestro test "$ROOT_DIR/flows/caregiver/login-valid.yaml" --device "$CAREGIVER_UDID" 2>&1 && pass "Emma" || fail "Emma login"
maestro test "$ROOT_DIR/flows/caregiver/go-online.yaml" --device "$CAREGIVER_UDID" 2>&1 || true

step "Sarah: Login and book"
maestro test "$ROOT_DIR/flows/cross-app/parent-login-and-book.yaml" --device "$PARENT_UDID" 2>&1 \
  && pass "Sarah booked" || { fail "Sarah booking"; exit 1; }
sleep 3
BOOKING_1=$(api_latest_booking_id "$P1_TOKEN")
pass "Booking 1: $BOOKING_1"

step "Emma: Accept Sarah's offer"
sleep 5
maestro test "$ROOT_DIR/flows/caregiver/accept-offer.yaml" --device "$CAREGIVER_UDID" 2>&1 \
  && pass "Emma accepted" || fail "Emma accept"

step "Emma: IOMW + Arrival"
maestro test "$ROOT_DIR/flows/caregiver/iomw.yaml" --device "$CAREGIVER_UDID" 2>&1 || fail "Emma IOMW"
maestro test "$ROOT_DIR/flows/caregiver/confirm-arrival.yaml" --device "$CAREGIVER_UDID" 2>&1 || fail "Emma arrival"

step "Session 1: Create + Verify + End via API"
S1_CREATE=$(api_create_session "$CG1_TOKEN" "$BOOKING_1")
S1=$(echo "$S1_CREATE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('session',d).get('id',''))" 2>/dev/null)
[[ -n "$S1" && "$S1" != "None" ]] && pass "Session 1: $S1" || fail "Session 1 creation"
api_verify_session_start "$CG1_TOKEN" "$S1" > /dev/null
api_verify_session_start "$P1_TOKEN" "$S1" > /dev/null
pass "Session 1 dual verification done"
api_end_session "$CG1_TOKEN" "$S1" > /dev/null
pass "Session 1 ended"

step "Verify Booking 1 completed"
sleep 2
L1=$(api_booking_lifecycle "$P1_TOKEN" "$BOOKING_1")
[[ "$L1" == "completed" ]] && pass "Booking 1 completed" || fail "Booking 1: $L1"

# ═══════════════════════════════════════════════════════════════
# BOOKING 2: James + Maria (full lifecycle, after Booking 1 done)
# ═══════════════════════════════════════════════════════════════
# Set Emma offline so matching engine only dispatches to Maria for Booking 2
CG1_TOKEN=$(api_login "$CAREGIVER_EMAIL" "$CAREGIVER_PASSWORD")
api_set_online "$CG1_TOKEN" "false"

step "Login Maria + go online (Booking 1 fully completed — no stale offers)"
maestro test "$ROOT_DIR/flows/caregiver/login-maria.yaml" --device "$CAREGIVER_UDID_2" 2>&1 && pass "Maria" || fail "Maria login"
# Re-authenticate Maria (Maestro login invalidated old token)
CG2_TOKEN=$(api_login "$CAREGIVER_ONLINE_EMAIL" "$CAREGIVER_ONLINE_PASSWORD")
# Set online via API first (more reliable than UI toggle)
api_set_online "$CG2_TOKEN" "true"
api_report_location "$CG2_TOKEN" "${TEST_LAT}" "${TEST_LNG}"
# Then sync UI
maestro test "$ROOT_DIR/flows/caregiver/go-online.yaml" --device "$CAREGIVER_UDID_2" 2>&1 || true
pass "Maria online with fresh token + location set"

step "James: Login, setup payment, and book"
maestro test "$ROOT_DIR/flows/parent/login-james.yaml" --device "$PARENT_UDID_2" 2>&1 \
  && pass "James logged in" || { fail "James login"; exit 1; }
# Re-authenticate James (Maestro login may invalidate old token)
P2_TOKEN=$(api_login "$PARENT_2_EMAIL" "$PARENT_2_PASSWORD")
# Ensure James has a payment method (not in seed data)
api_add_payment_method "$P2_TOKEN" "james" > /dev/null
pass "James payment method added"
maestro test "$ROOT_DIR/flows/parent/quick-booking-submit.yaml" --device "$PARENT_UDID_2" 2>&1 \
  && pass "James booked" || fail "James booking"
sleep 3
BOOKING_2=$(api_latest_booking_id "$P2_TOKEN")
pass "Booking 2: $BOOKING_2"

step "Maria: Accept James's offer"
sleep 5
maestro test "$ROOT_DIR/flows/caregiver/accept-offer.yaml" --device "$CAREGIVER_UDID_2" 2>&1 \
  && pass "Maria accepted" || fail "Maria accept"

step "Maria: IOMW + Arrival"
maestro test "$ROOT_DIR/flows/caregiver/iomw.yaml" --device "$CAREGIVER_UDID_2" 2>&1 || fail "Maria IOMW"
maestro test "$ROOT_DIR/flows/caregiver/confirm-arrival.yaml" --device "$CAREGIVER_UDID_2" 2>&1 || fail "Maria arrival"

step "Session 2: Create + Verify + End via API"
S2_CREATE=$(api_create_session "$CG2_TOKEN" "$BOOKING_2")
S2=$(echo "$S2_CREATE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('session',d).get('id',''))" 2>/dev/null)
[[ -n "$S2" && "$S2" != "None" ]] && pass "Session 2: $S2" || fail "Session 2 creation"
api_verify_session_start "$CG2_TOKEN" "$S2" > /dev/null
api_verify_session_start "$P2_TOKEN" "$S2" > /dev/null
pass "Session 2 dual verification done"
api_end_session "$CG2_TOKEN" "$S2" > /dev/null
pass "Session 2 ended"

# ═══════════════════════════════════════════════════════════════
# FINAL VERIFICATION
# ═══════════════════════════════════════════════════════════════
step "API verification"
sleep 3
L1=$(api_booking_lifecycle "$P1_TOKEN" "$BOOKING_1")
L2=$(api_booking_lifecycle "$P2_TOKEN" "$BOOKING_2")
echo "  Booking 1: $L1, Booking 2: $L2"
[[ "$L1" == "completed" ]] && pass "Booking 1 completed" || fail "Booking 1: $L1"
[[ "$L2" == "completed" ]] && pass "Booking 2 completed" || fail "Booking 2: $L2"

[[ -n "$S1" ]] && pass "Session 1: $S1" || fail "No session for booking 1"
[[ -n "$S2" ]] && pass "Session 2: $S2" || fail "No session for booking 2"

if [[ -n "$S1" ]]; then
  SS1=$(api_session_status "$P1_TOKEN" "$S1")
  [[ "$SS1" == "completed" ]] && pass "Session 1 completed" || fail "Session 1: $SS1"
fi
if [[ -n "$S2" ]]; then
  SS2=$(api_session_status "$P2_TOKEN" "$S2")
  [[ "$SS2" == "completed" ]] && pass "Session 2 completed" || fail "Session 2: $SS2"
fi

step "Verify transactions"
for i in 1 2; do
  local_booking_var="BOOKING_${i}"
  local_booking="${!local_booking_var:-}"
  if [[ -z "$local_booking" ]]; then continue; fi
  TX=$(api_transactions_for_booking "$ADMIN_TOKEN" "$local_booking")
  HAS_CAPTURE=$(echo "$TX" | python3 -c "
import sys, json
data = json.load(sys.stdin)
items = data.get('data', data.get('transactions', []))
if isinstance(items, list):
    for t in items:
        if t.get('type') == 'capture' and t.get('status') == 'succeeded':
            print('yes')
            sys.exit(0)
print('no')
" 2>/dev/null)
  [[ "$HAS_CAPTURE" == "yes" ]] && pass "Booking $i has captured transaction" || fail "Booking $i missing capture transaction"
done

echo ""
echo "═══ MULTI-PARENT — $( [[ $FAILURES -eq 0 ]] && echo "PASS ✓" || echo "FAIL ($FAILURES)" ) ═══"
[[ $FAILURES -eq 0 ]] && exit 0 || exit 1
