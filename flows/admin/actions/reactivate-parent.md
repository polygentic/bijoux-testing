# Admin Action: Reactivate Parent

## UAT ID
UAT-L3.2

## Setup (run via bash)
```bash
source config/environment.sh && source scripts/lib/api-helpers.sh && source scripts/lib/admin-api-helpers.sh
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
SARAH_ID=$(admin_get_user_id_by_email "$ADMIN_TOKEN" "parent-sarah@test.bijoux.app")
# Suspend first so we can reactivate
admin_change_user_status "$ADMIN_TOKEN" "$SARAH_ID" "suspended" "Setup for reactivation test"
```

## Admin Action (execute in Chrome)
1. Navigate to http://localhost:3001/users
2. Search for "Sarah" and click to open detail
3. Verify status shows "Suspended"
4. Click "Reactivate" or "Activate" button
5. Confirm if prompted
6. Verify status changes to "Active"
7. Take a screenshot

## API Verification (run via bash)
```bash
source config/environment.sh && source scripts/lib/api-helpers.sh && source scripts/lib/admin-api-helpers.sh
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
SARAH_ID=$(admin_get_user_id_by_email "$ADMIN_TOKEN" "parent-sarah@test.bijoux.app")
STATUS=$(admin_get_user "$ADMIN_TOKEN" "$SARAH_ID" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',d).get('status',''))")
echo "Sarah status: $STATUS"
# Expected: active
```

## Pass Criteria
- Reactivate button visible on suspended parent
- Status updates to "Active" in admin after action
- API confirms status = active
