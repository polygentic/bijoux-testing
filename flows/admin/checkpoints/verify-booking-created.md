# Checkpoint: Verify Booking Created in Admin Portal

## Context
Run after parent creates a booking in the iOS E2E flow. Verifies the booking appears in the admin portal with correct lifecycle status.

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!
- BOOKING_ID available from state.json or script output

## Steps
1. Navigate to http://localhost:3001/bookings
2. Look for the booking in the list (may need to sort by newest first)
3. Verify the booking row shows lifecycle status "Matching" or "Created"
4. Click the booking row to open detail
5. Verify Booking Details card shows the booking ID
6. Verify Parent Info shows the correct parent name
7. Take a screenshot

## Pass Criteria
- Booking appears in admin bookings list
- Lifecycle status is "Matching" or "Created"
- Parent name matches the E2E test parent
