#!/usr/bin/env bash
# Build and install caregiver app on simulator
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/environment.sh"

if [[ -z "$CAREGIVER_UDID" ]]; then
    echo "ERROR: Caregiver simulator not found. Run: config/simulators.sh create" >&2
    exit 1
fi

echo "=== Building caregiver app ==="
xcodebuild build \
    -project "$BIJOUX_CAREGIVER_DIR/bijouxCaregiverApp.xcodeproj" \
    -scheme "$CAREGIVER_SCHEME" \
    -destination "platform=iOS Simulator,id=$CAREGIVER_UDID" \
    -derivedDataPath "$CAREGIVER_DERIVED_DATA" \
    -quiet \
    CODE_SIGNING_ALLOWED=NO

# Find the .app bundle
APP_PATH=$(find "$CAREGIVER_DERIVED_DATA" -name "bijouxCaregiverApp.app" -type d | head -1)
if [[ -z "$APP_PATH" ]]; then
    echo "ERROR: Could not find built .app bundle" >&2
    exit 1
fi

echo "Installing on simulator $CAREGIVER_SIM_NAME ($CAREGIVER_UDID)..."
xcrun simctl install "$CAREGIVER_UDID" "$APP_PATH"

echo "=== Caregiver app installed ==="
