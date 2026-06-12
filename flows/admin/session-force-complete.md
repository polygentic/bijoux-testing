# Force Complete Session

## UAT ID
UAT-14.3

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!
- At least one session exists with status "in_progress"
- NOTE: If no in_progress session exists, this test requires creating an active session first via the booking lifecycle (parent creates booking, caregiver accepts, session starts). Document this prerequisite gap if encountered

## Steps
1. Navigate to http://localhost:3001/sessions
2. Filter by Status: select "In Progress" to locate an in_progress session
3. If no in_progress sessions exist, document that this test cannot be executed without an active session and STOP
4. Click on an in_progress session row to open the session detail page
5. Verify the "Force Complete" button is visible
6. Click the "Force Complete" button
7. Verify a confirmation modal appears with a reason input field
8. Enter the reason: "UAT test force complete"
9. Click the confirm/submit button
10. Verify the session status changes to "Completed" on the detail page
11. Verify the "Force Complete" button is no longer visible

## Pass Criteria
- Force Complete button is present on in_progress sessions
- Modal appears with a reason input field
- After confirmation, the session status updates to "Completed"
- Force Complete button disappears after successful completion
- If no in_progress session exists, the test is documented as blocked with the prerequisite noted
