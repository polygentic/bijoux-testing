# Admin Logout

## UAT ID
UAT-9.3

## Prerequisites
- Admin portal running at http://localhost:3001
- Already logged in as admin@bijoux.app (complete UAT-9.1 first)

## Steps
1. From the admin dashboard, locate the logout button or link (check sidebar bottom, top-right avatar/menu, or settings area)
2. Click the logout button/link
3. Wait for navigation to complete
4. Verify the page redirects to /login
5. Navigate to http://localhost:3001/ (root URL)
6. Verify the browser redirects back to /login

## Pass Criteria
- Clicking the logout button redirects the user to the /login page
- After logout, navigating to the root URL (/) redirects back to /login
- The dashboard and sidebar are no longer accessible without re-authenticating
- No session or auth errors appear — the logout is clean
