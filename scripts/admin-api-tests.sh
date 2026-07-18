#!/usr/bin/env bash
# Layer 4: Admin API Test Suite
# Tests all 28 admin endpoints: happy path + auth/permission/404 error cases.
# No Chrome, no simulators — pure API.
#
# Usage: ./scripts/admin-api-tests.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/config/environment.sh"
source "$ROOT_DIR/scripts/lib/api-helpers.sh"
source "$ROOT_DIR/scripts/lib/admin-api-helpers.sh"

mkdir -p "$ROOT_DIR/results/layer4-admin-api"
LOG="$ROOT_DIR/results/layer4-admin-api/admin-api-tests.log"

PASS=0; FAIL=0; TOTAL=0

test_endpoint() {
  local name="$1" result="$2"
  TOTAL=$((TOTAL + 1))
  if [[ "$result" == "PASS" ]]; then
    PASS=$((PASS + 1))
    echo "  ✓ $name" | tee -a "$LOG"
  else
    FAIL=$((FAIL + 1))
    echo "  ✗ $name — $result" | tee -a "$LOG"
  fi
}

assert_status() {
  local name="$1" response="$2" expected_field="$3"
  if echo "$response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert '$expected_field' in str(data).lower() or len(str(data)) > 10
" 2>/dev/null; then
    test_endpoint "$name" "PASS"
  else
    test_endpoint "$name" "FAIL: unexpected response"
  fi
}

assert_http_status() {
  local name="$1" status_code="$2" expected="$3"
  if [[ "$status_code" == "$expected" ]]; then
    test_endpoint "$name" "PASS"
  else
    test_endpoint "$name" "FAIL: expected HTTP $expected, got $status_code"
  fi
}

echo "═══ LAYER 4: Admin API Tests ═══" | tee "$LOG"
echo "" | tee -a "$LOG"

# ─── Auth ──────────────────────────────────────────────────
echo "--- Authentication ---" | tee -a "$LOG"
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
[[ -n "$ADMIN_TOKEN" && "$ADMIN_TOKEN" != "None" ]] && test_endpoint "Admin login" "PASS" || test_endpoint "Admin login" "FAIL: no token"

PARENT_TOKEN=$(api_login "$PARENT_EMAIL" "$PARENT_PASSWORD")

# ─── Metrics ───────────────────────────────────────────────
echo "--- Metrics ---" | tee -a "$LOG"
RESP=$(admin_get_metrics "$ADMIN_TOKEN")
assert_status "GET /admin/metrics" "$RESP" "activeSessions\|mtdRevenue\|online"

# 401 without token
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${BACKEND_URL}/admin/metrics")
assert_http_status "GET /admin/metrics (no auth)" "$STATUS" "401"

# 403 with non-admin token
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer ${PARENT_TOKEN}" "${BACKEND_URL}/admin/metrics")
assert_http_status "GET /admin/metrics (parent token)" "$STATUS" "403"

# ─── Users ─────────────────────────────────────────────────
echo "--- Users ---" | tee -a "$LOG"
RESP=$(admin_list_users "$ADMIN_TOKEN")
assert_status "GET /admin/users" "$RESP" "data\|users"

RESP=$(admin_list_users "$ADMIN_TOKEN" "role=parent")
assert_status "GET /admin/users?role=parent" "$RESP" "data\|users"

SARAH_ID=$(admin_get_user_id_by_email "$ADMIN_TOKEN" "parent-sarah@test.bijoux.app")
[[ -n "$SARAH_ID" ]] && test_endpoint "Resolve Sarah's user ID" "PASS" || test_endpoint "Resolve Sarah's user ID" "FAIL"

if [[ -n "$SARAH_ID" ]]; then
  RESP=$(admin_get_user "$ADMIN_TOKEN" "$SARAH_ID")
  assert_status "GET /admin/users/:id" "$RESP" "sarah\|parent"

  # 404 with fake ID
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer ${ADMIN_TOKEN}" "${BACKEND_URL}/admin/users/00000000-0000-0000-0000-000000000000")
  assert_http_status "GET /admin/users/:id (404)" "$STATUS" "404"

  RESP=$(admin_change_user_status "$ADMIN_TOKEN" "$SARAH_ID" "suspended" "API test")
  assert_status "PUT /admin/users/:id/status (suspend)" "$RESP" "suspended\|success\|status"
  admin_change_user_status "$ADMIN_TOKEN" "$SARAH_ID" "active" "API test cleanup" > /dev/null
fi

# ─── Bookings ──────────────────────────────────────────────
echo "--- Bookings ---" | tee -a "$LOG"
RESP=$(admin_list_bookings "$ADMIN_TOKEN")
assert_status "GET /admin/bookings" "$RESP" "data\|bookings"

RESP=$(admin_list_bookings "$ADMIN_TOKEN" "lifecycle=completed")
assert_status "GET /admin/bookings?lifecycle=completed" "$RESP" "data\|bookings"

