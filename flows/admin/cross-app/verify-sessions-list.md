# Cross-App Verify: Sessions List & Filter

## UAT ID
UAT-L2.11

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!

## Steps
1. Navigate to http://localhost:3001/sessions
2. Verify sessions table loads
3. If status filter exists, filter by "Completed" — verify E2E sessions appear
4. If caregiver filter exists, filter by "Emma" or "Maria"
5. Verify session rows show: session ID, status, caregiver name, booking link, duration
6. Take a screenshot

## Pass Criteria
- Sessions table populated with E2E sessions
- Status filter works
- Session rows show key fields
