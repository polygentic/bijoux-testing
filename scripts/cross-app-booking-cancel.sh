#!/usr/bin/env bash
# UAT-19.2: Booking Cancellation — Cross-Platform Test
#
# Orchestrates: Parent App → Backend API → Admin Portal → Parent App verification
# Flow: Parent creates booking → Admin cancels → Parent sees cancelled state
#
# Prerequisites:
#   - Backend running with seed data
#   - Parent simulator booted with app installed
#   - Admin portal running at localhost:3001
#
# Usage:
#   source config/environment.sh
#   ./scripts/cross-app-booking-cancel.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ -z "${BACKEND_URL:-}" ]]; then
  source "$ROOT_DIR/config/environment.sh"
fi

if [[ -z "$PARENT_UDID" ]]; then
  echo "ERROR: PARENT_UDID not set. Boot simulators first."
  exit 1
fi

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
# PHASE 1: Get tokens
# ─────────────────────────────────────────────────
step "Authenticate via API"

PARENT_TOKEN=$(curl -s -X POST "${BACKEND_URL}/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${PARENT_EMAIL}\",\"password\":\"${PARENT_PASSWORD}\"}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('accessToken',''))" 2>/dev/null)

ADMIN_TOKEN=$(curl -s -X POST "${BACKEND_URL}/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${ADMIN_EMAIL}\",\"password\":\"${ADMIN_PASSWORD}\"}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('accessToken',''))" 2>/dev/null)

[[ -n "$PARENT_TOKEN" && "$PARENT_TOKEN" != "None" ]] && pass "Parent token" || fail "Parent token"
[[ -n "$ADMIN_TOKEN" && "$ADMIN_TOKEN" != "None" ]] && pass "Admin token" || fail "Admin token"

# ─────────────────────────────────────────────────
# PHASE 2: Parent creates booking
# ─────────────────────────────────────────────────
step "Parent: Login and create booking"

maestro --udid="$PARENT_UDID" test "$ROOT_DIR/flows/parent/login-valid.yaml" 2>&1 || fail "Parent login"

# Create booking via API (more reliable than UI for cross-app test)
BOOKING_RESPONSE=$(curl -s -X POST "${BACKEND_URL}/bookings" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${PARENT_TOKEN}" \
  -d "{
    \"type\": \"request_now\",
    \"address\": \"${TEST_ADDRESS}\",
    \"latitude\": ${TEST_LAT},
    \"longitude\": ${TEST_LNG}
  }" 2>/dev/null)

BOOKING_ID=$(echo "$BOOKING_RESPONSE" \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
d = data.get('data', data)
print(d.get('id', ''))" 2>/dev/null)

if [[ -n "$BOOKING_ID" && "$BOOKING_ID" != "" ]]; then
  pass "Booking created: $BOOKING_ID"
else
  fail "Could not create booking"
  echo "  Response: $BOOKING_RESPONSE"
  exit 1
fi

# Verify booking is active
sleep 2

BOOKING_STATUS=$(curl -s -H "Authorization: Bearer ${PARENT_TOKEN}" \
  "${BACKEND_URL}/bookings/${BOOKING_ID}" \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
d = data.get('data', data)
print(d.get('status', d.get('lifecycle', '')))" 2>/dev/null)

echo "  Booking status: $BOOKING_STATUS"

# ─────────────────────────────────────────────────
# PHASE 3: Admin cancels booking via API
# ─────────────────────────────────────────────────
step "Admin: Cancel booking via API"

CANCEL_RESPONSE=$(curl -s -X POST "${BACKEND_URL}/admin/bookings/${BOOKING_ID}/cancel" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -d '{"reason": "UAT-19.2 cross-app cancellation test"}' 2>/dev/null)

echo "  Cancel response: $CANCEL_RESPONSE"

sleep 2

# Verify cancellation
CANCELLED_STATUS=$(curl -s -H "Authorization: Bearer ${PARENT_TOKEN}" \
  "${BACKEND_URL}/bookings/${BOOKING_ID}" \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
d = data.get('data', data)
print(d.get('status', d.get('lifecycle', '')))" 2>/dev/null)

echo "  Booking status after cancel: $CANCELLED_STATUS"

if [[ "$CANCELLED_STATUS" == "cancelled" ]]; then
  pass "Booking cancelled via admin API"
else
  fail "Booking not cancelled (got: $CANCELLED_STATUS)"
fi

# ─────────────────────────────────────────────────
# PHASE 4: Verify in parent app
# ─────────────────────────────────────────────────
step "Parent: Verify cancelled state in app"

echo "  Refreshing parent app to check for cancelled booking..."

# Navigate to activity/history to see cancelled booking
maestro --udid="$PARENT_UDID" test "$ROOT_DIR/flows/parent/activity-history.yaml" 2>&1 || \
  echo "  WARNING: Could not navigate to activity history"

echo "  Take screenshot for manual verification:"
maestro --udid="$PARENT_UDID" test -c "
- takeScreenshot: $ROOT_DIR/results/cross-app/parent-booking-cancelled
" 2>&1 || true

# ─────────────────────────────────────────────────
# PHASE 5: Admin portal verification (instructions)
# ─────────────────────────────────────────────────
step "Admin Portal Verification"

echo "  Verify in admin portal at ${ADMIN_URL}:"
echo "  1. Navigate to ${ADMIN_URL}/bookings"
echo "  2. Find booking $BOOKING_ID"
echo "  3. Verify status shows 'Cancelled'"
echo "  4. Verify cancellation reason shows 'UAT-19.2 cross-app cancellation test'"
echo ""
echo "  See flows/admin/booking-cancel.md for Claude-in-Chrome automation"

# ─────────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════"
echo "  UAT-19.2 RESULTS"
echo "═══════════════════════════════════════════════════"
echo "  Booking ID: ${BOOKING_ID:-N/A}"
echo "  Final Status: ${CANCELLED_STATUS:-N/A}"
echo "  Failures: $FAILURES"
echo ""

if [[ $FAILURES -eq 0 ]]; then
  echo "  OVERALL: PASS"
  exit 0
else
  echo "  OVERALL: FAIL ($FAILURES failures)"
  exit 1
fi
