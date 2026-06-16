# Cross-App Verify: Bookings List & Filter

## UAT ID
UAT-L2.7

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!
- E2E scripts have created bookings

## Steps
1. Navigate to http://localhost:3001/bookings
2. Verify the bookings table loads with data
3. If lifecycle filter exists, filter by "Completed" — verify completed E2E bookings appear
4. If date filter exists, filter by today's date
5. Verify each booking row shows: booking ID, parent name, lifecycle status, date
6. Click a booking to verify navigation to detail page works
7. Navigate back, take a screenshot

## Pass Criteria
- Bookings table populated with E2E bookings
- Lifecycle filter works correctly
- Booking rows show ID, parent, status, date
- Row click navigates to booking detail
