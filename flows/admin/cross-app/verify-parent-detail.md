# Cross-App Verify: Parent Detail

## UAT ID
UAT-L2.5

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!

## Steps
1. Navigate to http://localhost:3001/users
2. Search for "Sarah" and click to open her detail page
3. Verify parent profile card shows: name, email (parent-sarah@test.bijoux.app), phone
4. Verify children section shows at least one child
5. Verify booking history section shows bookings from E2E runs
6. Check that booking entries show lifecycle status
7. Take a screenshot

## Pass Criteria
- Sarah's profile shows correct email and name
- Children list is populated
- Booking history shows E2E bookings with correct lifecycle status
