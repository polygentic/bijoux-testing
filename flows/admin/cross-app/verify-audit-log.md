# Cross-App Verify: Audit Log

## UAT ID
UAT-L2.19

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!
- Layer 1 E2E scripts have run (generating audit entries)

## Steps
1. Navigate to http://localhost:3001/audit-log
2. Verify the audit log table loads with entries
3. Test filtering by date range (today's date)
4. Look for audit entries related to E2E actions: booking creation, session completion, caregiver approval
5. Click on an audit entry to verify it shows: actor, resource type, action, timestamp, details
6. Take a screenshot

## Pass Criteria
- Audit log table loads with entries
- Date filter works — shows today's entries
- Entries contain actor, resource, action, and timestamp
- E2E-related actions are logged
