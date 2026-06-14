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
d = data.get('data', data)
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
  api_get_booking "$token" "$booking_id" \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
d = data.get('data', data)
s = d.get('session', {})
print(s.get('id', ''))" 2>/dev/null
}

# Get session status. Args: token, session_id
api_session_status() {
  local token="$1" session_id="$2"
  curl -s -H "Authorization: Bearer ${token}" \
    "${BACKEND_URL}/sessions/${session_id}" \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
d = data.get('data', data)
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

# Reseed backend for clean state. No args.
api_reseed() {
  echo "  Reseeding backend..."
  (cd "$BIJOUX_BACKEND_DIR" && npm run db:seed 2>/dev/null && npx tsx prisma/seed-uat.ts 2>/dev/null) || true
  echo "  Backend reseeded"
}
