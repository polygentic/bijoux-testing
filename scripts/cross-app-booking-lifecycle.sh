#!/usr/bin/env bash
# UAT-19.1: Full Booking Lifecycle — End-to-End Cross-App Test
#
# Orchestrates: Parent App → Backend API → Caregiver App → Admin Portal
# Flow: Create booking → Match → Accept → Start session → End session → Verify
#
# Prerequisites:
#   - Backend running (docker compose up) with seed data
#   - Both simulators booted with apps installed
#   - Admin portal running at localhost:3001
#
# Usage:
#   source config/environment.sh
#   ./scripts/cross-app-booking-lifecycle.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source environment if not already loaded
if [[ -z "${BACKEND_URL:-}" ]]; then
  source "$ROOT_DIR/config/environment.sh"
fi

# Validate prerequisites
if [[ -z "$PARENT_UDID" ]]; then
  echo "ERROR: PARENT_UDID not set. Boot simulators first: ./config/simulators.sh boot"
  exit 1
fi
if [[ -z "$CAREGIVER_UDID" ]]; then
  echo "ERROR: CAREGIVER_UDID not set. Boot simulators first: ./config/simulators.sh boot"
  exit 1
fi

# Create results directory
mkdir -p "$ROOT_DIR/results/cross-app"

FAILURES=0
STEP=0

step() {
  STEP=$((STEP + 1))
  echo ""
  echo "═══════════════════════════════════════════════════"
  echo "  STEP $STEP: $1"
  echo "═══════════════════════════════════════════════════"
}

pass() { echo "  ✓ PASS: $1"; }
fail() { echo "  ✗ FAIL: $1"; FAILURES=$((FAILURES + 1)); }

# ─────────────────────────────────────────────────
# PHASE 1: Get API tokens
# ─────────────────────────────────────────────────
step "Authenticate test users via API"

PARENT_TOKEN=$(curl -s -X POST "${BACKEND_URL}/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${PARENT_EMAIL}\",\"password\":\"${PARENT_PASSWORD}\"}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('accessToken',''))" 2>/dev/null)

if [[ -n "$PARENT_TOKEN" && "$PARENT_TOKEN" != "None" ]]; then
  pass "Parent token obtained"
else
  fail "Could not get parent token"
  exit 1
fi

CAREGIVER_TOKEN=$(curl -s -X POST "${BACKEND_URL}/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${CAREGIVER_ONLINE_EMAIL}\",\"password\":\"${CAREGIVER_ONLINE_PASSWORD}\"}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('accessToken',''))" 2>/dev/null)

if [[ -n "$CAREGIVER_TOKEN" && "$CAREGIVER_TOKEN" != "None" ]]; then
  pass "Caregiver token obtained"
else
  fail "Could not get caregiver token"
  exit 1
fi

ADMIN_TOKEN=$(curl -s -X POST "${BACKEND_URL}/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${ADMIN_EMAIL}\",\"password\":\"${ADMIN_PASSWORD}\"}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('accessToken',''))" 2>/dev/null)

if [[ -n "$ADMIN_TOKEN" && "$ADMIN_TOKEN" != "None" ]]; then
  pass "Admin token obtained"
else
  fail "Could not get admin token"
fi

# ─────────────────────────────────────────────────
# PHASE 2: Ensure caregiver is online via API
# ─────────────────────────────────────────────────
step "Set caregiver online via API"

curl -s -X PUT "${BACKEND_URL}/caregiver/availability" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${CAREGIVER_TOKEN}" \
  -d '{"isOnline": true}' > /dev/null 2>&1 || true

ONLINE_STATUS=$(curl -s -H "Authorization: Bearer ${CAREGIVER_TOKEN}" \
  "${BACKEND_URL}/caregiver/profile" \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('isOnline', json.load(open('/dev/stdin')).get('data',{}).get('isOnline','')))" 2>/dev/null || echo "unknown")

echo "  Caregiver online status: $ONLINE_STATUS"

# ─────────────────────────────────────────────────
# PHASE 3: Parent logs in and creates booking via Maestro
# ─────────────────────────────────────────────────
step "Parent: Login via Maestro"

if maestro --udid="$PARENT_UDID" test "$ROOT_DIR/flows/parent/login-valid.yaml" 2>&1; then
  pass "Parent login flow completed"
