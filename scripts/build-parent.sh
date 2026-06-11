#!/usr/bin/env bash
# Build and install parent app on simulator
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/environment.sh"

if [[ -z "$PARENT_UDID" ]]; then
    echo "ERROR: Parent simulator not found. Run: config/simulators.sh create" >&2
    exit 1
fi

echo "=== Building parent app ==="
xcodebuild build \
    -project "$BIJOUX_PARENT_DIR/bijouxParentApp.xcodeproj" \
    -scheme "$PARENT_SCHEME" \
    -destination "platform=iOS Simulator,id=$PARENT_UDID" \
    -derivedDataPath "$PARENT_DERIVED_DATA" \
    -quiet \
    CODE_SIGNING_ALLOWED=NO

# Find the .app bundle
APP_PATH=$(find "$PARENT_DERIVED_DATA" -name "bijouxParentApp.app" -type d | head -1)
if [[ -z "$APP_PATH" ]]; then
    echo "ERROR: Could not find built .app bundle" >&2
    exit 1
fi

echo "Installing on simulator $PARENT_SIM_NAME ($PARENT_UDID)..."
xcrun simctl install "$PARENT_UDID" "$APP_PATH"

echo "=== Parent app installed ==="
