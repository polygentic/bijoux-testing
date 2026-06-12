# Create New Market Pricing

## UAT ID
UAT-17.4

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!
- No existing "Houston" market in the pricing table (or it has been cleaned up from a previous test run)

## Steps
1. Navigate to http://localhost:3001/settings/pricing
2. Verify the pricing table is displayed
3. Locate and click the "Add Market" button
4. Verify a modal or form appears with fields for market configuration
5. Enter the following values:
   - Market Name: Houston
   - State: TX
   - Caregiver Rate: 3800 (in cents)
   - Platform Fee: 0.40
   - Child Surcharge: 1000 (in cents)
   - Minimum Hours: 3
   - Demand Multiplier: 1.0
6. Click the submit/save button
7. Verify the modal closes
8. Verify the new "Houston" market appears in the pricing table
9. Verify the Houston row displays the correct values: TX state, $38.00/hr rate (3800 cents), 40% fee, $10.00 surcharge (1000 cents), 3 min hours, 1.0 demand multiplier

## Pass Criteria
- Add Market button is visible and clickable
- Modal/form appears with all required fields
- All fields accept the specified values
- After submission, the Houston market appears in the pricing table
- Houston row displays correct values matching the input: Market "Houston", State "TX", rate 3800 cents ($38.00), fee 0.40, surcharge 1000 cents ($10.00), min hours 3, demand multiplier 1.0
