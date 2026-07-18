# Admin Portal E2E Integration — Design Spec

> Comprehensive multi-app E2E testing that includes the admin portal (bijouxAdmin)
> alongside the parent iOS app and caregiver iOS app, with full UI verification
> across all three apps and an independent API validation layer.

**Date:** 2026-06-15
**Branch:** `feat/admin-portal-e2e` (feature branch off `main`)
**Depends on:** `feat/real-matching-e2e` (merged or in-progress)

---

## 1. Context

The `feat/real-matching-e2e` branch delivered 4 cross-app E2E scripts testing the
parent iOS app and caregiver iOS app against the real matching engine. These scripts
use Maestro for iOS simulator automation and shell scripts with `curl` for API
orchestration.

The admin portal (bijouxAdmin, Next.js at `localhost:3001`) is not yet included in
cross-app E2E testing. The admin portal has 41 functions across 8 categories, 19 of
which trigger downstream effects visible in the iOS apps.

This spec adds the admin portal as a full participant in E2E testing — every admin
function tested through the real admin UI via Claude in Chrome, plus a separate
API-only validation layer. The platform is licensed to other businesses and must
support SLA guarantees, so coverage must be comprehensive.

---

## 2. Architecture

Four test layers, run in sequence by a local orchestrator:

### Layer 1 — Integrated Checkpoints
Admin portal verification calls added to the existing 4 iOS E2E scripts. After key
events (booking created, offer accepted, session completed), the script opens the
admin portal via Claude in Chrome and verifies the event is reflected in real time.

### Layer 2 — Admin Verification Suite
Standalone Chrome-driven tests for all 22 read-only admin functions. Runs after the
iOS E2E layer against the state it created. Covers list/filter pages, detail views,
dashboard KPIs, audit log, search, CSV exports.

### Layer 3 — Admin Action Suite
19 self-contained shell scripts for admin-initiated actions. Each creates its own
precondition state via API helpers, performs the admin action in Chrome, then verifies
the downstream effect on iOS sims via lightweight Maestro flows (login + check one
screen).

### Layer 4 — Admin API Suite
Shell scripts hitting all 28 admin API endpoints with `curl`. Validates response
structure, status codes, data correctness. No browser, no sims — pure API. Final
safety net.

### Why This Architecture (Approach C)

- **Independent retryability:** Each Layer 3 action test is self-contained. A failure
  can be retried without re-running other layers.
- **Resilience:** No layer blocks another. iOS suite failure doesn't prevent admin
  testing. Admin UI failure doesn't prevent API testing.
- **CI/CD ready:** Self-contained tests parallelize on cloud device farms without
  restructuring. The architecture maps directly to a future CI/CD pipeline.
- **Lightweight Maestro in Layer 3:** Action tests use API setup + minimal Maestro
  (login + verify one screen), not full E2E flows. Faster and less fragile.
- **Belt and suspenders:** The same admin functions are tested through the UI (Layers
  1-3) and via API (Layer 4), cross-validating each other.

---

## 3. Admin Function Inventory (41 functions)

### User Management (6)

| # | Function | Type | Cross-App Effect |
|---|----------|------|-----------------|
| 1 | List & filter users | Verification | — |
| 2 | View parent detail | Verification | — |
| 3 | Suspend parent | Action | Parent app: login blocked |
| 4 | Reactivate parent | Action | Parent app: can log in again |
| 5 | Issue credit | Action | Parent app: credit visible |
| 6 | View credit history | Verification | — |

### Booking Management (4)

| # | Function | Type | Cross-App Effect |
|---|----------|------|-----------------|
| 7 | List & filter bookings | Verification | — |
| 8 | View booking detail | Verification | — |
| 9 | Cancel booking | Action | Parent: cancellation shown, Caregiver: offer revoked |
| 10 | Override booking price | Action | Parent: updated cost shown |

### Caregiver Management (10)

| # | Function | Type | Cross-App Effect |
|---|----------|------|-----------------|
| 11 | List caregivers + pipeline KPIs | Verification | — |
| 12 | View caregiver detail | Verification | — |
| 13 | Approve caregiver | Action | Caregiver app: can go online |
| 14 | Suspend caregiver | Action | Caregiver: forced offline, Parent: assignment revoked |
| 15 | Reactivate caregiver | Action | Caregiver app: can log in and go online |
| 16 | Invite caregiver | Action | Invite status updated |
| 17 | Initiate BG check | Action | Caregiver: BG status updates |
| 18 | Set BG check status | Action | Affects approval eligibility |
| 19 | Initiate IDV | Action | Caregiver: IDV status updates |
| 20 | Set IDV status | Action | Affects approval eligibility |

