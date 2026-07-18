# Admin Action: Suspend Parent

## UAT ID
UAT-L3.1

## Setup (run via bash)
```bash
source config/environment.sh && source scripts/lib/api-helpers.sh && source scripts/lib/admin-api-helpers.sh
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
# Get Sarah's user ID
SARAH_ID=$(admin_get_user_id_by_email "$ADMIN_TOKEN" "parent-sarah@test.bijoux.app")
echo "Sarah user ID: $SARAH_ID"
# Ensure Sarah is active (not already suspended)
admin_change_user_status "$ADMIN_TOKEN" "$SARAH_ID" "active" "Pre-test reset"
```

## Admin Action (execute in Chrome)
1. Navigate to http://localhost:3001/users
2. Search for "Sarah Mitchell" or "parent-sarah"
3. Click Sarah's row to open her detail page
4. Look for a "Suspend" or "Suspend Account" button
5. Click it
6. If a confirmation modal appears, enter reason: "UAT suspension test"
7. Confirm the action
8. Verify Sarah's status changes to "Suspended" on the page
9. Take a screenshot

## iOS Verification (run via bash)
```bash
# Verify parent can't use the app (login blocked)
maestro test flows/verify/parent-login-blocked.yaml --device $PARENT_UDID 2>&1
```

## API Verification (run via bash)
```bash
source config/environment.sh && source scripts/lib/api-helpers.sh && source scripts/lib/admin-api-helpers.sh
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
SARAH_ID=$(admin_get_user_id_by_email "$ADMIN_TOKEN" "parent-sarah@test.bijoux.app")
USER_DATA=$(admin_get_user "$ADMIN_TOKEN" "$SARAH_ID")
STATUS=$(echo "$USER_DATA" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',d).get('status',''))")
echo "Sarah status: $STATUS"
# Expected: suspended
```

## Cleanup
```bash
# Reactivate Sarah for subsequent tests
admin_change_user_status "$ADMIN_TOKEN" "$SARAH_ID" "active" "Post-test cleanup"
```

## Pass Criteria
- Suspend button visible on active parent detail page
- Confirmation modal appears with reason field
- Status updates to "Suspended" in admin after action
- Parent app login is blocked (Maestro flow sees error, not home screen)
- API confirms status = suspended
