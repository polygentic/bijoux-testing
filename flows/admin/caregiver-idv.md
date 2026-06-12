# Caregiver Identity Verification — Jake Wilson

## UAT ID
UAT-12.6

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app (complete UAT-9.1 first)
- Seed data includes Jake Wilson (cg-pending) with status "Pending"

## Steps
1. Navigate to http://localhost:3001/caregivers
2. Wait for the caregiver table to load
3. Find Jake Wilson (cg-pending) in the table and click to open detail view
4. Locate the Trust & Safety card
5. Note the current IDV status
6. Click the "IDV" button (or "Initiate Identity Verification" equivalent)
7. Wait for the API call to complete
8. Verify the IDV status changes to "pending" (indicating the verification has been initiated)

## Pass Criteria
- The "IDV" button is visible and clickable for a caregiver without a completed identity verification
- Clicking the button initiates an API call (no client-side errors)
- The IDV status updates to "pending" in the Trust & Safety card
- Note: The Veriff webhook is stubbed in the test environment, so the status will NOT automatically update to "approved" — it will remain "pending" after initiation
