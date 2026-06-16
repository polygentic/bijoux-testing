# Cross-App Verify: Credit History

## UAT ID
UAT-L2.6

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!

## Steps
1. Navigate to Sarah's user detail page (http://localhost:3001/users, search "Sarah", click)
2. Find the credit history or credit ledger section
3. Verify the section loads without error
4. If credits have been issued (from Layer 3 tests), verify entries appear with amount, date, reason
5. Take a screenshot

## Pass Criteria
- Credit history section loads
- If credits exist, entries show amount, date, and reason
- If no credits yet, section shows empty state (not error)
