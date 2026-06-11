#!/usr/bin/env bash
# Bijoux Testing — Environment Configuration
# Source this file before running any test scripts.

# --- Repo Paths ---
export BIJOUX_PARENT_DIR="/Users/polygentic/Documents/dev/bijoux-ios"
export BIJOUX_CAREGIVER_DIR="/Users/polygentic/Documents/dev/bijouxCaregiverApp"
export BIJOUX_ADMIN_DIR="/Users/polygentic/Documents/dev/bijouxAdmin"
export BIJOUX_BACKEND_DIR="/Users/polygentic/Documents/dev/bijoux-backend"
export BIJOUX_TESTING_DIR="/Users/polygentic/Documents/dev/bijoux-testing"

# --- Bundle IDs ---
export PARENT_BUNDLE_ID="polygentic.bijouxParentApp"
export CAREGIVER_BUNDLE_ID="polygentic.bijouxCaregiverApp"

# --- Xcode Schemes ---
export PARENT_SCHEME="bijouxParentApp"
export CAREGIVER_SCHEME="bijouxCaregiverApp"

# --- Simulator Names ---
export PARENT_SIM_NAME="bijoux-parent"
export CAREGIVER_SIM_NAME="bijoux-care"

# --- Derived Data ---
export PARENT_DERIVED_DATA="/tmp/bijoux-build-parent"
export CAREGIVER_DERIVED_DATA="/tmp/bijoux-build-caregiver"

# --- Backend ---
export BACKEND_URL="http://localhost:3000/api/v1"

# --- Admin Portal ---
export ADMIN_URL="http://localhost:3001"

# --- Jira ---
export JIRA_ENV_FILE="/Users/polygentic/.config/bijoux/jira.env"

# --- Simulator UDIDs (populated by simulators.sh) ---
export PARENT_UDID=""
export CAREGIVER_UDID=""

# Load Jira credentials if available
if [[ -f "$JIRA_ENV_FILE" ]]; then
    set -a
    source "$JIRA_ENV_FILE"
    set +a
fi

# Load simulator UDIDs if simulators exist
_resolve_udid() {
    xcrun simctl list devices -j 2>/dev/null \
        | python3 -c "
import sys, json
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    for d in devices:
        if d['name'] == '$1' and d['state'] != 'Shutdown':
            print(d['udid'])
            sys.exit(0)
        elif d['name'] == '$1':
            print(d['udid'])
            sys.exit(0)
" 2>/dev/null
}

PARENT_UDID=$(_resolve_udid "$PARENT_SIM_NAME")
CAREGIVER_UDID=$(_resolve_udid "$CAREGIVER_SIM_NAME")
export PARENT_UDID CAREGIVER_UDID
