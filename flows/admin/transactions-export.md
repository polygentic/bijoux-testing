# Export Transactions CSV

## UAT ID
UAT-15.2

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!
- At least several transactions exist in the database

## Steps
1. Navigate to http://localhost:3001/transactions
2. Verify the transactions table is displayed with data
3. Locate the "Export CSV" or download button (may be an icon button in the table header area)
4. Click the export/download button
5. Verify a CSV file downloads to the local machine
6. Open the downloaded CSV file
7. Verify the CSV contains the following columns matching the table: Transaction ID, Booking ID, Type, Status, Amount, Stripe Ref, Created
8. Verify the CSV data rows match the data displayed in the table
9. Verify the CSV is well-formed (proper comma separation, quoted strings where needed)

## Pass Criteria
- Export CSV / download button is visible and clickable
- Clicking the button triggers a CSV file download
- The CSV file contains columns matching the table: Transaction ID, Booking ID, Type, Status, Amount, Stripe Ref, Created
- CSV data rows correspond to the transactions displayed in the UI
- The CSV file is properly formatted and parseable
