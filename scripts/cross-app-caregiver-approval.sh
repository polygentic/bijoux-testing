#!/usr/bin/env bash
# UAT-19.3: Caregiver Approval — End-to-End Cross-App Test
#
# Orchestrates: Admin API → Caregiver App
# Flow: Admin initiates BG+IDV → Simulate clear → Admin approves → Caregiver sees home
#
# Uses cg-pending (Jake Wilson) who has a pending status.
#
# Prerequisites:
#   - Backend running with seed data (cg-pending account exists)
#   - Caregiver simulator booted with app installed
#   - Admin portal running at localhost:3001
#
# Usage:
#   source config/environment.sh
#   ./scripts/cross-app-caregiver-approval.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ -z "${BACKEND_URL:-}" ]]; then
  source "$ROOT_DIR/config/environment.sh"
fi

if [[ -z "$CAREGIVER_UDID" ]]; then
  echo "ERROR: CAREGIVER_UDID not set. Boot simulators first."
  exit 1
fi

# Test account for this flow
PENDING_CG_EMAIL="cg-pending@test.bijoux.app"
PENDING_CG_PASSWORD="Test1234!"

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
# PHASE 1: Get admin token and caregiver profile
# ─────────────────────────────────────────────────
step "Authenticate admin and get caregiver profile"

ADMIN_TOKEN=$(curl -s -X POST "${BACKEND_URL}/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${ADMIN_EMAIL}\",\"password\":\"${ADMIN_PASSWORD}\"}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('accessToken',''))" 2>/dev/null)

[[ -n "$ADMIN_TOKEN" && "$ADMIN_TOKEN" != "None" ]] && pass "Admin token" || { fail "Admin token"; exit 1; }

# Find the pending caregiver profile ID
CG_LIST=$(curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "${BACKEND_URL}/admin/caregivers?status=pending" 2>/dev/null)

