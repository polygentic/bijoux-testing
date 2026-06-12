# Caregiver Approve — Jake Wilson

## UAT ID
UAT-12.3

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app (complete UAT-9.1 first)
- Seed data includes Jake Wilson (cg-pending) with status "Pending"
- Approval requires BG check = clear AND IDV = approved

## Steps
1. Navigate to http://localhost:3001/caregivers
2. Wait for the caregiver table to load
3. Find Jake Wilson (cg-pending) in the table and click to open detail view
4. Verify Jake Wilson's status is "Pending"
5. Check the Trust & Safety card for BG check and IDV statuses
6. If BG check is NOT "clear" or IDV is NOT "approved":
   - Verify the "Approve" button is disabled, greyed out, or hidden
   - Note in results: "Approve button correctly disabled — prerequisites not met (BG: [status], IDV: [status])"
   - End test here
7. If BG check IS "clear" AND IDV IS "approved":
   - Click the "Approve" button
   - A confirmation modal should appear
   - Click "Confirm" in the modal
   - Wait for the action to complete
   - Verify Jake Wilson's status changes to "Approved"

## Pass Criteria
- Jake Wilson's detail page loads and shows status "Pending"
- If BG check and IDV prerequisites are NOT met: the Approve button is disabled or hidden, preventing approval of an unvetted caregiver
- If BG check and IDV prerequisites ARE met: clicking Approve and confirming changes the status to "Approved"
- The system enforces the rule that both BG check = clear and IDV = approved are required before approval
