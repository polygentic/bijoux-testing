# Admin Login — Valid Credentials

## UAT ID
UAT-9.1

## Prerequisites
- Admin portal running at http://localhost:3001
- Admin account exists: admin@bijoux.app / Test1234!

## Steps
1. Navigate to http://localhost:3001/login
2. Verify the login page loads with email and password fields
3. Click the email input field and type "admin@bijoux.app"
4. Click the password input field and type "Test1234!"
5. Click the "Sign In" button
6. Wait for navigation to complete

## Pass Criteria
- Login page renders with email and password inputs and a Sign In button
- After clicking Sign In with valid credentials, the page redirects to the admin dashboard (e.g. /dashboard or /)
- The sidebar is visible and displays "Bijoux Admin" branding
- No error messages are shown
