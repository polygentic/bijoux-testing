# Admin Action: Mark Session Disputed

## UAT ID
UAT-L3.15

## Context
Admin marks a completed session as disputed, typically after a parent complaint.

## Setup (run via bash)
```bash
source config/environment.sh && source scripts/lib/api-helpers.sh && source scripts/lib/admin-api-helpers.sh
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
# Find a completed session
SESSIONS=$(admin_list_sessions "$ADMIN_TOKEN" "status=completed")
echo "$SESSIONS" | python3 -c "
import sys, json
d = json.load(sys.stdin)
items = d.get('data', d.get('sessions', []))
if isinstance(items, list) and len(items) > 0:
    s = items[0]
    print(f\"Session: {s.get('id')} (status: {s.get('status')})\")
else:
    print('No completed sessions found')
"
```

## Admin Action (execute in Chrome)
1. Navigate to http://localhost:3001/sessions
2. Find a completed session
3. Click to open session detail
4. Click "Mark Disputed" button (or "Dispute" button)
5. Enter reason: "UAT dispute test — parent reported issue"
6. Confirm
7. Verify session shows disputed flag or status
8. Take a screenshot

## API Verification (run via bash)
```bash
source config/environment.sh && source scripts/lib/api-helpers.sh && source scripts/lib/admin-api-helpers.sh
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
SESSIONS=$(admin_list_sessions "$ADMIN_TOKEN" "status=completed&sort=-updatedAt&limit=5")
echo "$SESSIONS" | python3 -c "
import sys, json
d = json.load(sys.stdin)
items = d.get('data', d.get('sessions', []))
for s in (items if isinstance(items, list) else []):
    disputed = s.get('disputed', s.get('isDisputed', False))
    if disputed:
        print(f\"Disputed session: {s.get('id')}\")
        break
else:
    print('No disputed session found yet')
"
```

## Pass Criteria
- Mark Disputed button visible on completed sessions
- Modal accepts dispute reason
- Session shows disputed status after action
- API confirms dispute flag is set
