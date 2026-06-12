# Caregivers List and Filtering

## UAT ID
UAT-12.1

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app (complete UAT-9.1 first)
- Seed data includes caregivers in various statuses: pending (cg-pending / Jake Wilson), approved, suspended

## Steps
1. Navigate to http://localhost:3001/caregivers
2. Wait for the page to fully load
3. Verify 4 KPI cards are displayed at the top of the page:
   - "Pending Approval" with a numeric count
   - "Approved & Online" with a numeric count
   - "Approved & Offline" with a numeric count
   - "Suspended" with a numeric count
4. Verify the caregiver table loads with columns: Name, Email, Status, Online, Rating, Sessions, BG Check, IDV
5. Locate the Status filter dropdown and select "Pending"
6. Wait for the table to update
7. Verify cg-pending (Jake Wilson) appears in the filtered results
8. Verify all visible rows show Status = "Pending"
9. Clear the Status filter
10. Locate the BG Check filter (if available) and test filtering by BG check status
11. Verify the table updates to show only caregivers matching the selected BG check status

## Pass Criteria
- Four KPI cards are visible: "Pending Approval", "Approved & Online", "Approved & Offline", "Suspended"
- Each KPI card shows a numeric count
- The caregiver table displays columns: Name, Email, Status, Online, Rating, Sessions, BG Check, IDV
- Filtering by Status "Pending" shows only pending caregivers including Jake Wilson (cg-pending)
- BG Check filter works or is noted as not yet implemented
- Filters can be cleared to restore the full list
