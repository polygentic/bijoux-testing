# Pricing List View

## UAT ID
UAT-17.3

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!
- At least the Austin TX market exists in the pricing/settings data with a $40.00/hr caregiver rate and 40% platform fee

## Steps
1. Navigate to http://localhost:3001/settings/pricing
2. Verify the pricing table is displayed with the following columns: Market, State, Caregiver Rate, Platform Fee, Child Surcharge, Min Hours, Demand Mult., Effective Rate
3. Verify that rows are populated with market pricing data
4. Locate the Austin TX market row
5. Verify Austin TX displays a caregiver rate of $40.00/hr
6. Verify Austin TX displays a platform fee of 40% (0.40)
7. Verify the Effective Rate column is present and shows a calculated value
8. Verify the effective rate calculation is consistent (e.g., base rate with fee applied)
9. Review other market rows and verify all columns are populated with reasonable values

## Pass Criteria
- Table renders with all 8 required columns: Market, State, Caregiver Rate, Platform Fee, Child Surcharge, Min Hours, Demand Mult., Effective Rate
- Austin TX market is visible with $40.00/hr caregiver rate
- Austin TX market shows 40% (0.40) platform fee
- Effective Rate column is present and shows a calculated value for each market
- All market rows have populated values across all columns
