# Admin Action: Force Complete Session

## UAT ID
UAT-L3.14

## Context
Admin force-completes a session that is stuck in progress. Sets the final cost and marks it completed.

## Setup (run via bash)
```bash
source config/environment.sh && source scripts/lib/api-helpers.sh && source scripts/lib/admin-api-helpers.sh
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
# Find an in-progress or not_started session
SESSIONS=$(admin_list_sessions "$ADMIN_TOKEN" "status=in_progress")
echo "$SESSIONS" | python3 -c "
import sys, json
d = json.load(sys.stdin)
items = d.get('data', d.get('sessions', []))
if isinstance(items, list) and len(items) > 0:
    s = items[0]
    print(f\"Session: {s.get('id')} (status: {s.get('status')})\")
else:
    print('No in-progress sessions found. Run E2E flow first without ending session.')
"
```

## Admin Action (execute in Chrome)
1. Navigate to http://localhost:3001/sessions
2. Find an in-progress session (or any session that can be force-completed)
3. Click to open session detail
4. Verify current status is not "Completed"
5. Click "Force Complete" button
6. In the modal, enter final cost: $45.00 (4500 cents)
7. Enter reason: "UAT force complete test"
8. Confirm
9. Verify session status changes to "Completed"
10. Verify the admin-set cost is displayed
11. Take a screenshot

## API Verification (run via bash)
```bash
source config/environment.sh && source scripts/lib/api-helpers.sh && source scripts/lib/admin-api-helpers.sh
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
# Check latest completed session
SESSIONS=$(admin_list_sessions "$ADMIN_TOKEN" "status=completed&sort=-updatedAt&limit=1")
echo "$SESSIONS" | python3 -c "
import sys, json
d = json.load(sys.stdin)
items = d.get('data', d.get('sessions', []))
if isinstance(items, list) and len(items) > 0:
    s = items[0]
    print(f\"Session: {s.get('id')}, status: {s.get('status')}, cost: {s.get('finalCostCents', 'N/A')}c\")
"
```

## Pass Criteria
- Force Complete button visible on non-completed sessions
- Modal accepts cost and reason
- Session status updates to "Completed"
- Admin-set cost is displayed
- API confirms session completed with correct cost
