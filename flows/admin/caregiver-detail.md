# Caregiver Detail — Emma Thompson

## UAT ID
UAT-12.2

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app (complete UAT-9.1 first)
- Seed data includes Emma Thompson as an approved caregiver with complete profile data

## Steps
1. Navigate to http://localhost:3001/caregivers
2. Wait for the caregiver table to load
3. Find and click on "Emma Thompson" in the table to open her detail view
4. Verify the Profile card is displayed with: status, email, phone, bio
5. Verify the Professional card is displayed with: experience (years), certifications, hourly rate
6. Verify the Trust & Safety card is displayed with: BG check status (clear), IDV status (approved)
7. Verify the Preferences card is displayed with toggle switches for various preferences
8. Verify the Emergency Contact card is displayed with: name "David Thompson" and contact details
9. Verify the Earnings card is displayed with earnings information
10. Scroll down to verify the Session History table is visible with past session records

## Pass Criteria
- Emma Thompson's detail page loads with all information cards
- Profile card shows status, email, phone, and bio
- Professional card shows experience, certifications, and rate
- Trust & Safety card shows BG check = clear and IDV = approved
- Preferences card shows toggles for caregiver preferences
- Emergency Contact card shows David Thompson as the emergency contact
- Earnings card displays earnings data
- Session History table is visible with at least one session record
