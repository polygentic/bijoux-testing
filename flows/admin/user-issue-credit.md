# User Issue Credit — Sarah Mitchell

## UAT ID
UAT-11.5

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app (complete UAT-9.1 first)
- Seed data includes Sarah Mitchell with a credit balance of $25.00 and at least one booking

## Steps
1. Navigate to http://localhost:3001/users
2. Wait for the user table to load
3. Find and click on "Sarah Mitchell" to open her detail view
4. Navigate to the Credits tab if not already there
5. Note the current credit balance (expected: $25.00)
6. Click the "Issue Credit" button
7. A modal should appear with a form
8. In the modal, locate the booking dropdown and select a booking from the list
9. Enter the amount: $10.00
10. Select type: "Credit"
11. Enter reason: "UAT test credit"
12. Click the "Submit" button (or equivalent confirm button)
13. Wait for the action to complete
14. Verify the credit balance has increased by $10.00 (expected new balance: $35.00)
15. Verify a new ledger entry appears with amount $10.00, type "Credit", and reason "UAT test credit"

## Pass Criteria
- The "Issue Credit" button is visible on the user's Credits tab
- The modal provides fields for: booking selection, amount, type (Credit/Refund), and reason
- After submission, the credit balance increases by exactly $10.00
- A new ledger entry is created showing the $10.00 credit with the reason "UAT test credit"
- No errors are displayed during the process
