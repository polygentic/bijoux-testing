# Resolve Incident

## UAT ID
UAT-16.3

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!
- At least one incident exists with status "Open"

## Steps
1. Navigate to http://localhost:3001/incidents
2. Filter by Status: select "Open" to locate an open incident
3. Click on an open incident row to open the incident detail page
4. Verify the "Resolve" button is visible
5. Click the "Resolve" button
6. Verify a modal or form appears with a resolution notes input field
7. Enter resolution notes: "UAT test resolution - issue addressed with caregiver"
8. Click the confirm/submit button
9. Verify the incident status changes to "Resolved" on the detail page
10. Verify a Resolution card appears with the resolution notes "UAT test resolution - issue addressed with caregiver" and the resolved date
11. Verify the "Resolve" button is no longer visible on the page

## Pass Criteria
- Resolve button is present on open incidents
- Modal/form appears with a resolution notes input field
- After confirmation, the incident status updates to "Resolved"
- Resolution card appears displaying the resolution notes and resolved date
- Resolve button disappears after successful resolution
