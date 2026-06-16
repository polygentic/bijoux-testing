# Checkpoint: Verify Session Completed in Admin Portal

## Context
Run after session ends in the iOS E2E flow. Verifies session and transactions in admin.

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!
- SESSION_ID and BOOKING_ID available

## Steps
1. Navigate to http://localhost:3001/sessions
2. Find the session (filter by completed status if available)
3. Click to open session detail
4. Verify session status is "Completed"
5. Verify booking link points to the correct booking
6. Verify caregiver name matches
7. Navigate to http://localhost:3001/bookings/{BOOKING_ID}
8. Scroll to Transactions section
9. Verify authorization and capture transactions exist
10. Take a screenshot

## Pass Criteria
- Session shows as completed in admin
- Session detail shows correct booking and caregiver
- Transactions section shows authorization + capture
