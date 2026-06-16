# Cross-App Verify: Session Detail

## UAT ID
UAT-L2.12

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!

## Steps
1. Navigate to http://localhost:3001/sessions
2. Click a completed session from E2E runs
3. Verify session status is "Completed"
4. Verify booking link present and correct
5. Verify caregiver name matches
6. Verify verification checkmarks (if the 4-step verification timeline is shown)
7. Verify session timeline shows start and end times
8. If rating is shown, verify it matches the E2E rating (5 stars)
9. Take a screenshot

## Pass Criteria
- Session detail shows completed status
- Booking and caregiver links work
- Verification timeline or checkmarks visible
- Rating displayed if applicable
