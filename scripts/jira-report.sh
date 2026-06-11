#!/usr/bin/env bash
# Parse Maestro test results and report to Jira
# Usage: ./scripts/jira-report.sh <results-dir>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/environment.sh"
source "$SCRIPT_DIR/jira-helpers.sh"

RESULTS_DIR="${1:-$BIJOUX_TESTING_DIR/results}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
REPORT_FILE="$RESULTS_DIR/$(date +%Y-%m-%d)-run.md"

# Validate Jira connection
jira_validate_token || exit 1

echo "# UAT Run — $TIMESTAMP" > "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

PASS_COUNT=0
FAIL_COUNT=0

# Process each flow file to extract jira tag and check results
process_flow_result() {
    local flow_file="$1"
    local passed="$2"
    local error_msg="${3:-}"
    local screenshot="${4:-}"

    # Extract jira key from flow file comment
    local jira_key
    jira_key=$(grep -m1 '^# jira:' "$flow_file" 2>/dev/null | sed 's/# jira: *//' || echo "")

    # Extract UAT label
    local uat_label
    uat_label=$(grep -m1 '^# uat:' "$flow_file" 2>/dev/null | sed 's/# uat: *//' || echo "$(basename "$flow_file" .yaml)")

    if [[ "$passed" == "true" ]]; then
        PASS_COUNT=$((PASS_COUNT + 1))
        echo "  PASS: $uat_label"
        echo "| $uat_label | PASS | — |" >> "$REPORT_FILE"
        if [[ -n "$jira_key" ]]; then
            jira_add_comment "$jira_key" "$uat_label PASSED — $TIMESTAMP"
        fi
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo "  FAIL: $uat_label — $error_msg"
        echo "| $uat_label | FAIL | $error_msg |" >> "$REPORT_FILE"
        if [[ -n "$jira_key" ]]; then
            jira_add_comment "$jira_key" "$uat_label FAILED — $TIMESTAMP\n$error_msg"
            if [[ -n "$screenshot" && -f "$screenshot" ]]; then
                jira_attach_file "$jira_key" "$screenshot"
            fi
        else
            # No Jira key — create a bug
            jira_create_bug \
                "BUG: $uat_label — automated UAT failure" \
                "Flow: $(basename "$flow_file")\nTimestamp: $TIMESTAMP\nError: $error_msg" \
                "SEV-3"
            echo "  → Created bug ticket in BA"
        fi
    fi
}

echo "| Test | Result | Notes |" >> "$REPORT_FILE"
echo "|------|--------|-------|" >> "$REPORT_FILE"

echo ""
echo "=== UAT Results ==="
echo "Passed: $PASS_COUNT"
echo "Failed: $FAIL_COUNT"
echo "Report: $REPORT_FILE"
