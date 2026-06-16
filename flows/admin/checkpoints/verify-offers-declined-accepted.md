# Checkpoint: Verify Offer Decline and Accept in Admin Portal

## Context
Run during the decline-then-accept E2E flow. Verifies offer statuses in admin.

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!
- BOOKING_ID available

## Steps
1. Navigate to http://localhost:3001/bookings/{BOOKING_ID}
2. Scroll to Match Request section
3. Verify the offers table shows at least two offers
4. Verify one offer shows status "Declined" or "Rejected"
5. Verify another offer shows status "Accepted" or "Matched"
6. Verify the Assigned Caregiver card shows the accepting caregiver (not the declining one)
7. Take a screenshot

## Pass Criteria
- At least two offers visible in match request
- One offer declined, one accepted
- Assigned caregiver matches the accepting caregiver
