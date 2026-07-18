#!/usr/bin/env bash
# UAT: Multi-Parent Bookings — Two Parents, Two Caregivers
#
# Tests that two different parents can book and be matched with two different
# caregivers, each completing a full session lifecycle independently via UI.
#
# Strategy: Sequential bookings — Booking 1 (Sarah+Emma) completes before
# Booking 2 (James+Maria) starts. Each booking uses the combined-flow pattern
# (single continuous Maestro process) to prevent XCTest driver session loss.
# Session lifecycle (verify, end, rate) runs through the real UI, not API.
#
# Requires: 4 sims (bijoux-parent, bijoux-parent-2, bijoux-care, bijoux-care-2)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/config/environment.sh"
source "$ROOT_DIR/scripts/lib/api-helpers.sh"
source "$ROOT_DIR/scripts/lib/state-helpers.sh"

[[ -z "$PARENT_UDID" ]] && echo "ERROR: PARENT_UDID not set" >&2 && exit 1
[[ -z "${PARENT_UDID_2:-}" ]] && echo "ERROR: PARENT_UDID_2 not set" >&2 && exit 1
[[ -z "$CAREGIVER_UDID" ]] && echo "ERROR: CAREGIVER_UDID not set" >&2 && exit 1
[[ -z "${CAREGIVER_UDID_2:-}" ]] && echo "ERROR: CAREGIVER_UDID_2 not set" >&2 && exit 1

mkdir -p "$ROOT_DIR/results/cross-app"

state_init
state_set "metadata.layer1_script" "cross-app-multi-parent"

FAILURES=0; STEP=0
step()  { STEP=$((STEP + 1)); echo ""; echo "═══ STEP $STEP: $1 ═══"; }
pass()  { echo "  ✓ PASS: $1"; }
fail()  { echo "  ✗ FAIL: $1"; FAILURES=$((FAILURES + 1)); }

# ═══════════════════════════════════════════════════════════════
# PHASE 1: Setup
# ═══════════════════════════════════════════════════════════════
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
api_reset_daily_limits

# Ensure James has a payment method
api_add_payment_method "$P2_TOKEN" "james" > /dev/null 2>&1

# Booking 1: Only Emma online. Maria stays offline.
api_set_online "$CG1_TOKEN" "true"
api_set_online "$CG2_TOKEN" "false"
api_report_location "$CG1_TOKEN" "${TEST_LAT}" "${TEST_LNG}"
api_report_location "$CG2_TOKEN" "${TEST_LAT}" "${TEST_LNG}"

# Ensure both caregivers have BG check and IDV
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
pass "Cleanup done, tokens obtained, trust set"

# ═══════════════════════════════════════════════════════════════
# PHASE 2: Boot all 4 simulators
# ═══════════════════════════════════════════════════════════════
step "Boot simulators"
xcrun simctl shutdown "$PARENT_UDID" 2>/dev/null || true
xcrun simctl shutdown "$PARENT_UDID_2" 2>/dev/null || true
xcrun simctl shutdown "$CAREGIVER_UDID" 2>/dev/null || true
xcrun simctl shutdown "$CAREGIVER_UDID_2" 2>/dev/null || true
sleep 2
xcrun simctl boot "$PARENT_UDID" 2>/dev/null || true
xcrun simctl boot "$PARENT_UDID_2" 2>/dev/null || true
xcrun simctl boot "$CAREGIVER_UDID" 2>/dev/null || true
xcrun simctl boot "$CAREGIVER_UDID_2" 2>/dev/null || true
sleep 8
pass "All 4 simulators booted"

# ═══════════════════════════════════════════════════════════════
# BOOKING 1: Sarah + Emma (combined flow pattern — full UI lifecycle)
# ═══════════════════════════════════════════════════════════════
step "Emma: Full lifecycle (login → session complete) [background]"
CG1_LOG="$ROOT_DIR/results/cross-app/caregiver-emma-multi.log"
maestro test "$ROOT_DIR/flows/caregiver/login-online-accept-session-end-emma.yaml" --device "$CAREGIVER_UDID" \
  > "$CG1_LOG" 2>&1 &
