# Cross-App Verify: Users List & Filter

## UAT ID
UAT-L2.4

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!

## Steps
1. Navigate to http://localhost:3001/users
2. Verify the users table loads with data
3. Search for "Sarah" — verify Sarah Mitchell appears with role "parent"
4. Clear search, search for "Emma" — verify Emma appears with role "caregiver"
5. If role filter exists, filter by "parent" — verify only parents shown
6. Clear filter, filter by "caregiver" — verify only caregivers shown
7. Take a screenshot

## Pass Criteria
- Users table loads with test users
- Search by name works correctly
- Role filter (if available) filters accurately
- Sarah and Emma are findable as parent and caregiver respectively
