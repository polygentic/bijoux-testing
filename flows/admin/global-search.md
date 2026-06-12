# Global Search

## UAT ID
UAT-18.1

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!
- Database contains a user named "Sarah Mitchell", a caregiver named "Emma", and at least one booking with a known Booking ID

## Steps
1. On any admin page (e.g., http://localhost:3001/bookings), locate the global search trigger
2. Trigger global search by pressing Cmd+K (macOS) or clicking the search icon in the header
3. Verify a search overlay/modal appears with a text input
4. Type "Sarah" in the search input
5. Verify results appear grouped by type (Users, Caregivers, Bookings, Sessions)
6. Verify "Sarah Mitchell" appears under the Users group
7. Click the "Sarah Mitchell" result
8. Verify the browser navigates to Sarah Mitchell's user detail page
9. Navigate back to any admin page
10. Trigger global search again (Cmd+K or search icon)
11. Type a known Booking ID in the search input
12. Verify the booking appears in the search results under the Bookings group
13. Clear the search input
14. Type "Emma" in the search input
15. Verify a caregiver named "Emma" appears in the search results under the Caregivers group
16. Click the Emma result and verify navigation to the caregiver detail page

## Pass Criteria
- Global search is triggered by Cmd+K keyboard shortcut or by clicking the search icon in the header
- Search overlay appears with a text input field
- Searching "Sarah" returns results grouped by type (Users, Caregivers, Bookings, Sessions)
- Sarah Mitchell appears under Users in the results
- Clicking a result navigates to the correct detail page
- Searching by a Booking ID returns the matching booking
- Searching "Emma" returns the caregiver named Emma under the Caregivers group
