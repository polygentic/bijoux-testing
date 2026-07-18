#!/usr/bin/env bash
# Clean test-DB reset helpers for the proximity UAT harness.
#
# Sourced by scripts/cross-app-proximity-e2e.sh. NO `set -e` here (sourced, not executed).
#
# WHY (2026-07-16): the two-party DRIFT handoff (Scenario 2) and the permission-denial
# retry (Scenario 4) are sensitive to accumulated transactional data. Prior runs left ~165
# bookings / ~91 sessions / ~181 match_offers in the DB; the admin proximity-override then
# risked landing on a STALE prior-run session, and the baseline-booking guard bolted on top
# only reduced (did not eliminate) the mismatch. A clean per-scenario reset removes the
# accumulation entirely so each scenario resolves exactly ONE fresh booking/session — the
# deterministic foundation the flaky guards were trying to approximate.
#
# WHAT it does: purges every TEST-RUN-generated transactional row (bookings and everything
# that references them — transactions, credit_ledger, caregiver_ledger, sessions,
# match_offers, match_requests) in FK-safe order, then re-runs prisma/seed-uat.ts to restore
# the fixed-UUID baseline fixtures (users/profiles/children/payment-methods are upserted;
# BOOKING_001-004 + SESSION_001-002 are re-created). Migrations and schema are untouched —
# this is a DATA reset, not a `migrate reset` (far faster, and keeps the proximity migration
# in place). Static seed rows are deterministic, so restoring them does not reintroduce the
# race (their bookings are historical/cancelled/completed, never "matching").

# reset_test_db_clean
# Purge all transactional data, then re-seed the UAT baseline fixtures.
# Requires: docker `bijoux-postgres` up; $BIJOUX_BACKEND_DIR set (environment.sh).
reset_test_db_clean() {
  echo "  [db-reset] purging transactional rows (FK-safe order)…"
  # FK order (child → parent): financial/session rows first, then match graph, then bookings.
  # caregiver_ledger has no enforced FK but carries session_id/booking_id → clear it too.
  # NOTE: `docker exec -i` is REQUIRED so the heredoc reaches psql's stdin — without `-i` docker
  # does not attach stdin, the SQL is discarded, and psql deletes nothing (silent no-op).
  docker exec -i bijoux-postgres psql -U bijoux -d bijoux_dev >/dev/null 2>&1 <<'SQL'
BEGIN;
DELETE FROM transactions;
DELETE FROM credit_ledger;
DELETE FROM caregiver_ledger;
DELETE FROM sessions;
DELETE FROM match_offers;
DELETE FROM match_requests;
DELETE FROM bookings;
COMMIT;
SQL
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    echo "  [db-reset] WARNING: purge returned non-zero ($rc); continuing" >&2
  fi

  echo "  [db-reset] re-seeding UAT baseline fixtures…"
  ( cd "$BIJOUX_BACKEND_DIR" && npx tsx prisma/seed-uat.ts >/dev/null 2>&1 ) \
    || echo "  [db-reset] WARNING: seed-uat re-seed returned non-zero; continuing" >&2

  # Sanity: report the post-reset transactional counts so the scenario log shows a clean slate
  # (the only bookings/sessions present are the deterministic seed fixtures).
  local counts
  counts=$(docker exec bijoux-postgres psql -U bijoux -d bijoux_dev -t -c \
    "SELECT (SELECT count(*) FROM bookings) || ' bookings, ' || (SELECT count(*) FROM sessions) || ' sessions, ' || (SELECT count(*) FROM match_offers) || ' offers';" 2>/dev/null | tr -d ' \n' | sed 's/,/, /g')
  echo "  [db-reset] clean slate restored: ${counts:-unknown}"
}

# baseline_booking_ids
# Print the fixed-UUID seed bookings (one per line) so a scenario can distinguish a
# freshly-created run booking from the deterministic fixtures without a "latest before run"
# race. Used as a stronger guard than the timestamp-baseline approach.
baseline_booking_ids() {
  cat <<'IDS'
b0000001-0000-4000-8000-000000000001
b0000002-0000-4000-8000-000000000002
b0000003-0000-4000-8000-000000000003
b0000004-0000-4000-8000-000000000004
IDS
}
