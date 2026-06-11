#!/usr/bin/env bash
# Full autonomous UAT run
# Usage: ./scripts/orchestrate.sh [--skip-build] [--skip-backend]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$REPO_DIR/config/environment.sh"
source "$SCRIPT_DIR/jira-helpers.sh"

SKIP_BUILD=false
SKIP_BACKEND=false
for arg in "$@"; do
    case $arg in
        --skip-build)   SKIP_BUILD=true ;;
        --skip-backend) SKIP_BACKEND=true ;;
    esac
done

RESULTS_DIR="$REPO_DIR/results"
TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
RUN_DIR="$RESULTS_DIR/$TIMESTAMP"
mkdir -p "$RUN_DIR"

echo "==========================================="
echo "  Bijoux UAT Run — $TIMESTAMP"
echo "==========================================="

# --- 1. Validate ---
echo ""
echo "=== Step 1: Validate Prerequisites ==="
jira_validate_token
if [[ -z "$PARENT_UDID" || -z "$CAREGIVER_UDID" ]]; then
    echo "Simulators not found. Creating..."
    "$REPO_DIR/config/simulators.sh" create
    source "$REPO_DIR/config/environment.sh"
fi
echo "Parent simulator: $PARENT_UDID"
echo "Caregiver simulator: $CAREGIVER_UDID"

# --- 2. Backend ---
if [[ "$SKIP_BACKEND" == "false" ]]; then
    echo ""
    echo "=== Step 2: Start Backend ==="
    "$SCRIPT_DIR/backend-up.sh"
fi

# --- 3. Build ---
if [[ "$SKIP_BUILD" == "false" ]]; then
    echo ""
    echo "=== Step 3: Build iOS Apps ==="
    "$SCRIPT_DIR/build-parent.sh" || {
        echo "PARENT BUILD FAILED" >> "$RUN_DIR/errors.txt"
        jira_create_bug "BUG: Parent app build failure" "xcodebuild failed during UAT run $TIMESTAMP" "SEV-2"
    }
    "$SCRIPT_DIR/build-caregiver.sh" || {
        echo "CAREGIVER BUILD FAILED" >> "$RUN_DIR/errors.txt"
        jira_create_bug "BUG: Caregiver app build failure" "xcodebuild failed during UAT run $TIMESTAMP" "SEV-2"
    }
fi

# --- 4. Boot Simulators ---
echo ""
echo "=== Step 4: Boot Simulators ==="
"$REPO_DIR/config/simulators.sh" boot

# --- 5. Run Maestro Flows ---
echo ""
echo "=== Step 5: Run Parent App Flows ==="
for flow in "$REPO_DIR"/flows/parent/*.yaml; do
    echo "  Running: $(basename "$flow")"
    if maestro test "$flow" --device "$PARENT_UDID" --output "$RUN_DIR" 2>&1; then
        echo "  → PASS"
    else
        echo "  → FAIL"
        xcrun simctl io "$PARENT_UDID" screenshot "$RUN_DIR/fail-$(basename "$flow" .yaml).png" 2>/dev/null || true
    fi
done

echo ""
echo "=== Step 6: Run Caregiver App Flows ==="
for flow in "$REPO_DIR"/flows/caregiver/*.yaml; do
    echo "  Running: $(basename "$flow")"
    if maestro test "$flow" --device "$CAREGIVER_UDID" --output "$RUN_DIR" 2>&1; then
        echo "  → PASS"
    else
        echo "  → FAIL"
        xcrun simctl io "$CAREGIVER_UDID" screenshot "$RUN_DIR/fail-$(basename "$flow" .yaml).png" 2>/dev/null || true
    fi
done

# --- 7. Report ---
echo ""
echo "=== Step 7: Report to Jira ==="
"$SCRIPT_DIR/jira-report.sh" "$RUN_DIR"

# --- 8. Cleanup ---
echo ""
echo "=== Step 8: Cleanup ==="
"$REPO_DIR/config/simulators.sh" shutdown
if [[ "$SKIP_BACKEND" == "false" ]]; then
    "$SCRIPT_DIR/backend-down.sh"
fi

echo ""
echo "==========================================="
echo "  UAT Run Complete — Results in $RUN_DIR"
echo "==========================================="
