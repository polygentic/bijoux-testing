# Cross-App Verify: Global Search

## UAT ID
UAT-L2.21

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!

## Steps
1. Navigate to http://localhost:3001
2. Click the search icon or press Cmd+K to open global search
3. Search for "Sarah" — verify parent user appears in results
4. Clear search, search for "Emma" — verify caregiver appears
5. Clear search, search for a booking ID from state.json (if known)
6. Click a search result and verify it navigates to the correct detail page
7. Navigate back, take a screenshot

## Pass Criteria
- Global search opens via icon or Cmd+K
- Searching "Sarah" returns parent user result
- Searching "Emma" returns caregiver result
- Search results are clickable and navigate to correct pages
