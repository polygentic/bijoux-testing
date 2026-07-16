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

# ─── REAL CoreLocation authorization control (locationd-backed) ────────────────
#
# WHY THIS EXISTS (2026-07-16, evidence-based root-cause fix):
# `simctl privacy revoke/reset location` does NOT flip CLLocationManager.authorizationStatus on
# this simulator (iOS 26.x) — CoreLocation authorization is owned by the `locationd` daemon's
# `clients.plist`, NOT by the TCC.db that `simctl privacy` writes. (Verified: after a
# `simctl privacy revoke location`, the caregiver's locationd client stays Authorization=2 and NO
# denial takes effect — the app's `currentFix()` still succeeds.) So to exercise the REAL
# permission-denied branch (`CoreLocationService.currentFix()` throws `LocationFixError.permissionDenied`
# → the app shows "Turn on location to confirm you've arrived." and never POSTs /arrived), we edit
# locationd's own authorization record directly.
#
# locationd `Authorization` integer semantics (kCLClientAuthorization):
#   0 = not-determined   1 = DENIED   2 = AUTHORIZED (when-in-use / always)
# Setting it to 1 makes `CLLocationManager.authorizationStatus` == .denied → the guard at
# CoreLocationService.currentFix() (status must be .authorizedWhenInUse/.authorizedAlways) fails and
# it throws .permissionDenied. Setting it back to 2 (or 0) restores/prompts.
#
# MECHANICS: locationd rewrites clients.plist on shutdown, so we MUST stop locationd FIRST, edit the
# plist while it is down, and let launchd auto-relaunch it (it re-reads the edited plist on start and
# pushes the new authorization to clients). The app observes the change on its next cold launch
# (authorizationStatus is read fresh from locationd) — which is exactly the S4 relaunch path.
#
# NOTE: the injected value is verified after the edit (sim_coreloc_auth), so the harness FAILS LOUD
# if a future OS changes the plist format rather than silently falling back to a distance fail.

# _locationd_clients_plist <UDID>  → prints the path to the sim's locationd clients.plist
_locationd_clients_plist() {
  local udid="$1"
  echo "$HOME/Library/Developer/CoreSimulator/Devices/$udid/data/Library/Caches/locationd/clients.plist"
}

# _locationd_client_key <UDID> <bundleId>  → prints the locationd client KEY for the bundle.
# locationd registers clients under a key like `ipolygentic.bijouxCaregiverApp:` (leading tag +
# trailing colon), NOT the bare bundle id — so we DISCOVER it from the plist rather than hardcode it
# (survives reinstalls / format changes). Matches the <key>…<bundleId>…</key> entry.
_locationd_client_key() {
  local udid="$1" bundle_id="$2"
  local plist; plist="$(_locationd_clients_plist "$udid")"
  [[ -f "$plist" ]] || return 1
  # Escape regex metacharacters in the bundle id (dots) for a literal match.
  local esc; esc="$(printf '%s' "$bundle_id" | sed 's/[.[\*^$]/\\&/g')"
  plutil -convert xml1 -o - "$plist" 2>/dev/null \
    | grep -oE "<key>[^<]*${esc}[^<]*</key>" \
    | sed -e 's/^<key>//' -e 's/<\/key>$//' \
    | head -1
}

# sim_coreloc_auth <UDID> <bundleId>  → prints the current locationd Authorization integer
# (0=not-determined, 1=denied, 2=authorized), or empty if the client isn't registered yet.
sim_coreloc_auth() {
  local udid="$1" bundle_id="$2"
  local plist key; plist="$(_locationd_clients_plist "$udid")"
  key="$(_locationd_client_key "$udid" "$bundle_id")" || return 0
  [[ -z "$key" ]] && return 0
  # PlistBuddy uses ':' as a path separator; the key itself ENDS in a colon, so escape it as '\:'.
  local escaped_key="${key//:/\\:}"
  /usr/libexec/PlistBuddy -c "Print :${escaped_key}:Authorization" "$plist" 2>/dev/null
}

