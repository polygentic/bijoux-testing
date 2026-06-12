#!/usr/bin/env bash
# Seed the backend database with base data + UAT test accounts
# Usage: ./scripts/seed-backend.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/environment.sh"

echo "=== Seeding backend database ==="
cd "$BIJOUX_BACKEND_DIR"

echo "--- Running base seed ---"
npm run db:seed

echo ""
echo "--- Running UAT seed ---"
npx tsx prisma/seed-uat.ts

echo ""
echo "=== Seeding complete ==="
