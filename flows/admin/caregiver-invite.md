# Caregiver Generate Invite

## UAT ID
UAT-12.7

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app (complete UAT-9.1 first)
- At least one caregiver exists in the system

## Steps
1. Navigate to http://localhost:3001/caregivers
2. Wait for the caregiver table to load
3. Find any caregiver in the table and click to open their detail view
4. Locate the "Generate Invite" button
5. Click the "Generate Invite" button
6. Wait for the invite URL to be generated
7. Verify a green banner (success notification) appears containing the invite URL
8. Verify the invite URL is displayed in the banner
9. Attempt to copy the URL (click a copy button if available, or select the URL text)
10. Verify the URL has been copied or is selectable for copying

## Pass Criteria
- The "Generate Invite" button is visible on the caregiver detail page
- Clicking the button generates an invite URL without errors
- A green success banner appears displaying the generated invite URL
- The invite URL can be copied (via a copy button or text selection)
- The generated URL follows a valid URL format
