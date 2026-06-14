#!/usr/bin/env bash
# Lightweight Maestro test runner for bijoux UAT flows
# Usage: ./scripts/run-suite.sh [options]
#   --parent-only      Only run parent app flows
#   --caregiver-only   Only run caregiver app flows
#   --flow <name>      Run single flow (e.g., parent/login-valid)
#   --dry-run          List flows that would run without executing
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$REPO_DIR/config/environment.sh"

# ─── Parse flags ─────────────────────────────────────────────
PARENT_ONLY=false
CAREGIVER_ONLY=false
SINGLE_FLOW=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --parent-only)    PARENT_ONLY=true; shift ;;
    --caregiver-only) CAREGIVER_ONLY=true; shift ;;
    --flow)           SINGLE_FLOW="$2"; shift 2 ;;
    --dry-run)        DRY_RUN=true; shift ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--parent-only] [--caregiver-only] [--flow <name>] [--dry-run]" >&2
      exit 1
      ;;
  esac
done

# ─── Build flow list ─────────────────────────────────────────
FLOWS=()

if [[ -n "$SINGLE_FLOW" ]]; then
  # Single flow mode: resolve the name to a file path
  FLOW_FILE="$REPO_DIR/flows/${SINGLE_FLOW}.yaml"
  if [[ ! -f "$FLOW_FILE" ]]; then
    echo "ERROR: Flow not found: $FLOW_FILE" >&2
    exit 1
  fi
  FLOWS+=("$FLOW_FILE")
else
  # Collect parent flows
  if [[ "$CAREGIVER_ONLY" == "false" ]]; then
    for f in "$REPO_DIR"/flows/parent/*.yaml; do
      [[ -f "$f" ]] && FLOWS+=("$f")
    done
  fi
  # Collect caregiver flows
  if [[ "$PARENT_ONLY" == "false" ]]; then
    for f in "$REPO_DIR"/flows/caregiver/*.yaml; do
      [[ -f "$f" ]] && FLOWS+=("$f")
    done
  fi
fi

# ─── Filter out sub-flows (no launchApp = can't run standalone) ─
is_standalone() {
  grep -q 'launchApp' "$1"
}

STANDALONE_FLOWS=()
SKIPPED=0
for f in "${FLOWS[@]}"; do
  if is_standalone "$f"; then
    STANDALONE_FLOWS+=("$f")
  else
    SKIPPED=$((SKIPPED + 1))
  fi
done
FLOWS=("${STANDALONE_FLOWS[@]}")
TOTAL=${#FLOWS[@]}

if [[ "$TOTAL" -eq 0 ]]; then
  echo "No standalone flows to run."
  exit 0
fi

# ─── Dry run ─────────────────────────────────────────────────
if [[ "$DRY_RUN" == "true" ]]; then
  echo "Standalone flows ($TOTAL, skipped $SKIPPED sub-flow(s)):"
  echo ""
  for f in "${FLOWS[@]}"; do
    REL="${f#"$REPO_DIR"/flows/}"
    echo "  $REL"
  done
  exit 0
fi

# ─── Resolve device for a flow ────────────────────────────────
resolve_device() {
  local flow_path="$1"
  if [[ "$flow_path" == *"/parent/"* ]]; then
    echo "$PARENT_UDID"
  elif [[ "$flow_path" == *"/caregiver/"* ]]; then
    echo "$CAREGIVER_UDID"
  elif [[ "$flow_path" == *"/cross-app/"* ]]; then
    echo "$PARENT_UDID"
  else
    echo ""
  fi
}

# ─── Create results directory ─────────────────────────────────
TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
RUN_DIR="$REPO_DIR/results/$TIMESTAMP"
mkdir -p "$RUN_DIR"

# ─── Run flows ────────────────────────────────────────────────
PASS=0
FAIL=0
FAILURES=()

echo "==========================================="
echo "  Bijoux UAT Suite — $TIMESTAMP"
echo "  Flows: $TOTAL"
echo "==========================================="
echo ""

IDX=0
for FLOW in "${FLOWS[@]}"; do
  IDX=$((IDX + 1))
  REL="${FLOW#"$REPO_DIR"/flows/}"
  DEVICE=$(resolve_device "$FLOW")
  NAME=$(basename "$FLOW" .yaml)

  if [[ -z "$DEVICE" ]]; then
    echo "[$IDX/$TOTAL] SKIP  $REL (no device resolved)"
    FAILURES+=("$REL (no device)")
    FAIL=$((FAIL + 1))
    continue
  fi

  printf "[%d/%d] %-45s " "$IDX" "$TOTAL" "$REL"

  LOG_FILE="$RUN_DIR/${REL//\//-}.log"

  if maestro test "$FLOW" --device "$DEVICE" > "$LOG_FILE" 2>&1; then
    echo "PASS"
    PASS=$((PASS + 1))
  else
    echo "FAIL"
    FAIL=$((FAIL + 1))
    FAILURES+=("$REL")

    # Capture screenshot on failure
    SCREENSHOT="$RUN_DIR/fail-${NAME}.png"
    xcrun simctl io "$DEVICE" screenshot "$SCREENSHOT" 2>/dev/null || true
  fi
done

# ─── Summary ──────────────────────────────────────────────────
echo ""
echo "==========================================="
echo "  Results: $PASS passed, $FAIL failed (of $TOTAL)"
echo "  Output:  $RUN_DIR"
echo "==========================================="

if [[ ${#FAILURES[@]} -gt 0 ]]; then
  echo ""
  echo "  Failed flows:"
  for f in "${FAILURES[@]}"; do
    echo "    - $f"
  done
fi

echo ""

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
