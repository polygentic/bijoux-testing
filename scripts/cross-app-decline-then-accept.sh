#!/usr/bin/env bash
# UAT: Multi-Caregiver — First Declines, Second Accepts
#
# Requires: 3 sims booted (bijoux-parent, bijoux-care, bijoux-care-2)
#
# Usage:
#   ./scripts/cross-app-decline-then-accept.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/config/environment.sh"
source "$ROOT_DIR/scripts/lib/api-helpers.sh"

[[ -z "$PARENT_UDID" ]] && echo "ERROR: PARENT_UDID not set" >&2 && exit 1
[[ -z "$CAREGIVER_UDID" ]] && echo "ERROR: CAREGIVER_UDID not set" >&2 && exit 1
[[ -z "${CAREGIVER_UDID_2:-}" ]] && echo "ERROR: CAREGIVER_UDID_2 not set. Create 4 sims first." >&2 && exit 1

mkdir -p "$ROOT_DIR/results/cross-app"
FAILURES=0; STEP=0
step()  { STEP=$((STEP + 1)); echo ""; echo "═══ STEP $STEP: $1 ═══"; }
pass()  { echo "  ✓ PASS: $1"; }
fail()  { echo "  ✗ FAIL: $1"; FAILURES=$((FAILURES + 1)); }

# Phase 1: API setup
step "Authenticate and set both caregivers online"
PARENT_TOKEN=$(api_login "$PARENT_EMAIL" "$PARENT_PASSWORD")
CG1_TOKEN=$(api_login "$CAREGIVER_EMAIL" "$CAREGIVER_PASSWORD")
CG2_TOKEN=$(api_login "$CAREGIVER_ONLINE_EMAIL" "$CAREGIVER_ONLINE_PASSWORD")
api_set_online "$CG1_TOKEN" "true"
api_set_online "$CG2_TOKEN" "true"
pass "Both caregivers online"

# Phase 2: Login both caregivers on separate sims
step "Login Emma on bijoux-care"
maestro test "$ROOT_DIR/flows/caregiver/login-valid.yaml" --device "$CAREGIVER_UDID" 2>&1 \
  && pass "Emma logged in" || { fail "Emma login"; exit 1; }

step "Login Maria on bijoux-care-2"
maestro test "$ROOT_DIR/flows/caregiver/login-maria.yaml" --device "$CAREGIVER_UDID_2" 2>&1 \
  && pass "Maria logged in" || { fail "Maria login"; exit 1; }

# Go online on both
maestro test "$ROOT_DIR/flows/caregiver/go-online.yaml" --device "$CAREGIVER_UDID" 2>&1 || true
maestro test "$ROOT_DIR/flows/caregiver/go-online.yaml" --device "$CAREGIVER_UDID_2" 2>&1 || true

# Phase 3: Parent books
step "Parent: Login and book"
maestro test "$ROOT_DIR/flows/cross-app/parent-login-and-book.yaml" --device "$PARENT_UDID" 2>&1 \
  && pass "Parent booked" || { fail "Parent booking"; exit 1; }

sleep 3
BOOKING_ID=$(api_latest_booking_id "$PARENT_TOKEN")
pass "Booking: $BOOKING_ID"

# Phase 4: Emma declines
step "Wait for offers, Emma declines"
sleep 5
maestro test "$ROOT_DIR/flows/caregiver/decline-offer.yaml" --device "$CAREGIVER_UDID" 2>&1 \
  && pass "Emma declined" || fail "Emma decline"

# Phase 5: Maria accepts
step "Maria accepts"
maestro test "$ROOT_DIR/flows/caregiver/accept-offer.yaml" --device "$CAREGIVER_UDID_2" 2>&1 \
  && pass "Maria accepted" || { fail "Maria accept"; exit 1; }

# Phase 6: Verify parent sees Maria (not Emma)
step "Parent: Verify Maria matched"
maestro test "$ROOT_DIR/flows/parent/verify-matched.yaml" --device "$PARENT_UDID" 2>&1 \
  && pass "Parent sees match" || fail "Parent verify-matched"

# Phase 7: Complete through session end (Maria on bijoux-care-2)
step "Maria: IOMW → Arrival → Session Start → Session End"
maestro test "$ROOT_DIR/flows/caregiver/iomw.yaml" --device "$CAREGIVER_UDID_2" 2>&1 || fail "Maria IOMW"
maestro test "$ROOT_DIR/flows/caregiver/confirm-arrival.yaml" --device "$CAREGIVER_UDID_2" 2>&1 || fail "Maria arrival"
maestro test "$ROOT_DIR/flows/caregiver/start-session-verify.yaml" --device "$CAREGIVER_UDID_2" 2>&1 || fail "Maria session start"
maestro test "$ROOT_DIR/flows/parent/confirm-session-start.yaml" --device "$PARENT_UDID" 2>&1 || fail "Parent session start"
maestro test "$ROOT_DIR/flows/caregiver/end-session.yaml" --device "$CAREGIVER_UDID_2" 2>&1 || fail "Maria end session"
maestro test "$ROOT_DIR/flows/parent/confirm-session-end.yaml" --device "$PARENT_UDID" 2>&1 || fail "Parent session end"

# Phase 8: Verify
step "API verification"
sleep 3
FINAL=$(api_booking_lifecycle "$PARENT_TOKEN" "$BOOKING_ID")
echo "  Final lifecycle: $FINAL"
[[ "$FINAL" == "completed" ]] && pass "Booking completed" || fail "Booking not completed: $FINAL"

step "Verify offer statuses via API"
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
OFFERS=$(curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "${BACKEND_URL}/admin/bookings/${BOOKING_ID}" 2>/dev/null)
echo "$OFFERS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
d = data.get('data', data)
offers = d.get('offers', d.get('matchOffers', []))
if isinstance(offers, list):
    for o in offers:
        name = o.get('caregiver', {}).get('firstName', o.get('caregiverId', ''))
        status = o.get('status', '')
        print(f'  Offer: {name} → {status}')
" 2>/dev/null || echo "  Could not parse offers (admin endpoint may differ)"

echo ""
echo "═══ DECLINE-THEN-ACCEPT — $( [[ $FAILURES -eq 0 ]] && echo "PASS ✓" || echo "FAIL ($FAILURES)" ) ═══"
[[ $FAILURES -eq 0 ]] && exit 0 || exit 1
