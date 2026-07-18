# Plan: Full Real Matching Flow — Multi-Simulator E2E Testing

## Context

The current test suite uses "Simulate Accept" dev buttons instead of testing the real matching engine. This is wrong. The matching engine, offer dispatch, caregiver acceptance, IOMW, arrival, session start/end — all of it is fully implemented and testable against the real backend. We need to:

1. **Remove all Simulate Accept usage** from every flow and script
2. **Create 4+ simulators** (2 parent, 2 caregiver) to test real multi-device flows
3. **Test the full real matching flow** end-to-end with multiple caregivers
4. **File Jira ticket** to remove the Simulate Accept button/endpoint from the apps and backend

## Part 1: File Jira Ticket — Remove Simulate Accept

Create a Jira ticket in BA project:
- **Title:** Remove Simulate Accept button and admin simulate endpoints
- **Description:** Remove the "⚡ Simulate Accept" dev button from the parent app matching screen. Remove `POST /matching/admin/simulate-accept`, `POST /matching/admin/simulate-iomw`, and `POST /matching/admin/simulate-arrival` endpoints from the backend. These shortcuts bypass the real matching engine and should not exist — all testing must use the real flow.
- **Type:** Task
- **Priority:** SEV-2

## Part 2: Create 4 Simulators

**Files to modify:**
- `/Users/polygentic/Documents/dev/bijoux-testing/config/simulators.sh` — Add `bijoux-parent-2` and `bijoux-care-2` simulator creation
- `/Users/polygentic/Documents/dev/bijoux-testing/config/environment.sh` — Add `PARENT_UDID_2`, `CAREGIVER_UDID_2`, `PARENT_SIM_NAME_2`, `CAREGIVER_SIM_NAME_2`

**Simulator layout:**
| Simulator | Bundle | Login As | Purpose |
|-----------|--------|----------|---------|
| bijoux-parent (existing) | bijouxParentApp | parent-sarah | Primary parent |
| bijoux-parent-2 (new) | bijouxParentApp | parent-james | Second parent |
| bijoux-care (existing) | bijouxCaregiverApp | cg-emma | Primary caregiver |
| bijoux-care-2 (new) | bijouxCaregiverApp | cg-maria | Second caregiver |

## Part 3: Update Existing Flows — Remove Simulate Accept

**Files to modify:**
- `flows/cross-app/parent-login-and-book.yaml` — Remove any reference to simulate accept. After booking, the flow should end at the "Searching" state. Real acceptance happens on the caregiver simulator.
- `flows/parent/matching-searching.yaml` — Verify it doesn't use simulate accept
- `flows/parent/quick-booking-submit.yaml` — Same check
- `scripts/cross-app-booking-lifecycle.sh` — Rewrite to use real caregiver acceptance on a second simulator instead of API simulate endpoints
- `scripts/cross-app-booking-cancel.sh` — Same
- Any other flow referencing "Simulate Accept" or the simulate endpoints

## Part 4: Write Full Real E2E Matching Flow

**New file:** `scripts/cross-app-real-matching-e2e.sh`

This is the primary test. It orchestrates 2+ simulators in parallel:

### Flow:
1. **Seed backend** — Ensure cg-emma and cg-maria are approved + online
2. **Boot all 4 simulators**
3. **Login caregivers first:**
   - Run `caregiver/login-valid.yaml` on bijoux-care (cg-emma)
   - Run caregiver login flow on bijoux-care-2 (cg-maria)
   - Both caregivers go online (tap Go Online toggle)
4. **Parent creates booking:**
   - Run `parent-login-and-book.yaml` on bijoux-parent (Sarah)
   - Flow ends at "Searching..." screen
5. **Matching engine runs** (BullMQ worker processes, sends offers to online caregivers)
6. **Caregiver receives offer:**
   - Run `caregiver/accept-offer.yaml` on bijoux-care (cg-emma) — uses `extendedWaitUntil` to wait for offer to appear
   - Emma accepts the offer
7. **Verify parent app updates:**
   - Take screenshot on bijoux-parent — should show "Caregiver Found!" with Emma's info
8. **Caregiver confirms IOMW:**
   - Tap "Confirm I'm On My Way" on bijoux-care
   - Verify en-route state
