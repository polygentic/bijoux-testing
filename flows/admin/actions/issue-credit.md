# Admin Action: Issue Credit

## UAT ID
UAT-L3.3

## Setup (run via bash)
```bash
source config/environment.sh && source scripts/lib/api-helpers.sh && source scripts/lib/admin-api-helpers.sh
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
SARAH_ID=$(admin_get_user_id_by_email "$ADMIN_TOKEN" "parent-sarah@test.bijoux.app")
BALANCE_BEFORE=$(admin_get_credit_balance "$ADMIN_TOKEN" "$SARAH_ID" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',d).get('balanceCents',0))")
echo "Balance before: ${BALANCE_BEFORE}c"
```

## Admin Action (execute in Chrome)
1. Navigate to http://localhost:3001/users
2. Search for "Sarah" and click to open detail
3. Look for "Issue Credit" button
4. Click it
5. In the modal, enter amount: $25.00 (or 2500 cents)
6. Enter reason: "UAT credit test"
7. Submit
8. Verify success message appears
9. Verify credit balance updates on the page
10. Take a screenshot

## API Verification (run via bash)
```bash
source config/environment.sh && source scripts/lib/api-helpers.sh && source scripts/lib/admin-api-helpers.sh
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
SARAH_ID=$(admin_get_user_id_by_email "$ADMIN_TOKEN" "parent-sarah@test.bijoux.app")
BALANCE_AFTER=$(admin_get_credit_balance "$ADMIN_TOKEN" "$SARAH_ID" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',d).get('balanceCents',0))")
echo "Balance after: ${BALANCE_AFTER}c"
# Expected: BALANCE_BEFORE + 2500
```

## Pass Criteria
- Issue Credit button visible on parent detail
- Modal accepts amount and reason
- Credit balance updates in admin UI after issuance
- API balance increases by $25.00
