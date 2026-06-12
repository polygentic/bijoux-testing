# Audit Log List & Filters

## UAT ID
UAT-17.1

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!
- Audit log entries exist in the database with varied resource types, actors, and actions

## Steps
1. Navigate to http://localhost:3001/audit-log
2. Verify the audit log table is displayed with the following columns: Timestamp, Actor, Action, Resource Type, Resource ID, Details
3. Verify that rows are populated with audit log entries
4. Locate the Resource Type filter dropdown. Select "User"
5. Verify the table updates to show only entries where the resource type is "User"
6. Clear the Resource Type filter
7. Locate the Actor filter or search input. Enter a known actor email address (e.g., admin@bijoux.app)
8. Verify the table filters to show only entries where the actor matches the entered email
9. Clear the Actor filter
10. Locate the date range filter. Set a start date and end date that encompasses known audit log entries
11. Verify the table filters to show only entries within the selected date range
12. Clear the date range filter
13. Locate an audit log entry row with an expand/show details control (e.g., expand arrow or "Details" link)
14. Click the expand/show details control
15. Verify that JSON details are displayed for that entry, showing the full details payload

## Pass Criteria
- Table renders with all 6 required columns: Timestamp, Actor, Action, Resource Type, Resource ID, Details
- Resource Type filter "User" returns only user-related entries
- Actor filter by email returns only entries from that actor
- Date range filter restricts results to the selected range
- Expanding an entry displays JSON details for the audit event
- Clearing each filter restores the full unfiltered list
