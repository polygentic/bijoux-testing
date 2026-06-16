# Cross-App Verify: Caregiver Detail

## UAT ID
UAT-L2.10

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!

## Steps
1. Navigate to http://localhost:3001/caregivers
2. Search for "Emma" and click to open her detail page
3. Verify profile card: name, email (cg-emma@test.bijoux.app), status
4. Verify trust info: BG check status, IDV status
5. Verify sessions section: shows completed sessions from E2E runs
6. Verify earnings section: shows earnings if sessions completed
7. If rating is displayed, verify it shows the E2E-assigned rating
8. Take a screenshot

## Pass Criteria
- Emma's profile shows correct info
- Trust info (BG, IDV) displayed
- Session history populated from E2E runs
- Earnings reflect completed sessions