# _sim_set_coreloc_auth <UDID> <bundleId> <value>  (internal)
# Stops locationd, sets the client's Authorization to <value>, lets launchd relaunch locationd.
# Returns 0 on success; returns 1 if the client/plist is missing.
#
# When DENYING (value=1) we ALSO (a) revoke the TCC grant and (b) clear AuthorizationUpgradeAvailable
# so the app's on-en-route requestWhenInUseAuthorization() has nothing to upgrade FROM — on this
# simulator a running app can otherwise silently re-authorize itself back to 2 (a simulator artifact;
# a real denied-user device would stay denied). The periodic re-deny loop (sim_hold_deny_location_coreloc)
# is the final backstop against that spurious re-grant.
_sim_set_coreloc_auth() {
  local udid="$1" bundle_id="$2" value="$3"
  local plist key; plist="$(_locationd_clients_plist "$udid")"
  [[ -f "$plist" ]] || { echo "  (coreloc) no locationd clients.plist for $udid" >&2; return 1; }
  key="$(_locationd_client_key "$udid" "$bundle_id")"
  [[ -z "$key" ]] && { echo "  (coreloc) $bundle_id not yet registered with locationd on $udid" >&2; return 1; }
  local escaped_key="${key//:/\\:}"
  # For a denial, also revoke the TCC grant first so locationd can't reconcile back to authorized.
  if [[ "$value" == "1" ]]; then
    xcrun simctl privacy "$udid" revoke location "$bundle_id" >/dev/null 2>&1 || true
  fi
  # Stop locationd FIRST so it can't overwrite our edit on exit; launchd auto-relaunches it.
  xcrun simctl spawn "$udid" launchctl kill KILL system/com.apple.locationd >/dev/null 2>&1 || \
    xcrun simctl spawn "$udid" launchctl stop com.apple.locationd >/dev/null 2>&1 || true
  sleep 2
  /usr/libexec/PlistBuddy -c "Set :${escaped_key}:Authorization ${value}" "$plist" >/dev/null 2>&1
  if [[ "$value" == "1" ]]; then
    /usr/libexec/PlistBuddy -c "Set :${escaped_key}:AuthorizationUpgradeAvailable false" "$plist" >/dev/null 2>&1 || true
  fi
  # Let launchd relaunch locationd and re-read the edited plist.
  sleep 3
}

# _sim_redeny_fast <UDID> <bundleId>  (internal, used by the hold loop)
# A lighter re-deny for the tight loop: revoke TCC + restart locationd + set Authorization=1. Same
# effect as _sim_set_coreloc_auth 1 but without the extra verify read (the loop caller verifies).
_sim_redeny_fast() {
  local udid="$1" bundle_id="$2"
  local plist key; plist="$(_locationd_clients_plist "$udid")"
  key="$(_locationd_client_key "$udid" "$bundle_id")"
  [[ -z "$key" ]] && return 0
  local escaped_key="${key//:/\\:}"
  xcrun simctl privacy "$udid" revoke location "$bundle_id" >/dev/null 2>&1 || true
  xcrun simctl spawn "$udid" launchctl kill KILL system/com.apple.locationd >/dev/null 2>&1 || true
  sleep 1
  /usr/libexec/PlistBuddy -c "Set :${escaped_key}:Authorization 1" "$plist" >/dev/null 2>&1
  /usr/libexec/PlistBuddy -c "Set :${escaped_key}:AuthorizationUpgradeAvailable false" "$plist" >/dev/null 2>&1 || true
}

# PIDs of the background re-deny loops so they can be stopped.
CORELOC_DENY_PIDS=()

# sim_hold_deny_location_coreloc <UDID> <bundleId> [rounds] [interval_s]
# Continuously RE-ASSERTS CoreLocation denial in the background (default ~30 rounds × 4 s ≈ 2 min).
# The caregiver app, on the en-route screen, calls requestWhenInUseAuthorization() which on this
# simulator can spuriously re-authorize the app (Authorization flips 1→2). This loop keeps flipping
# it back to 1 so the app is DENIED at the arrival tap — the state a real denied-user device is in.
# Runs detached; caller stops it via kill_coreloc_deny before the grant-back.
sim_hold_deny_location_coreloc() {
  local udid="$1" bundle_id="$2" rounds="${3:-30}" interval="${4:-4}"
  (
    local i=0
    while [[ $i -lt $rounds ]]; do
      # Only re-deny if the app has flipped it back to authorized (avoids needless locationd churn).
      local cur; cur="$(sim_coreloc_auth "$udid" "$bundle_id")"
      if [[ "$cur" != "1" ]]; then
        _sim_redeny_fast "$udid" "$bundle_id"
      fi
      sleep "$interval"
      i=$((i + 1))
    done
  ) &
  CORELOC_DENY_PIDS+=("$!")
}

