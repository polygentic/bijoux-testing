# Booking Cancellation Cross-App Flow

## UAT ID
UAT-19.2

## Prerequisites
- API server running (e.g., http://localhost:3000)
- Admin portal running at http://localhost:3001
- Parent mobile app built and installed on simulator
- Logged-in parent account with valid payment method
- iOS Simulator UDID configured:
  - `PARENT_SIMULATOR_UDID` — Simulator running the parent app
- Maestro CLI installed and available in PATH
- Admin credentials: admin@bijoux.app / Test1234!

## Steps

### Phase 1: Parent Creates Booking (Parent App)
1. Launch the parent app on the parent simulator
2. Run the parent login maestro flow:
   ```bash
   maestro --udid=$PARENT_SIMULATOR_UDID test flows/parent/login.yaml
   ```
3. Create a new booking via the parent app:
   ```bash
   maestro --udid=$PARENT_SIMULATOR_UDID test flows/parent/create-booking.yaml
   ```
4. Retrieve the Booking ID:
   ```bash
   PARENT_TOKEN="<parent_jwt_token>"
   BOOKING_ID=$(curl -s -H "Authorization: Bearer $PARENT_TOKEN" \
     http://localhost:3000/api/v1/bookings?limit=1\&sort=-createdAt \
     | jq -r '.data[0].id')
   echo "Booking ID: $BOOKING_ID"
   ```
5. Verify the booking status is active:
   ```bash
   curl -s -H "Authorization: Bearer $PARENT_TOKEN" \
     http://localhost:3000/api/v1/bookings/$BOOKING_ID \
     | jq '.data.status'
   # Expected: "pending" or "matching"
   ```

### Phase 2: Admin Cancels Booking (Admin Portal)
6. Log in to the admin portal at http://localhost:3001 as admin@bijoux.app / Test1234!
7. Navigate to http://localhost:3001/bookings
8. Search for or locate the Booking ID from Phase 1
9. Click the booking row to open the detail page
10. Click the "Cancel Booking" button
11. In the modal, enter reason: "UAT-19.2 cross-app cancellation test"
12. Confirm the cancellation
13. Verify the booking status changes to "Cancelled" in the admin portal
14. Verify the cancellation info card shows the reason

### Phase 3: Parent App Reflects Cancelled State (Parent App)
15. Switch to the parent simulator
16. Navigate to the bookings list or booking detail in the parent app:
    ```bash
    maestro --udid=$PARENT_SIMULATOR_UDID test flows/parent/view-bookings.yaml
    ```
17. Alternatively, verify via API that the parent sees the cancelled status:
    ```bash
    curl -s -H "Authorization: Bearer $PARENT_TOKEN" \
      http://localhost:3000/api/v1/bookings/$BOOKING_ID \
      | jq '.data.status'
    # Expected: "cancelled"
    ```
18. Verify the parent app displays the booking as cancelled (e.g., status badge, greyed out, or moved to past bookings)

## Pass Criteria
- Parent successfully creates a booking via the parent app
- Admin can locate the booking in the admin portal
- Admin cancels the booking with a reason via the admin portal
- Admin portal shows the booking as "Cancelled" with the cancellation reason
- Parent app reflects the cancelled state (either via UI or confirmed via API)
- The booking status returned by the API is "cancelled" after admin cancellation
