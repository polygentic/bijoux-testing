# Export Audit Log CSV

## UAT ID
UAT-17.2

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!
- Audit log entries exist in the database

## Steps
1. Navigate to http://localhost:3001/audit-log
2. Verify the audit log table is displayed with data
3. Locate the "Export CSV" button
4. Click the Export CSV button
5. Verify a CSV file downloads to the local machine
6. Open the downloaded CSV file
7. Verify the CSV contains the following columns: Timestamp, Actor, Action, Resource Type, Resource ID, Details
8. Verify the Details column is included and contains the JSON or stringified details data
9. Verify the CSV data rows correspond to the audit log entries displayed in the UI

## Pass Criteria
- Export CSV button is visible and clickable
- Clicking the button triggers a CSV file download
- The CSV file contains all expected columns including: Timestamp, Actor, Action, Resource Type, Resource ID, Details
- The Details column is present and contains the event detail data
- CSV data rows correspond to the entries displayed in the table
- The CSV file is properly formatted and parseable
