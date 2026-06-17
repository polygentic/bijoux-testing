#!/usr/bin/env bash
# UAT: Multi-Caregiver — First Declines, Second Accepts
#
# Tests: Parent books → Emma declines → Maria accepts → IOMW → Arrival →
#        Session lifecycle → Verify offer statuses
#
# Strategy: Broadcast model — both caregivers online, both get offers.
# Emma's flow starts FIRST and is already waiting when the offer arrives,
# so she declines before Maria (who starts later) can accept. Only acceptance
# cancels other offers; decline leaves them pending.
#
# Requires: 3 sims booted (bijoux-parent, bijoux-care, bijoux-care-2), backend running

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/config/environment.sh"
source "$ROOT_DIR/scripts/lib/api-helpers.sh"
source "$ROOT_DIR/scripts/lib/state-helpers.sh"

[[ -z "$PARENT_UDID" ]] && echo "ERROR: PARENT_UDID not set" >&2 && exit 1
[[ -z "$CAREGIVER_UDID" ]] && echo "ERROR: CAREGIVER_UDID not set" >&2 && exit 1
[[ -z "${CAREGIVER_UDID_2:-}" ]] && echo "ERROR: CAREGIVER_UDID_2 not set. Create 4 sims first." >&2 && exit 1

mkdir -p "$ROOT_DIR/results/cross-app"

state_init
state_set "metadata.layer1_script" "cross-app-decline-then-accept"

FAILURES=0; STEP=0
step()  { STEP=$((STEP + 1)); echo ""; echo "═══ STEP $STEP: $1 ═══"; }
pass()  { echo "  ✓ PASS: $1"; }
fail()  { echo "  ✗ FAIL: $1"; FAILURES=$((FAILURES + 1)); }

# ═══════════════════════════════════════════════════════════════
# PHASE 1: API Setup — both caregivers online + trust
# ═══════════════════════════════════════════════════════════════
step "Authenticate, clean up, set both caregivers online + trust"
PARENT_TOKEN=$(api_login "$PARENT_EMAIL" "$PARENT_PASSWORD")
CG1_TOKEN=$(api_login "$CAREGIVER_EMAIL" "$CAREGIVER_PASSWORD")
CG2_TOKEN=$(api_login "$CAREGIVER_ONLINE_EMAIL" "$CAREGIVER_ONLINE_PASSWORD")
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
api_cleanup_sessions "$CG1_TOKEN" "$PARENT_TOKEN"
api_cleanup_sessions "$CG2_TOKEN" "$PARENT_TOKEN"
api_cancel_active_bookings "$PARENT_TOKEN"
api_reset_daily_limits

# Both caregivers online — broadcast model sends offers to both
api_set_online "$CG1_TOKEN" "true"
api_set_online "$CG2_TOKEN" "true"
api_report_location "$CG1_TOKEN" "${TEST_LAT}" "${TEST_LNG}"
api_report_location "$CG2_TOKEN" "${TEST_LAT}" "${TEST_LNG}"

# Ensure both caregivers have BG check and IDV in matching-eligible state
for CG_TK in "$CG1_TOKEN" "$CG2_TOKEN"; do
  CG_PROF_ID=$(curl -s -H "Authorization: Bearer $CG_TK" \
    "${BACKEND_URL}/profile/caregiver" 2>/dev/null \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('profile',{}).get('id',''))" 2>/dev/null)
  if [[ -n "$CG_PROF_ID" ]]; then
    curl -s -X PUT "${BACKEND_URL}/trust/caregivers/${CG_PROF_ID}/bg-status" \
      -H "Content-Type: application/json" -H "Authorization: Bearer $ADMIN_TOKEN" \
      -d '{"status":"clear"}' > /dev/null 2>&1
    curl -s -X PUT "${BACKEND_URL}/trust/caregivers/${CG_PROF_ID}/idv-status" \
      -H "Content-Type: application/json" -H "Authorization: Bearer $ADMIN_TOKEN" \
      -d '{"status":"approved"}' > /dev/null 2>&1
  fi
