# Admin Action: Approve Caregiver

## UAT ID
UAT-L3.7

## Setup (run via bash)
```bash
source config/environment.sh && source scripts/lib/api-helpers.sh && source scripts/lib/admin-api-helpers.sh
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
# Get Jake's caregiver profile ID (pending caregiver)
JAKE_CG_ID=$(admin_get_caregiver_profile_id_by_email "$ADMIN_TOKEN" "cg-pending")
echo "Jake caregiver profile ID: $JAKE_CG_ID"
# Check current status
admin_get_caregiver "$ADMIN_TOKEN" "$JAKE_CG_ID" | python3 -c "
import sys, json
d = json.load(sys.stdin)
cg = d.get('data', d.get('caregiver', d))
print(f\"Status: {cg.get('status', 'N/A')}\")
print(f\"BG: {cg.get('bgCheckStatus', 'N/A')}\")
print(f\"IDV: {cg.get('idvStatus', 'N/A')}\")
"
```

## Admin Action (execute in Chrome)
1. Navigate to http://localhost:3001/caregivers
2. Find Jake Wilson (cg-pending) and click to open detail
3. Verify status is "Pending"
4. Check Trust & Safety card for BG check and IDV statuses
5. If BG = clear AND IDV = approved, the "Approve" button should be enabled
6. Click "Approve"
7. Confirm in the modal
8. Verify status changes to "Approved"
9. Take a screenshot

## API Verification (run via bash)
```bash
source config/environment.sh && source scripts/lib/api-helpers.sh && source scripts/lib/admin-api-helpers.sh
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
JAKE_CG_ID=$(admin_get_caregiver_profile_id_by_email "$ADMIN_TOKEN" "cg-pending")
STATUS=$(admin_get_caregiver "$ADMIN_TOKEN" "$JAKE_CG_ID" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',d.get('caregiver',d)).get('status',''))")
echo "Jake status: $STATUS"
# Expected: approved
```

## Pass Criteria
- Approve button enabled only when BG=clear AND IDV=approved
- Status changes to "Approved" after confirmation
- API confirms approved status
