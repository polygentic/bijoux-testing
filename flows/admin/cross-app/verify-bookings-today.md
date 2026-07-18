# Cross-App Verify: Bookings Today Count

## UAT ID
UAT-L2.3

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!

## Steps
1. Navigate to http://localhost:3001 (dashboard)
2. Find the "Bookings Today" or "Today's Bookings" metric on the dashboard
3. Verify the count is > 0 (E2E scripts created bookings today)
4. If a "View All" link exists, click it and verify it navigates to bookings list filtered by today
5. Take a screenshot

## Pass Criteria
- Bookings today count is visible and > 0
