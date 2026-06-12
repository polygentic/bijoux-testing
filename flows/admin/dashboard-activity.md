# Dashboard Recent Activity

## UAT ID
UAT-10.2

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app (complete UAT-9.1 first)

## Steps
1. Navigate to the admin dashboard (http://localhost:3001/ or /dashboard)
2. Wait for the page to fully load
3. Scroll down if necessary to locate the "Recent Activity" section
4. Verify the section heading "Recent Activity" is visible
5. Examine the first audit log entry in the list
6. Verify the entry includes an action description (e.g. "User created", "Booking completed")
7. Verify the entry includes a resource identifier (e.g. user name, booking ID)
8. Verify the entry includes a timestamp (date/time)

## Pass Criteria
- A "Recent Activity" section is visible on the dashboard
- At least one audit log entry is displayed in the list
- Each visible entry contains an action (what happened), a resource (what it happened to), and a timestamp (when it happened)
- The entries are not in a loading or error state
