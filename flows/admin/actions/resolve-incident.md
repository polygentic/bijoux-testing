# Admin Action: Resolve Incident

## UAT ID
UAT-L3.18

## Context
Admin resolves an open incident with resolution notes.

## Setup (run via bash)
```bash
source config/environment.sh && source scripts/lib/api-helpers.sh && source scripts/lib/admin-api-helpers.sh
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
# Check for open incidents
INCIDENTS=$(admin_list_incidents "$ADMIN_TOKEN" "status=open")
echo "$INCIDENTS" | python3 -c "
import sys, json
d = json.load(sys.stdin)
items = d.get('data', d.get('incidents', []))
if isinstance(items, list) and len(items) > 0:
    i = items[0]
    print(f\"Incident: {i.get('id')} (type: {i.get('type')}, status: {i.get('status')})\")
else:
    print('No open incidents found. Incidents may be created by system events or disputes.')
"
```

## Admin Action (execute in Chrome)
1. Navigate to http://localhost:3001/incidents
2. If open incidents exist, click one to open detail
3. Click "Resolve" button
4. Enter resolution notes: "UAT resolution test — issue addressed"
5. Confirm
6. Verify incident status changes to "Resolved"
7. Take a screenshot
8. If no incidents exist, verify the empty state is clean and take a screenshot

## API Verification (run via bash)
```bash
source config/environment.sh && source scripts/lib/api-helpers.sh && source scripts/lib/admin-api-helpers.sh
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
INCIDENTS=$(admin_list_incidents "$ADMIN_TOKEN" "status=resolved")
echo "$INCIDENTS" | python3 -c "
import sys, json
d = json.load(sys.stdin)
items = d.get('data', d.get('incidents', []))
if isinstance(items, list) and len(items) > 0:
    print(f\"Resolved incidents: {len(items)}\")
    i = items[0]
    print(f\"Latest: {i.get('id')} — {i.get('notes', i.get('resolutionNotes', 'N/A'))}\")
else:
    print('No resolved incidents (may be expected if no incidents were created)')
"
```

## Pass Criteria
- Resolve button visible on open incidents
- Modal accepts resolution notes
- Incident status changes to "Resolved"
- API confirms resolved status
- If no incidents exist, empty state displays cleanly
