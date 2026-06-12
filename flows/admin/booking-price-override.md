# Booking Price Override

## UAT ID
UAT-13.4

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!
- At least one booking exists that supports price override

## Steps
1. Navigate to http://localhost:3001/bookings
2. Click on a booking row to open the booking detail page
3. Note the current price/cost displayed in the Booking Details card
4. Locate and click the "Price Override" button
5. Verify a modal appears with fields for new price and reason
6. Enter new price: $150.00
7. Enter reason: "UAT test override"
8. Click the submit/confirm button
9. Verify the modal closes
10. Verify the price override is now shown on the booking detail page
11. Verify both the original price and the override price ($150.00) are visible on the page

## Pass Criteria
- Price Override button is accessible on the booking detail page
- Modal accepts a new price and a reason for the override
- After submission, the booking detail page displays the price override
- Both the original price and the overridden price ($150.00) are visible
- The override reason "UAT test override" is recorded and visible
