#!/usr/bin/env bash
# Shared API helper functions for cross-app orchestration scripts.
# Source this file: source "$SCRIPT_DIR/lib/api-helpers.sh"

# Login and return access token. Args: email, password
api_login() {
  local email="$1" password="$2"
  curl -s -X POST "${BACKEND_URL}/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${email}\",\"password\":\"${password}\"}" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('accessToken',''))" 2>/dev/null
}

# Get booking by ID. Args: token, booking_id
api_get_booking() {
  local token="$1" booking_id="$2"
  curl -s -H "Authorization: Bearer ${token}" \
    "${BACKEND_URL}/bookings/${booking_id}" 2>/dev/null
}

# Get booking lifecycle status. Args: token, booking_id
api_booking_lifecycle() {
  local token="$1" booking_id="$2"
  api_get_booking "$token" "$booking_id" \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
d = data.get('booking', data.get('data', data))
print(d.get('lifecycle', d.get('status', '')))" 2>/dev/null
}

# Get latest booking ID for a parent. Args: token
api_latest_booking_id() {
  local token="$1"
  curl -s -H "Authorization: Bearer ${token}" \
    "${BACKEND_URL}/bookings?limit=1&sort=-createdAt" \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
items = data.get('data', data.get('bookings', []))
if isinstance(items, list) and len(items) > 0:
    print(items[0].get('id', ''))
else:
    print('')" 2>/dev/null
}

# Get session ID from booking. Args: token, booking_id
api_session_id() {
  local token="$1" booking_id="$2"
  curl -s -H "Authorization: Bearer ${token}" \
    "${BACKEND_URL}/sessions?bookingId=${booking_id}" 2>/dev/null \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
sessions = data.get('sessions', data.get('data', []))
if isinstance(sessions, list) and len(sessions) > 0:
    print(sessions[0].get('id', ''))
else:
    print('')" 2>/dev/null
}

# Get session status. Args: token, session_id
api_session_status() {
  local token="$1" session_id="$2"
  curl -s -H "Authorization: Bearer ${token}" \
    "${BACKEND_URL}/sessions/${session_id}" \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
d = data.get('session', data.get('data', data))
print(d.get('status', ''))" 2>/dev/null
}

