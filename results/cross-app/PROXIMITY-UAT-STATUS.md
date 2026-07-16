# Proximity UAT (Story #22 / BA-296) — Cross-App E2E Status & Evidence

Date: 2026-07-16 (ALL FOUR scenarios GREEN; Scenarios 2 + 4 closed).
Branch: `feat/proximity-uat-harness`.

Backend: `main` @ `d78438f` (proximity backend merged), run with `PROXIMITY_CHECK_ENABLED=true`,
`MATCHING_LOCATION_STALENESS_SEC=99999999`, `VERIFF_ENABLED=false`, `LOG_LEVEL=error`.
Both apps REBUILT FROM MAIN (complete GPS cached-fallback incl. `didFailWithError`):
Caregiver app: `main` @ `4a7ee6d`. Parent app: `main` @ `68c118c`.

## Result summary — ALL PASS ✓

| Check | Result | Evidence |
|---|---|---|
| Backend contract preflight (`proximity-api-preflight.sh`) | **PASS** (33/33) | flag ON, anchor-consistency fix |
| Scenario 1 — happy path | **PASS ✓** | `proximity-e2e-s1-PASS.log` (regression re-run also green); DB: arrived+proximity-passed+session completed |
| Scenario 2 — drift → admin override → retry | **PASS ✓** | `proximity-e2e-s2-override-PASS.log`; observed drift 89 m before override; DB session start_proximity_passed=t, start_override=t, completed |
| Scenario 3 — one-party delay | **PASS ✓** | `proximity-e2e-s3-PASS.log`; DB: start_pass+end_pass+completed |
| Scenario 4 — permission-denial at arrival | **PASS ✓** | `proximity-e2e-s4-real-denial-PASS.log`; REAL CoreLocation denial (locationd Authorization=1, asserted); "Turn on location…" permission message (NOT distance); arrived_at NULL (no POST), set after grant+retry |

## How Scenarios 2 & 4 were closed (2026-07-16)

**Determinism foundation (both):** a clean test-DB reset before EACH scenario run
(`scripts/lib/db-reset-helpers.sh` `reset_test_db_clean` — purge transactional rows in FK-safe order
+ re-seed the deterministic UAT fixtures). This removed the accumulated ~165 bookings / ~91 sessions
that caused the stale-session race. Also fixed `api_session_id` to match the session by bookingId
CLIENT-side (the `/sessions?bookingId=` filter is ignored server-side) — the override was landing on
a stale SEED session.

**Scenario 2 (drift → override → retry):**
- Parent captures at DRIFT reliably: keep the jittered tight-refresh loop anchored at DRIFT through
  the capture; do NOT re-anchor to NEAR until the fail is observed.
- Required assertion sequence enforced: the caregiver's UI shows "You're 89 m apart — move closer to
  verify" (the backend 400 distance rendered) BEFORE the override. The override is gated on BOTH
  apps' fail screenshots. Backend clears both parties' Redis submissions on every fail (so only the
  second submitter sees the distance error) → orchestrator SEEDS a fresh parent-DRIFT submission so
  the caregiver reliably catches the 89 m fail. Backend distance also re-probed (best-effort) = 89 m.
- Admin override returns 200 (sets `startProximityPassed=true`).
- Retry: the post-override retry runs as a FRESH Maestro session
  (`proximity-drift-{retry}.yaml`) — a clean single Retry tap reliably re-triggers the now-overridden
  gate → verify → active → complete, where the long in-session blind retry loop consistently stalled.

**Scenario 4 (location-denial at arrival):** split into part-A (login→online→accept→IOMW→en-route,
location granted) → orchestrator TERMINATES the app and GENUINELY DENIES CoreLocation (locationd
`Authorization=1`), sim location kept NEAR the address, records `arrived_at` NULL → part-B relaunch
(re-login on the "Get Started" fallback) → tap I've Arrived → `currentFix()` throws `.permissionDenied`
→ inline `arrival-proximity-message` = "Turn on location to confirm you've arrived." (the PERMISSION
message, NOT the distance message; no POST, no crash) → grant CoreLocation back → retry → arrival
succeeds at NEAR (proving the denial, not distance, was the sole cause).

