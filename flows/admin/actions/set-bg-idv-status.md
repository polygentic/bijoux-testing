# Admin Action: Set BG Check and IDV Status

## UAT ID
UAT-L3.13

## Context
Manually set BG check to "clear" and IDV to "approved" for a pending caregiver, then verify the Approve button becomes enabled.

## Setup (run via bash)
```bash
source config/environment.sh && source scripts/lib/api-helpers.sh && source scripts/lib/admin-api-helpers.sh
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
JAKE_CG_ID=$(admin_get_caregiver_profile_id_by_email "$ADMIN_TOKEN" "cg-pending")
echo "Jake caregiver profile ID: $JAKE_CG_ID"
# Check current trust statuses
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
3. Locate the Trust & Safety card
4. If BG status is not "clear":
   - Look for a "Set Status" dropdown or "Override" option for BG check
   - Set BG check to "clear"
5. If IDV status is not "approved":
   - Look for a "Set Status" dropdown or "Override" option for IDV
   - Set IDV to "approved"
6. After setting both:
   - Verify the "Approve" button becomes enabled/visible
   - Do NOT click Approve yet (that's a separate test)
7. Take a screenshot

## API Verification (run via bash)
```bash
source config/environment.sh && source scripts/lib/api-helpers.sh && source scripts/lib/admin-api-helpers.sh
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
JAKE_CG_ID=$(admin_get_caregiver_profile_id_by_email "$ADMIN_TOKEN" "cg-pending")
admin_get_caregiver "$ADMIN_TOKEN" "$JAKE_CG_ID" | python3 -c "
import sys, json
d = json.load(sys.stdin)
cg = d.get('data', d.get('caregiver', d))
print(f\"BG: {cg.get('bgCheckStatus', 'N/A')}\")
print(f\"IDV: {cg.get('idvStatus', 'N/A')}\")
# Expected: BG=clear, IDV=approved
"
```

## Pass Criteria
- BG check status can be manually set to "clear"
- IDV status can be manually set to "approved"
- After both are set, the Approve button becomes enabled
- API confirms bgCheckStatus=clear and idvStatus=approved
