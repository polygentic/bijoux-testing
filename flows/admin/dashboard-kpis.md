# Admin Portal — Dashboard KPIs

## Prerequisites
- Logged in to admin portal (run login.md first)

## Steps

1. Verify URL is http://localhost:3001/ (dashboard)
2. Look for 4 KPI cards with these labels:
   - "Active Sessions"
   - "Revenue (MTD)"
   - "Caregivers Online"
   - "Pending Approval"
3. Verify the "Bookings Today" card is visible
4. Verify the "Recent Activity" card is visible
5. Click the "Caregivers" link in the sidebar (a[href="/caregivers"])
6. Verify the caregivers list page loads — look for a table or data table component
7. Take a screenshot
8. Click the "Dashboard" link in the sidebar to return (a[href="/"])

## Pass Criteria
- All 4 KPI cards are rendered with numeric values (not "Loading...")
- Bookings Today and Recent Activity sections are visible
- Caregivers page loads without error
- Navigation between pages works
