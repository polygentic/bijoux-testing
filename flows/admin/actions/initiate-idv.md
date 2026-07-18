# Admin Action: Initiate Identity Verification

## UAT ID
UAT-L3.12

## Setup (run via bash)
```bash
source config/environment.sh && source scripts/lib/api-helpers.sh && source scripts/lib/admin-api-helpers.sh
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
JAKE_CG_ID=$(admin_get_caregiver_profile_id_by_email "$ADMIN_TOKEN" "cg-pending")
echo "Jake caregiver profile ID: $JAKE_CG_ID"
admin_get_caregiver "$ADMIN_TOKEN" "$JAKE_CG_ID" | python3 -c "
import sys, json
d = json.load(sys.stdin)
cg = d.get('data', d.get('caregiver', d))
print(f\"IDV status: {cg.get('idvStatus', 'N/A')}\")
"
```

## Admin Action (execute in Chrome)
1. Navigate to http://localhost:3001/caregivers
2. Find Jake Wilson (cg-pending) and click to open detail
3. Locate the Trust & Safety card
4. Note the current IDV status
5. Click "IDV" or "Initiate Identity Verification" button
6. Wait for the API call to complete
7. Verify IDV status changes to "pending"
8. Take a screenshot

## API Verification (run via bash)
```bash
source config/environment.sh && source scripts/lib/api-helpers.sh && source scripts/lib/admin-api-helpers.sh
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
JAKE_CG_ID=$(admin_get_caregiver_profile_id_by_email "$ADMIN_TOKEN" "cg-pending")
IDV_STATUS=$(admin_get_caregiver "$ADMIN_TOKEN" "$JAKE_CG_ID" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',d.get('caregiver',d)).get('idvStatus',''))")
echo "IDV status: $IDV_STATUS"
# Expected: pending
```

## Pass Criteria
- IDV button visible on caregiver without completed IDV
- Clicking initiates the verification (no errors)
- IDV status updates to "pending" in Trust & Safety card
- API confirms idvStatus = pending
