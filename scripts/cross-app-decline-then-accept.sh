#!/usr/bin/env bash
# UAT: Multi-Caregiver — First Declines, Second Accepts
#
# Tests: Parent books → Emma declines → Maria accepts → IOMW → Arrival →
#        Session lifecycle via UI → Verify offer statuses
#
# Strategy: Broadcast model — both caregivers online, both get offers.
# Emma's flow starts FIRST and is already waiting when the offer arrives,
# so she declines before Maria (who starts later) can accept. Only acceptance
# cancels other offers; decline leaves them pending.
#
# Session lifecycle runs through the real UI (Maestro combined flows) on both
# Maria's simulator and the parent simulator concurrently.
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

# Parent runs combined flow: login → book → wait arrival → verify → session → end → rate
# Runs in background so Emma can decline and Maria can start concurrently.
step "Parent: Full lifecycle (login → rate → done) [background]"
P_LOG="$ROOT_DIR/results/cross-app/parent-decline-test.log"
maestro test "$ROOT_DIR/flows/parent/login-book-session-end.yaml" --device "$PARENT_UDID" \
  > "$P_LOG" 2>&1 &
P_PID=$!
echo "  Parent flow started (PID: $P_PID)"

# Poll for booking ID (not cancelled/completed from previous runs)
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
[[ -n "$BOOKING_ID" ]] && state_append_booking "$BOOKING_ID" "Sarah" "" "matching"

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
# PHASE 5: Maria full lifecycle — accept + IOMW + arrive + session → complete
# In the broadcast model, Emma's decline does NOT cancel Maria's offer.
# Maria runs the combined flow covering the full session lifecycle via UI.
# ═══════════════════════════════════════════════════════════════
step "Maria: Full lifecycle (login → session complete) [background]"
CG2_LOG="$ROOT_DIR/results/cross-app/caregiver-maria-accept.log"
maestro test "$ROOT_DIR/flows/caregiver/login-online-accept-session-end.yaml" --device "$CAREGIVER_UDID_2" \
  > "$CG2_LOG" 2>&1 &
CG2_PID=$!
echo "  Maria flow started (PID: $CG2_PID)"

step "Wait for both lifecycle flows to complete"
CG2_OK=true; P_OK=true

if ! wait $CG2_PID; then
  echo "  Maria lifecycle log:"
  tail -30 "$CG2_LOG" 2>/dev/null
  fail "Maria full lifecycle"
  CG2_OK=false
else
  pass "Maria: login → online → accept → IOMW → arrive → verify → session → end → done"
fi

if ! wait $P_PID; then
  echo "  Parent lifecycle log:"
  tail -30 "$P_LOG" 2>/dev/null
  fail "Parent full lifecycle"
  P_OK=false
else
  pass "Parent: login → book → arrival → verify → session → end → rate → done"
fi

[[ "$CG2_OK" == "false" || "$P_OK" == "false" ]] && exit 1

# ═══════════════════════════════════════════════════════════════
# PHASE 6: API Verification
# ═══════════════════════════════════════════════════════════════
step "Resolve booking and session IDs from API"
sleep 3
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
  && pass "Session: $SESSION_ID" || fail "Could not resolve session ID"

step "Verify final state"
FINAL=$(api_booking_lifecycle "$PARENT_TOKEN" "$BOOKING_ID")
echo "  Final lifecycle: $FINAL"
[[ "$FINAL" == "completed" ]] && pass "Booking completed" || fail "Booking not completed: $FINAL"
state_set "bookings[0].caregiver" "Maria"
state_set "bookings[0].lifecycle" "completed"

if [[ -n "${SESSION_ID:-}" && "$SESSION_ID" != "None" ]]; then
  FINAL_SESSION=$(api_session_status "$PARENT_TOKEN" "$SESSION_ID")
  [[ "$FINAL_SESSION" == "completed" ]] && pass "Session completed" || fail "Session not completed: $FINAL_SESSION"
fi

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
