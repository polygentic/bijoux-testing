# Admin Action: Reactivate Caregiver

## UAT ID
UAT-L3.9

## Setup (run via bash)
```bash
source config/environment.sh && source scripts/lib/api-helpers.sh && source scripts/lib/admin-api-helpers.sh
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
EMMA_CG_ID=$(admin_get_caregiver_profile_id_by_email "$ADMIN_TOKEN" "cg-emma")
# Suspend first so we can reactivate
admin_set_caregiver_approval "$ADMIN_TOKEN" "$EMMA_CG_ID" "suspend" "Setup for reactivation test"
```

## Admin Action (execute in Chrome)
1. Navigate to http://localhost:3001/caregivers
2. Find Emma Thompson and click to open detail
3. Verify status shows "Suspended"
4. Click "Reactivate" or "Approve" button
5. Confirm if prompted
6. Verify status changes to "Approved" or "Active"
7. Take a screenshot

## API Verification (run via bash)
```bash
source config/environment.sh && source scripts/lib/api-helpers.sh && source scripts/lib/admin-api-helpers.sh
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
EMMA_CG_ID=$(admin_get_caregiver_profile_id_by_email "$ADMIN_TOKEN" "cg-emma")
STATUS=$(admin_get_caregiver "$ADMIN_TOKEN" "$EMMA_CG_ID" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',d.get('caregiver',d)).get('status',''))")
echo "Emma status: $STATUS"
# Expected: approved
```

## Pass Criteria
- Reactivate/Approve button visible on suspended caregiver
- Status changes to "Approved" after action
- API confirms approved status