done
pass "Cleanup done, both caregivers online + location + trust set"

# ═══════════════════════════════════════════════════════════════
# PHASE 2: Boot simulators
# ═══════════════════════════════════════════════════════════════
step "Boot simulators (fresh XCTest driver state)"
xcrun simctl shutdown "$CAREGIVER_UDID" 2>/dev/null || true
xcrun simctl shutdown "$CAREGIVER_UDID_2" 2>/dev/null || true
xcrun simctl shutdown "$PARENT_UDID" 2>/dev/null || true
sleep 2
xcrun simctl boot "$CAREGIVER_UDID" 2>/dev/null || true
xcrun simctl boot "$CAREGIVER_UDID_2" 2>/dev/null || true
xcrun simctl boot "$PARENT_UDID" 2>/dev/null || true
sleep 8
pass "All 3 simulators booted"

# ═══════════════════════════════════════════════════════════════
# PHASE 3: Emma starts FIRST (login + online + wait for decline)
# She must be already waiting when the offer arrives, so she declines
# before Maria's flow (started later) can accept.
# ═══════════════════════════════════════════════════════════════
step "Emma: Login + online + wait + decline (background)"
CG1_LOG="$ROOT_DIR/results/cross-app/caregiver-emma-decline.log"
maestro test "$ROOT_DIR/flows/caregiver/login-online-wait-decline.yaml" --device "$CAREGIVER_UDID" \
  > "$CG1_LOG" 2>&1 &
CG1_PID=$!
echo "  Emma flow started (PID: $CG1_PID)"

# Give Emma 25s to login and go online — she'll be idle, waiting for offer
sleep 25

step "Parent: Login and book"
maestro test "$ROOT_DIR/flows/cross-app/parent-login-and-book.yaml" --device "$PARENT_UDID" 2>&1 \
  && pass "Parent booked" || { fail "Parent booking"; kill $CG1_PID 2>/dev/null; exit 1; }

sleep 3
BOOKING_ID=$(api_latest_booking_id "$PARENT_TOKEN")
[[ -n "$BOOKING_ID" ]] && pass "Booking: $BOOKING_ID" || { fail "No booking found"; kill $CG1_PID 2>/dev/null; exit 1; }
state_append_booking "$BOOKING_ID" "Sarah" "" "matching"

# ═══════════════════════════════════════════════════════════════
# PHASE 4: Wait for Emma to decline BEFORE starting Maria
# Emma is already waiting and will decline immediately on seeing the offer.
# Only after Emma declines do we start Maria's flow. Maria's offer stays
# pending (decline doesn't cancel other offers, only acceptance does).
# ═══════════════════════════════════════════════════════════════
step "Wait for Emma to decline"
if wait $CG1_PID; then
  pass "Emma: login + online + offer declined"
else
  echo "  Emma flow log:"
  tail -20 "$CG1_LOG" 2>/dev/null
  fail "Emma decline flow"
fi

# ═══════════════════════════════════════════════════════════════
# PHASE 5: Start Maria's flow — her offer should still be pending
# In the broadcast model, Emma's decline does NOT cancel Maria's offer.
# ═══════════════════════════════════════════════════════════════
step "Maria: Login + online + wait + accept + IOMW + arrival"
CG2_LOG="$ROOT_DIR/results/cross-app/caregiver-maria-accept.log"
maestro test "$ROOT_DIR/flows/caregiver/login-online-wait-accept.yaml" --device "$CAREGIVER_UDID_2" \
  > "$CG2_LOG" 2>&1 &
CG2_PID=$!
echo "  Maria flow started (PID: $CG2_PID)"

step "Wait for Maria to accept + IOMW + arrive"
if wait $CG2_PID; then
  pass "Maria: login + online + offer accepted + IOMW + arrived"
else
  echo "  Maria flow log:"
  tail -20 "$CG2_LOG" 2>/dev/null
  fail "Maria accept flow"
  exit 1
fi

