# Incident Detail View

## UAT ID
UAT-16.2

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!
- At least one incident exists with a linked caregiver, a linked booking, and coordinate data. Ideally one open and one resolved incident for complete coverage

## Steps
1. Navigate to http://localhost:3001/incidents
2. Click on an incident row to open the incident detail page
3. Verify the Incident Details card is displayed with: ID, type, description, created date
4. If the incident has coordinates (e.g., location violation), verify the coordinates are displayed in the Incident Details card
5. Verify the Caregiver card is displayed with a clickable link to the caregiver's detail page
6. Click the caregiver link and verify it navigates to the caregiver detail page. Navigate back
7. If the incident is linked to a booking, verify the Booking card is displayed with a link to the booking detail page
8. Click the booking link and verify navigation. Navigate back
9. If the incident is resolved, verify the Resolution card is displayed with: resolved date and resolution notes
10. If the incident is open, verify no Resolution card is displayed

## Pass Criteria
- Incident Details card shows ID, type, description, and created date
- Coordinates are displayed when applicable (e.g., for location violations)
- Caregiver card shows caregiver info with a working link to caregiver detail
- Booking card is visible with a working link when the incident is linked to a booking
- Resolution card is displayed for resolved incidents with resolved date and resolution notes
- Resolution card is absent for open incidents