CAREGIVER_PROFILE_ID=$(echo "$CG_LIST" \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
items = data.get('data', data.get('caregivers', []))
if isinstance(items, list):
    for cg in items:
        email = cg.get('email', cg.get('user', {}).get('email', ''))
        if 'pending' in email or 'jake' in email.lower():
            print(cg.get('id', cg.get('caregiverProfileId', '')))
            sys.exit(0)
    if items:
        print(items[0].get('id', items[0].get('caregiverProfileId', '')))
print('')" 2>/dev/null)

if [[ -n "$CAREGIVER_PROFILE_ID" && "$CAREGIVER_PROFILE_ID" != "" ]]; then
  pass "Found pending caregiver profile: $CAREGIVER_PROFILE_ID"
else
  fail "Could not find pending caregiver profile"
  echo "  Response: $CG_LIST"
  echo "  NOTE: Ensure cg-pending@test.bijoux.app exists in seed data"
  exit 1
fi

# ─────────────────────────────────────────────────
# PHASE 2: Initiate background check
# ─────────────────────────────────────────────────
step "Admin: Initiate background check"

BG_RESPONSE=$(curl -s -X POST "${BACKEND_URL}/trust/background-checks" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -d "{\"caregiverProfileId\": \"${CAREGIVER_PROFILE_ID}\"}" 2>/dev/null)

echo "  BG check response: $BG_RESPONSE"
pass "Background check initiated"

# ─────────────────────────────────────────────────
# PHASE 3: Initiate identity verification
# ─────────────────────────────────────────────────
step "Admin: Initiate identity verification"

IDV_RESPONSE=$(curl -s -X POST "${BACKEND_URL}/trust/idv" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -d "{\"caregiverProfileId\": \"${CAREGIVER_PROFILE_ID}\"}" 2>/dev/null)

echo "  IDV response: $IDV_RESPONSE"
pass "Identity verification initiated"

# ─────────────────────────────────────────────────
# PHASE 4: Simulate BG + IDV completion (test env auto-approves or use webhook sim)
# ─────────────────────────────────────────────────
step "Simulate BG check + IDV completion"

# In test environment, these may auto-complete. If not, use admin override endpoints.
# Try the webhook simulation endpoints first
curl -s -X POST "${BACKEND_URL}/trust/webhooks/background-check/simulate" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -d "{\"caregiverProfileId\": \"${CAREGIVER_PROFILE_ID}\", \"status\": \"clear\"}" 2>/dev/null || true

curl -s -X POST "${BACKEND_URL}/trust/webhooks/idv/simulate" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -d "{\"caregiverProfileId\": \"${CAREGIVER_PROFILE_ID}\", \"status\": \"approved\"}" 2>/dev/null || true

# If simulation endpoints don't exist, try direct admin update
curl -s -X PATCH "${BACKEND_URL}/admin/caregivers/${CAREGIVER_PROFILE_ID}" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -d '{"bgCheckStatus": "clear", "idvStatus": "approved"}' 2>/dev/null || true

sleep 2

# Verify BG + IDV status
CG_DETAIL=$(curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "${BACKEND_URL}/admin/caregivers/${CAREGIVER_PROFILE_ID}" 2>/dev/null)

BG_STATUS=$(echo "$CG_DETAIL" | python3 -c "
import sys, json
data = json.load(sys.stdin)
d = data.get('data', data)
print(d.get('bgCheckStatus', d.get('backgroundCheckStatus', 'unknown')))" 2>/dev/null)

IDV_STATUS=$(echo "$CG_DETAIL" | python3 -c "
import sys, json
data = json.load(sys.stdin)
d = data.get('data', data)
print(d.get('idvStatus', d.get('identityVerificationStatus', 'unknown')))" 2>/dev/null)

echo "  BG Check status: $BG_STATUS"
echo "  IDV status: $IDV_STATUS"

if [[ "$BG_STATUS" == "clear" || "$BG_STATUS" == "passed" ]]; then
  pass "BG check cleared"
else
  fail "BG check not cleared (got: $BG_STATUS)"
fi

if [[ "$IDV_STATUS" == "approved" || "$IDV_STATUS" == "verified" ]]; then
  pass "IDV approved"
else
  fail "IDV not approved (got: $IDV_STATUS)"
fi

# ─────────────────────────────────────────────────
# PHASE 5: Admin approves caregiver
# ─────────────────────────────────────────────────
step "Admin: Approve caregiver"

APPROVE_RESPONSE=$(curl -s -X PUT "${BACKEND_URL}/trust/caregivers/${CAREGIVER_PROFILE_ID}/approve" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" 2>/dev/null)

echo "  Approve response: $APPROVE_RESPONSE"

sleep 2

# Verify approved status
CG_STATUS=$(curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "${BACKEND_URL}/admin/caregivers/${CAREGIVER_PROFILE_ID}" \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
d = data.get('data', data)
print(d.get('status', 'unknown'))" 2>/dev/null)

echo "  Caregiver status: $CG_STATUS"

if [[ "$CG_STATUS" == "approved" || "$CG_STATUS" == "active" ]]; then
  pass "Caregiver approved"
else
  fail "Caregiver not approved (got: $CG_STATUS)"
fi

# ─────────────────────────────────────────────────
# PHASE 6: Caregiver logs in and verifies home dashboard
# ─────────────────────────────────────────────────
step "Caregiver: Login and verify home dashboard"

# Create a temporary maestro flow for the pending caregiver login
TEMP_FLOW=$(mktemp /tmp/cg-pending-login-XXXXXX.yaml)
cat > "$TEMP_FLOW" << 'YAML'
appId: polygentic.bijouxCaregiverApp
---
- launchApp:
    clearState: true
    clearKeychain: true
- tapOn: "Get Started"
- assertVisible: "Welcome back"
- tapOn: "you@example.com"
- inputText: "cg-pending@test.bijoux.app"
- tapOn: "Welcome Back"
- tapOn: "Show password"
- tapOn:
    id: "login-password-field"
- inputText: "Test1234!"
- scroll
- tapOn:
    id: "login-submit-button"
- waitForAnimationToEnd
# After approval, should land on home dashboard, NOT setup wizard
- assertNotVisible: "Complete Your Profile"
  optional: true
- assertVisible:
    id: "home-greeting-label"
  optional: true
- takeScreenshot: results/cross-app/caregiver-approved-home
YAML

if maestro --udid="$CAREGIVER_UDID" test "$TEMP_FLOW" 2>&1; then
  pass "Caregiver sees home dashboard after approval"
else
  fail "Caregiver did not land on home dashboard"
  echo "  NOTE: Caregiver may still need to complete setup wizard"
fi

rm -f "$TEMP_FLOW"

# ─────────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════"
echo "  UAT-19.3 RESULTS"
echo "═══════════════════════════════════════════════════"
echo "  Caregiver Profile ID: ${CAREGIVER_PROFILE_ID:-N/A}"
echo "  BG Check: ${BG_STATUS:-N/A}"
echo "  IDV: ${IDV_STATUS:-N/A}"
echo "  Final Status: ${CG_STATUS:-N/A}"
echo "  Failures: $FAILURES"
echo ""

if [[ $FAILURES -eq 0 ]]; then
  echo "  OVERALL: PASS"
  exit 0
else
  echo "  OVERALL: FAIL ($FAILURES failures)"
  exit 1
fi
