# Transactions List & Filters

## UAT ID
UAT-15.1

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!
- Multiple transactions exist in the database with varied types (Authorization, Capture, Refund, etc.) and statuses (Succeeded, Pending, Failed, etc.)

## Steps
1. Navigate to http://localhost:3001/transactions
2. Verify the transactions table is displayed with the following columns: Transaction ID, Booking ID, Type, Status, Amount, Stripe Ref, Created
3. Verify that rows are populated with transaction data
4. Verify all amounts are formatted as currency (e.g., $25.00, not 2500 or 25)
5. Locate the Type filter dropdown. Select "Authorization"
6. Verify the table updates to show only transactions with type "Authorization"
7. Clear the Type filter
8. Locate the Status filter dropdown. Select "Succeeded"
9. Verify the table updates to show only transactions with status "Succeeded"
10. Clear the Status filter
11. Locate the date range filter. Set a start date and end date that encompasses known transactions
12. Verify the table filters to show only transactions within the selected date range
13. Clear the date range filter and verify all transactions reappear

## Pass Criteria
- Table renders with all 7 required columns: Transaction ID, Booking ID, Type, Status, Amount, Stripe Ref, Created
- Type filter "Authorization" returns only authorization transactions
- Status filter "Succeeded" returns only succeeded transactions
- Date range filter restricts results to the selected range
- All amounts are displayed in proper currency format (e.g., $XX.XX)
- Clearing each filter restores the full unfiltered list
