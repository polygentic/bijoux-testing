# Cross-App Verify: Audit Log CSV Export

## UAT ID
UAT-L2.20

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!

## Steps
1. Navigate to http://localhost:3001/audit-log
2. Apply a date filter for today's date
3. Look for an "Export" or "Download CSV" button
4. Click the export button
5. Verify a file downloads (check for download notification or file in downloads)
6. Take a screenshot

## Pass Criteria
- Export button is visible and clickable
- Clicking export triggers a file download
- Downloaded file has .csv extension
