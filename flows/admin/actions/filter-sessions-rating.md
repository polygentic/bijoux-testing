# Admin Action: Filter Sessions by Rating

## UAT ID
UAT-L3.19

## Context
Read-only action test. Admin navigates to sessions list and filters/sorts by rating to verify the feature works.

## Admin Action (execute in Chrome)
1. Navigate to http://localhost:3001/sessions
2. Look for rating filter/sort options in the table header or filter bar
3. If a rating filter exists:
   - Filter by 5 stars — verify only 5-star sessions shown
   - Clear filter, filter by 4 stars — verify only 4-star sessions shown
   - Clear all filters
4. If a rating sort exists:
   - Sort by rating descending — verify highest-rated sessions appear first
   - Sort by rating ascending — verify lowest-rated sessions appear first
5. Verify sessions without ratings are handled gracefully (shown at end or marked as "unrated")
6. Take a screenshot

## Pass Criteria
- Rating filter/sort is functional (if present in UI)
- Filtering by specific rating shows only matching sessions
- Sorting by rating orders sessions correctly
- Sessions without ratings are handled gracefully
- If rating filter is not implemented, note it as "feature not yet available"
