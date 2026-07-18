#!/usr/bin/env bash
# Admin-specific API helper functions for E2E testing.
# Extends api-helpers.sh with admin endpoint wrappers.
# Source AFTER api-helpers.sh: source "$SCRIPT_DIR/lib/admin-api-helpers.sh"

# ─── Dashboard & Metrics ─────────────────────────────────────

admin_get_metrics() {
  local token="$1"
  curl -s -H "Authorization: Bearer ${token}" \
    "${BACKEND_URL}/admin/metrics" 2>/dev/null
}

# ─── Users ────────────────────────────────────────────────────

admin_list_users() {
  local token="$1" query="${2:-}"
  curl -s -H "Authorization: Bearer ${token}" \
    "${BACKEND_URL}/admin/users?${query}" 2>/dev/null
}

admin_get_user() {
  local token="$1" user_id="$2"
  curl -s -H "Authorization: Bearer ${token}" \
    "${BACKEND_URL}/admin/users/${user_id}" 2>/dev/null
}

admin_change_user_status() {
  local token="$1" user_id="$2" status="$3" reason="${4:-Admin action}"
  curl -s -X PUT "${BACKEND_URL}/admin/users/${user_id}/status" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${token}" \
    -d "{\"status\":\"${status}\",\"reason\":\"${reason}\"}" 2>/dev/null
}

# ─── Bookings ─────────────────────────────────────────────────

admin_list_bookings() {
  local token="$1" query="${2:-}"
  curl -s -H "Authorization: Bearer ${token}" \
    "${BACKEND_URL}/admin/bookings?${query}" 2>/dev/null
}

admin_get_booking() {
  local token="$1" booking_id="$2"
  curl -s -H "Authorization: Bearer ${token}" \
    "${BACKEND_URL}/admin/bookings/${booking_id}" 2>/dev/null
}

admin_cancel_booking() {
  local token="$1" booking_id="$2" reason="${3:-Admin cancellation}"
  curl -s -X POST "${BACKEND_URL}/admin/bookings/${booking_id}/cancel" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${token}" \
    -d "{\"reason\":\"${reason}\"}" 2>/dev/null
}

admin_price_override() {
  local token="$1" booking_id="$2" amount_cents="$3" reason="${4:-Admin price override}"
  curl -s -X POST "${BACKEND_URL}/admin/bookings/${booking_id}/price-override" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${token}" \
    -d "{\"amountCents\":${amount_cents},\"reason\":\"${reason}\"}" 2>/dev/null
}

# ─── Sessions ─────────────────────────────────────────────────

admin_list_sessions() {
  local token="$1" query="${2:-}"
  curl -s -H "Authorization: Bearer ${token}" \
    "${BACKEND_URL}/admin/sessions?${query}" 2>/dev/null
}

admin_get_session() {
  local token="$1" session_id="$2"
  curl -s -H "Authorization: Bearer ${token}" \
    "${BACKEND_URL}/admin/sessions/${session_id}" 2>/dev/null
}

admin_override_session() {
  local token="$1" session_id="$2" status="$3" reason="${4:-Admin override}"
  curl -s -X POST "${BACKEND_URL}/admin/sessions/${session_id}/override" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${token}" \
    -d "{\"status\":\"${status}\",\"reason\":\"${reason}\"}" 2>/dev/null
}

admin_force_complete() {
  local token="$1" session_id="$2" cost_cents="$3" reason="${4:-Admin force complete}"
  curl -s -X POST "${BACKEND_URL}/admin/sessions/${session_id}/force-complete" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${token}" \
    -d "{\"finalCostCents\":${cost_cents},\"reason\":\"${reason}\"}" 2>/dev/null
}

# ─── Caregivers ───────────────────────────────────────────────

admin_list_caregivers() {
  local token="$1" query="${2:-}"
  curl -s -H "Authorization: Bearer ${token}" \
    "${BACKEND_URL}/admin/caregivers?${query}" 2>/dev/null
}

admin_get_caregiver() {
  local token="$1" caregiver_id="$2"
  curl -s -H "Authorization: Bearer ${token}" \
    "${BACKEND_URL}/admin/caregivers/${caregiver_id}" 2>/dev/null
}

admin_set_caregiver_approval() {
  local token="$1" caregiver_id="$2" action="$3" reason="${4:-Admin action}"
  curl -s -X POST "${BACKEND_URL}/admin/caregivers/${caregiver_id}/approval" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${token}" \
    -d "{\"action\":\"${action}\",\"reason\":\"${reason}\"}" 2>/dev/null
}

# ─── Pricing ──────────────────────────────────────────────────

admin_list_pricing() {
  local token="$1"
  curl -s -H "Authorization: Bearer ${token}" \
    "${BACKEND_URL}/admin/market-pricing" 2>/dev/null
}

admin_get_pricing() {
  local token="$1" pricing_id="$2"
  curl -s -H "Authorization: Bearer ${token}" \
    "${BACKEND_URL}/admin/market-pricing/${pricing_id}" 2>/dev/null
}

admin_create_pricing() {
  local token="$1" json_body="$2"
  curl -s -X POST "${BACKEND_URL}/admin/market-pricing" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${token}" \
    -d "$json_body" 2>/dev/null
}

admin_update_pricing() {
  local token="$1" pricing_id="$2" json_body="$3"
  curl -s -X PUT "${BACKEND_URL}/admin/market-pricing/${pricing_id}" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${token}" \
    -d "$json_body" 2>/dev/null
}

# ─── Incidents ────────────────────────────────────────────────

admin_list_incidents() {
  local token="$1" query="${2:-}"
  curl -s -H "Authorization: Bearer ${token}" \
    "${BACKEND_URL}/admin/incidents?${query}" 2>/dev/null
}

admin_resolve_incident() {
  local token="$1" incident_id="$2" notes="${3:-Resolved by admin}"
  curl -s -X POST "${BACKEND_URL}/admin/incidents/${incident_id}/resolve" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${token}" \
    -d "{\"notes\":\"${notes}\"}" 2>/dev/null
}

# ─── Audit Logs ───────────────────────────────────────────────

admin_list_audit_logs() {
  local token="$1" query="${2:-}"
  curl -s -H "Authorization: Bearer ${token}" \
    "${BACKEND_URL}/admin/audit-logs?${query}" 2>/dev/null
}

admin_get_audit_log() {
  local token="$1" log_id="$2"
  curl -s -H "Authorization: Bearer ${token}" \
    "${BACKEND_URL}/admin/audit-logs/${log_id}" 2>/dev/null
}

# ─── Credits ──────────────────────────────────────────────────

admin_issue_credit() {
  local token="$1" user_id="$2" amount_cents="$3" reason="${4:-Admin credit}"
  curl -s -X POST "${BACKEND_URL}/admin/credits/issue" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${token}" \
    -d "{\"userId\":\"${user_id}\",\"amountCents\":${amount_cents},\"reason\":\"${reason}\"}" 2>/dev/null
}

admin_get_credit_balance() {
  local token="$1" user_id="$2"
  curl -s -H "Authorization: Bearer ${token}" \
    "${BACKEND_URL}/admin/credits/${user_id}/balance" 2>/dev/null
}

admin_get_credit_history() {
  local token="$1" user_id="$2"
  curl -s -H "Authorization: Bearer ${token}" \
    "${BACKEND_URL}/admin/credits/${user_id}/history" 2>/dev/null
}

# ─── Transactions ─────────────────────────────────────────────

admin_list_transactions() {
  local token="$1" query="${2:-}"
  curl -s -H "Authorization: Bearer ${token}" \
    "${BACKEND_URL}/admin/transactions?${query}" 2>/dev/null
}

# ─── Search ───────────────────────────────────────────────────

admin_search() {
  local token="$1" query="$2"
  curl -s -H "Authorization: Bearer ${token}" \
    "${BACKEND_URL}/admin/search?q=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$query'))")" 2>/dev/null
}

# ─── User ID Resolvers ────────────────────────────────────────

admin_get_user_id_by_email() {
  local token="$1" email="$2"
  admin_list_users "$token" "search=${email}" \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
users = data.get('data', data.get('users', []))
if isinstance(users, list) and len(users) > 0:
    print(users[0].get('id', ''))
else:
    print('')" 2>/dev/null
}

admin_get_caregiver_profile_id_by_email() {
  local token="$1" email="$2"
  admin_list_caregivers "$token" "search=${email}" \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
cgs = data.get('data', data.get('caregivers', []))
if isinstance(cgs, list) and len(cgs) > 0:
    print(cgs[0].get('id', cgs[0].get('profileId', '')))
else:
    print('')" 2>/dev/null
}
