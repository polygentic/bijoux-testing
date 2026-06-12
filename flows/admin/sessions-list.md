# Sessions List & Filters

## UAT ID
UAT-14.1

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!
- Multiple sessions exist in the database with varied statuses, caregivers, dates, and at least one overtime session (actual duration > booked duration) if possible

## Steps
1. Navigate to http://localhost:3001/sessions
2. Verify the sessions table is displayed with the following columns: Session ID, Caregiver, Status, Started, Duration, Booked Duration, Amount, Rating
3. Verify that rows are populated with session data
4. Locate the Status filter dropdown. Select "Completed"
5. Verify the table updates to show only sessions with status "Completed"
6. Clear the Status filter
7. Locate the date range filter. Set a start date and end date that encompasses known sessions
8. Verify the table filters to show only sessions within the selected date range
9. Clear the date range filter
10. Locate the search input. Type a known caregiver name
11. Verify the table filters to show only sessions for that caregiver
12. Clear the search input
13. Inspect the table for any overtime sessions (where actual duration exceeds booked duration)
14. If overtime sessions exist, verify they are highlighted with an amber background

## Pass Criteria
- Table renders with all 8 required columns: Session ID, Caregiver, Status, Started, Duration, Booked Duration, Amount, Rating
- Status filter "Completed" returns only completed sessions
- Date range filter restricts results to the selected range
- Caregiver name search filters results to the matching caregiver
- Overtime sessions (actual > booked duration) are highlighted with amber background, if any exist
- Clearing each filter restores the full unfiltered list
