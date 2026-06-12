# Bijoux UAT — Seed Data Requirements

All test accounts use password: `Test1234!`

---

## Test Accounts

### Admin

| Email | Name | Role | Status | Purpose |
|-------|------|------|--------|---------|
| admin@bijoux.app | Admin User | admin | active | Primary admin portal testing |

### Parents

| Email | Name | Role | Status | Children | Credits | Purpose |
|-------|------|------|--------|----------|---------|---------|
| parent-sarah@test.bijoux.app | Sarah Mitchell | parent | active | 2 (Lily 5yo, Max 3yo) | $25.00 | Main happy-path parent |
| parent-james@test.bijoux.app | James Rivera | parent | active | 1 (Sofia 7yo) | $0.00 | Secondary parent (booking history) |
| parent-suspended@test.bijoux.app | Alex Chen | parent | suspended | 0 | $0.00 | Suspended account testing |

### Caregivers

| Email | Name | Status | Setup Complete | Approved | Online | BG Check | IDV | Purpose |
|-------|------|--------|---------------|----------|--------|----------|-----|---------|
| cg-emma@test.bijoux.app | Emma Thompson | active | YES | YES | NO | clear | approved | Main happy-path caregiver (fully onboarded) |
| cg-maria@test.bijoux.app | Maria Santos | active | YES | YES | YES | clear | approved | Online caregiver (for matching tests) |
| cg-pending@test.bijoux.app | Jake Wilson | pending | YES | NO | NO | pending | pending | Pending approval (admin approval flow) |
| cg-partial@test.bijoux.app | Aisha Patel | active | NO | NO | NO | none | none | Incomplete setup wizard |

### Accounts That Must NOT Exist (for signup testing)

| Email | Purpose |
|-------|---------|
| parent-new@test.bijoux.app | Parent signup happy path |
| cg-new@test.bijoux.app | Caregiver signup happy path |

---

## Children (belonging to parent-sarah)

| First Name | Last Name | DOB | Age | Gender | Allergies | Special Needs |
|------------|-----------|-----|-----|--------|-----------|---------------|
| Lily | Mitchell | 2021-03-15 | 5 | female | Peanuts | None |
| Max | Mitchell | 2023-06-20 | 3 | male | None | None |

## Children (belonging to parent-james)

| First Name | Last Name | DOB | Age | Gender | Allergies | Special Needs |
|------------|-----------|-----|-----|--------|-----------|---------------|
| Sofia | Rivera | 2019-01-10 | 7 | female | None | None |

---

## Caregiver Profiles (detail)

### Emma Thompson (cg-emma)
- Phone: +15125551001
- Gender: female
- DOB: 1995-08-12
- Address: 456 Oak Avenue, Austin, TX 78702
- Bio: "Experienced childcare provider with 5 years of experience."
- Years Experience: 5
- First Aid: YES, CPR: YES
- Hourly Rate: 4000 cents ($40/hr)
- Max Children: 3
- Skills: ["infant_care", "toddler_care", "homework_help"]
- Preferences: stairs OK, cats OK, dogs OK, manages allergies, administers medication, reliable transport
- Emergency Contact: David Thompson, +15125552001, brother

### Maria Santos (cg-maria)
- Phone: +15125551002
- Gender: female
- DOB: 1992-04-22
- Address: 789 Elm Street, Austin, TX 78703
- Bio: "Loving caregiver with pediatric nursing background."
- Years Experience: 8
- First Aid: YES, CPR: YES
- Hourly Rate: 4500 cents ($45/hr)
- Max Children: 4
- Skills: ["infant_care", "toddler_care", "special_needs", "first_aid"]
- Preferences: stairs OK, cats OK, dogs OK, manages allergies, administers medication, reliable transport
- Emergency Contact: Rosa Santos, +15125552002, mother
- Rating: 4.8, Total Sessions: 15

### Jake Wilson (cg-pending)
- Phone: +15125551003
- Gender: male
- DOB: 1998-11-05
- Address: 321 Pine Road, Austin, TX 78704
- Bio: "Education major with babysitting experience."
- Years Experience: 2
- First Aid: NO, CPR: NO
- Hourly Rate: 3500 cents ($35/hr)
- Max Children: 2
- Skills: ["toddler_care", "homework_help"]

---

## Bookings

| ID | Parent | Type | Status | Caregiver | Address | Duration | Est. Cost | Created |
|----|--------|------|--------|-----------|---------|----------|-----------|---------|
| booking-001 | parent-sarah | request_now | completed | cg-maria | 123 Main St, Austin TX | 180 min | $177.18 | 5 days ago |
| booking-002 | parent-sarah | scheduled | confirmed | cg-emma | 123 Main St, Austin TX | 240 min | $236.24 | 2 days ago |
| booking-003 | parent-james | request_now | cancelled | — | 456 Elm St, Austin TX | 180 min | $177.18 | 3 days ago |
| booking-004 | parent-sarah | request_now | matching | — | 123 Main St, Austin TX | 180 min | $177.18 | today |

---

## Sessions

| ID | Booking | Caregiver | Status | Started | Duration | Amount | Rating |
|----|---------|-----------|--------|---------|----------|--------|--------|
| session-001 | booking-001 | cg-maria | completed | 5 days ago | 195 min | $192.43 | 5 |
| session-002 | booking-002 | cg-emma | not_started | — | — | — | — |

---

## Transactions

| ID | Booking | Type | Status | Amount | Stripe Ref |
|----|---------|------|--------|--------|------------|
| txn-001 | booking-001 | authorization | succeeded | $250.00 | pi_test_auth_001 |
| txn-002 | booking-001 | capture | succeeded | $192.43 | pi_test_cap_001 |
| txn-003 | booking-002 | authorization | succeeded | $300.00 | pi_test_auth_002 |

---

## Credit Ledger (parent-sarah)

| Type | Amount | Balance After | Reason | Issued By |
|------|--------|---------------|--------|-----------|
| credit_issued | $25.00 | $25.00 | Welcome bonus | admin@bijoux.app |

---

## Incidents

| ID | Type | Caregiver | Booking | Status | Description |
|----|------|-----------|---------|--------|-------------|
| inc-001 | location_violation | cg-maria | booking-001 | resolved | Left geofence area during session |
| inc-002 | geofence_breach | cg-maria | — | open | Detected outside service area |

---

## Market Pricing

| Market | State | Caregiver Rate | Platform Fee | Child Surcharge | Min Hours | Demand Mult. |
|--------|-------|---------------|-------------|-----------------|-----------|--------------|
| Austin | TX | $40.00/hr | 40% | $10.00/hr | 3 | 1.0 |
| Dallas | TX | $38.00/hr | 40% | $10.00/hr | 3 | 1.0 |

---

## Audit Log Entries (pre-seeded)

| Actor | Action | Resource | Details |
|-------|--------|----------|---------|
| admin@bijoux.app | user.status_updated | User (parent-sarah) | Status changed to active |
| admin@bijoux.app | credit.issued | Credit (parent-sarah) | $25.00 welcome bonus |
| admin@bijoux.app | caregiver.approved | Caregiver (cg-emma) | Approved after BG+IDV clear |
| admin@bijoux.app | incident.resolved | Incident (inc-001) | Location violation resolved |
| admin@bijoux.app | market_pricing.created | MarketPricing (Austin) | Austin market created |
