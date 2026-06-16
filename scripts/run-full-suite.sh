#!/usr/bin/env bash
# Full E2E Test Suite Orchestrator
# Runs all 4 layers in sequence: iOS E2E → Admin Verification → Admin Actions → API Tests
#
# Usage:
#   ./scripts/run-full-suite.sh              # Run all layers
#   ./scripts/run-full-suite.sh --layer 1    # Run specific layer
#   ./scripts/run-full-suite.sh --layer 4    # API tests only (no Chrome/sims needed)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/config/environment.sh"

LAYER="${1:-all}"
[[ "$1" == "--layer" ]] && LAYER="${2:-all}"

RESULTS_DIR="$ROOT_DIR/results"
mkdir -p "$RESULTS_DIR"

echo "═══════════════════════════════════════════════════"
echo "  FULL E2E TEST SUITE"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "═══════════════════════════════════════════════════"

# Prerequisites check
echo ""
echo "--- Prerequisites ---"
curl -s "${BACKEND_URL}/pricing/current" > /dev/null 2>&1 \
  && echo "  ✓ Backend running" || { echo "  ✗ Backend not running at $BACKEND_URL"; exit 1; }

if [[ "$LAYER" == "all" || "$LAYER" == "1" || "$LAYER" == "2" || "$LAYER" == "3" ]]; then
  curl -s "${ADMIN_URL}" > /dev/null 2>&1 \
    && echo "  ✓ Admin portal running" || { echo "  ✗ Admin portal not running at $ADMIN_URL"; exit 1; }
fi

if [[ "$LAYER" == "all" || "$LAYER" == "1" || "$LAYER" == "3" ]]; then
  [[ -n "${PARENT_UDID:-}" ]] && echo "  ✓ Parent sim: $PARENT_UDID" || echo "  ⚠ Parent sim not found"
  [[ -n "${CAREGIVER_UDID:-}" ]] && echo "  ✓ Caregiver sim: $CAREGIVER_UDID" || echo "  ⚠ Caregiver sim not found"
fi

L1_RESULT="SKIP"; L2_RESULT="SKIP"; L3_RESULT="SKIP"; L4_RESULT="SKIP"

# ─── Layer 1: iOS E2E with Integrated Checkpoints ─────────
if [[ "$LAYER" == "all" || "$LAYER" == "1" ]]; then
  echo ""
  echo "═══ LAYER 1: iOS E2E Scripts ═══"
  L1_FAILURES=0

  mkdir -p "$RESULTS_DIR/layer1-ios-e2e"
  for script in \
    "$ROOT_DIR/scripts/cross-app-real-matching-e2e.sh" \
    "$ROOT_DIR/scripts/cross-app-decline-then-accept.sh" \
    "$ROOT_DIR/scripts/cross-app-cancel-after-match.sh" \
    "$ROOT_DIR/scripts/cross-app-multi-parent.sh"; do

    name=$(basename "$script" .sh)
    echo ""
    echo "--- $name ---"
    if "$script" > "$RESULTS_DIR/layer1-ios-e2e/${name}.log" 2>&1; then
      echo "  ✓ PASS"
    else
      echo "  ✗ FAIL (see $RESULTS_DIR/layer1-ios-e2e/${name}.log)"
      L1_FAILURES=$((L1_FAILURES + 1))
    fi
  done

  L1_RESULT=$([[ $L1_FAILURES -eq 0 ]] && echo "PASS" || echo "FAIL ($L1_FAILURES)")
  echo ""
  echo "  Layer 1 checkpoint prompts available in flows/admin/checkpoints/"
  echo "  Execute each via Claude in Chrome between E2E phases"
fi

# ─── Layer 2: Admin Verification Suite ─────────────────────
if [[ "$LAYER" == "all" || "$LAYER" == "2" ]]; then
  echo ""
  echo "═══ LAYER 2: Admin Verification Suite ═══"
  echo "  Run: ./scripts/run-admin-verification.sh"
  echo "  Execute 22 prompts in flows/admin/cross-app/ via Claude in Chrome"
  L2_RESULT="MANUAL"
fi

# ─── Layer 3: Admin Action Suite ───────────────────────────
if [[ "$LAYER" == "all" || "$LAYER" == "3" ]]; then
  echo ""
  echo "═══ LAYER 3: Admin Action Suite ═══"
  echo "  Execute 19 prompts in flows/admin/actions/ via Claude Code"
  echo "  Each prompt contains: setup (bash), admin action (Chrome), verify (bash + Maestro)"
  L3_RESULT="MANUAL"
fi

# ─── Layer 4: Admin API Suite ──────────────────────────────
if [[ "$LAYER" == "all" || "$LAYER" == "4" ]]; then
  echo ""
  echo "═══ LAYER 4: Admin API Suite ═══"
  mkdir -p "$RESULTS_DIR/layer4-admin-api"
  if "$ROOT_DIR/scripts/admin-api-tests.sh" > "$RESULTS_DIR/layer4-admin-api/admin-api-tests.log" 2>&1; then
    L4_RESULT="PASS"
    echo "  ✓ PASS"
  else
    L4_RESULT="FAIL"
    echo "  ✗ FAIL (see results/layer4-admin-api/admin-api-tests.log)"
  fi
fi

# ─── Summary ───────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════"
echo "  SUITE RESULTS"
echo "═══════════════════════════════════════════════════"
echo "  Layer 1 (iOS E2E):           $L1_RESULT"
echo "  Layer 2 (Admin Verification): $L2_RESULT"
echo "  Layer 3 (Admin Actions):      $L3_RESULT"
echo "  Layer 4 (Admin API):          $L4_RESULT"
echo "═══════════════════════════════════════════════════"

# Write summary JSON
python3 -c "
import json
summary = {
    'layer1': '$L1_RESULT',
    'layer2': '$L2_RESULT',
    'layer3': '$L3_RESULT',
    'layer4': '$L4_RESULT'
}
with open('$RESULTS_DIR/summary.json', 'w') as f:
    json.dump(summary, f, indent=2)
" 2>/dev/null
