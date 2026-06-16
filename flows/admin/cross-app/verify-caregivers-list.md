# Cross-App Verify: Caregivers List & Pipeline

## UAT ID
UAT-L2.9

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!

## Steps
1. Navigate to http://localhost:3001/caregivers
2. Verify the page loads with a caregiver list table
3. If pipeline KPI cards exist (total, approved, pending, online), verify they show counts
4. Search for "Emma" — verify Emma appears
5. Search for "Maria" — verify Maria appears
6. If status filter exists, test filtering by "approved" or "active"
7. If online filter exists, test it
8. Take a screenshot

## Pass Criteria
- Caregiver list loads with Emma and Maria
- Pipeline KPIs show non-zero counts (if present)
- Filters work correctly
