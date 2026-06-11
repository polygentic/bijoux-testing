# Admin Portal — Login Flow

## Prerequisites
- Admin portal running at http://localhost:3001
- Backend running and seeded (admin@bijoux.app account exists)

## Steps

1. Navigate to http://localhost:3001/login
2. Verify the login page loads — look for an email input field with id="email"
3. Click the email input field and type: admin@bijoux.app
4. Click the password input field (id="password") and type: Test1234!
5. Click the "Sign In" button (button[type="submit"])
6. Wait for redirect to dashboard — verify URL is http://localhost:3001/
7. Verify the sidebar is visible with text "Bijoux Admin"
8. Take a screenshot

## Pass Criteria
- Login form accepts credentials without error
- Redirects to dashboard after login
- Sidebar navigation is visible with "Bijoux Admin" logo text