9. **Caregiver arrives:**
   - Tap "I've Arrived" on bijoux-care
   - Verify arrived state
10. **Session start — dual verification:**
    - Caregiver taps "Start Verification" → tap "Capture" (stubbed selfie) on bijoux-care
    - Parent taps verification prompt on bijoux-parent (if shown)
    - Verify session active on both devices
11. **Session in progress:**
    - Verify timer running on caregiver sim
    - Verify active session card on parent sim
12. **Session end:**
    - Caregiver taps "End Session" → "Complete Session" → "Confirm" on bijoux-care
    - Parent confirms end on bijoux-parent (if prompted)
    - Tap "Capture" for end verification selfie (stubbed)
13. **Session summary:**
    - Verify caregiver sees earnings on bijoux-care
    - Verify parent sees charges + can rate on bijoux-parent
    - Parent rates session (tap stars + submit)
14. **Verify via API:**
    - `GET /sessions/:id` — status: completed, rating set, duration correct
    - `GET /activity/earnings` — caregiver ledger has earning entry
    - `GET /admin/bookings/:id` — lifecycle: completed
    - Check transaction: authorization + capture both succeeded

### Variant flows (additional scripts):

**`scripts/cross-app-decline-then-accept.sh`:**
- 2 caregivers online (Emma + Maria)
- Parent books → matching sends offers to both
- Emma declines → Maria accepts
- Verify parent sees Maria as matched caregiver
- Continue through full session lifecycle

**`scripts/cross-app-multi-parent.sh`:**
- 2 parents (Sarah + James) each create bookings
- 2 caregivers (Emma + Maria) each accept different bookings
- Verify both sessions run independently and complete

**`scripts/cross-app-cancel-after-match.sh`:**
- Parent books → caregiver accepts → IOMW
- Parent cancels booking
- Verify cancellation fee charged (caregiver was already IOMW)
- Verify caregiver returns to dashboard

## Part 5: Create Supporting Maestro Sub-Flows

These sub-flows run on individual simulators as part of the orchestration scripts:

**New caregiver sub-flows:**
- `flows/caregiver/go-online.yaml` — Login → tap Go Online → verify online state
- `flows/caregiver/iomw.yaml` — After accepting offer → tap "Confirm I'm On My Way" → verify en-route
- `flows/caregiver/arrive.yaml` — Tap "I've Arrived" → verify arrived state
- `flows/caregiver/start-session.yaml` — Tap "Start Verification" → Capture (stubbed) → verify session active
- `flows/caregiver/complete-session.yaml` — Tap "End Session" → confirm → Capture (stubbed) → verify completed + earnings shown

**New parent sub-flows:**
- `flows/parent/verify-caregiver-found.yaml` — Wait for "Caregiver Found" → take screenshot → verify caregiver name shown
- `flows/parent/verify-session-active.yaml` — Verify active session card or timer visible
- `flows/parent/rate-session.yaml` — After session complete → tap stars → submit rating → verify confirmation

## Part 6: Update run-suite.sh and orchestrate.sh

- `scripts/run-suite.sh` — Add `--multi-sim` flag that routes flows to all 4 simulators
- `scripts/orchestrate.sh` — Add cross-app real matching flow as primary E2E validation
- Remove any reference to simulate endpoints from all scripts

## Part 7: Update Documentation

- Update `docs/uat-test-plan.md` — Add new cross-app E2E tests, mark simulate-based tests as deprecated
- Update `docs/static-analysis-coverage-gaps.md` — Copy updated version
- Update `CLAUDE.md` — Note that simulate accept is banned

## Verification

1. All 4 simulators boot and have apps installed
2. `scripts/cross-app-real-matching-e2e.sh` runs end-to-end: parent books → real caregiver accepts → IOMW → arrival → session start → session end → rating → payment capture — all green
3. `scripts/cross-app-decline-then-accept.sh` — First caregiver declines, second accepts, full session completes
4. `scripts/cross-app-multi-parent.sh` — 2 independent booking+session flows complete in parallel
5. No flow or script references "Simulate Accept" or simulate endpoints
6. Jira ticket filed for removing simulate accept from codebase
7. API verification confirms: booking completed, session completed with rating, transaction captured, caregiver earnings in ledger
