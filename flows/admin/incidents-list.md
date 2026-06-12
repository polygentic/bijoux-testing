# Incidents List & Filters

## UAT ID
UAT-16.1

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!
- Multiple incidents exist in the database with varied types (Location Violation, etc.), statuses (Open, Resolved), and associated caregivers/bookings

## Steps
1. Navigate to http://localhost:3001/incidents
2. Verify the incidents table is displayed with the following columns: Incident ID, Type, Caregiver, Booking, Description, Created, Status
3. Verify that rows are populated with incident data
4. Locate the Type filter dropdown. Select "Location Violation"
5. Verify the table updates to show only incidents with type "Location Violation"
6. Clear the Type filter
7. Locate the Status filter dropdown. Select "Open"
8. Verify the table updates to show only incidents with status "Open"
9. Verify that open incidents are displayed with a red or highlighted background to distinguish them from resolved incidents
10. Clear the Status filter
11. Verify that resolved incidents are displayed with a normal (non-highlighted) background
12. Verify the visual distinction between open and resolved incidents is clear

## Pass Criteria
- Table renders with all 7 required columns: Incident ID, Type, Caregiver, Booking, Description, Created, Status
- Type filter "Location Violation" returns only location violation incidents
- Status filter "Open" returns only open incidents
- Open incidents are visually highlighted with a red or emphasized background
- Resolved incidents are displayed with a normal, non-highlighted background
- Clearing each filter restores the full unfiltered list
