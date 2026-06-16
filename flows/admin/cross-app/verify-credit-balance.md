# Cross-App Verify: Credit Balance

## UAT ID
UAT-L2.22

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!

## Steps
1. Navigate to http://localhost:3001/users
2. Search for or find Sarah's user entry
3. Click to open Sarah's detail page
4. Look for credit balance display
5. Verify the balance amount is displayed (may be $0.00 if no credits issued yet)
6. If a credit history section exists, verify it loads without error
7. Take a screenshot

## Pass Criteria
- User detail page shows credit balance
- Balance display is formatted as currency
- Credit history section (if present) loads without error
