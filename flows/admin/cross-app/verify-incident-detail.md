# Cross-App Verify: Incident Detail

## UAT ID
UAT-L2.17

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!

## Steps
1. Navigate to http://localhost:3001/incidents
2. If incidents exist, click one to open detail
3. Verify caregiver link resolves to correct caregiver
4. Verify booking link (if present) resolves to correct booking
5. If no incidents exist, verify empty state is clean
6. Take a screenshot

## Pass Criteria
- Incident detail page loads (or clean empty state)
- Links to caregiver and booking resolve correctly
