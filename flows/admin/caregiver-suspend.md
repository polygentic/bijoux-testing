# Caregiver Suspend — Emma Thompson

## UAT ID
UAT-12.4

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app (complete UAT-9.1 first)
- Seed data includes Emma Thompson as an approved caregiver

## Steps
1. Navigate to http://localhost:3001/caregivers
2. Wait for the caregiver table to load
3. Find Emma Thompson in the table and click to open detail view
4. Verify Emma Thompson's current status is "Approved" (or equivalent active status)
5. Note whether Emma Thompson is currently shown as "Online"
6. Click the "Suspend" button
7. A confirmation modal should appear with a reason input
8. Enter reason: "UAT test suspension"
9. Click the "Confirm" button in the modal
10. Wait for the action to complete
11. Verify Emma Thompson's status has changed to "Suspended"
12. Verify Emma Thompson is no longer shown as "Online" (taken offline automatically)

## Pass Criteria
- The Suspend button is visible for an approved caregiver
- A confirmation modal appears requiring a suspension reason
- After confirming, the caregiver's status changes to "Suspended"
- The suspended caregiver is automatically taken offline
- The suspension reason "UAT test suspension" is captured
