#!/usr/bin/env bash
# UAT: Multi-Parent Concurrent Bookings
#
# Requires: 4 sims (bijoux-parent, bijoux-parent-2, bijoux-care, bijoux-care-2)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/config/environment.sh"
source "$ROOT_DIR/scripts/lib/api-helpers.sh"

[[ -z "$PARENT_UDID" ]] && echo "ERROR: PARENT_UDID not set" >&2 && exit 1
[[ -z "${PARENT_UDID_2:-}" ]] && echo "ERROR: PARENT_UDID_2 not set" >&2 && exit 1
[[ -z "$CAREGIVER_UDID" ]] && echo "ERROR: CAREGIVER_UDID not set" >&2 && exit 1
[[ -z "${CAREGIVER_UDID_2:-}" ]] && echo "ERROR: CAREGIVER_UDID_2 not set" >&2 && exit 1

mkdir -p "$ROOT_DIR/results/cross-app"
FAILURES=0; STEP=0
step()  { STEP=$((STEP + 1)); echo ""; echo "═══ STEP $STEP: $1 ═══"; }
pass()  { echo "  ✓ PASS: $1"; }
fail()  { echo "  ✗ FAIL: $1"; FAILURES=$((FAILURES + 1)); }

# Setup
step "Authenticate all users"
P1_TOKEN=$(api_login "$PARENT_EMAIL" "$PARENT_PASSWORD")
P2_TOKEN=$(api_login "$PARENT_2_EMAIL" "$PARENT_2_PASSWORD")
CG1_TOKEN=$(api_login "$CAREGIVER_EMAIL" "$CAREGIVER_PASSWORD")
CG2_TOKEN=$(api_login "$CAREGIVER_ONLINE_EMAIL" "$CAREGIVER_ONLINE_PASSWORD")
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
api_set_online "$CG1_TOKEN" "true"
api_set_online "$CG2_TOKEN" "true"
pass "All tokens obtained, caregivers online"

# Login all 4 sims
step "Login all devices"
maestro test "$ROOT_DIR/flows/caregiver/login-valid.yaml" --device "$CAREGIVER_UDID" 2>&1 && pass "Emma" || fail "Emma login"
maestro test "$ROOT_DIR/flows/caregiver/login-maria.yaml" --device "$CAREGIVER_UDID_2" 2>&1 && pass "Maria" || fail "Maria login"
maestro test "$ROOT_DIR/flows/caregiver/go-online.yaml" --device "$CAREGIVER_UDID" 2>&1 || true
maestro test "$ROOT_DIR/flows/caregiver/go-online.yaml" --device "$CAREGIVER_UDID_2" 2>&1 || true

# Sarah books
step "Sarah: Login and book"
maestro test "$ROOT_DIR/flows/cross-app/parent-login-and-book.yaml" --device "$PARENT_UDID" 2>&1 \
  && pass "Sarah booked" || { fail "Sarah booking"; exit 1; }
sleep 3
BOOKING_1=$(api_latest_booking_id "$P1_TOKEN")
pass "Booking 1: $BOOKING_1"

# Emma accepts Sarah's booking
step "Emma: Accept Sarah's offer"
sleep 5
maestro test "$ROOT_DIR/flows/caregiver/accept-offer.yaml" --device "$CAREGIVER_UDID" 2>&1 \
  && pass "Emma accepted" || fail "Emma accept"

# James books
step "James: Login and book"
maestro test "$ROOT_DIR/flows/parent/login-james.yaml" --device "$PARENT_UDID_2" 2>&1 \
  && pass "James logged in" || { fail "James login"; exit 1; }
maestro test "$ROOT_DIR/flows/parent/quick-booking-submit.yaml" --device "$PARENT_UDID_2" 2>&1 \
  && pass "James booked" || fail "James booking"
sleep 3
BOOKING_2=$(api_latest_booking_id "$P2_TOKEN")
pass "Booking 2: $BOOKING_2"

# Maria accepts James's booking
step "Maria: Accept James's offer"
sleep 5
maestro test "$ROOT_DIR/flows/caregiver/accept-offer.yaml" --device "$CAREGIVER_UDID_2" 2>&1 \
  && pass "Maria accepted" || fail "Maria accept"

# Complete both sessions (abbreviated — IOMW through end)
step "Complete Session 1: Emma + Sarah"
maestro test "$ROOT_DIR/flows/caregiver/iomw.yaml" --device "$CAREGIVER_UDID" 2>&1 || fail "Emma IOMW"
maestro test "$ROOT_DIR/flows/caregiver/confirm-arrival.yaml" --device "$CAREGIVER_UDID" 2>&1 || fail "Emma arrival"
maestro test "$ROOT_DIR/flows/caregiver/start-session-verify.yaml" --device "$CAREGIVER_UDID" 2>&1 || fail "Emma session start"
maestro test "$ROOT_DIR/flows/parent/confirm-session-start.yaml" --device "$PARENT_UDID" 2>&1 || fail "Sarah confirm start"
maestro test "$ROOT_DIR/flows/caregiver/end-session.yaml" --device "$CAREGIVER_UDID" 2>&1 || fail "Emma end session"
maestro test "$ROOT_DIR/flows/parent/confirm-session-end.yaml" --device "$PARENT_UDID" 2>&1 || fail "Sarah confirm end"

step "Complete Session 2: Maria + James"
maestro test "$ROOT_DIR/flows/caregiver/iomw.yaml" --device "$CAREGIVER_UDID_2" 2>&1 || fail "Maria IOMW"
maestro test "$ROOT_DIR/flows/caregiver/confirm-arrival.yaml" --device "$CAREGIVER_UDID_2" 2>&1 || fail "Maria arrival"
maestro test "$ROOT_DIR/flows/caregiver/start-session-verify.yaml" --device "$CAREGIVER_UDID_2" 2>&1 || fail "Maria session start"
maestro test "$ROOT_DIR/flows/parent/confirm-session-start.yaml" --device "$PARENT_UDID_2" 2>&1 || fail "James confirm start"
maestro test "$ROOT_DIR/flows/caregiver/end-session.yaml" --device "$CAREGIVER_UDID_2" 2>&1 || fail "Maria end session"
maestro test "$ROOT_DIR/flows/parent/confirm-session-end.yaml" --device "$PARENT_UDID_2" 2>&1 || fail "James confirm end"

# Verify both completed
step "API verification"
sleep 3
L1=$(api_booking_lifecycle "$P1_TOKEN" "$BOOKING_1")
L2=$(api_booking_lifecycle "$P2_TOKEN" "$BOOKING_2")
echo "  Booking 1: $L1, Booking 2: $L2"
[[ "$L1" == "completed" ]] && pass "Booking 1 completed" || fail "Booking 1: $L1"
[[ "$L2" == "completed" ]] && pass "Booking 2 completed" || fail "Booking 2: $L2"

echo ""
echo "═══ MULTI-PARENT — $( [[ $FAILURES -eq 0 ]] && echo "PASS ✓" || echo "FAIL ($FAILURES)" ) ═══"
[[ $FAILURES -eq 0 ]] && exit 0 || exit 1
