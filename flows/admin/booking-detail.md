# Booking Detail View

## UAT ID
UAT-13.2

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!
- At least one booking exists with an assigned caregiver, a linked session, a match request with offers, and associated transactions

## Steps
1. Navigate to http://localhost:3001/bookings
2. Click on a booking row to open the booking detail page
3. Verify the Booking Details card is displayed with the following fields: ID, type, status, address, duration, cost
4. Verify the Parent Info card is displayed with: parent name (as a clickable link), email, phone number, and copy buttons next to email and phone
5. Click the copy button next to the email. Verify the email is copied to clipboard
6. Click the copy button next to the phone. Verify the phone number is copied to clipboard
7. If the booking has a matched caregiver, verify the Assigned Caregiver card is displayed with the caregiver's name and details
8. If the booking has an associated session, verify a Session link is present. Click it and verify it navigates to the session detail page. Navigate back
9. If the booking has a match request, verify the Match Request section is displayed with an offers table listing caregiver offers
10. Scroll to the Transactions section. Verify a transaction table is displayed with the booking's associated transactions

## Pass Criteria
- Booking Details card shows ID, type, status, address, duration, and cost
- Parent Info card shows name as a link, email, phone, and functional copy buttons
- Assigned Caregiver card is visible when a caregiver is matched
- Session link navigates to the correct session detail page when a session exists
- Match Request section displays offers table when a match request exists
- Transactions section displays a table of associated transactions
