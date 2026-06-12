# Users List and Filtering

## UAT ID
UAT-11.1

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app (complete UAT-9.1 first)
- Seed data includes users with various roles and statuses, including a user named "Sarah Mitchell" with role "parent"

## Steps
1. Navigate to http://localhost:3001/users
2. Wait for the user table to load
3. Verify the table displays columns: Name, Email, Phone, Role, Status, Joined
4. Locate the Role filter dropdown and select "Parent"
5. Wait for the table to update
6. Verify all visible rows show Role = "Parent"
7. Clear the Role filter (select "All" or reset)
8. Locate the Status filter dropdown and select "Active"
9. Wait for the table to update
10. Verify all visible rows show Status = "Active"
11. Clear the Status filter
12. Locate the search input field
13. Type "Sarah" into the search field
14. Wait for the table to update
15. Verify "Sarah Mitchell" appears in the filtered results

## Pass Criteria
- The user table loads with columns: Name, Email, Phone, Role, Status, Joined
- Filtering by Role "Parent" shows only users with the parent role
- Filtering by Status "Active" shows only users with active status
- Searching for "Sarah" returns results that include Sarah Mitchell
- Filters can be cleared and the full list is restored
