# Checkpoint: Verify Booking Cancelled in Admin Portal

## Context
Run after booking cancellation in the cancel-after-match E2E flow.

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!
- BOOKING_ID available

## Steps
1. Navigate to http://localhost:3001/bookings/{BOOKING_ID}
2. Verify booking lifecycle is "Cancelled"
3. Verify cancellation info card shows the reason
4. Scroll to Transactions section
5. Look for cancellation fee transaction
6. Take a screenshot

## Pass Criteria
- Booking lifecycle is Cancelled
- Cancellation reason is displayed
- Cancellation fee transaction exists (if applicable)