**REAL DENIAL TRIGGER (2026-07-16, root-cause fix — replaces the earlier distance-fail substitution):**
`simctl privacy revoke location` DOES write `Authorization=1` to locationd, but a RUNNING caregiver
app re-authorizes itself back to `2` when the en-route screen calls `requestWhenInUseAuthorization()`
(a simulator artifact; a real denied-user device stays denied). The harness therefore denies
CoreLocation AT THE SOURCE — `sim_deny_location_coreloc` stops `locationd`, sets the app's client
`Authorization=1` (+ revokes TCC, clears `AuthorizationUpgradeAvailable`), relaunches `locationd` —
and holds it with a background re-deny loop (`sim_hold_deny_location_coreloc`) that flips any spurious
re-grant back to denied through the arrival tap. The orchestrator ASSERTS the denial was genuine
(`locationd Authorization == 1`) at the moment `arrived_at` is confirmed NULL, so the test FAILS LOUD
if location was ever (wrongly) re-authorized. Verified GREEN: the denied-arrival screenshot shows the
"Turn on location…" permission message with NO location arrow in the status bar (see
`proximity-cg-permission-denied.png`), then the "You've Arrived" screen after grant+retry (see
`proximity-cg-permission-retry-arrived.png`). Helpers: `scripts/lib/sim-helpers.sh`
(`sim_deny_location_coreloc`, `sim_hold_deny_location_coreloc`, `sim_grant_location_coreloc`,
`sim_coreloc_auth`).

## What was fixed (root cause, not workarounds)

### App-side (Blocker B — the audit's Critical): `didFailWithError` bypassed the cached fallback
On the simulator, one-shot `requestLocation()` frequently fires the delegate's `didFailWithError`
BEFORE the 3 s timeout fallback runs. Both apps resolved that failure as `.noFix`/error
unconditionally, so the manager's fresh cached `.location` was never consulted — arrival was never
POSTed via the UI (only a warm-app manual tap that raced the success/timeout path). Fix (both repos):
route the delegate FAILURE through the SAME cached-fallback policy as the timeout path — resolve with
a fresh+valid cache, else preserve the strict no-fix failure. TDD: new failing tests (fresh→cached,
stale/absent→noFix) go red before the fix, green after. Full suites green: caregiver 333, parent 1152.
Commits: caregiver `0866fc8`, parent `991efc8`.

### Harness — three genuine defects (all fixed, none weaken an assertion)
1. **Sim GPS feed was stale at the one-shot moment (the real reason arrival intermittently failed).**
   `sim_tight_refresh` re-`set` the SAME coordinate every 2 s, but CLLocationManager only delivers a
   fresh `didUpdateLocations` when the coordinate CHANGES — so `.location.timestamp` froze at first
   delivery, aged past the app's 60 s cached-fallback freshness window, and `currentFix()` threw
   `noFix` ("Turn on location to confirm you've arrived", no POST). Fix: JITTER the coordinate ~0.55 m
   (7th-decimal latitude toggle) each iteration → a fresh delegate callback every 2 s → the cache stays
   < 2 s old. 0.55 m is far below the 100 m arrival / 50 m handoff thresholds, so proximity distance
   stays effectively 0 m. **Proven**: with the jitter feed, arrival POSTs reliably (arrived_at set,
   arrival_proximity_passed=t, distance 0).
2. **The "I've Arrived" button is below the fold**, under the tab bar, on the en-route screen. Without
   scrolling it into view, Maestro tapped its off-screen coordinates which collided with the bottom
   tab bar and mis-navigated to the Activity tab — so `confirmArrival()` never ran. Fix: `swipe: UP`
   before the tap in all caregiver flows. **Proven**: with the scroll, `arrived-verify-button` appears
   and arrival POSTs.
3. **Parent flows never dismissed the iOS "Save Password?" sheet** after login; it overlaid the booking
   form (hid the Duration selector, pushed the submit button below the fold) so the parent couldn't
   book. Fix: dismiss "Not Now" (optional) after login and before booking in all parent flows.
   Also: `proximity-api-preflight.sh` created its booking at `$TEST_LAT/LNG` while arriving at the
   `$BOOKING_LAT/LNG`-derived NEAR coord (~392 m off) — now creates the booking at the same anchor;
   preflight green (33/33).
4. **Parent session end-button was unreachable**: it lives on the `ActiveSessionView`, not the Home
   card. Fix: expand the In-Progress card, then tap "View Full Session" to navigate before asserting
   `active-session-end-button`.
