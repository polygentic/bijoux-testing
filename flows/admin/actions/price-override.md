# Admin Action: Price Override

## UAT ID
UAT-L3.6

## Setup (run via bash)
```bash
source config/environment.sh && source scripts/lib/api-helpers.sh && source scripts/lib/admin-api-helpers.sh
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
PARENT_TOKEN=$(api_login "$PARENT_EMAIL" "$PARENT_PASSWORD")
# Get a booking to override price on
BOOKING_ID=$(api_latest_booking_id "$PARENT_TOKEN")
BOOKING_DATA=$(admin_get_booking "$ADMIN_TOKEN" "$BOOKING_ID")
echo "Booking: $BOOKING_ID"
echo "$BOOKING_DATA" | python3 -c "
import sys, json
d = json.load(sys.stdin)
b = d.get('booking', d.get('data', d))
print(f\"Current cost: {b.get('totalCostCents', 'N/A')}c\")
print(f\"Lifecycle: {b.get('lifecycle', 'N/A')}\")
"
```

## Admin Action (execute in Chrome)
1. Navigate to http://localhost:3001/bookings
2. Click on the booking from setup output
3. Note the current price displayed in Booking Details card
4. Click the "Price Override" button
5. In the modal, enter new price: $150.00
6. Enter reason: "UAT price override test"
7. Submit
8. Verify the modal closes
9. Verify the price override is shown on the booking detail page
10. Verify both original and override prices are visible
11. Take a screenshot

## API Verification (run via bash)
```bash
source config/environment.sh && source scripts/lib/api-helpers.sh && source scripts/lib/admin-api-helpers.sh
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
PARENT_TOKEN=$(api_login "$PARENT_EMAIL" "$PARENT_PASSWORD")
BOOKING_ID=$(api_latest_booking_id "$PARENT_TOKEN")
BOOKING_DATA=$(admin_get_booking "$ADMIN_TOKEN" "$BOOKING_ID")
echo "$BOOKING_DATA" | python3 -c "
import sys, json
d = json.load(sys.stdin)
b = d.get('booking', d.get('data', d))
print(f\"Total cost: {b.get('totalCostCents', 'N/A')}c\")
override = b.get('priceOverride', b.get('overrideCostCents', 'N/A'))
print(f\"Override: {override}\")
"
```

## Pass Criteria
- Price Override button accessible on booking detail
- Modal accepts new price and reason
- Both original and override prices displayed after action
- API confirms the override value
