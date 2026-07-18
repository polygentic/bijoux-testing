# Cross-App Verify: Transactions List

## UAT ID
UAT-L2.14

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!

## Steps
1. Navigate to http://localhost:3001/transactions
2. Verify transactions table loads
3. If type filter exists, filter by "authorization" — verify E2E auth transactions
4. Filter by "capture" — verify E2E capture transactions
5. Verify each row shows: type, status, amount, date, associated booking/user
6. Take a screenshot

## Pass Criteria
- Transactions table populated
- Authorization and capture transactions from E2E visible
- Type filter works
- Amount displayed in correct format
