#!/usr/bin/env bash
# Stop backend services
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/environment.sh"

# Kill backend server
if [[ -f /tmp/bijoux-backend.pid ]]; then
    kill "$(cat /tmp/bijoux-backend.pid)" 2>/dev/null || true
    rm -f /tmp/bijoux-backend.pid
    echo "Backend server stopped"
fi

# Stop docker services
cd "$BIJOUX_BACKEND_DIR"
docker compose down
echo "Docker services stopped"
