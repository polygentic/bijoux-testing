# Admin Login — Invalid Credentials

## UAT ID
UAT-9.2

## Prerequisites
- Admin portal running at http://localhost:3001

## Steps
1. Navigate to http://localhost:3001/login
2. Verify the login page loads with email and password fields
3. Click the email input field and type "admin@bijoux.app"
4. Click the password input field and type "wrong123"
5. Click the "Sign In" button
6. Wait for the response to appear

## Pass Criteria
- An error message appears on the page (e.g. "Invalid credentials", "Incorrect password", or similar)
- The browser remains on the /login page (no redirect occurs)
- The email field still contains "admin@bijoux.app"
- No dashboard or sidebar content is visible