### Session Management (5)

| # | Function | Type | Cross-App Effect |
|---|----------|------|-----------------|
| 21 | List & filter sessions | Verification | — |
| 22 | View session detail | Verification | — |
| 23 | Force-complete session | Action | Both apps: session ended with admin-set cost |
| 24 | Mark session disputed | Action | Both apps: dispute status shown |
| 25 | Filter sessions by rating | Verification | — |

### Incident Management (3)

| # | Function | Type | Cross-App Effect |
|---|----------|------|-----------------|
| 26 | List & filter incidents | Verification | — |
| 27 | View incident detail | Verification | — |
| 28 | Resolve incident | Action | Caregiver: incident status updated |

### Financial & Transactions (4)

| # | Function | Type | Cross-App Effect |
|---|----------|------|-----------------|
| 29 | View transaction ledger | Verification | — |
| 30 | Export transactions CSV | Verification | — |
| 31 | Issue refund | Action | Parent: refund visible |
| 32 | View credit balance | Verification | — |

### Market Pricing (3)

| # | Function | Type | Cross-App Effect |
|---|----------|------|-----------------|
| 33 | List pricing configs | Verification | — |
| 34 | Create pricing config | Action | Parent: new rates in booking estimates |
| 35 | Edit pricing config | Action | Parent: updated rates in booking estimates |

### Dashboard & Observability (5)

| # | Function | Type | Cross-App Effect |
|---|----------|------|-----------------|
| 36 | Dashboard KPIs | Verification | — |
| 37 | Bookings today count | Verification | — |
| 38 | Recent activity feed | Verification | — |
| 39 | Audit log | Verification | — |
| 40 | Export audit log CSV | Verification | — |

### Search (1)

| # | Function | Type | Cross-App Effect |
|---|----------|------|-----------------|
| 41 | Global search (Cmd+K) | Verification | — |

**Totals:** 19 action functions, 22 verification functions.

### Known Backend Gaps (to log, not fix in test infra)

- No `GET /admin/incidents/:id` endpoint (frontend detail page exists)
- Caregiver invite endpoint not found in admin module (may be elsewhere)
- BG check / IDV initiation endpoints not in admin routes (may be in trust-safety module)

---

## 4. Layer 1 — Integrated Checkpoints

Added to the existing 4 iOS E2E scripts. Each checkpoint is a call to
`admin_checkpoint()` in `scripts/lib/admin-chrome-helpers.sh`.

### Checkpoint Locations

**cross-app-real-matching-e2e.sh (happy path):**
1. After Sarah books → booking in admin list, lifecycle = `matching`
2. After Emma accepts → booking detail shows caregiver = Emma, lifecycle = `confirmed`
3. After session created → session in admin list, status = `not_started`
4. After session verified → session detail shows verification checkmarks
5. After session ended → session status = `completed`, transaction = `captured`

**cross-app-decline-then-accept.sh:**
1. After Emma declines → booking detail shows declined offer
2. After Maria accepts → booking detail shows caregiver = Maria

**cross-app-cancel-after-match.sh:**
1. After cancellation → booking lifecycle = `cancelled`, cancel fee transaction exists

**cross-app-multi-parent.sh:**
1. After Booking 1 completed → dashboard KPI: completed count incremented
2. After Booking 2 completed → both bookings in admin list, lifecycle = `completed`

### Implementation

`scripts/lib/admin-chrome-helpers.sh` provides:

```bash
# Initialize Chrome session on admin portal
admin_chrome_init()

# Login to admin portal if not authenticated
admin_chrome_login()

# Navigate to a page and verify content
# Args: page_path, expected_content_description
admin_checkpoint() {
  local page_path="$1"
  local description="$2"
  # Uses Claude in Chrome MCP tools:
  # 1. Navigate to localhost:3001${page_path}
  # 2. Read page content
  # 3. Verify expected data present
  # 4. Take screenshot
  # 5. Return pass/fail
}

# Verify specific text/element is visible on current page
admin_verify_visible()

# Read structured data from a table or detail view
admin_read_field()
```

The Chrome session stays open across checkpoints within a single script run.
No re-login between checks.

---

## 5. Layer 2 — Admin Verification Suite

22 standalone Chrome-driven tests in `flows/admin/cross-app/`. Each is a `.md`
prompt file executed via Claude in Chrome against post-E2E state.

### Test Inventory

**Dashboard (3):**
- `verify-dashboard-kpis.md` — KPI cards: active sessions, MTD revenue, online caregivers, pending approvals. All non-zero after E2E runs.
- `verify-dashboard-activity.md` — Recent activity feed contains entries from E2E flows.
- `verify-bookings-today.md` — Bookings today count matches E2E-created bookings.

