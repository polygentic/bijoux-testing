#!/usr/bin/env bash
# Start backend services, run migrations, seed database
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/environment.sh"

echo "=== Starting backend services ==="
cd "$BIJOUX_BACKEND_DIR"

# Start docker services
docker compose up -d

# Wait for postgres
echo "Waiting for PostgreSQL..."
for i in $(seq 1 30); do
    if docker compose exec -T postgres pg_isready -U bijoux -d bijoux_dev > /dev/null 2>&1; then
        echo "PostgreSQL ready"
        break
    fi
    if [[ $i -eq 30 ]]; then
        echo "ERROR: PostgreSQL did not become ready in 30s" >&2
        exit 1
    fi
    sleep 1
done

# Run migrations
echo "Running migrations..."
npx prisma migrate deploy

# Seed database
echo "Seeding database..."
npx tsx prisma/seed.ts

# Seed test accounts
echo "Seeding test accounts..."
npx tsx scripts/seed-test-accounts.ts

# Start backend server in background
echo "Starting backend server..."
npm run dev &
BACKEND_PID=$!
echo "$BACKEND_PID" > /tmp/bijoux-backend.pid

# Wait for server to be ready
echo "Waiting for backend API..."
for i in $(seq 1 30); do
    if curl -s "$BACKEND_URL/../health" > /dev/null 2>&1 || curl -s "${BACKEND_URL%/api/v1}/health" > /dev/null 2>&1; then
        echo "Backend API ready at $BACKEND_URL"
        break
    fi
    if [[ $i -eq 30 ]]; then
        echo "WARNING: Backend may not be ready yet. Continuing..." >&2
    fi
    sleep 1
done

echo "=== Backend setup complete ==="
