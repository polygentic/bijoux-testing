# Admin Action: Initiate Background Check

## UAT ID
UAT-L3.11

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
print(f\"BG status: {cg.get('bgCheckStatus', 'N/A')}\")
"
```

## Admin Action (execute in Chrome)
1. Navigate to http://localhost:3001/caregivers
2. Find Jake Wilson (cg-pending) and click to open detail
3. Locate the Trust & Safety card
4. Note the current BG check status
5. Click "BG Check" or "Initiate Background Check" button
6. Wait for the API call to complete
7. Verify BG check status changes to "pending"
8. Take a screenshot

## API Verification (run via bash)
```bash
source config/environment.sh && source scripts/lib/api-helpers.sh && source scripts/lib/admin-api-helpers.sh
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
JAKE_CG_ID=$(admin_get_caregiver_profile_id_by_email "$ADMIN_TOKEN" "cg-pending")
BG_STATUS=$(admin_get_caregiver "$ADMIN_TOKEN" "$JAKE_CG_ID" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',d.get('caregiver',d)).get('bgCheckStatus',''))")
echo "BG status: $BG_STATUS"
# Expected: pending
```

## Pass Criteria
- BG Check button visible on caregiver without completed BG check
- Clicking initiates the check (no errors)
- BG status updates to "pending" in Trust & Safety card
- API confirms bgCheckStatus = pending
