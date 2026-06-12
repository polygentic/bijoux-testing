# Caregiver Approval End-to-End

## UAT ID
UAT-19.3

## Prerequisites
- API server running (e.g., http://localhost:3000)
- Admin portal running at http://localhost:3001
- Caregiver mobile app built and installed on simulator
- A pending caregiver account exists (registered but not yet approved, still in setup/onboarding state)
- iOS Simulator UDID configured:
  - `CAREGIVER_SIMULATOR_UDID` — Simulator running the caregiver app
- Maestro CLI installed and available in PATH
- Admin credentials: admin@bijoux.app / Test1234!

## Steps

### Phase 1: Admin Initiates Background Check & IDV (Admin Portal)
1. Log in to the admin portal at http://localhost:3001 as admin@bijoux.app / Test1234!
2. Navigate to http://localhost:3001/caregivers
3. Locate the pending caregiver in the caregivers list (filter by Status: "Pending" if available)
4. Click the caregiver row to open the caregiver detail page
5. Note the caregiver's name and email for later verification
6. Locate the Background Check section or action button
7. Initiate the background check for the caregiver:
   - Click "Initiate BG Check" or similar button
   - Confirm the action if a modal appears
8. Verify the background check status updates (e.g., "Pending" or "In Progress")
9. Locate the Identity Verification (IDV) section or action button
10. Initiate IDV for the caregiver:
    - Click "Initiate IDV" or similar button
    - Confirm the action if a modal appears
11. Verify the IDV status updates (e.g., "Pending" or "In Progress")

### Phase 2: Complete BG Check & IDV (API / Admin)
12. If using test/sandbox providers, the BG check and IDV may auto-complete. Otherwise, simulate completion via API:
    ```bash
    ADMIN_TOKEN="<admin_jwt_token>"
    CAREGIVER_ID="<caregiver_id>"

    # Mark BG check as passed (if manual override is available)
    curl -s -X PATCH \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d '{"backgroundCheckStatus": "passed"}' \
      http://localhost:3000/api/v1/admin/caregivers/$CAREGIVER_ID/background-check

    # Mark IDV as verified (if manual override is available)
    curl -s -X PATCH \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d '{"idvStatus": "verified"}' \
      http://localhost:3000/api/v1/admin/caregivers/$CAREGIVER_ID/identity-verification
    ```
13. Refresh the caregiver detail page in the admin portal
14. Verify BG check status shows "Passed" or "Completed"
15. Verify IDV status shows "Verified" or "Completed"

### Phase 3: Admin Approves Caregiver (Admin Portal)
16. On the caregiver detail page, locate the "Approve" button or status change action
17. Click "Approve" to approve the caregiver
18. Confirm the approval if a modal appears
19. Verify the caregiver status changes to "Approved" or "Active" in the admin portal
20. Verify the approval is reflected in the caregiver detail page

### Phase 4: Caregiver Logs In and Sees Home Dashboard (Caregiver App)
21. Launch the caregiver app on the caregiver simulator
22. Log in as the approved caregiver:
    ```bash
    maestro --udid=$CAREGIVER_SIMULATOR_UDID test flows/caregiver/login.yaml
    ```
    Note: The login flow should use the caregiver credentials. If the maestro flow uses hardcoded credentials, ensure they match the caregiver approved in Phase 3
23. Verify the caregiver app navigates to the home dashboard (NOT the setup wizard or onboarding flow)
24. Verify the home dashboard is displayed with expected elements:
    - Availability toggle or status
    - Upcoming bookings section (may be empty)
    - Earnings or stats section
25. Verify no setup wizard, onboarding steps, or "pending approval" messages are shown

### Alternative: Verify via API
26. If maestro verification is insufficient, confirm caregiver status via API:
    ```bash
    CAREGIVER_TOKEN="<caregiver_jwt_token>"
    curl -s -H "Authorization: Bearer $CAREGIVER_TOKEN" \
      http://localhost:3000/api/v1/caregiver/profile \
      | jq '.data.status, .data.onboardingComplete'
    # Expected: status "approved" or "active", onboardingComplete true
    ```

## Pass Criteria
- Admin can initiate background check for a pending caregiver
- Admin can initiate identity verification for a pending caregiver
- BG check and IDV statuses update correctly (passed/verified)
- Admin can approve the caregiver after BG check and IDV are complete
- Caregiver status changes to "Approved" or "Active" in the admin portal
- Caregiver logs in to the mobile app and sees the home dashboard
- Caregiver does NOT see the setup wizard or onboarding flow after approval
- No "pending approval" or "under review" messages are shown on the caregiver home dashboard
