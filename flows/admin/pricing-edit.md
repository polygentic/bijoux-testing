# Edit Market Pricing

## UAT ID
UAT-17.5

## Prerequisites
- Admin portal running at http://localhost:3001
- Logged in as admin@bijoux.app / Test1234!
- A "Dallas" market exists in the pricing table

## Steps
1. Navigate to http://localhost:3001/settings/pricing
2. Locate the Dallas market row in the pricing table
3. Click the edit (pencil) icon on the Dallas row
4. Verify a modal or form appears pre-populated with the current Dallas market values
5. Verify that the Market Name field is disabled/read-only
6. Verify that the State field is disabled/read-only
7. Locate the Caregiver Rate field. Change the value to 4000 (in cents)
8. Click the submit/save button
9. Verify the modal closes
10. Verify the Dallas market row in the table now shows the updated rate of $40.00/hr (4000 cents)
11. Verify the Market Name still reads "Dallas" and State still reads the original value

## Pass Criteria
- Edit (pencil) icon is visible on market rows and clickable
- Modal/form opens pre-populated with the current Dallas values
- Market Name field is disabled during edit
- State field is disabled during edit
- Caregiver Rate can be changed to 4000 (cents)
- After submission, the Dallas row reflects the updated rate ($40.00/hr)
- Market Name and State remain unchanged after the edit
