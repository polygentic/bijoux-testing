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

# NEAR: both parties at the booking address (0 m apart, 0 m from address)
SIM_LAT_NEAR="${TEST_LAT}"
SIM_LNG_NEAR="${TEST_LNG}"

# FAR: caregiver ~311 m north of the address (> 100 m arrival threshold)
SIM_LAT_FAR=$(python3 -c "print(round(${TEST_LAT} + 0.0028, 4))")
SIM_LNG_FAR="${TEST_LNG}"

# DRIFT: parent ~89 m north (> 50 m handoff threshold, < 100 m arrival threshold)
SIM_LAT_DRIFT_PARENT=$(python3 -c "print(round(${TEST_LAT} + 0.0008, 4))")
SIM_LNG_DRIFT_PARENT="${TEST_LNG}"

# Caregiver stays at NEAR in the DRIFT scenario (arrival passes, handoff fails)
SIM_LAT_DRIFT_CG="${TEST_LAT}"
SIM_LNG_DRIFT_CG="${TEST_LNG}"

export SIM_LAT_NEAR SIM_LNG_NEAR SIM_LAT_FAR SIM_LNG_FAR
export SIM_LAT_DRIFT_PARENT SIM_LNG_DRIFT_PARENT SIM_LAT_DRIFT_CG SIM_LNG_DRIFT_CG

# ─── Functions ────────────────────────────────────────────────────────────────

# sim_set_location <UDID> <lat> <lng>
# Sets the simulated CoreLocation position for a booted simulator.
# Device-level (not per-app); persists until changed or cleared. Safe to call
# before or after launchApp. `xcrun simctl location set` takes "<lat>,<lng>" as a
# single comma-separated argument (no space).
sim_set_location() {
  local udid="$1" lat="$2" lng="$3"
  xcrun simctl location "$udid" set "${lat},${lng}"
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
