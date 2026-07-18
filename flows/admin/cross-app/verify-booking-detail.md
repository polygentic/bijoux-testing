# Cross-App Verify: Booking Detail (Cross-App)

## UAT ID
UAT-L2.8

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!
- At least one completed booking from E2E run

## Steps
1. Navigate to http://localhost:3001/bookings
2. Click on a completed booking from the E2E run
3. Verify Booking Details card: ID, type, lifecycle = "Completed", address, duration, cost
4. Verify Parent Info card: name links to parent detail, email, phone
5. Verify Assigned Caregiver card: caregiver name matches E2E assignment
6. Verify Match Request section: offers table with at least one offer
7. Verify Transactions section: authorization and capture transactions present
8. If session exists, verify Session link navigates to session detail
9. Take a screenshot

## Pass Criteria
- All booking detail sections populated
- Parent and caregiver match E2E test data
- Match offers table shows offer lifecycle
- Transactions show authorization + capture
- Session link works
