# User Reactivate — Alex Chen

## UAT ID
UAT-11.4

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app (complete UAT-9.1 first)
- Alex Chen (parent-suspended@test.bijoux.app) is currently in "Suspended" status (complete UAT-11.3 first)

## Steps
1. Navigate to http://localhost:3001/users
2. Wait for the user table to load
3. Find Alex Chen (email: parent-suspended@test.bijoux.app) in the table
4. Verify Alex Chen's status is currently "Suspended"
5. Click on Alex Chen to open the detail view (or click a Reactivate button if available in the table row)
6. Click the "Reactivate" button
7. A confirmation modal should appear
8. Click the "Confirm" button in the modal
9. Wait for the action to complete
10. Verify Alex Chen's status has changed to "Active"

## Pass Criteria
- The Reactivate button is visible for a suspended user
- A confirmation modal appears before reactivation
- After confirming, the user's status changes to "Active" in the UI
- The user table reflects the updated status immediately or after refresh
