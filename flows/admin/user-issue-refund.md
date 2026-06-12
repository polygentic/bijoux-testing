# User Issue Refund — Sarah Mitchell

## UAT ID
UAT-11.6

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app (complete UAT-9.1 first)
- Seed data includes Sarah Mitchell with at least one booking eligible for refund

## Steps
1. Navigate to http://localhost:3001/users
2. Wait for the user table to load
3. Find and click on "Sarah Mitchell" to open her detail view
4. Navigate to the Credits tab if not already there
5. Note the current credit balance
6. Click the "Issue Credit" button
7. A modal should appear with a form
8. In the modal, locate the booking dropdown and select a booking from the list
9. Enter the amount: $5.00
10. Select type: "Refund"
11. Enter reason: "UAT test refund"
12. Click the "Submit" button (or equivalent confirm button)
13. Wait for the action to complete
14. Verify a new ledger entry appears with amount $5.00, type "Refund", and reason "UAT test refund"

## Pass Criteria
- The "Issue Credit" modal allows selecting "Refund" as the type
- After submission, a new refund ledger entry is created with amount $5.00 and reason "UAT test refund"
- The refund entry is clearly distinguishable from credit entries in the ledger (e.g. different type label or visual indicator)
- No Stripe errors appear (Stripe refund is bypassed in the test environment)
- The UI does not crash or show unexpected errors