**Users (3):**
- `verify-users-list.md` — Filter by parent (Sarah, James appear), filter by caregiver (Emma, Maria appear).
- `verify-parent-detail.md` — Sarah's profile: children list, credit balance, booking history.
- `verify-credit-history.md` — Sarah's credit ledger matches issued credits.

**Bookings (2):**
- `verify-bookings-list.md` — Filter by `completed`, confirm E2E bookings. Test date sorting.
- `verify-booking-detail.md` — Completed booking: parent, caregiver, lifecycle, offers list, transactions.

**Caregivers (2):**
- `verify-caregivers-list.md` — Pipeline KPIs, filter by online status matches sim state.
- `verify-caregiver-detail.md` — Emma: session count, earnings, trust info, rating.

**Sessions (3):**
- `verify-sessions-list.md` — Filter by `completed`, caregiver name filter.
- `verify-session-detail.md` — Booking link, caregiver, 4 verification checkmarks, timeline, rating.
- `verify-sessions-rating-filter.md` — Filter/sort by rating works correctly.

**Transactions (2):**
- `verify-transactions-list.md` — Filter by authorization/capture type, verify amounts.
- `verify-transactions-export.md` — Export CSV, verify file downloads with correct data.

**Incidents (2):**
- `verify-incidents-list.md` — Filter by type and resolved status.
- `verify-incident-detail.md` — Caregiver and booking links resolve correctly.

**Pricing (1):**
- `verify-pricing-list.md` — All market configs display with correct rates/fees/effective rates.

**Audit & Search (3):**
- `verify-audit-log.md` — Filter by date range, actor, resource. E2E actions logged.
- `verify-audit-export.md` — Export CSV, verify download and data.
- `verify-global-search.md` — Search by parent name, booking ID, caregiver name, session ID.

**Credit (1):**
- `verify-credit-balance.md` — Balance display matches ledger total.

### Execution

A runner script `scripts/run-admin-verification.sh` iterates through all `.md` files
in `flows/admin/cross-app/`, reads `results/state.json` for entity IDs, and executes
each prompt via Claude in Chrome. Results written to `results/layer2-admin-verification/`.

---

## 6. Layer 3 — Admin Action Suite

19 self-contained shell scripts in `scripts/`. Each follows the pattern:

```
API setup → Chrome action → Maestro verify → API verify
```

### Scripts

**User Management (4):**
- `admin-action-suspend-parent.sh` — Suspend Sarah → parent app login blocked
- `admin-action-reactivate-parent.sh` — Reactivate Sarah → parent app login works
- `admin-action-issue-credit.sh` — Issue $25 credit → parent app shows credit
- `admin-action-issue-refund.sh` — Issue refund → parent app shows refund

**Booking (2):**
- `admin-action-cancel-booking.sh` — Cancel matched booking → parent sees cancellation, caregiver sees offer revoked
- `admin-action-price-override.sh` — Override price → parent sees updated cost

**Caregiver (7):**
- `admin-action-approve-caregiver.sh` — Approve (BG=clear, IDV=approved) → caregiver can go online
- `admin-action-suspend-caregiver.sh` — Suspend → caregiver forced offline
- `admin-action-reactivate-caregiver.sh` — Reactivate → caregiver can go online
- `admin-action-invite-caregiver.sh` — Generate invite → status updated
- `admin-action-initiate-bg-check.sh` — Initiate BG check → status = pending
- `admin-action-initiate-idv.sh` — Initiate IDV → status = pending
- `admin-action-set-bg-idv-status.sh` — Set BG=clear + IDV=approved → Approve button appears

**Session (3):**
- `admin-action-force-complete.sh` — Force complete with cost → both apps show session ended
- `admin-action-mark-disputed.sh` — Mark disputed → both apps show dispute status
- `admin-action-filter-sessions-rating.sh` — Filter by rating (read-only, no sim verify)

**Pricing (2):**
- `admin-action-create-pricing.sh` — Create market pricing → parent app shows new rates
- `admin-action-edit-pricing.sh` — Edit pricing → parent app shows updated rates

**Incident (1):**
- `admin-action-resolve-incident.sh` — Resolve with notes → caregiver sees resolution

### Lightweight Maestro Pattern

Action tests use minimal Maestro flows for sim verification — not full E2E:

```yaml
# Example: verify-parent-booking-cancelled.yaml
appId: polygentic.bijouxParentApp
---
- launchApp
- waitForAnimationToEnd
# Navigate to booking/activity and check for cancellation
- assertVisible: "Cancelled"
- takeScreenshot: results/layer3/parent-booking-cancelled
```