# Set caregiver online status. Args: token, true|false
api_set_online() {
  local token="$1" online="$2"
  curl -s -X PUT "${BACKEND_URL}/profile/caregiver/online-status" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${token}" \
    -d "{\"isOnline\": ${online}}" > /dev/null 2>&1
}

# Get caregiver earnings summary. Args: token
api_earnings_summary() {
  local token="$1"
  curl -s -H "Authorization: Bearer ${token}" \
    "${BACKEND_URL}/activity/earnings" 2>/dev/null
}

# Get caregiver earnings ledger. Args: token
api_earnings_ledger() {
  local token="$1"
  curl -s -H "Authorization: Bearer ${token}" \
    "${BACKEND_URL}/activity/earnings/ledger" 2>/dev/null
}

# Get transactions for a booking. Args: admin_token, booking_id
api_transactions_for_booking() {
  local token="$1" booking_id="$2"
  curl -s -H "Authorization: Bearer ${token}" \
    "${BACKEND_URL}/admin/transactions?bookingId=${booking_id}" 2>/dev/null
}

# Poll until booking reaches target lifecycle. Args: token, booking_id, target_status, max_attempts
api_wait_for_lifecycle() {
  local token="$1" booking_id="$2" target="$3" max="${4:-20}"
  local attempt=0
  while [[ $attempt -lt $max ]]; do
    local current
    current=$(api_booking_lifecycle "$token" "$booking_id")
    if [[ "$current" == "$target" ]]; then
      echo "$current"
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 3
  done
  echo "$current"
  return 1
}

# Report caregiver location (updates profile lat/lng used by matching engine).
# Args: token, latitude, longitude
api_report_location() {
  local token="$1" lat="$2" lng="$3"
  curl -s -X PUT "${BACKEND_URL}/profile/caregiver" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${token}" \
    -d "{\"latitude\": ${lat}, \"longitude\": ${lng}}" > /dev/null 2>&1
}

# Cancel all active bookings for a parent. Args: token
api_cancel_active_bookings() {
  local token="$1"
  curl -s -H "Authorization: Bearer ${token}" \
    "${BACKEND_URL}/bookings?limit=20" 2>/dev/null \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
items = data.get('data', data.get('bookings', []))
if isinstance(items, list):
    for b in items:
        lifecycle = b.get('lifecycle', '')
        if lifecycle in ('matching', 'confirmed', 'matched', 'in_progress'):
            print(b.get('id', ''))
" 2>/dev/null | while read -r bid; do
    if [[ -n "$bid" ]]; then
      curl -s -X POST "${BACKEND_URL}/bookings/${bid}/cancel" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${token}" \
        -d '{"reason": "UAT test cleanup"}' > /dev/null 2>&1
      echo "  Cancelled booking: $bid"
    fi
  done
}

# End all active sessions for a caregiver. Args: caregiver_token, [parent_token]
# If parent_token provided, handles not_started sessions by verifying both sides first.
api_cleanup_sessions() {
  local cg_token="$1" parent_token="${2:-}"
  curl -s -H "Authorization: Bearer ${cg_token}" \
    "${BACKEND_URL}/sessions?limit=20" 2>/dev/null \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
sessions = data.get('sessions', data.get('data', []))
if isinstance(sessions, list):
    for s in sessions:
        status = s.get('status', '')
        if status in ('not_started', 'in_progress'):
            print(f'{s.get(\"id\", \"\")}|{status}')
" 2>/dev/null | while IFS='|' read -r sid sstatus; do
    if [[ -n "$sid" ]]; then
      if [[ "$sstatus" == "not_started" && -n "$parent_token" ]]; then
        # Verify from both sides to transition to in_progress first
        curl -s -X POST "${BACKEND_URL}/sessions/${sid}/verify/start" \
          -H "Content-Type: application/json" -H "Authorization: Bearer ${cg_token}" -d '{}' > /dev/null 2>&1
        curl -s -X POST "${BACKEND_URL}/sessions/${sid}/verify/start" \
          -H "Content-Type: application/json" -H "Authorization: Bearer ${parent_token}" -d '{}' > /dev/null 2>&1
        sleep 1
      fi
      curl -s -X POST "${BACKEND_URL}/sessions/${sid}/end" \
        -H "Content-Type: application/json" -H "Authorization: Bearer ${cg_token}" -d '{}' > /dev/null 2>&1
      echo "  Cleaned up session: $sid (was $sstatus)"
    fi
  done
}

# Create session from booking. Args: caregiver_token, booking_id
api_create_session() {
  local token="$1" booking_id="$2"
  curl -s -X POST "${BACKEND_URL}/sessions/start" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${token}" \
    -d "{\"bookingId\":\"${booking_id}\"}" 2>/dev/null
}

# Verify session start (auto-completes when VERIFF_ENABLED=false). Args: token, session_id
api_verify_session_start() {
  local token="$1" session_id="$2"
  curl -s -X POST "${BACKEND_URL}/sessions/${session_id}/verify/start" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${token}" \
    -d '{}' 2>/dev/null
}

# End session directly (dev mode). Args: token, session_id
api_end_session() {
  local token="$1" session_id="$2"
  curl -s -X POST "${BACKEND_URL}/sessions/${session_id}/end" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${token}" \
    -d '{}' 2>/dev/null
}

# Rate session. Args: parent_token, session_id, rating (1-5)
api_rate_session() {
  local token="$1" session_id="$2" rating="${3:-5}"
  curl -s -X POST "${BACKEND_URL}/sessions/${session_id}/rate" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${token}" \
    -d "{\"rating\":${rating}}" 2>/dev/null
}

# Add a test payment method to a parent account. Args: token, [label]
api_add_payment_method() {
  local token="$1" label="${2:-james}"
  curl -s -X POST "${BACKEND_URL}/payments/methods" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${token}" \
    -d "{\"stripePaymentMethodId\":\"pm_test_visa_4242_${label}\",\"brand\":\"visa\",\"last4\":\"4242\",\"expiryMonth\":12,\"expiryYear\":2028}" 2>/dev/null
}

# Cancel all completed test bookings from today via database.
# This resets the matching engine's daily limit counter.
# Args: none (uses docker exec to access PostgreSQL directly)
api_reset_daily_limits() {
  local count
  count=$(docker exec bijoux-postgres psql -U bijoux -d bijoux_dev -t -c "
    UPDATE bookings SET lifecycle = 'cancelled'
    WHERE lifecycle = 'completed'
    AND created_at >= CURRENT_DATE
    AND created_at < CURRENT_DATE + INTERVAL '1 day'
    RETURNING id;
  " 2>/dev/null | grep -c '[a-f0-9]' 2>/dev/null || echo "0")
  if [[ "$count" -gt 0 ]]; then
    echo "  Reset daily limits: cancelled $count completed test bookings from today"
  fi
}

# Reseed backend for clean state. No args.
api_reseed() {
  echo "  Reseeding backend..."
  (cd "$BIJOUX_BACKEND_DIR" && npm run db:seed 2>/dev/null && npx tsx prisma/seed-uat.ts 2>/dev/null) || true
  echo "  Backend reseeded"
}
