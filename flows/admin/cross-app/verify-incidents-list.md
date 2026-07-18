# Cross-App Verify: Incidents List

## UAT ID
UAT-L2.16

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!

## Steps
1. Navigate to http://localhost:3001/incidents
2. Verify the incidents table loads (may be empty if no incidents generated)
3. If incidents exist, verify filter by type and status works
4. Verify incident rows show: type, status, caregiver/booking link, date
5. Take a screenshot

## Pass Criteria
- Incidents page loads without error
- If incidents exist, they display with correct fields
- Filters work (if data exists to filter)