These verification-only flows live in `flows/verify/` and are reused across action
scripts.

---

## 7. Layer 4 — Admin API Suite

`scripts/admin-api-tests.sh` — hits all 28 admin API endpoints with `curl`.

### Endpoints

**Metrics & Dashboard (1):**
1. `GET /admin/metrics` — KPI fields present, non-zero values

**Users (3):**
2. `GET /admin/users` — paginated, role filter works
3. `GET /admin/users/:id` — correct user with profile
4. `PUT /admin/users/:id/status` — suspend/reactivate works

**Bookings (4):**
5. `GET /admin/bookings` — paginated, lifecycle filter works
6. `GET /admin/bookings/:id` — booking with parent, caregiver, offers, transactions
7. `POST /admin/bookings/:id/cancel` — lifecycle → cancelled, audit log created
8. `POST /admin/bookings/:id/price-override` — price updated, reason stored

**Sessions (4):**
9. `GET /admin/sessions` — paginated, status filter works
10. `GET /admin/sessions/:id` — session with booking, caregiver, timeline
11. `POST /admin/sessions/:id/override` — state updated
12. `POST /admin/sessions/:id/force-complete` — status → completed, cost stored

**Caregivers (3):**
13. `GET /admin/caregivers` — paginated, status/BG/IDV/online filters work
14. `GET /admin/caregivers/:id` — caregiver with sessions, earnings, trust
15. `POST /admin/caregivers/:id/approval` — approve/suspend works

**Pricing (4):**
16. `GET /admin/market-pricing` — all configs returned
17. `GET /admin/market-pricing/:id` — single config with 8 fields
18. `POST /admin/market-pricing` — creates config
19. `PUT /admin/market-pricing/:id` — updates config

**Incidents (2):**
20. `GET /admin/incidents` — paginated, type/status filter works
21. `POST /admin/incidents/:id/resolve` — status → resolved, notes stored

**Audit (2):**
22. `GET /admin/audit-logs` — paginated, actor/resource/action/date filters work
23. `GET /admin/audit-logs/:id` — entry with actor info

**Credits (3):**
24. `POST /admin/credits/issue` — credit created, balance updated
25. `GET /admin/credits/:userId/balance` — correct balance
26. `GET /admin/credits/:userId/history` — paginated ledger

**Transactions (1):**
27. `GET /admin/transactions` — paginated, type/status filter works

**Search (1):**
28. `GET /admin/search` — returns results for name, booking ID, caregiver, session ID

### Error Case Validation

Each endpoint also validates:
- 401 without auth token
- 403 with non-admin token (use parent token)
- 404 with nonexistent ID (where applicable)

---

## 8. Orchestrator

`scripts/run-full-suite.sh` runs all 4 layers in sequence.

### Execution Flow

```
1. Prerequisites check
   - Backend running (curl localhost:3000/api/v1/pricing/current)
   - All 4 sims booted (xcrun simctl list devices booted)
   - Admin portal running (curl localhost:3001)
   - Chrome available for Claude in Chrome

2. Reseed backend (npm run db:seed + seed-uat.ts)

3. Layer 1: iOS E2E with integrated checkpoints
   - cross-app-real-matching-e2e.sh
   - cross-app-decline-then-accept.sh
   - cross-app-cancel-after-match.sh
   - cross-app-multi-parent.sh
   - Writes results/state.json with entity IDs

4. Layer 2: Admin verification suite
   - scripts/run-admin-verification.sh
   - Reads results/state.json
   - Executes 22 .md prompts via Claude in Chrome

5. Layer 3: Admin action suite
   - 19 admin-action-*.sh scripts
   - Each self-contained (API setup + Chrome + Maestro)

6. Layer 4: Admin API suite
   - scripts/admin-api-tests.sh
   - 28 endpoints x (happy path + error cases)

7. Aggregate results
   - Collect pass/fail from all layers
   - Write results/summary.json

8. Jira reporting
   - scripts/jira-report.sh results/

9. Cleanup
   - (Optional) shutdown sims, stop admin portal
```

### Shared State

`results/state.json` — written by Layer 1, read by Layer 2:

```json
{
  "bookings": [
    {"id": "...", "parent": "Sarah", "caregiver": "Emma", "lifecycle": "completed"},
    {"id": "...", "parent": "James", "caregiver": "Maria", "lifecycle": "completed"}
  ],
  "sessions": [
    {"id": "...", "bookingId": "...", "status": "completed"}
  ],
  "users": {
    "sarah": {"id": "...", "role": "parent"},
    "james": {"id": "...", "role": "parent"},
    "emma": {"id": "...", "role": "caregiver"},
    "maria": {"id": "...", "role": "caregiver"}
  }
}
```

