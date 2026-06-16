# Cross-App Verify: Dashboard KPIs

## UAT ID
UAT-L2.1

## Context
Runs after Layer 1 iOS E2E scripts complete. Verifies dashboard KPI cards reflect the E2E test activity.

## State Data
Read `results/state.json` for expected counts. After a full E2E run, expect at least 1 completed booking.

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!
- Layer 1 E2E scripts have completed

## Steps
1. Navigate to http://localhost:3001 (dashboard)
2. Verify the dashboard page loads with KPI cards
3. Check "Completed Sessions" or similar metric card — should be non-zero
4. Check "MTD Revenue" or similar — should be non-zero (E2E bookings generate revenue)
5. Check "Online Caregivers" count — may be zero after E2E cleanup
6. Check "Pending Approvals" count
7. Take a screenshot of the full dashboard

## Pass Criteria
- Dashboard loads with all KPI cards visible
- At least one metric reflects E2E activity (completed sessions > 0 or revenue > 0)
- No error states or loading spinners stuck
