# Cross-App — Full Booking Lifecycle

## Prerequisites
- Backend running and seeded (including test accounts)
- Both iOS simulators booted with apps installed
- Admin portal running at http://localhost:3001
- Parent sim UDID available as $PARENT_UDID
- Caregiver sim UDID available as $CAREGIVER_UDID

## Steps

### Phase 1: Parent Creates Booking
1. Run `maestro test flows/parent/login.yaml --device $PARENT_UDID`
2. On the parent simulator, tap the "Request Now" card (id: home-request-now-card)
3. Verify QuickBookingView loads — look for "Request Caregiver" button
4. Take screenshot: results/cross-app-booking-created

### Phase 2: Backend Creates Match
5. Call backend to simulate caregiver acceptance:
   ```bash
   # First, get the active match request
   source config/environment.sh
   ACCESS_TOKEN=$(curl -s -X POST "$BACKEND_URL/auth/login" \
     -H "Content-Type: application/json" \
     -d '{"email":"parent-sarah@test.bijoux.app","password":"Test1234!"}' \
     | python3 -c "import sys,json; print(json.load(sys.stdin)['accessToken'])")

   # Create booking
   BOOKING_ID=$(curl -s -X POST "$BACKEND_URL/bookings" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $ACCESS_TOKEN" \
     -d '{"type":"request_now","address":"123 Test St, Austin, TX","latitude":30.2672,"longitude":-97.7431}' \
     | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

   # Start matching
   MATCH_ID=$(curl -s -X POST "$BACKEND_URL/matching/start" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $ACCESS_TOKEN" \
     -d "{\"bookingId\":\"$BOOKING_ID\"}" \
     | python3 -c "import sys,json; print(json.load(sys.stdin)['matchRequestId'])")

   # Simulate caregiver accepting
   curl -s -X POST "$BACKEND_URL/matching/admin/simulate-accept" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $ACCESS_TOKEN" \
     -d "{\"requestId\":\"$MATCH_ID\"}"
   ```

### Phase 3: Verify in Admin Portal
6. In admin portal browser, navigate to Sessions page (click "Sessions" in sidebar)
7. Look for a session row — verify it exists
8. Take screenshot: results/cross-app-admin-session

### Phase 4: Caregiver Sees Session
9. Run `maestro test flows/caregiver/login.yaml --device $CAREGIVER_UDID`
10. On caregiver simulator, verify home screen shows an active job or offer
11. Take screenshot: results/cross-app-caregiver-home

## Pass Criteria
- Parent can initiate a booking via the app
- Backend matching produces a caregiver assignment
- Admin portal shows the session
- Caregiver app reflects the matched state
- All screenshots captured without error