# kill_coreloc_deny  — stop all background re-deny loops started this process.
kill_coreloc_deny() {
  local pid
  for pid in "${CORELOC_DENY_PIDS[@]}"; do
    [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
  done
  CORELOC_DENY_PIDS=()
}

# sim_deny_location_coreloc <UDID> <bundleId>
# GENUINELY denies CoreLocation for the app (authorizationStatus → .denied). See block comment above.
# The app must be relaunched (cold) to observe .denied — callers relaunch via the part-B Maestro flow.
sim_deny_location_coreloc() {
  local udid="$1" bundle_id="$2"
  _sim_set_coreloc_auth "$udid" "$bundle_id" 1 || return 1
  local got; got="$(sim_coreloc_auth "$udid" "$bundle_id")"
  if [[ "$got" == "1" ]]; then
    echo "  (coreloc) DENIED CoreLocation for $bundle_id on $udid (locationd Authorization=1)"
    return 0
  fi
  echo "  (coreloc) FAILED to deny: locationd Authorization is '${got:-<missing>}', expected 1" >&2
  return 1
}

# sim_grant_location_coreloc <UDID> <bundleId>
# Restores CoreLocation authorization (authorizationStatus → .authorizedWhenInUse). Pairs with
# sim_deny_location_coreloc for the S4 grant-back-and-retry step. Also re-runs `simctl privacy grant`
# (harmless; keeps TCC coherent for any other consumer).
sim_grant_location_coreloc() {
  local udid="$1" bundle_id="$2"
  # Re-enable upgrade + grant TCC first so the restore is clean (deny had disabled both).
  local plist key; plist="$(_locationd_clients_plist "$udid")"
  key="$(_locationd_client_key "$udid" "$bundle_id")"
  xcrun simctl privacy "$udid" grant location "$bundle_id" >/dev/null 2>&1 || true
  _sim_set_coreloc_auth "$udid" "$bundle_id" 2 || return 1
  if [[ -n "$key" ]]; then
    local escaped_key="${key//:/\\:}"
    /usr/libexec/PlistBuddy -c "Set :${escaped_key}:AuthorizationUpgradeAvailable false" "$plist" >/dev/null 2>&1 || true
  fi
  xcrun simctl privacy "$udid" grant location "$bundle_id" >/dev/null 2>&1 || true
  local got; got="$(sim_coreloc_auth "$udid" "$bundle_id")"
  if [[ "$got" == "2" ]]; then
    echo "  (coreloc) RESTORED CoreLocation for $bundle_id on $udid (locationd Authorization=2)"
    return 0
  fi
  echo "  (coreloc) FAILED to restore: locationd Authorization is '${got:-<missing>}', expected 2" >&2
  return 1
}

# proximity_drift_distance <sessionId> <phase>
# Reads BOTH parties' submitted proximity GPS from Redis (the same keys the backend's
# submitProximityCheck writes: `proximity:<sessionId>:<phase>:<role>`, 5-min TTL) and prints
# the party-to-party haversine distance in whole meters — the SAME value the backend returns in
# its 400 `proximityFailed` response. Prints nothing (empty) until BOTH parties have submitted.
#
# WHY (2026-07-16): the DRIFT handoff FAIL is transient — the backend returns a 400 with
# distanceMeters but does NOT persist a "failed" flag (start_proximity_passed stays NULL; a
# distance is written only on PASS). So the orchestrator cannot poll the DB to confirm the drift
# registered. Reading the two Redis submissions and recomputing the distance is functionally
# identical to the backend's own computation, and lets Scenario 2 GATE the admin override on an
# OBSERVED ~89 m drift (both parties submitted, > 50 m handoff threshold) rather than firing the
# override on a bare timer before the parent's one-shot even resolved at DRIFT (the prior
# "passed naturally" flake). Requires docker `bijoux-redis` up.
proximity_drift_distance() {
  local session_id="$1" phase="${2:-start}"
  local cg_raw parent_raw
  cg_raw=$(docker exec bijoux-redis redis-cli --no-raw GET "proximity:${session_id}:${phase}:caregiver" 2>/dev/null)
  parent_raw=$(docker exec bijoux-redis redis-cli --no-raw GET "proximity:${session_id}:${phase}:parent" 2>/dev/null)
  # redis-cli --no-raw wraps strings in quotes and escapes inner quotes; strip to plain JSON.
  cg_raw=$(printf '%s' "$cg_raw" | sed -e 's/^"//' -e 's/"$//' -e 's/\\"/"/g')
  parent_raw=$(printf '%s' "$parent_raw" | sed -e 's/^"//' -e 's/"$//' -e 's/\\"/"/g')
  [[ -z "$cg_raw" || "$cg_raw" == "nil" || -z "$parent_raw" || "$parent_raw" == "nil" ]] && return 0
  python3 -c "
import json, math, sys
try:
    cg = json.loads('''$cg_raw''')
    p  = json.loads('''$parent_raw''')
except Exception:
    sys.exit(0)
R = 6371000.0
la1, lo1 = math.radians(cg['latitude']), math.radians(cg['longitude'])
la2, lo2 = math.radians(p['latitude']),  math.radians(p['longitude'])
dla, dlo = la2 - la1, lo2 - lo1
a = math.sin(dla/2)**2 + math.cos(la1)*math.cos(la2)*math.sin(dlo/2)**2
print(round(R * 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))))
" 2>/dev/null
}
