# Cross-App Verify: Pricing Configurations

## UAT ID
UAT-L2.18

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!

## Steps
1. Navigate to http://localhost:3001/settings/pricing
2. Verify pricing configurations table loads
3. Verify at least one market pricing config exists (from seed data)
4. Check that each config shows: market/state, base rate, platform fee, effective rate
5. Take a screenshot

## Pass Criteria
- Pricing page loads with seeded market configs
- Each config shows rate/fee fields
- Data matches expected seed values
