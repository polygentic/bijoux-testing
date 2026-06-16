# Admin Action: Create Market Pricing

## UAT ID
UAT-L3.16

## Setup (run via bash)
```bash
source config/environment.sh && source scripts/lib/api-helpers.sh && source scripts/lib/admin-api-helpers.sh
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
# Check existing pricing configs
EXISTING=$(admin_list_pricing "$ADMIN_TOKEN")
echo "$EXISTING" | python3 -c "
import sys, json
d = json.load(sys.stdin)
items = d.get('data', d.get('configs', d.get('pricing', [])))
if isinstance(items, list):
    for p in items:
        print(f\"  {p.get('marketName', p.get('state', 'N/A'))}: {p.get('baseRateCents', p.get('caregiverRateCents', 'N/A'))}c\")
"
```

## Admin Action (execute in Chrome)
1. Navigate to http://localhost:3001/settings/pricing
2. Verify the pricing table is displayed
3. Click the "Add Market" button
4. In the modal/form, enter:
   - Market Name: Houston
   - State: TX
   - Caregiver Rate: 3800 (cents)
   - Platform Fee: 0.40
   - Child Surcharge: 1000 (cents)
   - Minimum Hours: 3
   - Demand Multiplier: 1.0
5. Click submit/save
6. Verify the modal closes
7. Verify "Houston" appears in the pricing table
8. Verify the Houston row shows correct values
9. Take a screenshot

## API Verification (run via bash)
```bash
source config/environment.sh && source scripts/lib/api-helpers.sh && source scripts/lib/admin-api-helpers.sh
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
PRICING=$(admin_list_pricing "$ADMIN_TOKEN")
echo "$PRICING" | python3 -c "
import sys, json
d = json.load(sys.stdin)
items = d.get('data', d.get('configs', d.get('pricing', [])))
houston = [p for p in items if 'houston' in str(p).lower() or p.get('state') == 'TX']
if houston:
    h = houston[0]
    print(f\"Found Houston: rate={h.get('caregiverRateCents', h.get('baseRateCents', 'N/A'))}c\")
else:
    print('Houston pricing not found')
"
```

## Pass Criteria
- Add Market button visible and functional
- Modal accepts all pricing fields
- New market appears in table after creation
- API confirms Houston pricing config exists
