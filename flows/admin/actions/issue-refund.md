# Admin Action: Issue Refund

## UAT ID
UAT-L3.4

## Setup (run via bash)
```bash
source config/environment.sh && source scripts/lib/api-helpers.sh && source scripts/lib/admin-api-helpers.sh
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
# Need a completed booking with a captured transaction
# Use latest completed booking
PARENT_TOKEN=$(api_login "$PARENT_EMAIL" "$PARENT_PASSWORD")
BOOKING_ID=$(api_latest_booking_id "$PARENT_TOKEN")
echo "Booking for refund: $BOOKING_ID"
TRANSACTIONS=$(api_transactions_for_booking "$ADMIN_TOKEN" "$BOOKING_ID")
echo "Transactions: $TRANSACTIONS" | python3 -c "import sys,json; [print(f\"  {t.get('type')}:{t.get('status')}\") for t in json.load(sys.stdin).get('data',[])]" 2>/dev/null
```

## Admin Action (execute in Chrome)
1. Navigate to http://localhost:3001/bookings
2. Find the completed booking (from setup output)
3. Click to open booking detail
4. Scroll to transactions section
5. Look for a "Refund" button on a captured transaction
6. Click refund
7. If amount field shown, enter full or partial amount
8. Enter reason: "UAT refund test"
9. Confirm
10. Verify refund transaction appears in the table
11. Take a screenshot

## API Verification (run via bash)
```bash
source config/environment.sh && source scripts/lib/api-helpers.sh && source scripts/lib/admin-api-helpers.sh
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
PARENT_TOKEN=$(api_login "$PARENT_EMAIL" "$PARENT_PASSWORD")
BOOKING_ID=$(api_latest_booking_id "$PARENT_TOKEN")
TRANSACTIONS=$(api_transactions_for_booking "$ADMIN_TOKEN" "$BOOKING_ID")
echo "$TRANSACTIONS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
items = data.get('data', data.get('transactions', []))
has_refund = any(t.get('type') == 'refund' for t in items)
print(f'has_refund={has_refund}')
for t in items: print(f\"  {t.get('type')}:{t.get('status')}:{t.get('amountCents')}c\")
"
# Expected: has_refund=True
```

## Pass Criteria
- Refund button available on captured transactions
- Refund accepts amount and reason
- Refund transaction appears in table after action
- API confirms refund transaction exists
