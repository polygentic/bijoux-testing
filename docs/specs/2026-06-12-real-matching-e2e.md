# Spec: Real Multi-Simulator E2E Matching Flow

**Date:** 2026-06-12
**Status:** DONE — implemented on feat/real-matching-e2e (BA-273)

---

## Problem

The UAT test suite uses a "Simulate Accept" dev button (`POST /matching/admin/simulate-accept`) to bypass the real matching engine. This means the core business flow — the matching algorithm, offer dispatch to multiple caregivers, caregiver offer receipt, acceptance, IOMW, arrival, session start/end, and payment capture — has **never been tested end-to-end against real devices**. The simulate endpoints and button must be removed from the codebase entirely.

## Solution

1. Create 4 iOS simulators (2 parent, 2 caregiver) and write orchestration scripts that test the **real** matching flow across multiple devices simultaneously.
2. Remove all references to "Simulate Accept" from every test flow, script, and documentation.
3. File a Jira ticket to remove the simulate accept button and endpoints from the app and backend codebases.

## Done When (Acceptance Criteria)

### AC-1: Simulator Infrastructure
- [ ] 4 simulators exist and boot: `bijoux-parent`, `bijoux-parent-2`, `bijoux-care`, `bijoux-care-2`
- [ ] `config/environment.sh` exports `PARENT_UDID`, `PARENT_UDID_2`, `CAREGIVER_UDID`, `CAREGIVER_UDID_2`
- [ ] `config/simulators.sh create` creates all 4; `boot` boots all 4; `shutdown` shuts down all 4
- [ ] Both iOS apps are installable on all 4 simulators

### AC-2: Full Booking→Matching→Session→Payment E2E (Happy Path)
- [ ] Script `scripts/cross-app-real-matching-e2e.sh` executes the following sequence without using any simulate endpoints:
  1. Caregiver (cg-emma or cg-maria) logged in and online on caregiver sim
  2. Parent (parent-sarah) creates a booking on parent sim
  3. Matching engine (BullMQ worker) processes and dispatches offers to online caregivers
  4. Caregiver app on caregiver sim receives offer (via polling — `extendedWaitUntil` in Maestro sub-flow)
  5. Caregiver accepts offer on caregiver sim
  6. Parent sim shows "Caregiver Found!" with correct caregiver name
  7. Caregiver taps "Confirm I'm On My Way" on caregiver sim
  8. Caregiver taps "I've Arrived" on caregiver sim
  9. Both parties complete session start verification (tap "Capture" for stubbed selfie)
  10. Session is active — timer visible on caregiver sim
  11. Caregiver ends session on caregiver sim (End Session → confirm → Capture for stubbed selfie)
  12. Parent rates session on parent sim (tap stars → submit)
  13. API verification confirms: booking lifecycle=completed, session status=completed, rating stored, transaction captured, caregiver earnings in ledger
- [ ] The script exits 0 on success, non-zero on failure
- [ ] Screenshots captured at each phase in `results/cross-app/`

### AC-3: Multi-Caregiver Decline→Accept Flow
- [ ] Script `scripts/cross-app-decline-then-accept.sh` tests:
  1. Two caregivers logged in and online (cg-emma on bijoux-care, cg-maria on bijoux-care-2)
  2. Parent creates booking
  3. Both caregivers receive offers
  4. First caregiver (Emma) declines
  5. Second caregiver (Maria) accepts
  6. Parent sees Maria as matched caregiver (not Emma)
  7. Session completes through to end
- [ ] API verification confirms: Emma's offer status=declined, Maria's offer status=accepted

### AC-4: Multi-Parent Concurrent Bookings
- [ ] Script `scripts/cross-app-multi-parent.sh` tests:
  1. Two caregivers online (Emma, Maria)
  2. Parent Sarah creates booking on bijoux-parent → matched to one caregiver
  3. Parent James creates booking on bijoux-parent-2 → matched to the other caregiver
  4. Both sessions run to completion independently
- [ ] API verification confirms: 2 separate completed bookings, 2 separate completed sessions, 2 separate captured transactions

### AC-5: Cancellation After Match (Fee Verification)
- [ ] Script `scripts/cross-app-cancel-after-match.sh` tests:
  1. Caregiver accepts offer and taps IOMW
  2. Parent cancels booking after IOMW
  3. Booking lifecycle → cancelled
  4. Cancellation fee charged (caregiver was already IOMW)
  5. Caregiver returns to dashboard/idle state
- [ ] API verification confirms: booking cancelled, cancellation fee transaction exists

### AC-6: Earnings & Payment Verification
- [ ] After any completed session, the script verifies via API:
  - `GET /activity/earnings` returns correct caregiver earnings total
  - `GET /activity/earnings/ledger` shows an `earning` entry matching the session
  - Earnings amount matches formula: `(caregiverRateCents + additionalChildren × childSurchargeCents) × demandMultiplier × (billableMinutes / 60)`
  - Transaction table has both `authorization` (at booking) and `capture` (at session end) with status=succeeded
  - Parent's payment method was charged the correct total (base + platform fee + surcharges)

### AC-7: Simulate Accept Removal
- [ ] Zero references to "Simulate Accept", "simulate-accept", "simulate_accept", "simulate-iomw", "simulate-arrival" in any file under `bijoux-testing/`
- [ ] Jira ticket created in BA project for removing simulate endpoints from backend and simulate button from parent app

### AC-8: All Existing Tests Still Pass
- [ ] All 38 Maestro flows still pass (none relied on simulate accept for their core assertions)
- [ ] `scripts/run-suite.sh` completes with same or better pass rate as before

## Out of Scope

- **Removing simulate endpoints from backend/app code** — that's a separate ticket for the app developers. We file the ticket, we don't make the code change.
- **Credit application during payment** — known backend gap (credit_applied never written). Tracked separately as BA-272.
- **Push notification testing** — FCM doesn't work on simulators. All flows use polling/waitUntil.
- **Real Veriff/Checkr integration** — these are stubbed. We tap "Capture" to bypass.
- **Stripe real charges** — bypass mode in test env. We verify transaction records, not actual Stripe API calls.
- **Writing new Maestro flows for every coverage gap** from the static analysis — this spec focuses on the multi-sim E2E matching flow. Other gaps are separate work.

## Dependencies

- Backend running with UAT seed data (cg-emma, cg-maria approved and seeded)
- Both iOS apps built and installed on all 4 simulators
- Maestro MCP tools available (or Maestro CLI with Java)
- Redis running (BullMQ matching worker needs it)

## Risks

| Risk | Mitigation |
|------|-----------|
| Matching worker may be slow to dispatch offers | Use generous timeouts in `extendedWaitUntil` (60-90s). Add API polling fallback. |
| Caregiver app may not show offers without push notifications | App polls `GET /matching/offers/pending` on interval. Verify polling is enabled in dev/test builds. |
| Running 4 simulators simultaneously may be resource-heavy | Test on current machine. If too slow, fall back to 2 sims and run scenarios sequentially. |
| Sub-flow selectors may be wrong (never tested against real flow) | Inspect each screen with `mcp__maestro__inspect_screen` before writing flows. Fix selectors as discovered. |
| Session dual-verification may block (both parties must verify) | Map exact UI on both devices. Handle with ordered sub-flow execution + waits. |
