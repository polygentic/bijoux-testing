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
export PARENT_SIM_NAME_2="bijoux-parent-2"
export CAREGIVER_SIM_NAME_2="bijoux-care-2"

# --- Derived Data ---
export PARENT_DERIVED_DATA="/tmp/bijoux-build-parent"
export CAREGIVER_DERIVED_DATA="/tmp/bijoux-build-caregiver"

# --- Backend ---
export BACKEND_URL="http://localhost:3000/api/v1"

# --- Admin Portal ---
export ADMIN_URL="http://localhost:3001"

# --- Test Account Credentials ---
export PARENT_EMAIL="parent-sarah@test.bijoux.app"
export PARENT_PASSWORD="Test1234!"
export PARENT_2_EMAIL="parent-james@test.bijoux.app"
export PARENT_2_PASSWORD="Test1234!"
export CAREGIVER_EMAIL="cg-emma@test.bijoux.app"
export CAREGIVER_PASSWORD="Test1234!"
export CAREGIVER_ONLINE_EMAIL="cg-maria@test.bijoux.app"
export CAREGIVER_ONLINE_PASSWORD="Test1234!"
export ADMIN_EMAIL="admin@bijoux.app"
export ADMIN_PASSWORD="Test1234!"

# --- Test Data ---
export TEST_ADDRESS="123 Main St, Austin, TX"
export TEST_LAT="30.2672"
export TEST_LNG="-97.7431"

# --- Java (required by Maestro) ---
if [[ -d "/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home" ]]; then
    export JAVA_HOME="/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
    export PATH="$JAVA_HOME/bin:$PATH"
fi

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
PARENT_UDID_2=$(_resolve_udid "$PARENT_SIM_NAME_2")
CAREGIVER_UDID_2=$(_resolve_udid "$CAREGIVER_SIM_NAME_2")
export PARENT_UDID_2 CAREGIVER_UDID_2
