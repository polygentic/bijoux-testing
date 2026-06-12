# Bookings List & Filters

## UAT ID
UAT-13.1

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!
- At least several bookings exist in the database with varied statuses, types, dates, and parent names (including a parent named "Sarah")

## Steps
1. Navigate to http://localhost:3001/bookings
2. Verify the bookings table is displayed with the following columns: Booking ID, Parent, Type, Status, Scheduled, Estimated, Location, Created
3. Verify that rows are populated with booking data
4. Locate the Status filter dropdown. Select "Completed"
5. Verify the table updates to show only bookings with status "Completed"
6. Clear the Status filter
7. Locate the Type filter dropdown. Select "Request Now"
8. Verify the table updates to show only bookings with type "Request Now"
9. Clear the Type filter
10. Locate the date range filter. Set a start date and end date that encompasses known bookings
11. Verify the table filters to show only bookings within the selected date range
12. Clear the date range filter
13. Locate the search input. Type "Sarah"
14. Verify the table filters to show only bookings where the parent name contains "Sarah"
15. Clear the search input and verify all bookings reappear

## Pass Criteria
- Table renders with all 8 required columns: Booking ID, Parent, Type, Status, Scheduled, Estimated, Location, Created
- Status filter "Completed" returns only completed bookings
- Type filter "Request Now" returns only request-now bookings
- Date range filter restricts results to the selected range
- Search by "Sarah" returns only bookings associated with a parent named Sarah
- Clearing each filter restores the full unfiltered list
