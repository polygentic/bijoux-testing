# Cancel Booking

## UAT ID
UAT-13.3

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!
- At least one active booking exists that is NOT in "Cancelled" or "Completed" status

## Steps
1. Navigate to http://localhost:3001/bookings
2. Identify a booking with an active status (not Cancelled or Completed). Note the Booking ID
3. Click the booking row to open the booking detail page
4. Verify the "Cancel Booking" button is visible
5. Click the "Cancel Booking" button
6. Verify a confirmation modal appears
7. In the modal, enter the reason: "UAT test cancellation"
8. Click the confirm/submit button in the modal
9. Verify the booking status changes to "Cancelled" on the detail page
10. Verify a cancellation info card appears showing the cancellation reason "UAT test cancellation"
11. Verify the "Cancel Booking" button is no longer visible on the page

## Pass Criteria
- Cancel Booking button is present on active bookings
- Modal appears with a reason input field
- After confirmation, the booking status updates to "Cancelled"
- Cancellation info card is displayed with the entered reason
- Cancel Booking button is removed after successful cancellation