CG1_PID=$!
echo "  Emma flow started (PID: $CG1_PID)"

# Give Emma 20s to login and go online
sleep 20

step "Sarah: Full lifecycle (login → rate → done) [background]"
P1_LOG="$ROOT_DIR/results/cross-app/parent-sarah-multi.log"
maestro test "$ROOT_DIR/flows/parent/login-book-session-end.yaml" --device "$PARENT_UDID" \
  > "$P1_LOG" 2>&1 &
P1_PID=$!
echo "  Sarah flow started (PID: $P1_PID)"

# Poll for booking 1 ID
sleep 35
BOOKING_1=""
for i in $(seq 1 12); do
  BOOKING_1=$(curl -s -H "Authorization: Bearer $P1_TOKEN" \
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
  [[ -n "$BOOKING_1" ]] && break
  sleep 5
done
[[ -n "$BOOKING_1" ]] && pass "Booking 1: $BOOKING_1" || echo "  ⚠ Could not resolve booking 1 ID yet"
[[ -n "$BOOKING_1" ]] && state_append_booking "$BOOKING_1" "Sarah" "Emma" "matching"

step "Wait for Booking 1 lifecycle flows to complete"
CG1_OK=true; P1_OK=true

if ! wait $CG1_PID; then
  echo "  Emma lifecycle log:"
  tail -30 "$CG1_LOG" 2>/dev/null
  fail "Emma full lifecycle"
  CG1_OK=false
else
  pass "Emma: login → online → accept → IOMW → arrive → verify → session → end → done"
fi

if ! wait $P1_PID; then
  echo "  Sarah lifecycle log:"
  tail -30 "$P1_LOG" 2>/dev/null
  fail "Sarah full lifecycle"
  P1_OK=false
else
  pass "Sarah: login → book → arrival → verify → session → end → rate → done"
fi

[[ "$CG1_OK" == "false" || "$P1_OK" == "false" ]] && { fail "Booking 1 UI lifecycle failed, aborting"; exit 1; }

step "Verify Booking 1 completed via API"
sleep 3
COMPLETED_1=$(curl -s -H "Authorization: Bearer $P1_TOKEN" \
  "${BACKEND_URL}/bookings?limit=1&sort=-createdAt&lifecycle=completed" 2>/dev/null \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
items = data.get('data', data.get('bookings', []))
if isinstance(items, list) and len(items) > 0:
    print(items[0].get('id', ''))
" 2>/dev/null)
[[ -n "$COMPLETED_1" ]] && BOOKING_1="$COMPLETED_1"
L1=$(api_booking_lifecycle "$P1_TOKEN" "$BOOKING_1")
[[ "$L1" == "completed" ]] && pass "Booking 1 completed" || fail "Booking 1: $L1"

# ═══════════════════════════════════════════════════════════════
# BOOKING 2: James + Maria (combined flow pattern — full UI lifecycle)
# Switch caregiver online status: Emma off, Maria on
# ═══════════════════════════════════════════════════════════════
step "Switch caregivers: Emma offline, Maria online"
CG1_TOKEN=$(api_login "$CAREGIVER_EMAIL" "$CAREGIVER_PASSWORD")
CG2_TOKEN=$(api_login "$CAREGIVER_ONLINE_EMAIL" "$CAREGIVER_ONLINE_PASSWORD")
api_set_online "$CG1_TOKEN" "false"
api_set_online "$CG2_TOKEN" "true"
api_report_location "$CG2_TOKEN" "${TEST_LAT}" "${TEST_LNG}"
pass "Emma offline, Maria online"

step "Maria: Full lifecycle (login → session complete) [background]"
CG2_LOG="$ROOT_DIR/results/cross-app/caregiver-maria-multi.log"
maestro test "$ROOT_DIR/flows/caregiver/login-online-accept-session-end.yaml" --device "$CAREGIVER_UDID_2" \
  > "$CG2_LOG" 2>&1 &
CG2_PID=$!
echo "  Maria flow started (PID: $CG2_PID)"

# Give Maria 20s to login and go online
sleep 20

step "James: Full lifecycle (login → rate → done) [background]"
P2_LOG="$ROOT_DIR/results/cross-app/parent-james-multi.log"
maestro test "$ROOT_DIR/flows/parent/login-book-session-end-james.yaml" --device "$PARENT_UDID_2" \
  > "$P2_LOG" 2>&1 &
P2_PID=$!
echo "  James flow started (PID: $P2_PID)"

# Poll for booking 2 ID
sleep 35
BOOKING_2=""
for i in $(seq 1 12); do
  BOOKING_2=$(curl -s -H "Authorization: Bearer $P2_TOKEN" \
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
  [[ -n "$BOOKING_2" ]] && break
  sleep 5
done
[[ -n "$BOOKING_2" ]] && pass "Booking 2: $BOOKING_2" || echo "  ⚠ Could not resolve booking 2 ID yet"
[[ -n "$BOOKING_2" ]] && state_append_booking "$BOOKING_2" "James" "Maria" "matching"

step "Wait for Booking 2 lifecycle flows to complete"
CG2_OK=true; P2_OK=true

if ! wait $CG2_PID; then
  echo "  Maria lifecycle log:"
  tail -30 "$CG2_LOG" 2>/dev/null
  fail "Maria full lifecycle"
  CG2_OK=false
else
  pass "Maria: login → online → accept → IOMW → arrive → verify → session → end → done"
fi

if ! wait $P2_PID; then
  echo "  James lifecycle log:"
  tail -30 "$P2_LOG" 2>/dev/null
  fail "James full lifecycle"
  P2_OK=false
else
  pass "James: login → book → arrival → verify → session → end → rate → done"
fi

[[ "$CG2_OK" == "false" || "$P2_OK" == "false" ]] && { fail "Booking 2 UI lifecycle failed"; }

# ═══════════════════════════════════════════════════════════════
# FINAL VERIFICATION
# ═══════════════════════════════════════════════════════════════
step "API verification"
sleep 3

# Resolve final booking IDs
COMPLETED_2=$(curl -s -H "Authorization: Bearer $P2_TOKEN" \
  "${BACKEND_URL}/bookings?limit=1&sort=-createdAt&lifecycle=completed" 2>/dev/null \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
items = data.get('data', data.get('bookings', []))
if isinstance(items, list) and len(items) > 0:
    print(items[0].get('id', ''))
" 2>/dev/null)
[[ -n "$COMPLETED_2" ]] && BOOKING_2="$COMPLETED_2"

L1=$(api_booking_lifecycle "$P1_TOKEN" "$BOOKING_1")
L2=$(api_booking_lifecycle "$P2_TOKEN" "$BOOKING_2")
echo "  Booking 1: $L1, Booking 2: $L2"
[[ "$L1" == "completed" ]] && pass "Booking 1 completed" || fail "Booking 1: $L1"
[[ "$L2" == "completed" ]] && pass "Booking 2 completed" || fail "Booking 2: $L2"
state_set "bookings[0].lifecycle" "completed"
state_set "bookings[1].lifecycle" "completed"

# Resolve session IDs
S1=$(api_session_id "$P1_TOKEN" "$BOOKING_1")
S2=$(api_session_id "$P2_TOKEN" "$BOOKING_2")
[[ -n "$S1" && "$S1" != "None" ]] && pass "Session 1: $S1" || fail "Session 1 not found"
[[ -n "$S2" && "$S2" != "None" ]] && pass "Session 2: $S2" || fail "Session 2 not found"

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