### Failure Handling

- Layer 1 failure: log, continue to Layers 2-4. Layer 2 verifies whatever state exists. Layer 3 is unaffected (self-contained). Layer 4 is unaffected.
- Layer 2 failure: log per-test, continue. Does not block Layers 3-4.
- Layer 3 failure: each script independent. One failure does not block others.
- Layer 4 failure: log per-endpoint.
- No layer blocks another. All 4 always run.

### Results Directory

```
results/
  state.json
  layer1-ios-e2e/
    happy-path.log
    decline-then-accept.log
    cancel-after-match.log
    multi-parent.log
    screenshots/
  layer2-admin-verification/
    verify-dashboard-kpis.log
    verify-bookings-list.log
    ... (22 test logs)
    screenshots/
  layer3-admin-actions/
    admin-action-cancel-booking.log
    admin-action-suspend-parent.log
    ... (19 action logs)
    screenshots/
  layer4-admin-api/
    admin-api-tests.log
  summary.json
```

---

## 9. Technology Stack

| Component | Tool | Notes |
|-----------|------|-------|
| iOS simulator automation | Maestro 2.6 | YAML flows, text/ID selectors |
| Admin portal automation | Claude in Chrome (MCP) | Browser automation via accessibility tree |
| API testing | curl + python3 | Shell scripts, JSON parsing |
| Backend | Node.js (localhost:3000) | Existing bijoux-backend |
| Admin portal | Next.js (localhost:3001) | Existing bijouxAdmin |
| Orchestration | Bash shell scripts | Sequential layer execution |
| Results reporting | Jira API | Existing jira-helpers.sh |

### Future considerations (tracked in global TODO)

- Evaluate Xcode 27 Device Hub + mcpbridge when it exits beta — may replace Maestro
  with native Apple tooling (no JVM, better ecosystem integration)
- Evaluate SimPilot as Swift-native Maestro alternative
- Add caregiver signup + onboarding E2E flow (currently using seeded caregivers)

---

## 10. Test Accounts

All tests use seeded accounts from `fixtures/test-accounts.json` and `seed-uat.ts`:

| Account | Email | Role | Notes |
|---------|-------|------|-------|
| Admin | admin@bijoux.app | admin | Admin portal access |
| Sarah | parent-sarah@test.bijoux.app | parent | Primary parent, has payment method |
| James | parent-james@test.bijoux.app | parent | Second parent, payment method added via API |
| Emma | cg-emma@test.bijoux.app | caregiver | Primary caregiver |
| Maria | cg-maria@test.bijoux.app | caregiver | Second caregiver |

Password for all: `Test1234!`

---

## 11. File Structure

```
bijoux-testing/
  flows/
    admin/
      cross-app/              # Layer 2: 22 verification prompts
        verify-dashboard-kpis.md
        verify-bookings-list.md
        verify-booking-detail.md
        ...
    verify/                   # Lightweight Maestro verification flows
      parent-sees-cancellation.yaml
      caregiver-sees-offline.yaml
      parent-sees-credit.yaml
      ...
  scripts/
    lib/
      api-helpers.sh          # Existing + new admin API helpers
      admin-chrome-helpers.sh  # NEW: Chrome automation helpers
    run-full-suite.sh         # NEW: Top-level orchestrator
    run-admin-verification.sh # NEW: Layer 2 runner
    admin-api-tests.sh        # NEW: Layer 4
    admin-action-suspend-parent.sh      # Layer 3
    admin-action-reactivate-parent.sh
    admin-action-issue-credit.sh
    admin-action-issue-refund.sh
    admin-action-cancel-booking.sh
    admin-action-price-override.sh
    admin-action-approve-caregiver.sh
    admin-action-suspend-caregiver.sh
    admin-action-reactivate-caregiver.sh
    admin-action-invite-caregiver.sh
    admin-action-initiate-bg-check.sh
    admin-action-initiate-idv.sh
    admin-action-set-bg-idv-status.sh
    admin-action-force-complete.sh
    admin-action-mark-disputed.sh
    admin-action-filter-sessions-rating.sh
    admin-action-create-pricing.sh
    admin-action-edit-pricing.sh
    admin-action-resolve-incident.sh
  results/
    state.json
    layer1-ios-e2e/
    layer2-admin-verification/
    layer3-admin-actions/
    layer4-admin-api/
    summary.json
```