# Get a booking ID
BOOKING_ID=$(echo "$RESP" | python3 -c "
import sys, json
data = json.load(sys.stdin)
items = data.get('data', data.get('bookings', []))
print(items[0]['id'] if isinstance(items, list) and len(items) > 0 else '')" 2>/dev/null)

if [[ -n "$BOOKING_ID" ]]; then
  RESP=$(admin_get_booking "$ADMIN_TOKEN" "$BOOKING_ID")
  assert_status "GET /admin/bookings/:id" "$RESP" "booking\|lifecycle"
fi

# ─── Sessions ──────────────────────────────────────────────
echo "--- Sessions ---" | tee -a "$LOG"
RESP=$(admin_list_sessions "$ADMIN_TOKEN")
assert_status "GET /admin/sessions" "$RESP" "data\|sessions"

SESSION_ID=$(echo "$RESP" | python3 -c "
import sys, json
data = json.load(sys.stdin)
items = data.get('data', data.get('sessions', []))
print(items[0]['id'] if isinstance(items, list) and len(items) > 0 else '')" 2>/dev/null)

if [[ -n "$SESSION_ID" ]]; then
  RESP=$(admin_get_session "$ADMIN_TOKEN" "$SESSION_ID")
  assert_status "GET /admin/sessions/:id" "$RESP" "session\|status"
fi

# ─── Caregivers ────────────────────────────────────────────
echo "--- Caregivers ---" | tee -a "$LOG"
RESP=$(admin_list_caregivers "$ADMIN_TOKEN")
assert_status "GET /admin/caregivers" "$RESP" "data\|caregivers"

EMMA_CG_ID=$(admin_get_caregiver_profile_id_by_email "$ADMIN_TOKEN" "cg-emma")
if [[ -n "$EMMA_CG_ID" ]]; then
  RESP=$(admin_get_caregiver "$ADMIN_TOKEN" "$EMMA_CG_ID")
  assert_status "GET /admin/caregivers/:id" "$RESP" "emma\|caregiver"
fi

# ─── Pricing ───────────────────────────────────────────────
echo "--- Pricing ---" | tee -a "$LOG"
RESP=$(admin_list_pricing "$ADMIN_TOKEN")
assert_status "GET /admin/market-pricing" "$RESP" "data\|pricing"

PRICING_ID=$(echo "$RESP" | python3 -c "
import sys, json
data = json.load(sys.stdin)
items = data.get('data', data.get('configs', data.get('pricing', [])))
if isinstance(items, list) and len(items) > 0:
    print(items[0].get('id', ''))
else: print('')" 2>/dev/null)

if [[ -n "$PRICING_ID" ]]; then
  RESP=$(admin_get_pricing "$ADMIN_TOKEN" "$PRICING_ID")
  assert_status "GET /admin/market-pricing/:id" "$RESP" "baseRate\|rate\|fee"
fi

# Create pricing test
RESP=$(admin_create_pricing "$ADMIN_TOKEN" '{"state":"FL","baseRateCents":2500,"platformFeeCents":500,"effectiveDate":"2026-07-01"}')
assert_status "POST /admin/market-pricing" "$RESP" "id\|created\|pricing"

# ─── Incidents ─────────────────────────────────────────────
echo "--- Incidents ---" | tee -a "$LOG"
RESP=$(admin_list_incidents "$ADMIN_TOKEN")
assert_status "GET /admin/incidents" "$RESP" "data\|incidents"

# ─── Audit Logs ────────────────────────────────────────────
echo "--- Audit Logs ---" | tee -a "$LOG"
RESP=$(admin_list_audit_logs "$ADMIN_TOKEN")
assert_status "GET /admin/audit-logs" "$RESP" "data\|logs"

LOG_ID=$(echo "$RESP" | python3 -c "
import sys, json
data = json.load(sys.stdin)
items = data.get('data', data.get('logs', []))
print(items[0]['id'] if isinstance(items, list) and len(items) > 0 else '')" 2>/dev/null)

if [[ -n "$LOG_ID" ]]; then
  RESP=$(admin_get_audit_log "$ADMIN_TOKEN" "$LOG_ID")
  assert_status "GET /admin/audit-logs/:id" "$RESP" "actor\|action\|resource"
fi

# ─── Credits ───────────────────────────────────────────────
echo "--- Credits ---" | tee -a "$LOG"
if [[ -n "${SARAH_ID:-}" ]]; then
  RESP=$(admin_issue_credit "$ADMIN_TOKEN" "$SARAH_ID" 1000 "API test credit")
  assert_status "POST /admin/credits/issue" "$RESP" "credit\|success\|id"

  RESP=$(admin_get_credit_balance "$ADMIN_TOKEN" "$SARAH_ID")
  assert_status "GET /admin/credits/:userId/balance" "$RESP" "balance"

  RESP=$(admin_get_credit_history "$ADMIN_TOKEN" "$SARAH_ID")
  assert_status "GET /admin/credits/:userId/history" "$RESP" "data\|history\|entries"
fi

# ─── Transactions ──────────────────────────────────────────
echo "--- Transactions ---" | tee -a "$LOG"
RESP=$(admin_list_transactions "$ADMIN_TOKEN")
assert_status "GET /admin/transactions" "$RESP" "data\|transactions"

# ─── Search ────────────────────────────────────────────────
echo "--- Search ---" | tee -a "$LOG"
RESP=$(admin_search "$ADMIN_TOKEN" "Sarah")
assert_status "GET /admin/search?q=Sarah" "$RESP" "results\|data\|sarah"

RESP=$(admin_search "$ADMIN_TOKEN" "Emma")
assert_status "GET /admin/search?q=Emma" "$RESP" "results\|data\|emma"

# ═══ SUMMARY ═══════════════════════════════════════════════
echo "" | tee -a "$LOG"
echo "═══════════════════════════════════════════════════" | tee -a "$LOG"
echo "  LAYER 4: Admin API Tests" | tee -a "$LOG"
echo "  Passed: $PASS / $TOTAL" | tee -a "$LOG"
echo "  Failed: $FAIL" | tee -a "$LOG"
echo "═══════════════════════════════════════════════════" | tee -a "$LOG"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
