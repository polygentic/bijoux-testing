# Dashboard KPI Cards

## UAT ID
UAT-10.1

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app (complete UAT-9.1 first)

## Steps
1. Navigate to the admin dashboard (http://localhost:3001/ or /dashboard)
2. Wait for the page to fully load (all data fetched)
3. Locate the KPI cards section at the top of the dashboard
4. Identify the "Active Sessions" KPI card
5. Identify the "Revenue (MTD)" KPI card
6. Identify the "Caregivers Online" KPI card
7. Identify the "Pending Approval" KPI card
8. Verify each of the 4 KPI cards displays a numeric value (not "Loading..." or a spinner)
9. Locate the "Bookings Today" card on the dashboard

## Pass Criteria
- All 4 KPI cards are visible on the dashboard: "Active Sessions", "Revenue (MTD)", "Caregivers Online", "Pending Approval"
- Each KPI card displays a numeric value (integer or currency) rather than a loading state
- The "Bookings Today" card is visible on the dashboard
- No error states or blank cards are present
