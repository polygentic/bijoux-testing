#!/usr/bin/env bash
# Simulator location + permission helpers for the proximity UAT harness.
#
# Sourced by scripts/proximity-api-preflight.sh and scripts/cross-app-proximity-e2e.sh.
# NO `set -e` here — callers own error handling (this file is sourced, not executed).
#
# Requires config/environment.sh to have been sourced first (provides $TEST_LAT / $TEST_LNG).
#
# Coordinate sets (anchored on the booking address $TEST_LAT / $TEST_LNG):
#   NEAR   — both parties at the booking address: 0 m from address, 0 m apart.
#   FAR    — caregiver ~311 m north (TEST_LAT + 0.0028°): exceeds the 100 m arrival threshold.
#   DRIFT  — parent  ~89 m north  (TEST_LAT + 0.0008°): exceeds the 50 m handoff threshold but
#            stays below the 100 m arrival threshold; caregiver stays NEAR in this set.
#
# Threshold math: 1° latitude ≈ 111,000 m, so 0.001° ≈ 111 m.
#   0.0028° × 111,000 ≈ 311 m  (> 100 m)  → FAR fails arrival
#   0.0008° × 111,000 ≈  89 m  (50 m < 89 m < 100 m) → DRIFT passes arrival, fails handoff

# ─── Coordinate constants (derived from environment.sh, not hardcoded) ────────
#
# ANCHORED ON BOOKING_LAT/LNG (2026-07-15): the backend proximity checks compare the
# caregiver's/parent's GPS against the BOOKING's coordinate, which is the parent app's
# CLIENT-GEOCODE of "100 Congress Ave" = (30.2639922, -97.7447808), NOT the profile's stored
# TEST_LAT/LNG (391 m away). Anchoring these on TEST_LAT/LNG put every party ~391 m from the
# booking — beyond the 100 m arrival threshold — so UI arrival always FAILED proximity and
# arrived_at stayed NULL. Anchoring on BOOKING_LAT/LNG puts NEAR at 0 m from the real anchor.
# See config/environment.sh BOOKING_LAT/LNG for the full rationale.
PROX_ANCHOR_LAT="${BOOKING_LAT:-$TEST_LAT}"
PROX_ANCHOR_LNG="${BOOKING_LNG:-$TEST_LNG}"

# NEAR: both parties at the booking address (0 m apart, 0 m from address)
SIM_LAT_NEAR="${PROX_ANCHOR_LAT}"
SIM_LNG_NEAR="${PROX_ANCHOR_LNG}"

# FAR: caregiver ~311 m north of the address (> 100 m arrival threshold)
SIM_LAT_FAR=$(python3 -c "print(round(${PROX_ANCHOR_LAT} + 0.0028, 7))")
SIM_LNG_FAR="${PROX_ANCHOR_LNG}"

# DRIFT: parent ~89 m north (> 50 m handoff threshold, < 100 m arrival threshold)
SIM_LAT_DRIFT_PARENT=$(python3 -c "print(round(${PROX_ANCHOR_LAT} + 0.0008, 7))")
SIM_LNG_DRIFT_PARENT="${PROX_ANCHOR_LNG}"

# Caregiver stays at NEAR in the DRIFT scenario (arrival passes, handoff fails)
SIM_LAT_DRIFT_CG="${PROX_ANCHOR_LAT}"
SIM_LNG_DRIFT_CG="${PROX_ANCHOR_LNG}"

export PROX_ANCHOR_LAT PROX_ANCHOR_LNG
export SIM_LAT_NEAR SIM_LNG_NEAR SIM_LAT_FAR SIM_LNG_FAR
export SIM_LAT_DRIFT_PARENT SIM_LNG_DRIFT_PARENT SIM_LAT_DRIFT_CG SIM_LNG_DRIFT_CG

# ─── Functions ────────────────────────────────────────────────────────────────

# sim_set_location <UDID> <lat> <lng>
# Sets the simulated CoreLocation position for a booted simulator.
# Device-level (not per-app); persists until changed or cleared. Safe to call
# before or after launchApp. `xcrun simctl location set` takes "<lat>,<lng>" as a
# single comma-separated argument (no space).
#
# ⚠️ NOTE (2026-07-15): a single `set` provides a STATIC point that continuous
# `startUpdatingLocation()` consumers read fine, but ONE-SHOT `requestLocation()`
# (used by the caregiver app's confirmArrival → currentFix()) does NOT reliably
# receive it on the simulator, so the one-shot can fail and the arrival POST never
# fires. For any flow that hits a one-shot fix (arrival, handoff proximity-check),
# prefer sim_start_location (continuous feed). (Even the continuous feed did not fully
# resolve UI arrival on the current sim — see PROXIMITY-UAT-STATUS.md; that residual is
# an app/simulator one-shot-location issue, not a harness bug.)
sim_set_location() {
  local udid="$1" lat="$2" lng="$3"
  xcrun simctl location "$udid" set "${lat},${lng}"
}