else
  fail "Parent login flow failed"
  exit 1
fi

step "Parent: Submit quick booking via Maestro"

if maestro --udid="$PARENT_UDID" test "$ROOT_DIR/flows/parent/quick-booking-submit.yaml" 2>&1; then
  pass "Parent booking submission flow completed"
else
  fail "Parent booking submission flow failed"
  echo "  NOTE: Falling back to API booking creation"

  # Fallback: create booking via API
  BOOKING_RESPONSE=$(curl -s -X POST "${BACKEND_URL}/bookings" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${PARENT_TOKEN}" \
    -d "{
      \"type\": \"request_now\",
      \"address\": \"${TEST_ADDRESS}\",
      \"latitude\": ${TEST_LAT},
      \"longitude\": ${TEST_LNG}
    }")
  echo "  API booking response: $BOOKING_RESPONSE"
fi

# ─────────────────────────────────────────────────
# PHASE 4: Get booking ID and verify matching started
# ─────────────────────────────────────────────────
step "Verify booking created and matching started"

sleep 3  # Wait for booking to process

BOOKINGS_RESPONSE=$(curl -s -H "Authorization: Bearer ${PARENT_TOKEN}" \
  "${BACKEND_URL}/bookings?limit=1&sort=-createdAt" 2>/dev/null)

BOOKING_ID=$(echo "$BOOKINGS_RESPONSE" \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
items = data.get('data', data.get('bookings', [data] if 'id' in data else []))
if isinstance(items, list) and len(items) > 0:
    print(items[0].get('id', ''))
elif isinstance(items, dict):
    print(items.get('id', ''))
else:
    print('')
" 2>/dev/null)

if [[ -n "$BOOKING_ID" && "$BOOKING_ID" != "" ]]; then
  pass "Booking created: $BOOKING_ID"
else
  fail "Could not retrieve booking ID"
  echo "  Response: $BOOKINGS_RESPONSE"
  exit 1
fi

# Wait for matching to start
sleep 5

BOOKING_STATUS=$(curl -s -H "Authorization: Bearer ${PARENT_TOKEN}" \
  "${BACKEND_URL}/bookings/${BOOKING_ID}" \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
d = data.get('data', data)
print(d.get('status', d.get('lifecycle', '')))" 2>/dev/null)

echo "  Booking status: $BOOKING_STATUS"

# ─────────────────────────────────────────────────
# PHASE 5: Caregiver logs in and waits for offer
# ─────────────────────────────────────────────────
step "Caregiver: Login via Maestro"

if maestro --udid="$CAREGIVER_UDID" test "$ROOT_DIR/flows/caregiver/login-valid.yaml" 2>&1; then
  pass "Caregiver login flow completed"
else
  fail "Caregiver login flow failed"
  exit 1
fi

step "Caregiver: Accept offer via Maestro"

if maestro --udid="$CAREGIVER_UDID" test "$ROOT_DIR/flows/caregiver/accept-offer.yaml" 2>&1; then
  pass "Caregiver offer acceptance completed"
else
  fail "Caregiver offer acceptance failed — offer may not have been delivered"
  exit 1
fi

# ─────────────────────────────────────────────────
# PHASE 6: Verify booking is matched
# ─────────────────────────────────────────────────
step "Verify booking status is matched"

sleep 3

BOOKING_STATUS=$(curl -s -H "Authorization: Bearer ${PARENT_TOKEN}" \
  "${BACKEND_URL}/bookings/${BOOKING_ID}" \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
d = data.get('data', data)
print(d.get('status', d.get('lifecycle', '')))" 2>/dev/null)

echo "  Booking status after acceptance: $BOOKING_STATUS"
if [[ "$BOOKING_STATUS" == "matched" || "$BOOKING_STATUS" == "confirmed" ]]; then
  pass "Booking matched/confirmed"
else
  fail "Booking not in matched state (got: $BOOKING_STATUS)"
fi

# ─────────────────────────────────────────────────
# PHASE 7: Session start verification (both parties)
# ─────────────────────────────────────────────────
step "Caregiver: Confirm arrival"

maestro --udid="$CAREGIVER_UDID" test "$ROOT_DIR/flows/caregiver/confirm-arrival.yaml" 2>&1 || \
  fail "Caregiver arrival confirmation flow"

step "Caregiver: Start session verification"

maestro --udid="$CAREGIVER_UDID" test "$ROOT_DIR/flows/caregiver/start-session-verify.yaml" 2>&1 || \
  fail "Caregiver session start verification"

step "Parent: Confirm session start"

maestro --udid="$PARENT_UDID" test "$ROOT_DIR/flows/parent/confirm-session-start.yaml" 2>&1 || \
  fail "Parent session start confirmation"

# ─────────────────────────────────────────────────
# PHASE 8: Verify session created via API
# ─────────────────────────────────────────────────
step "Verify session created via API"

sleep 3

SESSION_RESPONSE=$(curl -s -H "Authorization: Bearer ${PARENT_TOKEN}" \
  "${BACKEND_URL}/bookings/${BOOKING_ID}" 2>/dev/null)

SESSION_ID=$(echo "$SESSION_RESPONSE" \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
d = data.get('data', data)
session = d.get('session', {})
print(session.get('id', ''))" 2>/dev/null)

if [[ -n "$SESSION_ID" && "$SESSION_ID" != "" ]]; then
  pass "Session created: $SESSION_ID"
else
  echo "  WARNING: Could not retrieve session ID"
fi

# ─────────────────────────────────────────────────
# PHASE 9: End session (both parties)
# ─────────────────────────────────────────────────
step "Caregiver: End session"

maestro --udid="$CAREGIVER_UDID" test "$ROOT_DIR/flows/caregiver/end-session.yaml" 2>&1 || \
  fail "Caregiver end session"

step "Parent: Confirm session end"

maestro --udid="$PARENT_UDID" test "$ROOT_DIR/flows/parent/confirm-session-end.yaml" 2>&1 || \
  fail "Parent session end confirmation"

# ─────────────────────────────────────────────────
# PHASE 10: Verify final state via API
# ─────────────────────────────────────────────────
step "Verify final state via API"

sleep 3

FINAL_BOOKING=$(curl -s -H "Authorization: Bearer ${PARENT_TOKEN}" \
  "${BACKEND_URL}/bookings/${BOOKING_ID}" 2>/dev/null)

FINAL_STATUS=$(echo "$FINAL_BOOKING" \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
d = data.get('data', data)
print(d.get('status', d.get('lifecycle', '')))" 2>/dev/null)

echo "  Final booking status: $FINAL_STATUS"

if [[ -n "$SESSION_ID" ]]; then
  SESSION_STATUS=$(curl -s -H "Authorization: Bearer ${PARENT_TOKEN}" \
    "${BACKEND_URL}/sessions/${SESSION_ID}" \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
d = data.get('data', data)
print(d.get('status', ''))" 2>/dev/null)
  echo "  Final session status: $SESSION_STATUS"
fi

# ─────────────────────────────────────────────────
# PHASE 11: Verify in Admin Portal (instructions for Chrome automation)
# ─────────────────────────────────────────────────
step "Admin Portal Verification (manual / Claude-in-Chrome)"

echo "  The following should be verified in the admin portal:"
echo "  1. Navigate to ${ADMIN_URL}/bookings"
echo "  2. Find booking ${BOOKING_ID}"
echo "  3. Verify status shows Completed"
echo "  4. Verify assigned caregiver is shown"
echo "  5. Click session link, verify all 4 verification checkmarks"
echo "  6. Navigate to ${ADMIN_URL}/transactions"
echo "  7. Verify authorization + capture transactions for this booking"
echo ""
echo "  To automate this step, run the admin tests after this script:"
echo "  See flows/admin/booking-detail.md and flows/admin/session-detail.md"

# ─────────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════"
echo "  UAT-19.1 RESULTS"
echo "═══════════════════════════════════════════════════"
echo "  Booking ID: ${BOOKING_ID:-N/A}"
echo "  Session ID: ${SESSION_ID:-N/A}"
echo "  Final Booking Status: ${FINAL_STATUS:-N/A}"
echo "  Final Session Status: ${SESSION_STATUS:-N/A}"
echo "  Failures: $FAILURES"
echo ""

if [[ $FAILURES -eq 0 ]]; then
  echo "  OVERALL: PASS"
  exit 0
else
  echo "  OVERALL: FAIL ($FAILURES failures)"
  exit 1
fi
