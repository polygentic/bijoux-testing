# Admin Action: Edit Market Pricing

## UAT ID
UAT-L3.17

## Setup (run via bash)
```bash
source config/environment.sh && source scripts/lib/api-helpers.sh && source scripts/lib/admin-api-helpers.sh
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
# Verify Dallas market exists in pricing
PRICING=$(admin_list_pricing "$ADMIN_TOKEN")
echo "$PRICING" | python3 -c "
import sys, json
d = json.load(sys.stdin)
items = d.get('data', d.get('configs', d.get('pricing', [])))
dallas = [p for p in items if 'dallas' in str(p).lower()]
if dallas:
    d = dallas[0]
    print(f\"Dallas: id={d.get('id')}, rate={d.get('caregiverRateCents', d.get('baseRateCents', 'N/A'))}c\")
else:
    print('Dallas pricing not found — may need to seed first')
"
```

## Admin Action (execute in Chrome)
1. Navigate to http://localhost:3001/settings/pricing
2. Locate the Dallas market row
3. Click the edit (pencil) icon on the Dallas row
4. Verify modal opens pre-populated with current Dallas values
5. Verify Market Name and State fields are disabled/read-only
6. Change Caregiver Rate to 4000 (cents)
7. Click submit/save
8. Verify modal closes
9. Verify Dallas row now shows updated rate ($40.00/hr)
10. Take a screenshot

## API Verification (run via bash)
```bash
source config/environment.sh && source scripts/lib/api-helpers.sh && source scripts/lib/admin-api-helpers.sh
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
PRICING=$(admin_list_pricing "$ADMIN_TOKEN")
echo "$PRICING" | python3 -c "
import sys, json
d = json.load(sys.stdin)
items = d.get('data', d.get('configs', d.get('pricing', [])))
dallas = [p for p in items if 'dallas' in str(p).lower()]
if dallas:
    rate = dallas[0].get('caregiverRateCents', dallas[0].get('baseRateCents', 'N/A'))
    print(f\"Dallas rate: {rate}c (expected: 4000c)\")
else:
    print('Dallas not found')
"
```

## Pass Criteria
- Edit icon visible on market rows
- Modal pre-populates current values
- Market Name and State are read-only during edit
- Rate change persists after save
- API confirms updated rate = 4000c
