# User Suspend — Alex Chen

## UAT ID
UAT-11.3

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app (complete UAT-9.1 first)
- Seed data includes Alex Chen (parent-suspended@test.bijoux.app)

## Steps
1. Navigate to http://localhost:3001/users
2. Wait for the user table to load
3. Find Alex Chen (email: parent-suspended@test.bijoux.app) in the table
4. Note Alex Chen's current status — if already suspended, skip to UAT-11.4
5. Click on Alex Chen to open the detail view (or click a Suspend button if available in the table row)
6. Click the "Suspend" button
7. A confirmation modal should appear
8. In the modal, locate the reason input field and type "UAT test suspension"
9. Click the "Confirm" button in the modal
10. Wait for the action to complete
11. Verify Alex Chen's status has changed to "Suspended"
12. Check the dashboard or audit log section for a new entry reflecting this suspension

## Pass Criteria
- The Suspend button is visible and clickable for an active user
- A confirmation modal appears requiring a reason before suspension
- After confirming, the user's status changes to "Suspended" in the UI
- An audit log entry is created recording the suspension action
- The suspension reason "UAT test suspension" is captured