# sim_start_location <UDID> <lat> <lng> [span_meters]
# Starts a CONTINUOUS simulated-location feed anchored at (lat,lng). Unlike `set`,
# `simctl location start` issues periodic location updates (default 1s interval),
# which is what makes the caregiver app's one-shot requestLocation()/currentFix()
# reliably deliver a fix. Uses two waypoints ~span_meters apart (default 12 m, far
# below the 100 m arrival and 50 m handoff thresholds so the device stays "at" the
# address) at a slow speed so the feed runs for minutes across the whole
# accept→IOMW→arrival→handoff window. Re-invoke to refresh (idempotent; restarts the
# scenario). Anchors on the FIRST point so proximity distance stays ~0–12 m.
sim_start_location() {
  local udid="$1" lat="$2" lng="$3" span="${4:-12}"
  # 1° latitude ≈ 111,000 m → span meters north as a decimal-degree delta.
  local lat2
  lat2=$(python3 -c "print(round(${lat} + ${span}/111000.0, 7))")
  # speed 0.1 m/s over ~span m ⇒ the interpolation runs ~span*10 s (≈120 s for 12 m),
  # emitting a fix every 1 s the entire time. Callers refresh via periodic_start_location.
  xcrun simctl location "$udid" start --speed=0.1 --interval=1 "${lat},${lng}" "${lat2},${lng}"
}

# sim_tight_refresh <UDID> <lat> <lng> [interval_s] [rounds]
# Background loop that re-issues `simctl location set` at a TIGHT interval (default 2s)
# for [rounds] iterations (default 90 ≈ 3 min). Runs detached; caller does not wait.
#
# WHY (2026-07-15, evidence-based): the cached-fallback fix
# (caregiver fix/current-fix-cached-fallback, parent fix/get-current-fix-cached-fallback)
# resolves a silent one-shot from `CLLocationManager.location` only when that cache is
# FRESH (age <= 60s). Empirically on this simulator (iOS 26.5), `simctl location set` DOES
# reach the app's CLLocationManager (proven: a matching-location report picks up a new `set`
# coord within one cadence), but the `simctl location start` continuous feed's delegate
# callbacks can lapse between the ~90s `periodic_start_location` restarts, leaving the
# manager's `.location.timestamp` stale enough for the fallback's 60s window to reject it —
# so `confirmArrival()`/handoff `currentFix()` throws `noFix` and never POSTs `/arrived`.
#
# CRITICAL (proven 2026-07-16): re-`set`ting the SAME coordinate does NOT deliver a fresh
# `didUpdateLocations` to the app — CLLocationManager only fires the delegate when the
# coordinate CHANGES. So a fixed-coord `set` loop leaves `.location.timestamp` frozen at the
# first delivery; it ages past the fallback's 60s freshness window and `currentFix()` throws
# `noFix` (the app shows "Turn on location to confirm you've arrived." and never POSTs). This
# is exactly why UI arrival intermittently failed while a manual warm-app tap sometimes
# succeeded (it raced the delegate before the timestamp went stale).
#
# FIX: JITTER the coordinate by ~0.5 m (toggle the 7th decimal of latitude, ≈0.55 m) every
# iteration. Each change forces a fresh `didUpdateLocations`, keeping `.location.timestamp`
# continuously < ~2 s old so the one-shot's cached fallback always accepts it. 0.5 m is orders
# of magnitude below the 100 m arrival / 50 m handoff thresholds, so proximity distance stays
# effectively 0 m — this does NOT weaken any assertion, it only keeps the injected GPS *fresh*,
# which a real device at the address (with normal GPS noise) inherently is.
sim_tight_refresh() {
  # rounds default 210 × 2s ≈ 7 min — comfortably covers the whole
  # login→online→offer→accept→IOMW→arrival→handoff→session window of one scenario.
  local udid="$1" lat="$2" lng="$3" interval="${4:-2}" rounds="${5:-210}"
  # Two anchor points ~0.55 m apart (7th-decimal latitude toggle). Alternating between them
  # each iteration guarantees a coordinate CHANGE → a fresh delegate callback → fresh timestamp.
  local lat_a lat_b
  lat_a=$(python3 -c "print(round(${lat} + 0.0000025, 7))")
  lat_b=$(python3 -c "print(round(${lat} - 0.0000025, 7))")
  (
    local i=0
    while [[ $i -lt $rounds ]]; do
      if (( i % 2 == 0 )); then
        xcrun simctl location "$udid" set "${lat_a},${lng}" 2>/dev/null || true
      else
        xcrun simctl location "$udid" set "${lat_b},${lng}" 2>/dev/null || true
      fi
      sleep "$interval"
      i=$((i + 1))
    done
  ) &
  # Track the loop PID so kill_sim_refreshers can stop it (e.g. when re-anchoring
  # sims mid-scenario, or on cleanup). Without this the ~7 min loops orphan and
  # churn the sim location across runs.
  SIM_REFRESH_PIDS+=("$!")
}

# PIDs of the background sim_tight_refresh loops, so they can be stopped.
SIM_REFRESH_PIDS=()

# kill_sim_refreshers
# Stops all background sim_tight_refresh loops started this process. Call before
# re-anchoring the sims to a new coordinate (so the old loop doesn't fight the new
# one) and at scenario end (so loops don't orphan and churn the next run's GPS).
kill_sim_refreshers() {
  local pid
  for pid in "${SIM_REFRESH_PIDS[@]}"; do
    [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
  done
  SIM_REFRESH_PIDS=()
}

# sim_grant_location <UDID> <bundleId>
# Pre-grants location TCC permission so no OS dialog appears.
# MUST be called AFTER launchApp — `clearState: true` in Maestro resets TCC on
# every launch, so the grant must land after the app process has registered its
# bundle with TCC (callers sleep ~8s after starting the Maestro process first).
sim_grant_location() {
  local udid="$1" bundle_id="$2"
  xcrun simctl privacy "$udid" grant location "$bundle_id"
}

# sim_clear_location <UDID>
# Clears the simulated location override (returns to device default).
# No-op if the simulator is not booted.
sim_clear_location() {
  local udid="$1"
  xcrun simctl location "$udid" clear
}
