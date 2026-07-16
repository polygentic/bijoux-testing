# Spec: Proximity UAT Harness

**Date:** 2026-07-03
**Status:** Implemented on `feat/proximity-uat-harness` (BA-296). API pre-flight GREEN;
two-simulator UI scenarios blocked pending parent-app #20 (see "Known Blockers").
**Backend spec:** `bijoux-backend/docs/specs/2026-07-02-proximity-app-changes-spec.md` §7
**Plan:** `docs/superpowers/plans/2026-07-03-plan-22-bijoux-testing-proximity-uat.md`
**Jira:** BA-296 (story); UAT subtasks BA-299 (happy-path), BA-300 (drift→override),
BA-301 (one-party-delay), BA-302 (permission-denial)

---

## Problem

The Proximity Verification feature (#18 caregiver GPS arrival + silent handoff gate,
#20 parent handoff gate, #21 admin override UI) has no E2E test harness. Before the
`PROXIMITY_CHECK_ENABLED` flag can be flipped ON in staging, we need:

1. Simulator location + permission helpers (`xcrun simctl location` / `privacy`).
2. Runnable-today API contract verification (no simulator) — because with the flag ON the
   backend rejects every arrival and every session start/end with a 400 unless the clients
   ship validated GPS delivery.
3. A cross-app Maestro journey covering the four UAT scenarios on two iOS simulators.

## Solution

See the plan. Three deliverables in `bijoux-testing`:

1. `scripts/lib/sim-helpers.sh` — `sim_set_location` / `sim_grant_location` /
   `sim_clear_location` + NEAR / FAR / DRIFT coordinate constants derived from
   `$TEST_LAT`/`$TEST_LNG`.
2. `scripts/proximity-api-preflight.sh` — curl-based contract verification for all backend
   proximity endpoint shapes + admin overrides, flag ON, no simulator.
3. `scripts/cross-app-proximity-e2e.sh` + 7 Maestro YAML flows — four UAT scenarios on two
   simulators (`bijoux-parent` + `bijoux-care`).

## Done When (Acceptance Criteria)

### AC-1: sim-helpers.sh
- [x] `scripts/lib/sim-helpers.sh` exists, is sourced by `cross-app-proximity-e2e.sh` +
      `proximity-api-preflight.sh`.
- [x] `sim_set_location <UDID> <lat> <lng>` wraps `xcrun simctl location <UDID> set "<lat>,<lng>"`.
- [x] `sim_grant_location <UDID> <bundleId>` wraps `xcrun simctl privacy <UDID> grant location <bundleId>`.
- [x] NEAR / FAR / DRIFT coordinate constants exported and documented; derived from `$TEST_LAT`.
- [x] Coordinates land on the correct side of each threshold: NEAR 0 m, FAR ~311 m (> 100 m
      arrival), DRIFT ~89 m (50 m < 89 m < 100 m — passes arrival, fails handoff).

### AC-2: proximity-api-preflight.sh — **GREEN**
- [x] Script exists and is executable; runs against a backend with `PROXIMITY_CHECK_ENABLED=true`
      using only curl + python3 (no simulator).
- [x] TEST 1: Arrival PASS — POST `/arrived` NEAR → 200, `arrivedAt` present.
- [x] TEST 2: Arrival FAIL — POST `/arrived` FAR → 400, `status=failed`, `thresholdMeters=100`.
- [x] TEST 3: Handoff start PASS — CG first → 200 `waiting`; parent → 200 `passed`; CG re-POST →
      200 `passed` (idempotency); then `verify/start` → 200.
- [x] TEST 4: Handoff FAIL — CG NEAR first → 200 `waiting`; parent DRIFT → 400 `failed`,
      `thresholdMeters=50`; `verify/start` blocked → 400. (Poster order matters: a lone parent
      DRIFT POST returns 200 `waiting`, not 400.)
- [x] TEST 5: Admin arrival override → 200 `{overridden:true}`; 403 non-admin; **422** for missing
      reason (backend VALIDATION_ERROR contract — the plan anticipated 400).
- [x] TEST 6: Admin session proximity override → 200 `{overridden:true}`; `verify/start` succeeds
      after override; 403 non-admin.
- [x] TEST 7: Flag-OFF regression note (skips on `SKIP_FLAG_OFF_TEST=true`).
- [x] Exits 0 on all pass; `OVERALL: PASS` verified across repeat runs.

### AC-3: Maestro Flows
- [x] 7 YAML files: caregiver (happy-path, drift-override, one-party-delay, permission-denial);
      parent (happy-path, drift-override, one-party-delay) — no parent permission-denial.
- [x] All use `clearState: true` + `clearKeychain: true`; include `tapOn: Allow While Using App,
      optional: true`. Flows do not call simctl — that is the orchestrator's job.
- [x] Accessibility ids match the shipped caregiver app (`proximity-waiting-label`,
      `arrived-verify-button`, `verification-capture-button`, `in-progress-end-button`).
- [x] All 7 validate under maestro and parse via `yaml.safe_load_all` (Maestro files are
      two-document YAML: a config doc, `---`, then the steps list; `yaml.safe_load` — used in the
      plan's AC-3 command — fails on ALL Maestro flows including the existing ones, so
      `safe_load_all` is the correct validator).

### AC-4: cross-app-proximity-e2e.sh
- [x] Script exists, is executable, sources sim-helpers.sh; `bash -n` clean.
- [x] `--scenario=1|2|3|4` / `--all` dispatch; background Maestro processes with `wait $PID`;
      admin override API called mid-run for scenario 2; per-scenario logs + screenshots under
      `results/cross-app/`.
- [ ] `--scenario=1` exits 0 with booking `completed` — **BLOCKED** (see Known Blockers): the
      two-party UI handoff cannot resolve because parent app #20 is unmerged.

### AC-5: UAT Plan + Spec
- [x] `docs/uat-test-plan.md` has the UAT-20 block (5 rows) + UAT-19.8/19.9.
- [x] This spec file exists.

## Known Blockers (2026-07-15)

**Parent app #20 (proximity changes) is NOT merged on `bijoux-ios` main.** `grep -r proximity`
over `bijouxParentApp/**/*.swift` returns zero matches — no `proximity-check` submission, no
`parent-proximity-waiting-label`, no proximity UI. The parent app calls `verify/start` directly.

Consequence with the flag ON: the two-party start-handoff gate needs BOTH parties to POST
`/sessions/:id/proximity-check`. The caregiver submits and gets `waiting`; the parent never
submits, so the gate never resolves to `passed`, and the backend blocks the parent's
`verify/start` (`BadRequestError('Proximity check required before verification')`). The session
cannot start through the UI, so scenarios 1–4 cannot reach `completed` end-to-end.

Separately, the caregiver arrival step does not complete on the simulator: `confirmArrival`
(`HomeViewModel.swift`) requires a live GPS fix from `env.location.currentFix()`, which does not
materialise reliably on the sim at tap time (TCC permission/fix timing race), so `POST /arrived`
is not sent (`arrived_at` stays NULL) and `arrived-verify-button` never appears.

**The backend contract itself is correct** — the API pre-flight (which simulates both parties via
curl) is GREEN. Flip `PROXIMITY_CHECK_ENABLED` ON in staging only after parent app #20 lands.

## Out of Scope
- Admin console proximity override UI (#21) — depends on #25 (backend detail fields).
- End-phase proximity (`phase: "end"`) UI coverage — the flows cover start-phase handoff; the
  pre-flight covers `phase: "start"` override in TEST 6.
- Stripe / Checkr / Veriff real integrations (stubbed in test env).
- Performance benchmarking of the 3 s poll loop; push-notification delivery (no FCM on sims).

## Dependencies
- Backend `main` with proximity enforcement + `PROXIMITY_CHECK_ENABLED=true` for flag-ON tests.
- Caregiver app #18 (present) and parent app #20 (**NOT present**) built + installed on the sims.
- Redis running (proximity TTL). Permissive `MATCHING_LOCATION_STALENESS_SEC` so the matching
  pool is not emptied by the #26 freshness filter (which this UAT does not test).
