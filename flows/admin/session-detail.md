# Session Detail View

## UAT ID
UAT-14.2

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!
- At least one session exists with a linked booking, caregiver, parent, verification events, a rating/review, and timeline events

## Steps
1. Navigate to http://localhost:3001/sessions
2. Click on a session row to open the session detail page
3. Verify the Session Details card is displayed with: ID, status, started, ended, booked duration, actual duration, amount
4. Verify the Booking card is displayed with a clickable link to the associated booking
5. Click the booking link and verify it navigates to the booking detail page. Navigate back to the session detail
6. Verify the Caregiver card is displayed with: caregiver name (as a clickable link) and phone number
7. Verify the Parent card is displayed with parent information
8. Verify the Verification Status card is displayed with 4 checkmarks: parent start, caregiver start, parent end, caregiver end
9. Verify each checkmark indicates whether that verification step has been completed
10. If the session has a rating, verify the Rating & Review card is displayed with the star rating and review text
11. If the session has a timeline, verify the Timeline card is displayed with chronological events (e.g., session started, verification received, session ended)

## Pass Criteria
- Session Details card shows ID, status, started, ended, booked duration, actual duration, and amount
- Booking card links to the correct booking detail page
- Caregiver card shows name as a link and phone number
- Parent card displays parent information
- Verification Status card shows 4 checkmarks for parent start, caregiver start, parent end, caregiver end
- Rating & Review card is visible with rating and review text when a rating exists
- Timeline card displays chronological events when timeline data exists
