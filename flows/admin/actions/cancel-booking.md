# Admin Action: Cancel Booking

## UAT ID
UAT-L3.5

## Setup (run via bash)
```bash
source config/environment.sh && source scripts/lib/api-helpers.sh && source scripts/lib/admin-api-helpers.sh
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
PARENT_TOKEN=$(api_login "$PARENT_EMAIL" "$PARENT_PASSWORD")
CAREGIVER_TOKEN=$(api_login "$CAREGIVER_ONLINE_EMAIL" "$CAREGIVER_ONLINE_PASSWORD")
# Ensure a matched booking exists for cancellation
api_set_online "$CAREGIVER_TOKEN" "true"
api_report_location "$CAREGIVER_TOKEN" "$TEST_LAT" "$TEST_LNG"
# Get latest booking (should be in matched/confirmed state from prior E2E run)
BOOKING_ID=$(api_latest_booking_id "$PARENT_TOKEN")
LIFECYCLE=$(api_booking_lifecycle "$PARENT_TOKEN" "$BOOKING_ID")
echo "Booking: $BOOKING_ID (lifecycle: $LIFECYCLE)"
```

## Admin Action (execute in Chrome)
1. Navigate to http://localhost:3001/bookings
2. Find the booking from setup output (or any active booking)
3. Click the booking row to open detail page
4. Verify the "Cancel Booking" button is visible
5. Click "Cancel Booking"
6. In the confirmation modal, enter reason: "UAT admin cancellation test"
7. Confirm the action
8. Verify booking status changes to "Cancelled"
9. Verify cancellation info card shows the reason
10. Take a screenshot

## API Verification (run via bash)
```bash
source config/environment.sh && source scripts/lib/api-helpers.sh && source scripts/lib/admin-api-helpers.sh
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
PARENT_TOKEN=$(api_login "$PARENT_EMAIL" "$PARENT_PASSWORD")
BOOKING_ID=$(api_latest_booking_id "$PARENT_TOKEN")
LIFECYCLE=$(api_booking_lifecycle "$PARENT_TOKEN" "$BOOKING_ID")
echo "Booking lifecycle: $LIFECYCLE"
# Expected: cancelled
```

## Pass Criteria
- Cancel Booking button visible on active bookings
- Confirmation modal accepts reason
- Booking status updates to "Cancelled" in admin
- Cancellation info card displays with reason
- API confirms lifecycle = cancelled
