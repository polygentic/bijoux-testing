#!/usr/bin/env bash
# Bijoux Testing — Simulator Management
# Usage: ./config/simulators.sh [create|boot|shutdown|delete]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/environment.sh"

# Auto-detect latest iOS runtime
get_latest_runtime() {
    xcrun simctl list runtimes -j \
        | python3 -c "
import sys, json
data = json.load(sys.stdin)
ios_runtimes = [r for r in data.get('runtimes', []) if r['name'].startswith('iOS') and r['isAvailable']]
if ios_runtimes:
    # Sort by version descending
    ios_runtimes.sort(key=lambda r: r['version'], reverse=True)
    print(ios_runtimes[0]['identifier'])
else:
    print('NONE', file=sys.stderr)
    sys.exit(1)
"
}

# Auto-detect best iPhone device type
get_device_type() {
    xcrun simctl list devicetypes -j \
        | python3 -c "
import sys, json
data = json.load(sys.stdin)
# Prefer iPhone 16 Pro, fall back to newest iPhone
preferred = ['iPhone-16-Pro', 'iPhone-16', 'iPhone-15-Pro', 'iPhone-15']
for pref in preferred:
    for dt in data.get('devicetypes', []):
        if pref in dt['identifier']:
            print(dt['identifier'])
            sys.exit(0)
# Fallback: last iPhone in list
for dt in reversed(data.get('devicetypes', [])):
    if 'iPhone' in dt['identifier']:
        print(dt['identifier'])
        sys.exit(0)
print('NONE', file=sys.stderr)
sys.exit(1)
"
}

create_simulators() {
    local runtime device_type
    runtime=$(get_latest_runtime)
    device_type=$(get_device_type)
    echo "Using runtime: $runtime"
    echo "Using device type: $device_type"

    # Create parent simulator
    if xcrun simctl list devices -j | python3 -c "
import sys, json
data = json.load(sys.stdin)
for devices in data['devices'].values():
    for d in devices:
        if d['name'] == '$PARENT_SIM_NAME':
            sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
        echo "Simulator '$PARENT_SIM_NAME' already exists"
    else
        local parent_udid
        parent_udid=$(xcrun simctl create "$PARENT_SIM_NAME" "$device_type" "$runtime")
        echo "Created '$PARENT_SIM_NAME': $parent_udid"
    fi

    # Create caregiver simulator
    if xcrun simctl list devices -j | python3 -c "
import sys, json
data = json.load(sys.stdin)
for devices in data['devices'].values():
    for d in devices:
        if d['name'] == '$CAREGIVER_SIM_NAME':
            sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
        echo "Simulator '$CAREGIVER_SIM_NAME' already exists"
    else
        local care_udid
        care_udid=$(xcrun simctl create "$CAREGIVER_SIM_NAME" "$device_type" "$runtime")
        echo "Created '$CAREGIVER_SIM_NAME': $care_udid"
    fi

    # Create second parent simulator
    if xcrun simctl list devices -j | python3 -c "
import sys, json
data = json.load(sys.stdin)
for devices in data['devices'].values():
    for d in devices:
        if d['name'] == '$PARENT_SIM_NAME_2':
            sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
        echo "Simulator '$PARENT_SIM_NAME_2' already exists"
    else
        local parent_udid_2
        parent_udid_2=$(xcrun simctl create "$PARENT_SIM_NAME_2" "$device_type" "$runtime")
        echo "Created '$PARENT_SIM_NAME_2': $parent_udid_2"
    fi

    # Create second caregiver simulator
    if xcrun simctl list devices -j | python3 -c "
import sys, json
data = json.load(sys.stdin)
for devices in data['devices'].values():
    for d in devices:
        if d['name'] == '$CAREGIVER_SIM_NAME_2':
            sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
        echo "Simulator '$CAREGIVER_SIM_NAME_2' already exists"
    else
        local care_udid_2
        care_udid_2=$(xcrun simctl create "$CAREGIVER_SIM_NAME_2" "$device_type" "$runtime")
        echo "Created '$CAREGIVER_SIM_NAME_2': $care_udid_2"
    fi
}

boot_simulators() {
    source "$SCRIPT_DIR/environment.sh"  # re-resolve UDIDs
    if [[ -n "$PARENT_UDID" ]]; then
        xcrun simctl boot "$PARENT_UDID" 2>/dev/null || true
        echo "Booted $PARENT_SIM_NAME ($PARENT_UDID)"
    else
        echo "ERROR: $PARENT_SIM_NAME not found. Run: $0 create" >&2
        exit 1
    fi
    if [[ -n "$CAREGIVER_UDID" ]]; then
        xcrun simctl boot "$CAREGIVER_UDID" 2>/dev/null || true
        echo "Booted $CAREGIVER_SIM_NAME ($CAREGIVER_UDID)"
    else
        echo "ERROR: $CAREGIVER_SIM_NAME not found. Run: $0 create" >&2
        exit 1
    fi
    # Boot second pair (optional — only if they exist)
    source "$SCRIPT_DIR/environment.sh"
    if [[ -n "${PARENT_UDID_2:-}" ]]; then
        xcrun simctl boot "$PARENT_UDID_2" 2>/dev/null || true
        echo "Booted $PARENT_SIM_NAME_2 ($PARENT_UDID_2)"
    fi
    if [[ -n "${CAREGIVER_UDID_2:-}" ]]; then
        xcrun simctl boot "$CAREGIVER_UDID_2" 2>/dev/null || true
        echo "Booted $CAREGIVER_SIM_NAME_2 ($CAREGIVER_UDID_2)"
    fi
    open -a Simulator
}

shutdown_simulators() {
    source "$SCRIPT_DIR/environment.sh"
    [[ -n "$PARENT_UDID" ]] && xcrun simctl shutdown "$PARENT_UDID" 2>/dev/null || true
    [[ -n "$CAREGIVER_UDID" ]] && xcrun simctl shutdown "$CAREGIVER_UDID" 2>/dev/null || true
    [[ -n "${PARENT_UDID_2:-}" ]] && xcrun simctl shutdown "$PARENT_UDID_2" 2>/dev/null || true
    [[ -n "${CAREGIVER_UDID_2:-}" ]] && xcrun simctl shutdown "$CAREGIVER_UDID_2" 2>/dev/null || true
    echo "Simulators shut down"
}

delete_simulators() {
    source "$SCRIPT_DIR/environment.sh"
    [[ -n "$PARENT_UDID" ]] && xcrun simctl delete "$PARENT_UDID" 2>/dev/null || true
    [[ -n "$CAREGIVER_UDID" ]] && xcrun simctl delete "$CAREGIVER_UDID" 2>/dev/null || true
    [[ -n "${PARENT_UDID_2:-}" ]] && xcrun simctl delete "$PARENT_UDID_2" 2>/dev/null || true
    [[ -n "${CAREGIVER_UDID_2:-}" ]] && xcrun simctl delete "$CAREGIVER_UDID_2" 2>/dev/null || true
    echo "Simulators deleted"
}

case "${1:-}" in
    create)   create_simulators ;;
    boot)     boot_simulators ;;
    shutdown) shutdown_simulators ;;
    delete)   delete_simulators ;;
    *)        echo "Usage: $0 {create|boot|shutdown|delete}" >&2; exit 1 ;;
esac
