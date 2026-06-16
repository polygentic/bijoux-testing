#!/usr/bin/env bash
# Layer 2: Admin Verification Suite Runner
# Lists all cross-app verification prompts for Claude Code to execute.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "═══════════════════════════════════════════════════"
echo "  LAYER 2: Admin Verification Suite"
echo "═══════════════════════════════════════════════════"

PROMPTS_DIR="$ROOT_DIR/flows/admin/cross-app"
RESULTS_DIR="$ROOT_DIR/results/layer2-admin-verification"
mkdir -p "$RESULTS_DIR"

if [[ ! -f "$ROOT_DIR/results/state.json" ]]; then
  echo "WARNING: results/state.json not found. Layer 2 tests may lack entity IDs."
fi

TOTAL=0
for prompt in "$PROMPTS_DIR"/verify-*.md; do
  [[ -f "$prompt" ]] || continue
  TOTAL=$((TOTAL + 1))
  name=$(basename "$prompt" .md)
  echo ""
  echo "--- [$TOTAL] $name ---"
  echo "  Prompt: $prompt"
  echo "  Execute this prompt in Claude in Chrome against http://localhost:3001"
  echo "  Log results to: $RESULTS_DIR/${name}.log"
done

echo ""
echo "═══════════════════════════════════════════════════"
echo "  Total prompts: $TOTAL"
echo "  Execute each via Claude in Chrome"
echo "═══════════════════════════════════════════════════"