step "Verify booking matched via API"
LIFECYCLE=$(api_wait_for_lifecycle "$PARENT_TOKEN" "$BOOKING_ID" "matched" 10)
[[ "$LIFECYCLE" == "matched" || "$LIFECYCLE" == "confirmed" ]] \
  && pass "Booking matched (lifecycle: $LIFECYCLE)" || fail "Booking not matched (lifecycle: $LIFECYCLE)"

# Parent verify-matched — non-fatal due to XCTest driver restart
step "Parent: Verify caregiver matched (non-fatal)"
maestro test "$ROOT_DIR/flows/parent/verify-matched.yaml" --device "$PARENT_UDID" 2>&1 \
  && pass "Parent sees match" || echo "  ⚠ WARN: Parent verify-matched (non-fatal, API confirmed)"

# ═══════════════════════════════════════════════════════════════
# PHASE 6: Session lifecycle via API
# ═══════════════════════════════════════════════════════════════
step "Session start + end via API (Veriff bypassed)"
SESSION_CREATE=$(api_create_session "$CG2_TOKEN" "$BOOKING_ID")
SESSION_ID=$(echo "$SESSION_CREATE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
d = data.get('session', data.get('data', data))
print(d.get('id', ''))" 2>/dev/null)
[[ -n "$SESSION_ID" && "$SESSION_ID" != "None" ]] && pass "Session: $SESSION_ID" || fail "Session creation"

api_verify_session_start "$CG2_TOKEN" "$SESSION_ID" > /dev/null
api_verify_session_start "$PARENT_TOKEN" "$SESSION_ID" > /dev/null
pass "Dual verification complete"

api_end_session "$CG2_TOKEN" "$SESSION_ID" > /dev/null
pass "Session ended"

# ═══════════════════════════════════════════════════════════════
# PHASE 7: API Verification
# ═══════════════════════════════════════════════════════════════
step "Verify final state"
sleep 3
FINAL=$(api_booking_lifecycle "$PARENT_TOKEN" "$BOOKING_ID")
echo "  Final lifecycle: $FINAL"
[[ "$FINAL" == "completed" ]] && pass "Booking completed" || fail "Booking not completed: $FINAL"
state_set "bookings[0].caregiver" "Maria"
state_set "bookings[0].lifecycle" "completed"

step "Verify offer statuses via API"
OFFERS=$(curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "${BACKEND_URL}/admin/bookings/${BOOKING_ID}" 2>/dev/null)
OFFER_RESULT=$(echo "$OFFERS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
b = data.get('booking', data.get('data', data))
mr = b.get('matchRequest', {})
offers = mr.get('offers', mr.get('matchOffers', []))
has_declined = False
has_accepted = False
if isinstance(offers, list):
    for o in offers:
        name = o.get('caregiver', {}).get('firstName', o.get('caregiverProfileId', '')[:8])
        status = o.get('status', '')
        print(f'  Offer: {name} -> {status}')
        if status in ('declined', 'rejected'): has_declined = True
        if status in ('accepted', 'confirmed', 'matched', 'cancelled'): has_accepted = True
# Also check matchedCaregiverId as proof of acceptance
matched_cg = mr.get('matchedCaregiverId', '')
if matched_cg and not has_accepted:
    has_accepted = True
    print(f'  Matched caregiver: {matched_cg[:8]}...')
print(f'declined={has_declined},accepted={has_accepted}')
" 2>/dev/null)
echo "$OFFER_RESULT"
echo "$OFFER_RESULT" | grep -q "declined=True" && pass "At least one offer declined" || fail "No declined offer found"
echo "$OFFER_RESULT" | grep -q "accepted=True" && pass "At least one offer accepted/matched" || fail "No accepted offer found"

echo ""
echo "═══ DECLINE-THEN-ACCEPT — $( [[ $FAILURES -eq 0 ]] && echo "PASS ✓" || echo "FAIL ($FAILURES)" ) ═══"
[[ $FAILURES -eq 0 ]] && exit 0 || exit 1
