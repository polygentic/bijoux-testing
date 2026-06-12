# User Detail — Parent (Sarah Mitchell)

## UAT ID
UAT-11.2

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app (complete UAT-9.1 first)
- Seed data includes Sarah Mitchell as a parent with children Lily and Max, and a credit balance of $25.00

## Steps
1. Navigate to http://localhost:3001/users
2. Wait for the user table to load
3. Find and click on "Sarah Mitchell" in the table to open her detail view
4. Verify the Profile tab is shown by default
5. On the Profile tab, verify the following fields are displayed: email, phone, role (parent), status (active)
6. Click the "Children" tab
7. Verify "Lily" appears in the children list
8. Verify "Max" appears in the children list
9. Click the "Credits" tab
10. Verify the credit balance shows $25.00
11. Verify at least one ledger entry is visible in the credit history

## Pass Criteria
- Sarah Mitchell's detail page loads successfully
- Profile tab shows email, phone, role=parent, status=active
- Children tab lists both Lily and Max
- Credits tab displays a credit balance of $25.00
- Credits tab shows at least one ledger entry with details (date, amount, type, reason)