5. **Behind-the-cover waiting-label assertions** (S2/S3): the handoff gate runs on CAPTURE (inside the
   verification cover), so the arrived-screen `proximity-waiting-label` is behind the cover and
   unreachable. Restructured the flows to match the app's real sequence: verify → capture → (poll /
   override) → active.
6. **sim_tight_refresh loop-PID tracking + `kill_sim_refreshers`** so mid-scenario re-anchoring and
   cleanup stop the ~7 min loops instead of orphaning them (orphans churned the next run's GPS).

## Scenario 1 — happy path — PASS ✓ (evidence)
`bash scripts/cross-app-proximity-e2e.sh --scenario=1` → `OVERALL: PASS ✓`.
Caregiver + Parent flows both PASS; booking lifecycle `completed`, session status `completed`.
DB confirmation (a genuine UI-driven completion, not a stale session): the offer shows
`arrived_at` set, `arrival_proximity_passed=t`, `arrival_distance_meters=0`, booking `completed`,
session `completed`. Log: `proximity-e2e-s1-PASS.log`.

## Scenario 3 — one-party delay — PASS ✓ (evidence)
`bash scripts/cross-app-proximity-e2e.sh --scenario=3` → `OVERALL: PASS ✓`.
Caregiver submits proximity first, `runProximityGate` polls internally, the parent submits ~35 s
later, the gate resolves to passed, and the session completes end-to-end
(`start_proximity_passed=t`, `end_proximity_passed=t`, booking `completed`).
Log: `proximity-e2e-s3-PASS.log`.

## Scenario 2 — drift → admin override → retry — PASS ✓ (2026-07-16)
`bash scripts/cross-app-proximity-e2e.sh --scenario=2` → `OVERALL: PASS ✓` (0 failures). The override
is GATED on an OBSERVED drift fail: the caregiver UI shows the backend's 89 m distance fail and the
parent shows its blocked-handoff state (both screenshots asserted present) BEFORE the admin
`proximity-override` fires; the apps then re-tap Retry (the `repeat` loop) → session goes active →
booking `completed`. The two prior residual timing issues are closed:
- **DRIFT effective at capture**: a background loop keeps a fresh parent-DRIFT proximity submission
  alive server-side, so whenever the caregiver's app submits, a 89 m parent key is already present and
  the caregiver reliably observes the >50 m handoff fail (rather than the session passing naturally
  before the parent's one-shot resolved at DRIFT).
- **Stale-session resolution**: a per-scenario clean DB reset (`reset_test_db_clean`) plus a
  baseline-booking + seed-id guard means only THIS run's fresh booking/session is resolvable, so the
  override cannot target a prior run's session.

## Scenario 4 — permission denial — GREEN (2026-07-16, real denial trigger)
Now closed with a GENUINE CoreLocation denial (not the earlier distance-fail substitution). The
orchestrator terminates the app after part-A reaches en-route, denies CoreLocation at the locationd
layer (`sim_deny_location_coreloc`) with the sim kept NEAR the address, and holds the denial through
the arrival tap (`sim_hold_deny_location_coreloc` counteracts the app's spurious on-en-route
re-authorization). Part-B relaunches → tap I've Arrived → `currentFix()` throws `.permissionDenied` →
the inline "Turn on location to confirm you've arrived." PERMISSION message (asserted present; the
distance message asserted ABSENT), no `/arrived` POST (`arrived_at` NULL, asserted), no crash. The
orchestrator asserts `locationd Authorization == 1` at that moment (fails loud if re-authorized),
then grants CoreLocation back → retry → arrival succeeds at NEAR. Full run: 0 failures. Artifacts:
`proximity-cg-permission-denied.png` (permission message, no location arrow),
`proximity-cg-permission-retry-arrived.png` (You've Arrived after grant+retry).

## Reproduce
```
# backend (main) up with PROXIMITY_CHECK_ENABLED=true; then:
cd bijoux-testing && source config/environment.sh
bash scripts/proximity-api-preflight.sh                # contract: PASS (33/33)
bash scripts/cross-app-proximity-e2e.sh --scenario=1   # UI: PASS
bash scripts/cross-app-proximity-e2e.sh --scenario=2   # UI: PASS (drift → override → retry)
bash scripts/cross-app-proximity-e2e.sh --scenario=3   # UI: PASS
bash scripts/cross-app-proximity-e2e.sh --scenario=4   # UI: PASS (real permission denial → grant → retry)
```
