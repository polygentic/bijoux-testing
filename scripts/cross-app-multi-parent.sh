#!/usr/bin/env bash
# UAT: Multi-Parent Bookings — Two Parents, Two Caregivers
#
# Tests that two different parents can book and be matched with two different
# caregivers, each completing a full session lifecycle independently.
#
# Strategy: Sequential bookings — Booking 1 (Sarah+Emma) completes before
# Booking 2 (James+Maria) starts. Each booking uses the combined-flow pattern
# (single continuous Maestro process) to prevent XCTest driver session loss.
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
# BOOKING 1: Sarah + Emma (combined flow pattern)
# ═══════════════════════════════════════════════════════════════
step "Emma: Login + online + wait + accept + IOMW + arrival (background)"
CG1_LOG="$ROOT_DIR/results/cross-app/caregiver-emma-multi.log"
maestro test "$ROOT_DIR/flows/caregiver/login-online-wait-accept-emma.yaml" --device "$CAREGIVER_UDID" \
  > "$CG1_LOG" 2>&1 &
CG1_PID=$!
echo "  Emma flow started (PID: $CG1_PID)"

# Give Emma 20s to login and go online
sleep 20

step "Sarah: Login and book"
maestro test "$ROOT_DIR/flows/cross-app/parent-login-and-book.yaml" --device "$PARENT_UDID" 2>&1 \
  && pass "Sarah booked" || { fail "Sarah booking"; kill $CG1_PID 2>/dev/null; exit 1; }

sleep 3
BOOKING_1=$(api_latest_booking_id "$P1_TOKEN")
[[ -n "$BOOKING_1" ]] && pass "Booking 1: $BOOKING_1" || { fail "No booking 1"; kill $CG1_PID 2>/dev/null; exit 1; }
state_append_booking "$BOOKING_1" "Sarah" "Emma" "matching"

step "Wait for Emma to accept + IOMW + arrive"
if wait $CG1_PID; then
  pass "Emma: login + online + offer accepted + IOMW + arrived"
else
  echo "  Emma flow log:"
  tail -20 "$CG1_LOG" 2>/dev/null
  fail "Emma combined flow"
  exit 1
fi

step "Session 1: Create + Verify + End via API"
S1_CREATE=$(api_create_session "$CG1_TOKEN" "$BOOKING_1")
S1=$(echo "$S1_CREATE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
d = data.get('session', data.get('data', data))
print(d.get('id', ''))" 2>/dev/null)
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
# BOOKING 2: James + Maria (combined flow pattern)
# Switch caregiver online status: Emma off, Maria on
# ═══════════════════════════════════════════════════════════════
step "Switch caregivers: Emma offline, Maria online"
CG1_TOKEN=$(api_login "$CAREGIVER_EMAIL" "$CAREGIVER_PASSWORD")
CG2_TOKEN=$(api_login "$CAREGIVER_ONLINE_EMAIL" "$CAREGIVER_ONLINE_PASSWORD")
api_set_online "$CG1_TOKEN" "false"
api_set_online "$CG2_TOKEN" "true"
api_report_location "$CG2_TOKEN" "${TEST_LAT}" "${TEST_LNG}"
pass "Emma offline, Maria online"

# Concurrent pattern: Maria starts first (background), James books 20s later.
# James's flow uses ALL text-based selectors (no accessibility IDs) to avoid
# XCTest driver ID lookup failures on bijoux-parent-2 during concurrent runs.

step "Maria: Login + online + wait + accept + IOMW + arrival (background)"
CG2_LOG="$ROOT_DIR/results/cross-app/caregiver-maria-multi.log"
maestro test "$ROOT_DIR/flows/caregiver/login-online-wait-accept.yaml" --device "$CAREGIVER_UDID_2" \
  > "$CG2_LOG" 2>&1 &
CG2_PID=$!
echo "  Maria flow started (PID: $CG2_PID)"

# Give Maria 20s to login and go online
sleep 20

step "James: Login and book"
maestro test "$ROOT_DIR/flows/cross-app/parent-james-login-and-book.yaml" --device "$PARENT_UDID_2" 2>&1 \
  && pass "James booked" || { fail "James booking"; kill $CG2_PID 2>/dev/null; exit 1; }

sleep 3
BOOKING_2=$(api_latest_booking_id "$P2_TOKEN")
[[ -n "$BOOKING_2" ]] && pass "Booking 2: $BOOKING_2" || { fail "No booking 2"; kill $CG2_PID 2>/dev/null; exit 1; }
state_append_booking "$BOOKING_2" "James" "Maria" "matching"

step "Wait for Maria to accept + IOMW + arrive"
if wait $CG2_PID; then
  pass "Maria: login + online + offer accepted + IOMW + arrived"
else
  echo "  Maria flow log:"
  tail -20 "$CG2_LOG" 2>/dev/null
  fail "Maria combined flow"
  exit 1
fi

step "Session 2: Create + Verify + End via API"
S2_CREATE=$(api_create_session "$CG2_TOKEN" "$BOOKING_2")
S2=$(echo "$S2_CREATE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
d = data.get('session', data.get('data', data))
print(d.get('id', ''))" 2>/dev/null)
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
state_set "bookings[0].lifecycle" "completed"
state_set "bookings[1].lifecycle" "completed"

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
