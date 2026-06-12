# Full Booking Lifecycle (End-to-End)

## UAT ID
UAT-19.1

## Prerequisites
- API server running (e.g., http://localhost:3000)
- Admin portal running at http://localhost:3001
- Parent mobile app built and installed on simulator
- Caregiver mobile app built and installed on simulator
- Logged-in parent account with valid payment method
- Approved caregiver account with availability set
- iOS Simulator UDIDs configured:
  - `PARENT_SIMULATOR_UDID` — Simulator running the parent app
  - `CAREGIVER_SIMULATOR_UDID` — Simulator running the caregiver app
- Maestro CLI installed and available in PATH

## Steps

### Phase 1: Parent Creates Booking (Parent App)
1. Launch the parent app on the parent simulator
2. Run the parent login maestro flow:
   ```bash
   maestro --udid=$PARENT_SIMULATOR_UDID test flows/parent/login.yaml
   ```
3. Create a new booking via the parent app:
   ```bash
   maestro --udid=$PARENT_SIMULATOR_UDID test flows/parent/create-booking.yaml
   ```
4. Note the Booking ID from the confirmation screen or retrieve it via API:
   ```bash
   PARENT_TOKEN="<parent_jwt_token>"
   BOOKING_ID=$(curl -s -H "Authorization: Bearer $PARENT_TOKEN" \
     http://localhost:3000/api/v1/bookings?limit=1\&sort=-createdAt \
     | jq -r '.data[0].id')
   echo "Booking ID: $BOOKING_ID"
   ```

### Phase 2: Matching Finds Caregiver (API)
5. Trigger or wait for the matching engine to process the booking:
   ```bash
   # Check match request status
   curl -s -H "Authorization: Bearer $PARENT_TOKEN" \
     http://localhost:3000/api/v1/bookings/$BOOKING_ID/match-request \
     | jq '.data.status, .data.offers'
   ```
6. Verify at least one caregiver offer is generated

### Phase 3: Caregiver Accepts (Caregiver App)
7. Launch the caregiver app on the caregiver simulator
8. Run the caregiver login maestro flow:
   ```bash
   maestro --udid=$CAREGIVER_SIMULATOR_UDID test flows/caregiver/login.yaml
   ```
9. Accept the booking via the caregiver app:
   ```bash
   maestro --udid=$CAREGIVER_SIMULATOR_UDID test flows/caregiver/accept-booking.yaml
   ```
10. Verify the booking status changes to matched:
    ```bash
    curl -s -H "Authorization: Bearer $PARENT_TOKEN" \
      http://localhost:3000/api/v1/bookings/$BOOKING_ID \
      | jq '.data.status'
    # Expected: "matched"
    ```

### Phase 4: Session Starts (Both Apps)
11. Start the session from the caregiver app:
    ```bash
    maestro --udid=$CAREGIVER_SIMULATOR_UDID test flows/caregiver/start-session.yaml
    ```
12. Confirm session start from the parent app:
    ```bash
    maestro --udid=$PARENT_SIMULATOR_UDID test flows/parent/confirm-session-start.yaml
    ```
13. Retrieve the Session ID:
    ```bash
    SESSION_ID=$(curl -s -H "Authorization: Bearer $PARENT_TOKEN" \
      http://localhost:3000/api/v1/bookings/$BOOKING_ID/session \
      | jq -r '.data.id')
    echo "Session ID: $SESSION_ID"
    ```

### Phase 5: Session Ends (Both Apps)
14. End the session from the caregiver app:
    ```bash
    maestro --udid=$CAREGIVER_SIMULATOR_UDID test flows/caregiver/end-session.yaml
    ```
15. Confirm session end from the parent app:
    ```bash
    maestro --udid=$PARENT_SIMULATOR_UDID test flows/parent/confirm-session-end.yaml
    ```
16. Verify session status:
    ```bash
    curl -s -H "Authorization: Bearer $PARENT_TOKEN" \
      http://localhost:3000/api/v1/sessions/$SESSION_ID \
      | jq '.data.status'
    # Expected: "completed"
    ```

### Phase 6: Payment Captured (API)
17. Verify payment was captured:
    ```bash
    curl -s -H "Authorization: Bearer $PARENT_TOKEN" \
      http://localhost:3000/api/v1/bookings/$BOOKING_ID/transactions \
      | jq '.data[] | {type, status, amount}'
    # Expected: authorization succeeded, capture succeeded
    ```

### Phase 7: Admin Verifies (Admin Portal)
18. Log in to the admin portal at http://localhost:3001 as admin@bijoux.app / Test1234!
19. Navigate to http://localhost:3001/bookings
20. Search for the Booking ID noted in Phase 1
21. Click the booking row and verify:
    - Status is "Completed"
    - Assigned Caregiver is shown
    - Session link is present
22. Click the Session link and verify:
    - Status is "Completed"
    - Verification checkmarks show all 4 verifications completed
23. Navigate to http://localhost:3001/transactions
24. Verify authorization and capture transactions exist for this booking

## Pass Criteria
- Parent successfully creates a booking via the parent app
- Matching engine generates at least one caregiver offer
- Caregiver accepts the booking via the caregiver app
- Session starts with verification from both caregiver and parent
- Session ends with verification from both caregiver and parent
- Session status reaches "completed"
- Payment authorization and capture transactions succeed
- Admin portal shows the completed booking with all details
- Admin portal shows the completed session with all 4 verification checkmarks
- Admin portal shows successful transactions for the booking
