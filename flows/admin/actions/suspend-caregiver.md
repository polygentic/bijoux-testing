# Admin Action: Suspend Caregiver

## UAT ID
UAT-L3.8

## Setup (run via bash)
```bash
source config/environment.sh && source scripts/lib/api-helpers.sh && source scripts/lib/admin-api-helpers.sh
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
EMMA_CG_ID=$(admin_get_caregiver_profile_id_by_email "$ADMIN_TOKEN" "cg-emma")
echo "Emma caregiver profile ID: $EMMA_CG_ID"
# Ensure Emma is approved (not already suspended)
admin_set_caregiver_approval "$ADMIN_TOKEN" "$EMMA_CG_ID" "approve" "Pre-test reset"
```

## Admin Action (execute in Chrome)
1. Navigate to http://localhost:3001/caregivers
2. Find Emma Thompson and click to open detail
3. Verify status is "Approved"
4. Note online status
5. Click "Suspend"
6. Enter reason: "UAT suspension test"
7. Confirm
8. Verify status changes to "Suspended"
9. Verify Emma is taken offline
10. Take a screenshot

## iOS Verification (run via bash)
```bash
# Verify caregiver is forced offline
maestro test flows/verify/caregiver-forced-offline.yaml --device $CAREGIVER_UDID 2>&1
```

## API Verification (run via bash)
```bash
source config/environment.sh && source scripts/lib/api-helpers.sh && source scripts/lib/admin-api-helpers.sh
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
EMMA_CG_ID=$(admin_get_caregiver_profile_id_by_email "$ADMIN_TOKEN" "cg-emma")
STATUS=$(admin_get_caregiver "$ADMIN_TOKEN" "$EMMA_CG_ID" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',d.get('caregiver',d)).get('status',''))")
echo "Emma status: $STATUS"
# Expected: suspended
```

## Cleanup
```bash
admin_set_caregiver_approval "$ADMIN_TOKEN" "$EMMA_CG_ID" "approve" "Post-test cleanup"
```

## Pass Criteria
- Suspend button visible on approved caregiver
- Modal requires suspension reason
- Status changes to "Suspended"
- Caregiver taken offline automatically
- Maestro confirms caregiver forced offline
- API confirms suspended status
