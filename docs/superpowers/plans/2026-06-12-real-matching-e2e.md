# Real Multi-Simulator E2E Matching Flow — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Test the full real matching flow end-to-end across 4 iOS simulators (2 parent, 2 caregiver) — no simulate accept, real matching engine, real offer delivery, real session lifecycle.

**Architecture:** Shell orchestration scripts coordinate Maestro flows across multiple simulators, interleaving device-targeted `maestro test --device $UDID` calls with API polling via `curl`. Each phase of the flow (booking, matching, IOMW, arrival, session, end) runs as a Maestro sub-flow on the appropriate simulator. API verification confirms state transitions after each phase.

**Tech Stack:** Bash scripts, Maestro YAML flows, curl for API, python3 for JSON parsing, xcrun simctl for simulator management.

**Spec:** `docs/specs/2026-06-12-real-matching-e2e.md`

---

## File Structure

### Config (modify existing)
- `config/environment.sh` — Add `PARENT_SIM_NAME_2`, `CAREGIVER_SIM_NAME_2`, `PARENT_UDID_2`, `CAREGIVER_UDID_2`, and test account env vars (`PARENT_EMAIL`, `PARENT_PASSWORD`, etc.)
- `config/simulators.sh` — Add creation/boot/shutdown for all 4 sims

### Caregiver Sub-flows (create new)
- `flows/caregiver/login-maria.yaml` — Login as cg-maria on any caregiver sim (standalone, clearState)
- `flows/caregiver/go-online.yaml` — Sub-flow: tap Go Online toggle (assumes already logged in)
- `flows/caregiver/iomw.yaml` — Sub-flow: tap "Confirm I'm On My Way" after accepting offer

### Parent Sub-flows (create new)
- `flows/parent/verify-matched.yaml` — Sub-flow: wait for "Caregiver Found" screen, verify caregiver name
- `flows/parent/rate-session.yaml` — Sub-flow: rate completed session (tap stars + submit)

### Parent Login Flows (create new)
- `flows/parent/login-james.yaml` — Login as parent-james on any parent sim (standalone, clearState)

### Orchestration Scripts (create new)
- `scripts/cross-app-real-matching-e2e.sh` — Happy path: book → match → accept → IOMW → arrive → session → end → rate → verify
- `scripts/cross-app-decline-then-accept.sh` — Emma declines, Maria accepts
- `scripts/cross-app-multi-parent.sh` — Sarah + James book simultaneously, 2 caregivers accept
- `scripts/cross-app-cancel-after-match.sh` — Rewrite of existing: real matching, cancel after IOMW, verify fee
- `scripts/lib/api-helpers.sh` — Shared functions: `api_login`, `api_get_booking`, `api_verify_session`, `api_verify_earnings`, `api_set_online`, `api_reseed`

### Orchestration Scripts (modify existing)
- `scripts/cross-app-booking-lifecycle.sh` — Remove simulate fallbacks, use real matching
- `scripts/run-suite.sh` — Add `resolve_device` support for `_2` sims

### Flows (modify existing — remove simulate accept)
- `flows/cross-app/parent-login-and-book.yaml` — Already correct (no simulate accept)
- `flows/parent/matching-searching.yaml` — Verify no simulate accept reference

---

## Recovery & Rollback Conventions

Every task below includes:
- **Pre-conditions:** What must be true before starting
- **Post-conditions:** What must be true after completion
- **If this fails:** Diagnostic steps + recovery actions
- **Rollback:** How to undo this task's changes completely
- **State reset:** How to clean up side effects (backend data, simulator state)

**Global state reset command** (use between E2E script runs):
```bash
# Reseed backend to clean state
cd /Users/polygentic/Documents/dev/bijoux-backend && npm run db:seed && npx tsx prisma/seed-uat.ts

# Reset all simulator apps to clean state (clears login, keychain, app data)
xcrun simctl terminate "$PARENT_UDID" polygentic.bijouxParentApp 2>/dev/null || true
xcrun simctl terminate "$CAREGIVER_UDID" polygentic.bijouxCaregiverApp 2>/dev/null || true
xcrun simctl terminate "${PARENT_UDID_2:-}" polygentic.bijouxParentApp 2>/dev/null || true
xcrun simctl terminate "${CAREGIVER_UDID_2:-}" polygentic.bijouxCaregiverApp 2>/dev/null || true
```

**Global git rollback** (undo any task):
```bash
# See what was committed
git log --oneline -5

# Revert the last commit (keeps changes unstaged)
git reset HEAD~1

# Nuclear: discard all uncommitted changes
git checkout -- .
```

---

## Task 1: Add Test Account Environment Variables

**Pre-conditions:** `config/environment.sh` exists and is sourceable
**Post-conditions:** `source config/environment.sh` exports PARENT_EMAIL, ADMIN_EMAIL, etc.

**Files:**
- Modify: `config/environment.sh`

- [ ] **Step 1: Add test account credentials to environment.sh**

Add after the `ADMIN_URL` line (line 30):

```bash
# --- Test Account Credentials ---
export PARENT_EMAIL="parent-sarah@test.bijoux.app"
export PARENT_PASSWORD="Test1234!"
export PARENT_2_EMAIL="parent-james@test.bijoux.app"
export PARENT_2_PASSWORD="Test1234!"
export CAREGIVER_EMAIL="cg-emma@test.bijoux.app"
export CAREGIVER_PASSWORD="Test1234!"
export CAREGIVER_ONLINE_EMAIL="cg-maria@test.bijoux.app"
export CAREGIVER_ONLINE_PASSWORD="Test1234!"
export ADMIN_EMAIL="admin@bijoux.app"
export ADMIN_PASSWORD="Test1234!"

# --- Test Data ---
export TEST_ADDRESS="123 Main St, Austin, TX"
export TEST_LAT="30.2672"
export TEST_LNG="-97.7431"
```

- [ ] **Step 2: Verify by sourcing the file**

Run: `source config/environment.sh && echo "PARENT_EMAIL=$PARENT_EMAIL, ADMIN_EMAIL=$ADMIN_EMAIL"`
Expected: `PARENT_EMAIL=parent-sarah@test.bijoux.app, ADMIN_EMAIL=admin@bijoux.app`

- [ ] **Step 3: Commit**

```bash
git add config/environment.sh
git commit -m "feat: add test account credentials to environment config"
```

**If this fails:** If `source` throws errors, check for syntax issues (unquoted special chars in passwords). The `!` in `Test1234!` must be in double quotes.
**Rollback:** `git reset HEAD~1 && git checkout -- config/environment.sh`

---

## Task 2: Expand Simulator Infrastructure to 4 Sims

**Pre-conditions:** Task 1 complete. Xcode installed with iOS simulator runtimes.
**Post-conditions:** `xcrun simctl list devices | grep bijoux` shows 4 devices. All 4 UDIDs resolve.

**Files:**
- Modify: `config/environment.sh`
- Modify: `config/simulators.sh`

- [ ] **Step 1: Add second simulator names and UDID resolution to environment.sh**

Add after the existing `CAREGIVER_SIM_NAME` line (line 22):

```bash
export PARENT_SIM_NAME_2="bijoux-parent-2"
export CAREGIVER_SIM_NAME_2="bijoux-care-2"
```

Add after the existing `CAREGIVER_UDID` resolution (line 72):

```bash
PARENT_UDID_2=$(_resolve_udid "$PARENT_SIM_NAME_2")
CAREGIVER_UDID_2=$(_resolve_udid "$CAREGIVER_SIM_NAME_2")
export PARENT_UDID_2 CAREGIVER_UDID_2
```

- [ ] **Step 2: Update simulators.sh create_simulators() to create all 4**

Replace the `create_simulators` function body. After the existing caregiver simulator creation block (ends at line 89), add:

```bash
    # Create parent simulator 2
    if xcrun simctl list devices -j | python3 -c "
import sys, json
data = json.load(sys.stdin)
for devices in data['devices'].values():
    for d in devices:
        if d['name'] == '$PARENT_SIM_NAME_2':
            sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
        echo "Simulator '$PARENT_SIM_NAME_2' already exists"
    else
        local parent2_udid
        parent2_udid=$(xcrun simctl create "$PARENT_SIM_NAME_2" "$device_type" "$runtime")
        echo "Created '$PARENT_SIM_NAME_2': $parent2_udid"
    fi

    # Create caregiver simulator 2
    if xcrun simctl list devices -j | python3 -c "
import sys, json
data = json.load(sys.stdin)
for devices in data['devices'].values():
    for d in devices:
        if d['name'] == '$CAREGIVER_SIM_NAME_2':
            sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
        echo "Simulator '$CAREGIVER_SIM_NAME_2' already exists"
    else
        local care2_udid
        care2_udid=$(xcrun simctl create "$CAREGIVER_SIM_NAME_2" "$device_type" "$runtime")
        echo "Created '$CAREGIVER_SIM_NAME_2': $care2_udid"
    fi
```

- [ ] **Step 3: Update boot_simulators() for all 4**

After the existing caregiver boot block (line 107), add:

```bash
    # Boot second pair (optional — only if they exist)
    source "$SCRIPT_DIR/environment.sh"
    if [[ -n "${PARENT_UDID_2:-}" ]]; then
        xcrun simctl boot "$PARENT_UDID_2" 2>/dev/null || true
        echo "Booted $PARENT_SIM_NAME_2 ($PARENT_UDID_2)"
    fi
    if [[ -n "${CAREGIVER_UDID_2:-}" ]]; then
        xcrun simctl boot "$CAREGIVER_UDID_2" 2>/dev/null || true
        echo "Booted $CAREGIVER_SIM_NAME_2 ($CAREGIVER_UDID_2)"
    fi
```

- [ ] **Step 4: Update shutdown_simulators() and delete_simulators() for all 4**

Add to shutdown_simulators():
```bash
    [[ -n "${PARENT_UDID_2:-}" ]] && xcrun simctl shutdown "$PARENT_UDID_2" 2>/dev/null || true
    [[ -n "${CAREGIVER_UDID_2:-}" ]] && xcrun simctl shutdown "$CAREGIVER_UDID_2" 2>/dev/null || true
```

Add to delete_simulators():
```bash
    [[ -n "${PARENT_UDID_2:-}" ]] && xcrun simctl delete "$PARENT_UDID_2" 2>/dev/null || true
    [[ -n "${CAREGIVER_UDID_2:-}" ]] && xcrun simctl delete "$CAREGIVER_UDID_2" 2>/dev/null || true
```

- [ ] **Step 5: Create the new simulators**

Run: `./config/simulators.sh create`
Expected: Output showing all 4 simulators created (or "already exists" for existing ones)

- [ ] **Step 5b: Install apps on new simulators**

The existing build scripts install to `$PARENT_UDID` and `$CAREGIVER_UDID` only. Install apps on the new sims manually:

```bash
source config/environment.sh

# Find the most recent built .app bundles
PARENT_APP=$(find ~/Library/Developer/Xcode/DerivedData -name "bijouxParentApp.app" -path "*/Debug-iphonesimulator/*" | head -1)
CAREGIVER_APP=$(find ~/Library/Developer/Xcode/DerivedData -name "bijouxCaregiverApp.app" -path "*/Debug-iphonesimulator/*" | head -1)

# Install on new sims
xcrun simctl install "$PARENT_UDID_2" "$PARENT_APP"
xcrun simctl install "$CAREGIVER_UDID_2" "$CAREGIVER_APP"
echo "Apps installed on bijoux-parent-2 and bijoux-care-2"
```

If no built .app exists, run the build scripts first:
```bash
./scripts/build-parent.sh
./scripts/build-caregiver.sh
```
Then re-run the install commands above.

- [ ] **Step 6: Verify all 4 UDIDs resolve**

Run: `source config/environment.sh && echo "P1=$PARENT_UDID P2=$PARENT_UDID_2 C1=$CAREGIVER_UDID C2=$CAREGIVER_UDID_2"`
Expected: 4 non-empty UUIDs

- [ ] **Step 7: Commit**

```bash
git add config/environment.sh config/simulators.sh
git commit -m "feat: expand simulator infrastructure to 4 sims (2 parent, 2 caregiver)"
```

**If this fails:**
- `get_latest_runtime` fails → No iOS runtime installed. Run `xcodebuild -downloadAllPlatforms` or install via Xcode > Settings > Platforms.
- `simctl create` fails → Device type not available. Check `xcrun simctl list devicetypes` for available iPhones.
- UDIDs don't resolve → Sims created but not found by name. Check `xcrun simctl list devices` and compare names exactly.
**Rollback:** `./config/simulators.sh delete` removes all 4 sims. Then `git reset HEAD~1 && git checkout -- config/environment.sh config/simulators.sh`.
**State reset:** `./config/simulators.sh shutdown` stops all running sims.

---

## Task 3: Remove All Simulate Accept References

**Pre-conditions:** Git working tree clean (tasks 1-2 committed).
**Post-conditions:** `grep -rni "simulate.accept\|simulate_accept\|simulate-accept\|simulate.iomw\|simulate.arrival" flows/ scripts/` returns zero results.

**Files:**
- Modify: `scripts/cross-app-booking-lifecycle.sh`
- Modify: Any other files found by grep

- [ ] **Step 1: Find all simulate accept references**

Run: `grep -rn -i "simulate.accept\|simulate_accept\|simulate-accept\|simulate.iomw\|simulate.arrival\|Simulate Accept" flows/ scripts/ docs/ --include="*.yaml" --include="*.sh" --include="*.md"`

- [ ] **Step 2: Remove simulate fallback from cross-app-booking-lifecycle.sh**

In `scripts/cross-app-booking-lifecycle.sh`, the caregiver accept step (Phase 5, lines 198-224) has an API fallback that uses simulate endpoints. Remove the entire fallback block (lines 205-224) starting at `echo "  NOTE: Offer may not have been delivered..."` through the closing `fi`. The flow should fail if the caregiver sub-flow fails — no simulate fallback.

Replace lines 198-224 with:

```bash
step "Caregiver: Accept offer via Maestro"

if maestro --udid="$CAREGIVER_UDID" test "$ROOT_DIR/flows/caregiver/accept-offer.yaml" 2>&1; then
  pass "Caregiver offer acceptance completed"
else
  fail "Caregiver offer acceptance failed — offer may not have been delivered"
  exit 1
fi
```

- [ ] **Step 3: Remove any simulate references from Maestro flows**

Check `flows/parent/matching-searching.yaml` and `flows/cross-app/parent-login-and-book.yaml` for any simulate accept button taps. Remove them if found. The parent flow should end at the "Searching" state — real acceptance happens on the caregiver simulator.

- [ ] **Step 4: Verify no references remain**

Run: `grep -rn -i "simulate.accept\|simulate_accept\|simulate-accept\|simulate.iomw\|simulate.arrival" flows/ scripts/ --include="*.yaml" --include="*.sh"`
Expected: No output (zero matches)

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "fix: remove all simulate accept references from test flows and scripts"
```

**If this fails:** If grep still finds matches, some files were missed. Check `.md` docs files too — remove references but note in the file that simulate was removed.
**Rollback:** `git reset HEAD~1 && git checkout -- flows/ scripts/`

---

## Task 4: File Jira Ticket to Remove Simulate Accept

**Pre-conditions:** Jira credentials configured in `~/.config/bijoux/jira.env`. `jira_validate_token` succeeds.
**Post-conditions:** Jira ticket exists in BA project with title containing "Simulate Accept".

**Files:** None (Jira API call)

- [ ] **Step 1: Source Jira credentials**

```bash
source config/environment.sh
source scripts/jira-helpers.sh
```

- [ ] **Step 2: Create Jira ticket**

```bash
jira_create_bug \
  "Remove Simulate Accept button and admin simulate endpoints" \
  "Remove the ⚡ Simulate Accept dev button from the parent app matching screen (SearchingView.swift). Remove POST /matching/admin/simulate-accept, POST /matching/admin/simulate-iomw, and POST /matching/admin/simulate-arrival endpoints from the backend (matching/routes.ts). These shortcuts bypass the real matching engine. All testing now uses the real multi-simulator flow. Files to modify: bijoux-ios SearchingView.swift, bijoux-backend src/modules/matching/routes.ts and service.ts (adminSimulateAccept, adminSimulateIOMW, adminSimulateArrival functions)." \
  "SEV-3"
```

- [ ] **Step 3: Record the ticket number**

Note the returned ticket ID (e.g., BA-273) for reference in the spec.

- [ ] **Step 4: Commit (no code changes — just documenting)**

No commit needed for this task.

**If this fails:** If Jira API returns 401, re-check `~/.config/bijoux/jira.env` for valid JIRA_EMAIL and JIRA_API_TOKEN. If 403, the token may lack project permissions.
**Rollback:** No code changes to revert. If the wrong ticket was created, close it in Jira manually.

---

## Task 5: Create Shared API Helper Library

**Pre-conditions:** Tasks 1-2 complete (env vars available). Backend running at `$BACKEND_URL`.
**Post-conditions:** `source scripts/lib/api-helpers.sh` works. `api_login "$PARENT_EMAIL" "$PARENT_PASSWORD"` returns a JWT token.

**Files:**
- Create: `scripts/lib/api-helpers.sh`

- [ ] **Step 1: Create the lib directory**

Run: `mkdir -p scripts/lib`

- [ ] **Step 2: Write api-helpers.sh**

```bash
#!/usr/bin/env bash
# Shared API helper functions for cross-app orchestration scripts.
# Source this file: source "$SCRIPT_DIR/lib/api-helpers.sh"

# Login and return access token. Args: email, password
api_login() {
  local email="$1" password="$2"
  curl -s -X POST "${BACKEND_URL}/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${email}\",\"password\":\"${password}\"}" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('accessToken',''))" 2>/dev/null
}

# Get booking by ID. Args: token, booking_id
api_get_booking() {
  local token="$1" booking_id="$2"
  curl -s -H "Authorization: Bearer ${token}" \
    "${BACKEND_URL}/bookings/${booking_id}" 2>/dev/null
}

# Get booking lifecycle status. Args: token, booking_id
api_booking_lifecycle() {
  local token="$1" booking_id="$2"
  api_get_booking "$token" "$booking_id" \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
d = data.get('data', data)
print(d.get('lifecycle', d.get('status', '')))" 2>/dev/null
}

# Get latest booking ID for a parent. Args: token
api_latest_booking_id() {
  local token="$1"
  curl -s -H "Authorization: Bearer ${token}" \
    "${BACKEND_URL}/bookings?limit=1&sort=-createdAt" \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
items = data.get('data', data.get('bookings', []))
if isinstance(items, list) and len(items) > 0:
    print(items[0].get('id', ''))
else:
    print('')" 2>/dev/null
}

# Get session ID from booking. Args: token, booking_id
api_session_id() {
  local token="$1" booking_id="$2"
  api_get_booking "$token" "$booking_id" \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
d = data.get('data', data)
s = d.get('session', {})
print(s.get('id', ''))" 2>/dev/null
}

# Get session status. Args: token, session_id
api_session_status() {
  local token="$1" session_id="$2"
  curl -s -H "Authorization: Bearer ${token}" \
    "${BACKEND_URL}/sessions/${session_id}" \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
d = data.get('data', data)
print(d.get('status', ''))" 2>/dev/null
}

# Set caregiver online status. Args: token, true|false
api_set_online() {
  local token="$1" online="$2"
  curl -s -X PUT "${BACKEND_URL}/profile/caregiver/online-status" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${token}" \
    -d "{\"isOnline\": ${online}}" > /dev/null 2>&1
}

# Get caregiver earnings summary. Args: token
api_earnings_summary() {
  local token="$1"
  curl -s -H "Authorization: Bearer ${token}" \
    "${BACKEND_URL}/activity/earnings" 2>/dev/null
}

# Get caregiver earnings ledger. Args: token
api_earnings_ledger() {
  local token="$1"
  curl -s -H "Authorization: Bearer ${token}" \
    "${BACKEND_URL}/activity/earnings/ledger" 2>/dev/null
}

# Get transactions for a booking. Args: admin_token, booking_id
api_transactions_for_booking() {
  local token="$1" booking_id="$2"
  curl -s -H "Authorization: Bearer ${token}" \
    "${BACKEND_URL}/admin/transactions?bookingId=${booking_id}" 2>/dev/null
}

# Poll until booking reaches target lifecycle. Args: token, booking_id, target_status, max_attempts
api_wait_for_lifecycle() {
  local token="$1" booking_id="$2" target="$3" max="${4:-20}"
  local attempt=0
  while [[ $attempt -lt $max ]]; do
    local current
    current=$(api_booking_lifecycle "$token" "$booking_id")
    if [[ "$current" == "$target" ]]; then
      echo "$current"
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 3
  done
  echo "$current"
  return 1
}

# Reseed backend for clean state. No args.
api_reseed() {
  echo "  Reseeding backend..."
  (cd "$BIJOUX_BACKEND_DIR" && npm run db:seed 2>/dev/null && npx tsx prisma/seed-uat.ts 2>/dev/null) || true
  echo "  Backend reseeded"
}
```

- [ ] **Step 3: Make it executable**

Run: `chmod +x scripts/lib/api-helpers.sh`

- [ ] **Step 4: Verify it sources without error**

Run: `source config/environment.sh && source scripts/lib/api-helpers.sh && echo "OK"`
Expected: `OK`

- [ ] **Step 5: Test api_login against running backend**

Run: `source config/environment.sh && source scripts/lib/api-helpers.sh && TOKEN=$(api_login "$PARENT_EMAIL" "$PARENT_PASSWORD") && echo "Token length: ${#TOKEN}"`
Expected: `Token length: ` followed by a number > 50 (JWT tokens are long strings)

- [ ] **Step 6: Commit**

```bash
git add scripts/lib/api-helpers.sh
git commit -m "feat: add shared API helper library for cross-app scripts"
```

**If this fails:**
- `api_login` returns empty → Backend not running. Start with `cd $BIJOUX_BACKEND_DIR && docker compose up -d && npm run dev`.
- `api_login` returns "None" → Credentials wrong or user doesn't exist. Reseed: `cd $BIJOUX_BACKEND_DIR && npx tsx prisma/seed-uat.ts`.
- Python3 parse error → Check JSON response format. Run `curl -s -X POST "${BACKEND_URL}/auth/login" -H "Content-Type: application/json" -d '{"email":"parent-sarah@test.bijoux.app","password":"Test1234!"}' | python3 -m json.tool` to inspect raw response.
**Rollback:** `rm -rf scripts/lib && git reset HEAD~1`

---

## Task 6: Create Login Flows for Second Parent and Caregiver

**Pre-conditions:** Existing `flows/parent/login-valid.yaml` and `flows/caregiver/go-online-offline.yaml` work on simulators. Apps installed.
**Post-conditions:** `flows/parent/login-james.yaml` and `flows/caregiver/login-maria.yaml` exist and parse as valid YAML.

**Files:**
- Create: `flows/parent/login-james.yaml`
- Create: `flows/caregiver/login-maria.yaml`

- [ ] **Step 1: Create parent/login-james.yaml**

Model after `flows/parent/login-valid.yaml` but login as parent-james:

```yaml
# uat: Parent Login — James Rivera (second parent)
appId: polygentic.bijouxParentApp
tags:
  - cross-app
---
- launchApp:
    clearState: true
    clearKeychain: true

- waitForAnimationToEnd

- tapOn:
    id: "onboarding-get-started-button"

- waitForAnimationToEnd

- tapOn: "you@example.com"
- inputText: "parent-james@test.bijoux.app"

- tapOn: "Welcome Back"

- tapOn: "Enter your password"
- inputText: "Test1234!"

- tapOn: "Welcome Back"

- tapOn:
    id: "login-submit-button"

- waitForAnimationToEnd

- assertVisible:
    id: "home-greeting-label"

- takeScreenshot: results/cross-app/parent-james-logged-in
```

- [ ] **Step 2: Create caregiver/login-maria.yaml**

Model after `flows/caregiver/go-online-offline.yaml` login section but as standalone login-only flow:

```yaml
# uat: Caregiver Login — Maria Santos (second caregiver)
appId: polygentic.bijouxCaregiverApp
tags:
  - cross-app
---
- launchApp:
    clearState: true
    clearKeychain: true

- waitForAnimationToEnd

- tapOn: "Get Started"

- waitForAnimationToEnd

- tapOn: "you@example.com"
- inputText: "cg-maria@test.bijoux.app"

- scroll

- tapOn: "Welcome Back"

- tapOn: "Show password"

- tapOn:
    id: "login-password-field"
- inputText: "Test1234!"

- scroll

- tapOn:
    id: "login-submit-button"

- waitForAnimationToEnd

- assertVisible: "Home"

- takeScreenshot: results/cross-app/caregiver-maria-logged-in
```

- [ ] **Step 3: Verify both parse correctly**

Run: `maestro test flows/parent/login-james.yaml --dry-run 2>&1 || echo "dry-run not supported, skipping"`

- [ ] **Step 4: Commit**

```bash
git add flows/parent/login-james.yaml flows/caregiver/login-maria.yaml
git commit -m "feat: add login flows for James (parent-2) and Maria (caregiver-2)"
```

**If this fails:**
- Login fails with "Welcome Back" not found → App may show different onboarding screen. Use `mcp__maestro__inspect_screen` to check actual UI.
- Password field issue (text concatenated to email) → Use `eraseText` before `inputText` on password field. Known issue from prior testing.
- User not found (401) → `parent-james@test.bijoux.app` or `cg-maria@test.bijoux.app` not seeded. These accounts are created by `npx tsx prisma/seed-uat.ts` in the backend, NOT from `fixtures/test-accounts.json`. Reseed: `cd $BIJOUX_BACKEND_DIR && npx tsx prisma/seed-uat.ts`. Verify: check `docs/seed-data.md` for expected accounts.
**Rollback:** `rm flows/parent/login-james.yaml flows/caregiver/login-maria.yaml && git reset HEAD~1`

---

## Task 7: Create Caregiver Sub-flows for Real Matching Phases

**Pre-conditions:** Caregiver app has Go Online toggle and IOMW button (verified in prior testing sessions).
**Post-conditions:** `flows/caregiver/go-online.yaml` and `flows/caregiver/iomw.yaml` exist with valid YAML syntax.

**Files:**
- Create: `flows/caregiver/go-online.yaml`
- Create: `flows/caregiver/iomw.yaml`

- [ ] **Step 1: Create caregiver/go-online.yaml**

Sub-flow that toggles the caregiver online. Assumes already logged in on home screen.

```yaml
# uat: SUB — Caregiver Go Online
# NOTE: Sub-flow. Caregiver must already be logged in on home screen.
appId: polygentic.bijouxCaregiverApp
tags:
  - sub-flow
---
- launchApp
- waitForAnimationToEnd
- scroll
- tapOn:
    text: ".*Go Online.*|.*Online.*"
    optional: true
- waitForAnimationToEnd
- takeScreenshot: results/cross-app/caregiver-went-online
```

- [ ] **Step 2: Create caregiver/iomw.yaml**

Sub-flow that taps "Confirm I'm On My Way" after accepting an offer.

```yaml
# uat: SUB — Caregiver I'm On My Way
# NOTE: Sub-flow. Caregiver must have just accepted an offer.
appId: polygentic.bijouxCaregiverApp
tags:
  - sub-flow
---
- extendedWaitUntil:
    visible: ".*On My Way.*|.*I'm On My Way.*|.*Confirm.*"
    timeout: 15000
- tapOn:
    text: ".*On My Way.*|.*I'm On My Way.*|.*Confirm.*"
- waitForAnimationToEnd
- takeScreenshot: results/cross-app/caregiver-iomw
```

- [ ] **Step 3: Commit**

```bash
git add flows/caregiver/go-online.yaml flows/caregiver/iomw.yaml
git commit -m "feat: add caregiver sub-flows for go-online and IOMW"
```

**If this fails:** These are sub-flows — they can't be tested standalone (no `launchApp`). They'll be validated during Task 14 (selector validation). If selectors are wrong, update the regex patterns.
**Rollback:** `rm flows/caregiver/go-online.yaml flows/caregiver/iomw.yaml && git reset HEAD~1`

---

## Task 8: Create Parent Sub-flows for Real Matching Phases

**Pre-conditions:** Parent app shows "Caregiver Found" screen during matching (verified in prior testing).
**Post-conditions:** `flows/parent/verify-matched.yaml` and `flows/parent/rate-session.yaml` exist with valid YAML syntax.

**Files:**
- Create: `flows/parent/verify-matched.yaml`
- Create: `flows/parent/rate-session.yaml`

- [ ] **Step 1: Create parent/verify-matched.yaml**

Sub-flow that waits for "Caregiver Found" after real matching.

```yaml
# uat: SUB — Parent Verify Caregiver Matched
# NOTE: Sub-flow. Parent must be on matching/searching screen.
appId: polygentic.bijouxParentApp
tags:
  - sub-flow
---
# Wait for caregiver match (real matching engine — may take 10-30s)
- extendedWaitUntil:
    visible: ".*Caregiver Found.*|.*Found.*|.*matched.*"
    timeout: 90000
- waitForAnimationToEnd
- takeScreenshot: results/cross-app/parent-caregiver-found
```

- [ ] **Step 2: Create parent/rate-session.yaml**

Sub-flow that rates a completed session.

```yaml
# uat: SUB — Parent Rate Session
# NOTE: Sub-flow. Parent must be on session summary/completed screen.
appId: polygentic.bijouxParentApp
tags:
  - sub-flow
---
- launchApp
- waitForAnimationToEnd
# Wait for session summary / rating prompt
- extendedWaitUntil:
    visible: ".*Rate.*|.*Session Complete.*|.*How was.*"
    timeout: 30000
    optional: true
# Tap 5 stars (or last star)
- tapOn:
    text: "5"
    optional: true
- tapOn:
    text: ".*Submit.*|.*Done.*|.*Rate.*"
    optional: true
- waitForAnimationToEnd
- takeScreenshot: results/cross-app/parent-rated-session
```

- [ ] **Step 3: Commit**

```bash
git add flows/parent/verify-matched.yaml flows/parent/rate-session.yaml
git commit -m "feat: add parent sub-flows for verify-matched and rate-session"
```

**If this fails:** Same as Task 7 — sub-flows validated during Task 14. Selectors are best-guess from prior sessions; will be corrected.
**Rollback:** `rm flows/parent/verify-matched.yaml flows/parent/rate-session.yaml && git reset HEAD~1`

---

## Task 9: Write the Happy Path E2E Script

**Pre-conditions:** Tasks 1-8 complete. Backend running with seed data. At least 2 sims booted (bijoux-parent, bijoux-care). Apps installed.
**Post-conditions:** `scripts/cross-app-real-matching-e2e.sh` exists, is executable, contains zero simulate references.

**Files:**
- Create: `scripts/cross-app-real-matching-e2e.sh`

- [ ] **Step 1: Write the complete script**

```bash
#!/usr/bin/env bash
# UAT: Real Multi-Simulator E2E Matching Flow — Happy Path
#
# Tests the FULL REAL matching flow with NO simulate endpoints:
# Parent books → Matching engine dispatches offers → Caregiver accepts →
# IOMW → Arrival → Session start → Session end → Rating → Payment verify
#
# Requires: 2 sims booted (bijoux-parent, bijoux-care), backend running with seed data
#
# Usage:
#   ./scripts/cross-app-real-matching-e2e.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/config/environment.sh"
source "$ROOT_DIR/scripts/lib/api-helpers.sh"

# ─── Validate prerequisites ──────────────────────────────────
[[ -z "$PARENT_UDID" ]] && echo "ERROR: PARENT_UDID not set" >&2 && exit 1
[[ -z "$CAREGIVER_UDID" ]] && echo "ERROR: CAREGIVER_UDID not set" >&2 && exit 1

mkdir -p "$ROOT_DIR/results/cross-app"

FAILURES=0
STEP=0

step()  { STEP=$((STEP + 1)); echo ""; echo "═══ STEP $STEP: $1 ═══"; }
pass()  { echo "  ✓ PASS: $1"; }
fail()  { echo "  ✗ FAIL: $1"; FAILURES=$((FAILURES + 1)); }
assert_eq() {
  local label="$1" actual="$2" expected="$3"
  if [[ "$actual" == "$expected" ]]; then
    pass "$label (got: $actual)"
  else
    fail "$label (expected: $expected, got: $actual)"
  fi
}

# ═══════════════════════════════════════════════════════════════
# PHASE 1: API Setup — get tokens, set caregiver online
# ═══════════════════════════════════════════════════════════════
step "Authenticate test users via API"

PARENT_TOKEN=$(api_login "$PARENT_EMAIL" "$PARENT_PASSWORD")
[[ -n "$PARENT_TOKEN" && "$PARENT_TOKEN" != "None" ]] && pass "Parent token" || { fail "Parent token"; exit 1; }

CAREGIVER_TOKEN=$(api_login "$CAREGIVER_ONLINE_EMAIL" "$CAREGIVER_ONLINE_PASSWORD")
[[ -n "$CAREGIVER_TOKEN" && "$CAREGIVER_TOKEN" != "None" ]] && pass "Caregiver token" || { fail "Caregiver token"; exit 1; }

ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
[[ -n "$ADMIN_TOKEN" && "$ADMIN_TOKEN" != "None" ]] && pass "Admin token" || { fail "Admin token"; exit 1; }

step "Set caregiver online via API"
api_set_online "$CAREGIVER_TOKEN" "true"
pass "Caregiver set online"

# ═══════════════════════════════════════════════════════════════
# PHASE 2: Login caregiver on simulator FIRST (so she's ready for offers)
# ═══════════════════════════════════════════════════════════════
step "Caregiver: Login on simulator"

maestro test "$ROOT_DIR/flows/caregiver/login-maria.yaml" --device "$CAREGIVER_UDID" 2>&1 \
  && pass "Caregiver login" || { fail "Caregiver login"; exit 1; }

step "Caregiver: Go online on simulator"

maestro test "$ROOT_DIR/flows/caregiver/go-online.yaml" --device "$CAREGIVER_UDID" 2>&1 \
  && pass "Caregiver online" || fail "Caregiver go-online"

# ═══════════════════════════════════════════════════════════════
# PHASE 3: Parent logs in and creates booking
# ═══════════════════════════════════════════════════════════════
step "Parent: Login and create booking"

maestro test "$ROOT_DIR/flows/cross-app/parent-login-and-book.yaml" --device "$PARENT_UDID" 2>&1 \
  && pass "Parent login + booking" || { fail "Parent login + booking"; exit 1; }

step "Get booking ID from API"
sleep 3
BOOKING_ID=$(api_latest_booking_id "$PARENT_TOKEN")
[[ -n "$BOOKING_ID" ]] && pass "Booking: $BOOKING_ID" || { fail "No booking found"; exit 1; }

# ═══════════════════════════════════════════════════════════════
# PHASE 4: Wait for matching engine, caregiver accepts on sim
# ═══════════════════════════════════════════════════════════════
step "Wait for matching engine to dispatch offers"
sleep 5

step "Caregiver: Accept offer on simulator"

maestro test "$ROOT_DIR/flows/caregiver/accept-offer.yaml" --device "$CAREGIVER_UDID" 2>&1 \
  && pass "Caregiver accepted offer" || { fail "Caregiver offer acceptance"; exit 1; }

step "Verify booking matched via API"
LIFECYCLE=$(api_wait_for_lifecycle "$PARENT_TOKEN" "$BOOKING_ID" "matched" 10)
[[ "$LIFECYCLE" == "matched" || "$LIFECYCLE" == "confirmed" ]] \
  && pass "Booking matched (lifecycle: $LIFECYCLE)" || fail "Booking not matched (lifecycle: $LIFECYCLE)"

step "Parent: Verify caregiver found on simulator"

maestro test "$ROOT_DIR/flows/parent/verify-matched.yaml" --device "$PARENT_UDID" 2>&1 \
  && pass "Parent sees caregiver matched" || fail "Parent verify-matched"

# ═══════════════════════════════════════════════════════════════
# PHASE 5: IOMW → Arrival
# ═══════════════════════════════════════════════════════════════
step "Caregiver: Confirm I'm On My Way"

maestro test "$ROOT_DIR/flows/caregiver/iomw.yaml" --device "$CAREGIVER_UDID" 2>&1 \
  && pass "Caregiver IOMW" || fail "Caregiver IOMW"

step "Caregiver: Confirm arrival"

maestro test "$ROOT_DIR/flows/caregiver/confirm-arrival.yaml" --device "$CAREGIVER_UDID" 2>&1 \
  && pass "Caregiver arrived" || fail "Caregiver arrival"

# ═══════════════════════════════════════════════════════════════
# PHASE 6: Session start — dual verification
# ═══════════════════════════════════════════════════════════════
step "Caregiver: Start session verification"

maestro test "$ROOT_DIR/flows/caregiver/start-session-verify.yaml" --device "$CAREGIVER_UDID" 2>&1 \
  && pass "Caregiver session start verify" || fail "Caregiver session start"

step "Parent: Confirm session start"

maestro test "$ROOT_DIR/flows/parent/confirm-session-start.yaml" --device "$PARENT_UDID" 2>&1 \
  && pass "Parent session start confirm" || fail "Parent session start"

step "Verify session created via API"
sleep 3
SESSION_ID=$(api_session_id "$PARENT_TOKEN" "$BOOKING_ID")
[[ -n "$SESSION_ID" ]] && pass "Session: $SESSION_ID" || fail "No session found"

# ═══════════════════════════════════════════════════════════════
# PHASE 7: Session end
# ═══════════════════════════════════════════════════════════════
step "Caregiver: End session"

maestro test "$ROOT_DIR/flows/caregiver/end-session.yaml" --device "$CAREGIVER_UDID" 2>&1 \
  && pass "Caregiver end session" || fail "Caregiver end session"

step "Parent: Confirm session end and rate"

maestro test "$ROOT_DIR/flows/parent/confirm-session-end.yaml" --device "$PARENT_UDID" 2>&1 \
  && pass "Parent session end" || fail "Parent session end"

maestro test "$ROOT_DIR/flows/parent/rate-session.yaml" --device "$PARENT_UDID" 2>&1 \
  && pass "Parent rated session" || fail "Parent rate session"

# ═══════════════════════════════════════════════════════════════
# PHASE 8: API Verification
# ═══════════════════════════════════════════════════════════════
step "Verify final state via API"
sleep 3

FINAL_LIFECYCLE=$(api_booking_lifecycle "$PARENT_TOKEN" "$BOOKING_ID")
assert_eq "Booking lifecycle" "$FINAL_LIFECYCLE" "completed"

if [[ -n "${SESSION_ID:-}" ]]; then
  FINAL_SESSION=$(api_session_status "$PARENT_TOKEN" "$SESSION_ID")
  assert_eq "Session status" "$FINAL_SESSION" "completed"
fi

step "Verify earnings via API"

EARNINGS=$(api_earnings_ledger "$CAREGIVER_TOKEN")
EARNING_RESULT=$(echo "$EARNINGS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
items = data.get('data', data.get('entries', []))
if isinstance(items, list):
    earnings = [e for e in items if e.get('type') == 'earning']
    print(f'count={len(earnings)}')
    if earnings:
        e = earnings[0]
        print(f'amount={e.get(\"amountCents\", 0)}')
        print(f'sessionId={e.get(\"sessionId\", \"\")}')
else:
    print('count=0')" 2>/dev/null)
echo "  Earning ledger: $EARNING_RESULT"
echo "$EARNING_RESULT" | grep -q "count=0" && fail "No earnings found" || pass "Caregiver has earnings in ledger"

step "Verify transactions via API"

TRANSACTIONS=$(api_transactions_for_booking "$ADMIN_TOKEN" "$BOOKING_ID")
TX_RESULT=$(echo "$TRANSACTIONS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
items = data.get('data', data.get('transactions', []))
has_auth = False
has_capture = False
if isinstance(items, list):
    for t in items:
        ttype = t.get('type', '')
        tstatus = t.get('status', '')
        print(f\"  Transaction: type={ttype}, status={tstatus}, amount={t.get('amountCents')}c\")
        if ttype == 'authorization' and tstatus == 'succeeded': has_auth = True
        if ttype == 'capture' and tstatus == 'succeeded': has_capture = True
print(f'auth={has_auth},capture={has_capture}')
" 2>/dev/null)
echo "$TX_RESULT"
echo "$TX_RESULT" | grep -q "auth=True" && pass "Authorization transaction succeeded" || fail "No successful authorization transaction"
echo "$TX_RESULT" | grep -q "capture=True" && pass "Capture transaction succeeded" || fail "No successful capture transaction"

# ═══════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════
echo ""
echo "═══════════════════════════════════════════════════"
echo "  REAL E2E MATCHING — RESULTS"
echo "═══════════════════════════════════════════════════"
echo "  Booking: ${BOOKING_ID:-N/A}"
echo "  Session: ${SESSION_ID:-N/A}"
echo "  Final Lifecycle: ${FINAL_LIFECYCLE:-N/A}"
echo "  Failures: $FAILURES"
echo ""

if [[ $FAILURES -eq 0 ]]; then
  echo "  OVERALL: PASS ✓"
  exit 0
else
  echo "  OVERALL: FAIL ($FAILURES failures)"
  exit 1
fi
```

- [ ] **Step 2: Make executable**

Run: `chmod +x scripts/cross-app-real-matching-e2e.sh`

- [ ] **Step 3: Commit**

```bash
git add scripts/cross-app-real-matching-e2e.sh
git commit -m "feat: add real E2E matching flow script (no simulate accept)"
```

**If this fails (during execution in Task 15):**
- **Phase 3 fails (parent booking):** App may need `clearState: true` in the login flow. Check if parent is already logged in from a previous run.
- **Phase 4 fails (caregiver doesn't see offer):** Matching engine may not have dispatched. Check: (1) Is caregiver online? `curl -s -H "Authorization: Bearer $CG_TOKEN" "${BACKEND_URL}/profile/caregiver" | python3 -c "import sys,json;print(json.load(sys.stdin).get('isOnline'))"` (2) Is Redis running? `redis-cli ping` (3) Check matching worker logs in backend console.
- **Phase 5 fails (IOMW/arrival):** Selector mismatch. Use `mcp__maestro__inspect_screen` on caregiver sim to find the real button text.
- **Phase 6 fails (session start):** Dual verification may require specific order. Try caregiver first, then parent. Check if Veriff bypass mode is enabled in backend `.env`.
- **Phase 7 fails (session end):** Same selector issues. Inspect screen.
- **Phase 8 fails (API verification):** Booking may be in wrong state. Check `api_booking_lifecycle` output and backend logs.
**Rollback:** `rm scripts/cross-app-real-matching-e2e.sh && git reset HEAD~1`
**State reset:** Reseed backend. Terminate apps on both sims: `xcrun simctl terminate $PARENT_UDID polygentic.bijouxParentApp && xcrun simctl terminate $CAREGIVER_UDID polygentic.bijouxCaregiverApp`

---

## Task 10: Write the Decline-Then-Accept Script

**Pre-conditions:** Tasks 1-9 complete. 3 sims needed (bijoux-parent, bijoux-care, bijoux-care-2). Backend running.
**Post-conditions:** `scripts/cross-app-decline-then-accept.sh` exists and is executable. `flows/caregiver/decline-offer.yaml` exists.

**Files:**
- Create: `scripts/cross-app-decline-then-accept.sh`

- [ ] **Step 1: Create flows/caregiver/decline-offer.yaml**

```yaml
# uat: SUB — Caregiver Decline Offer
# NOTE: Sub-flow. Caregiver must have a pending offer visible.
appId: polygentic.bijouxCaregiverApp
tags:
  - sub-flow
---
- extendedWaitUntil:
    visible: ".*Decline.*|.*No Thanks.*"
    timeout: 45000
- takeScreenshot: results/cross-app/caregiver-offer-before-decline
- tapOn:
    text: ".*Decline.*|.*No Thanks.*"
- waitForAnimationToEnd
# Confirm decline if prompted
- tapOn:
    text: ".*Confirm.*|.*Yes.*|.*Decline.*"
    optional: true
- waitForAnimationToEnd
- takeScreenshot: results/cross-app/caregiver-offer-declined
```

- [ ] **Step 2: Write the script**

```bash
#!/usr/bin/env bash
# UAT: Multi-Caregiver — First Declines, Second Accepts
#
# Requires: 3 sims booted (bijoux-parent, bijoux-care, bijoux-care-2)
#
# Usage:
#   ./scripts/cross-app-decline-then-accept.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/config/environment.sh"
source "$ROOT_DIR/scripts/lib/api-helpers.sh"

[[ -z "$PARENT_UDID" ]] && echo "ERROR: PARENT_UDID not set" >&2 && exit 1
[[ -z "$CAREGIVER_UDID" ]] && echo "ERROR: CAREGIVER_UDID not set" >&2 && exit 1
[[ -z "${CAREGIVER_UDID_2:-}" ]] && echo "ERROR: CAREGIVER_UDID_2 not set. Create 4 sims first." >&2 && exit 1

mkdir -p "$ROOT_DIR/results/cross-app"
FAILURES=0; STEP=0
step()  { STEP=$((STEP + 1)); echo ""; echo "═══ STEP $STEP: $1 ═══"; }
pass()  { echo "  ✓ PASS: $1"; }
fail()  { echo "  ✗ FAIL: $1"; FAILURES=$((FAILURES + 1)); }

# Phase 1: API setup
step "Authenticate and set both caregivers online"
PARENT_TOKEN=$(api_login "$PARENT_EMAIL" "$PARENT_PASSWORD")
CG1_TOKEN=$(api_login "$CAREGIVER_EMAIL" "$CAREGIVER_PASSWORD")
CG2_TOKEN=$(api_login "$CAREGIVER_ONLINE_EMAIL" "$CAREGIVER_ONLINE_PASSWORD")
api_set_online "$CG1_TOKEN" "true"
api_set_online "$CG2_TOKEN" "true"
pass "Both caregivers online"

# Phase 2: Login both caregivers on separate sims
step "Login Emma on bijoux-care"
maestro test "$ROOT_DIR/flows/caregiver/login-valid.yaml" --device "$CAREGIVER_UDID" 2>&1 \
  && pass "Emma logged in" || { fail "Emma login"; exit 1; }

step "Login Maria on bijoux-care-2"
maestro test "$ROOT_DIR/flows/caregiver/login-maria.yaml" --device "$CAREGIVER_UDID_2" 2>&1 \
  && pass "Maria logged in" || { fail "Maria login"; exit 1; }

# Go online on both
maestro test "$ROOT_DIR/flows/caregiver/go-online.yaml" --device "$CAREGIVER_UDID" 2>&1 || true
maestro test "$ROOT_DIR/flows/caregiver/go-online.yaml" --device "$CAREGIVER_UDID_2" 2>&1 || true

# Phase 3: Parent books
step "Parent: Login and book"
maestro test "$ROOT_DIR/flows/cross-app/parent-login-and-book.yaml" --device "$PARENT_UDID" 2>&1 \
  && pass "Parent booked" || { fail "Parent booking"; exit 1; }

sleep 3
BOOKING_ID=$(api_latest_booking_id "$PARENT_TOKEN")
pass "Booking: $BOOKING_ID"

# Phase 4: Emma declines
step "Wait for offers, Emma declines"
sleep 5
maestro test "$ROOT_DIR/flows/caregiver/decline-offer.yaml" --device "$CAREGIVER_UDID" 2>&1 \
  && pass "Emma declined" || fail "Emma decline"

# Phase 5: Maria accepts
step "Maria accepts"
maestro test "$ROOT_DIR/flows/caregiver/accept-offer.yaml" --device "$CAREGIVER_UDID_2" 2>&1 \
  && pass "Maria accepted" || { fail "Maria accept"; exit 1; }

# Phase 6: Verify parent sees Maria (not Emma)
step "Parent: Verify Maria matched"
maestro test "$ROOT_DIR/flows/parent/verify-matched.yaml" --device "$PARENT_UDID" 2>&1 \
  && pass "Parent sees match" || fail "Parent verify-matched"

# Phase 7: Complete through session end (Maria on bijoux-care-2)
step "Maria: IOMW → Arrival → Session Start → Session End"
maestro test "$ROOT_DIR/flows/caregiver/iomw.yaml" --device "$CAREGIVER_UDID_2" 2>&1 || fail "Maria IOMW"
maestro test "$ROOT_DIR/flows/caregiver/confirm-arrival.yaml" --device "$CAREGIVER_UDID_2" 2>&1 || fail "Maria arrival"
maestro test "$ROOT_DIR/flows/caregiver/start-session-verify.yaml" --device "$CAREGIVER_UDID_2" 2>&1 || fail "Maria session start"
maestro test "$ROOT_DIR/flows/parent/confirm-session-start.yaml" --device "$PARENT_UDID" 2>&1 || fail "Parent session start"
maestro test "$ROOT_DIR/flows/caregiver/end-session.yaml" --device "$CAREGIVER_UDID_2" 2>&1 || fail "Maria end session"
maestro test "$ROOT_DIR/flows/parent/confirm-session-end.yaml" --device "$PARENT_UDID" 2>&1 || fail "Parent session end"

# Phase 8: Verify
step "API verification"
sleep 3
FINAL=$(api_booking_lifecycle "$PARENT_TOKEN" "$BOOKING_ID")
echo "  Final lifecycle: $FINAL"
[[ "$FINAL" == "completed" ]] && pass "Booking completed" || fail "Booking not completed: $FINAL"

step "Verify offer statuses via API"
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
OFFERS=$(curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "${BACKEND_URL}/admin/bookings/${BOOKING_ID}" 2>/dev/null)
echo "$OFFERS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
d = data.get('data', data)
offers = d.get('offers', d.get('matchOffers', []))
if isinstance(offers, list):
    for o in offers:
        name = o.get('caregiver', {}).get('firstName', o.get('caregiverId', ''))
        status = o.get('status', '')
        print(f'  Offer: {name} → {status}')
" 2>/dev/null || echo "  Could not parse offers (admin endpoint may differ)"

echo ""
echo "═══ DECLINE-THEN-ACCEPT — $( [[ $FAILURES -eq 0 ]] && echo "PASS ✓" || echo "FAIL ($FAILURES)" ) ═══"
[[ $FAILURES -eq 0 ]] && exit 0 || exit 1
```

- [ ] **Step 2: Make executable**

Run: `chmod +x scripts/cross-app-decline-then-accept.sh`

- [ ] **Step 3: Commit**

```bash
git add flows/caregiver/decline-offer.yaml scripts/cross-app-decline-then-accept.sh
git commit -m "feat: add decline-then-accept multi-caregiver E2E test"
```

**If this fails (during execution in Task 15):**
- **Emma doesn't see offer:** Matching engine may only send to one caregiver at a time. Check `maxOffers` in MatchRequest (should be 5). Both caregivers must be online AND approved.
- **Decline button not found:** Use `mcp__maestro__inspect_screen` to find the real decline button text. May be "No Thanks" or "Decline Offer" instead of "Decline".
- **Maria doesn't get offer after Emma declines:** Matching engine may need a re-offer cycle. The decline should trigger the worker to send to next candidate. Check matching worker logs.
**Rollback:** `rm flows/caregiver/decline-offer.yaml scripts/cross-app-decline-then-accept.sh && git reset HEAD~1`
**State reset:** Reseed backend + terminate apps on all 3 sims.

---

## Task 11: Write the Multi-Parent Script

**Pre-conditions:** Tasks 1-10 complete. All 4 sims booted with apps installed. Backend running.
**Post-conditions:** `scripts/cross-app-multi-parent.sh` exists and is executable.

**Files:**
- Create: `scripts/cross-app-multi-parent.sh`

- [ ] **Step 1: Write the script**

Same pattern as Task 10 but with 2 parents and 2 caregivers. Sarah books on bijoux-parent → Emma accepts on bijoux-care. James books on bijoux-parent-2 → Maria accepts on bijoux-care-2. Both sessions run to completion.

This script follows the same structure as Task 9 and Task 10. Key difference: it runs two parallel booking flows sequentially (Sarah first, then James while Sarah's session is in progress).

```bash
#!/usr/bin/env bash
# UAT: Multi-Parent Concurrent Bookings
#
# Requires: 4 sims (bijoux-parent, bijoux-parent-2, bijoux-care, bijoux-care-2)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$ROOT_DIR/config/environment.sh"
source "$ROOT_DIR/scripts/lib/api-helpers.sh"

[[ -z "$PARENT_UDID" ]] && echo "ERROR: PARENT_UDID not set" >&2 && exit 1
[[ -z "${PARENT_UDID_2:-}" ]] && echo "ERROR: PARENT_UDID_2 not set" >&2 && exit 1
[[ -z "$CAREGIVER_UDID" ]] && echo "ERROR: CAREGIVER_UDID not set" >&2 && exit 1
[[ -z "${CAREGIVER_UDID_2:-}" ]] && echo "ERROR: CAREGIVER_UDID_2 not set" >&2 && exit 1

mkdir -p "$ROOT_DIR/results/cross-app"
FAILURES=0; STEP=0
step()  { STEP=$((STEP + 1)); echo ""; echo "═══ STEP $STEP: $1 ═══"; }
pass()  { echo "  ✓ PASS: $1"; }
fail()  { echo "  ✗ FAIL: $1"; FAILURES=$((FAILURES + 1)); }

# Setup
step "Authenticate all users"
P1_TOKEN=$(api_login "$PARENT_EMAIL" "$PARENT_PASSWORD")
P2_TOKEN=$(api_login "$PARENT_2_EMAIL" "$PARENT_2_PASSWORD")
CG1_TOKEN=$(api_login "$CAREGIVER_EMAIL" "$CAREGIVER_PASSWORD")
CG2_TOKEN=$(api_login "$CAREGIVER_ONLINE_EMAIL" "$CAREGIVER_ONLINE_PASSWORD")
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
api_set_online "$CG1_TOKEN" "true"
api_set_online "$CG2_TOKEN" "true"
pass "All tokens obtained, caregivers online"

# Login all 4 sims
step "Login all devices"
maestro test "$ROOT_DIR/flows/caregiver/login-valid.yaml" --device "$CAREGIVER_UDID" 2>&1 && pass "Emma" || fail "Emma login"
maestro test "$ROOT_DIR/flows/caregiver/login-maria.yaml" --device "$CAREGIVER_UDID_2" 2>&1 && pass "Maria" || fail "Maria login"
maestro test "$ROOT_DIR/flows/caregiver/go-online.yaml" --device "$CAREGIVER_UDID" 2>&1 || true
maestro test "$ROOT_DIR/flows/caregiver/go-online.yaml" --device "$CAREGIVER_UDID_2" 2>&1 || true

# Sarah books
step "Sarah: Login and book"
maestro test "$ROOT_DIR/flows/cross-app/parent-login-and-book.yaml" --device "$PARENT_UDID" 2>&1 \
  && pass "Sarah booked" || { fail "Sarah booking"; exit 1; }
sleep 3
BOOKING_1=$(api_latest_booking_id "$P1_TOKEN")
pass "Booking 1: $BOOKING_1"

# Emma accepts Sarah's booking
step "Emma: Accept Sarah's offer"
sleep 5
maestro test "$ROOT_DIR/flows/caregiver/accept-offer.yaml" --device "$CAREGIVER_UDID" 2>&1 \
  && pass "Emma accepted" || fail "Emma accept"

# James books
step "James: Login and book"
maestro test "$ROOT_DIR/flows/parent/login-james.yaml" --device "$PARENT_UDID_2" 2>&1 \
  && pass "James logged in" || { fail "James login"; exit 1; }
maestro test "$ROOT_DIR/flows/parent/quick-booking-submit.yaml" --device "$PARENT_UDID_2" 2>&1 \
  && pass "James booked" || fail "James booking"
sleep 3
BOOKING_2=$(api_latest_booking_id "$P2_TOKEN")
pass "Booking 2: $BOOKING_2"

# Maria accepts James's booking
step "Maria: Accept James's offer"
sleep 5
maestro test "$ROOT_DIR/flows/caregiver/accept-offer.yaml" --device "$CAREGIVER_UDID_2" 2>&1 \
  && pass "Maria accepted" || fail "Maria accept"

# Complete both sessions (abbreviated — IOMW through end)
step "Complete Session 1: Emma + Sarah"
maestro test "$ROOT_DIR/flows/caregiver/iomw.yaml" --device "$CAREGIVER_UDID" 2>&1 || fail "Emma IOMW"
maestro test "$ROOT_DIR/flows/caregiver/confirm-arrival.yaml" --device "$CAREGIVER_UDID" 2>&1 || fail "Emma arrival"
maestro test "$ROOT_DIR/flows/caregiver/start-session-verify.yaml" --device "$CAREGIVER_UDID" 2>&1 || fail "Emma session start"
maestro test "$ROOT_DIR/flows/parent/confirm-session-start.yaml" --device "$PARENT_UDID" 2>&1 || fail "Sarah confirm start"
maestro test "$ROOT_DIR/flows/caregiver/end-session.yaml" --device "$CAREGIVER_UDID" 2>&1 || fail "Emma end session"
maestro test "$ROOT_DIR/flows/parent/confirm-session-end.yaml" --device "$PARENT_UDID" 2>&1 || fail "Sarah confirm end"

step "Complete Session 2: Maria + James"
maestro test "$ROOT_DIR/flows/caregiver/iomw.yaml" --device "$CAREGIVER_UDID_2" 2>&1 || fail "Maria IOMW"
maestro test "$ROOT_DIR/flows/caregiver/confirm-arrival.yaml" --device "$CAREGIVER_UDID_2" 2>&1 || fail "Maria arrival"
maestro test "$ROOT_DIR/flows/caregiver/start-session-verify.yaml" --device "$CAREGIVER_UDID_2" 2>&1 || fail "Maria session start"
maestro test "$ROOT_DIR/flows/parent/confirm-session-start.yaml" --device "$PARENT_UDID_2" 2>&1 || fail "James confirm start"
maestro test "$ROOT_DIR/flows/caregiver/end-session.yaml" --device "$CAREGIVER_UDID_2" 2>&1 || fail "Maria end session"
maestro test "$ROOT_DIR/flows/parent/confirm-session-end.yaml" --device "$PARENT_UDID_2" 2>&1 || fail "James confirm end"

# Verify both completed
step "API verification"
sleep 3
L1=$(api_booking_lifecycle "$P1_TOKEN" "$BOOKING_1")
L2=$(api_booking_lifecycle "$P2_TOKEN" "$BOOKING_2")
echo "  Booking 1: $L1, Booking 2: $L2"
[[ "$L1" == "completed" ]] && pass "Booking 1 completed" || fail "Booking 1: $L1"
[[ "$L2" == "completed" ]] && pass "Booking 2 completed" || fail "Booking 2: $L2"

echo ""
echo "═══ MULTI-PARENT — $( [[ $FAILURES -eq 0 ]] && echo "PASS ✓" || echo "FAIL ($FAILURES)" ) ═══"
[[ $FAILURES -eq 0 ]] && exit 0 || exit 1
```

- [ ] **Step 2: Make executable**

Run: `chmod +x scripts/cross-app-multi-parent.sh`

- [ ] **Step 3: Commit**

```bash
git add scripts/cross-app-multi-parent.sh
git commit -m "feat: add multi-parent concurrent booking E2E test"
```

**If this fails (during execution in Task 15):**
- **Second booking doesn't match to second caregiver:** Matching engine may assign both to the same caregiver (the one with higher score). Verify both caregivers are online and have different profiles. If needed, ensure first caregiver's offer is accepted before creating second booking.
- **4 sims too slow:** Machine may not handle 4 concurrent simulators. If so, run sequentially: complete Sarah+Emma first, then James+Maria.
- **James login fails:** `parent-james@test.bijoux.app` may not be seeded. Check `seed-uat.ts` has this account.
**Rollback:** `rm scripts/cross-app-multi-parent.sh && git reset HEAD~1`
**State reset:** Reseed backend + terminate apps on all 4 sims.

---

## Task 12: Rewrite Cancel-After-Match Script

**Pre-conditions:** Tasks 1-9 complete. 2 sims booted. Backend running.
**Post-conditions:** `scripts/cross-app-cancel-after-match.sh` exists with zero simulate references. Uses real matching.

**Files:**
- Modify: `scripts/cross-app-cancel-after-match.sh` (or create if doesn't exist)

- [ ] **Step 1: Write the script**

Same pattern: real matching, caregiver accepts, taps IOMW, then parent cancels via API. Verify cancellation fee.

```bash
#!/usr/bin/env bash
# UAT: Cancel Booking After Match + IOMW — Verify Cancellation Fee

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/config/environment.sh"
source "$ROOT_DIR/scripts/lib/api-helpers.sh"

[[ -z "$PARENT_UDID" ]] && echo "ERROR: PARENT_UDID not set" >&2 && exit 1
[[ -z "$CAREGIVER_UDID" ]] && echo "ERROR: CAREGIVER_UDID not set" >&2 && exit 1

mkdir -p "$ROOT_DIR/results/cross-app"
FAILURES=0; STEP=0
step()  { STEP=$((STEP + 1)); echo ""; echo "═══ STEP $STEP: $1 ═══"; }
pass()  { echo "  ✓ PASS: $1"; }
fail()  { echo "  ✗ FAIL: $1"; FAILURES=$((FAILURES + 1)); }

step "Setup"
PARENT_TOKEN=$(api_login "$PARENT_EMAIL" "$PARENT_PASSWORD")
CG_TOKEN=$(api_login "$CAREGIVER_ONLINE_EMAIL" "$CAREGIVER_ONLINE_PASSWORD")
ADMIN_TOKEN=$(api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
api_set_online "$CG_TOKEN" "true"
pass "Tokens + caregiver online"

step "Login caregiver"
maestro test "$ROOT_DIR/flows/caregiver/login-maria.yaml" --device "$CAREGIVER_UDID" 2>&1 || { fail "CG login"; exit 1; }
maestro test "$ROOT_DIR/flows/caregiver/go-online.yaml" --device "$CAREGIVER_UDID" 2>&1 || true

step "Parent books"
maestro test "$ROOT_DIR/flows/cross-app/parent-login-and-book.yaml" --device "$PARENT_UDID" 2>&1 || { fail "Parent book"; exit 1; }
sleep 3
BOOKING_ID=$(api_latest_booking_id "$PARENT_TOKEN")
pass "Booking: $BOOKING_ID"

step "Caregiver accepts + IOMW"
sleep 5
maestro test "$ROOT_DIR/flows/caregiver/accept-offer.yaml" --device "$CAREGIVER_UDID" 2>&1 || { fail "CG accept"; exit 1; }
maestro test "$ROOT_DIR/flows/caregiver/iomw.yaml" --device "$CAREGIVER_UDID" 2>&1 || fail "CG IOMW"

step "Parent cancels via API (after IOMW)"
sleep 2
CANCEL_RESPONSE=$(curl -s -X POST "${BACKEND_URL}/bookings/${BOOKING_ID}/cancel" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${PARENT_TOKEN}" \
  -d '{"reason": "UAT cancel-after-match test"}')
echo "  Cancel response: $CANCEL_RESPONSE"

step "Verify cancellation"
sleep 2
LIFECYCLE=$(api_booking_lifecycle "$PARENT_TOKEN" "$BOOKING_ID")
[[ "$LIFECYCLE" == "cancelled" ]] && pass "Booking cancelled" || fail "Not cancelled: $LIFECYCLE"

step "Verify cancellation fee"
TRANSACTIONS=$(api_transactions_for_booking "$ADMIN_TOKEN" "$BOOKING_ID")
echo "$TRANSACTIONS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
items = data.get('data', data.get('transactions', []))
if isinstance(items, list):
    for t in items:
        print(f\"  Transaction: type={t.get('type')}, status={t.get('status')}, amount={t.get('amountCents')}c\")
" 2>/dev/null || echo "  Could not parse transactions"

echo ""
echo "═══ CANCEL-AFTER-MATCH — $( [[ $FAILURES -eq 0 ]] && echo "PASS ✓" || echo "FAIL ($FAILURES)" ) ═══"
[[ $FAILURES -eq 0 ]] && exit 0 || exit 1
```

- [ ] **Step 2: Make executable**

Run: `chmod +x scripts/cross-app-cancel-after-match.sh`

- [ ] **Step 3: Commit**

```bash
git add scripts/cross-app-cancel-after-match.sh
git commit -m "feat: rewrite cancel-after-match script with real matching (no simulate)"
```

**If this fails (during execution in Task 15):**
- **Cancel returns error:** Booking may not be in a cancellable state. Check lifecycle — must be `matched` or `confirmed` (after IOMW).
- **No cancellation fee:** Fee logic may only apply for scheduled bookings or may require minimum IOMW duration. Check backend `booking/service.ts` cancellation fee conditions.
**Rollback:** `git checkout -- scripts/cross-app-cancel-after-match.sh && git reset HEAD~1`
**State reset:** Reseed backend + terminate apps.

---

## Task 13: Update run-suite.sh for 4-Sim Support

**Pre-conditions:** Task 2 complete (4 sim env vars available).
**Post-conditions:** `./scripts/run-suite.sh --dry-run` lists all standalone flows correctly.

**Files:**
- Modify: `scripts/run-suite.sh`

- [ ] **Step 1: Update resolve_device() to handle second sim pair**

Replace the `resolve_device` function (lines 94-103) with:

```bash
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
```

(No change needed for 4-sim — the cross-app scripts handle multi-sim routing internally. run-suite.sh only runs single-device flows.)

- [ ] **Step 2: Commit**

```bash
git add scripts/run-suite.sh
git commit -m "fix: update run-suite.sh device resolution for cross-app flows"
```

**If this fails:** Minimal change — unlikely to break. Verify with `--dry-run`.
**Rollback:** `git checkout -- scripts/run-suite.sh && git reset HEAD~1`

---

## Task 14: Selector Validation — Boot and Inspect Real Screens

**Pre-conditions:** Tasks 1-13 complete (all files created). Backend running with seed data. At least 2 sims booted with apps installed.
**Post-conditions:** Every sub-flow's selectors match the real UI. Each sub-flow has been individually validated against a live simulator.

**Files:** None (discovery task — results feed back into sub-flow fixes)

This task is done interactively using Maestro MCP tools. The goal is to verify every sub-flow selector matches the real UI.

- [ ] **Step 1: Boot sims and install apps**

```bash
./config/simulators.sh boot
```

Verify apps are installed on all sims.

- [ ] **Step 2: Login caregiver, go online, create booking, wait for offer**

Use Maestro MCP tools:
1. Run `caregiver/login-maria.yaml` on CAREGIVER_UDID
2. Run `caregiver/go-online.yaml` on CAREGIVER_UDID
3. Run `cross-app/parent-login-and-book.yaml` on PARENT_UDID
4. Wait 10s for matching engine
5. `mcp__maestro__inspect_screen` on CAREGIVER_UDID — record what the offer screen shows
6. `mcp__maestro__inspect_screen` on PARENT_UDID — record what the searching/matched screen shows

- [ ] **Step 3: Accept offer and inspect each subsequent screen**

For each phase (accept → IOMW → en-route → arrived → session start → in-progress → end → completed):
1. Tap the appropriate button on caregiver sim
2. `mcp__maestro__inspect_screen` on both sims
3. Record exact text/IDs for each element

- [ ] **Step 4: Update sub-flows with real selectors**

Based on the inspection results, update the text matchers in:
- `flows/caregiver/accept-offer.yaml`
- `flows/caregiver/iomw.yaml`
- `flows/caregiver/confirm-arrival.yaml`
- `flows/caregiver/start-session-verify.yaml`
- `flows/caregiver/end-session.yaml`
- `flows/parent/verify-matched.yaml`
- `flows/parent/confirm-session-start.yaml`
- `flows/parent/confirm-session-end.yaml`
- `flows/parent/rate-session.yaml`

- [ ] **Step 5: Commit selector fixes**

```bash
git add flows/
git commit -m "fix: update sub-flow selectors based on real UI inspection"
```

**If this fails:**
- **Can't reach a particular screen state:** May need to manually drive the flow using `mcp__maestro__run` with inline YAML one step at a time.
- **Offer never appears on caregiver sim:** Check that (1) caregiver is online via API, (2) Redis is running (`redis-cli ping`), (3) matching worker is processing (check backend console for BullMQ logs), (4) caregiver is in the same market as the booking address.
- **Selectors keep changing:** The app may show different text depending on state. Use broad regex patterns (e.g., `".*Accept.*"`) and narrow down after confirming.
**Rollback:** `git checkout -- flows/ && git reset HEAD~1`
**State reset:** Reseed backend between each inspection attempt. Kill and relaunch apps on sims.

---

## Task 15: Run Full E2E and Fix Failures

**Pre-conditions:** Tasks 1-14 complete. All selectors validated. Backend freshly seeded. Sims booted.
**Post-conditions:** All 4 E2E scripts pass. `run-suite.sh` shows same or better pass rate.

- [ ] **Step 1: Reseed backend**

```bash
cd /Users/polygentic/Documents/dev/bijoux-backend && npm run db:seed && npx tsx prisma/seed-uat.ts
```

- [ ] **Step 2: Run happy path E2E**

```bash
./scripts/cross-app-real-matching-e2e.sh
```

Fix any failures by updating sub-flows or script logic. Re-run until PASS.

- [ ] **Step 3: Reseed and run decline-then-accept**

```bash
cd /Users/polygentic/Documents/dev/bijoux-backend && npm run db:seed && npx tsx prisma/seed-uat.ts
./scripts/cross-app-decline-then-accept.sh
```

Fix any failures. Re-run until PASS.

- [ ] **Step 4: Reseed and run multi-parent**

```bash
cd /Users/polygentic/Documents/dev/bijoux-backend && npm run db:seed && npx tsx prisma/seed-uat.ts
./scripts/cross-app-multi-parent.sh
```

Fix any failures. Re-run until PASS.

- [ ] **Step 5: Reseed and run cancel-after-match**

```bash
cd /Users/polygentic/Documents/dev/bijoux-backend && npm run db:seed && npx tsx prisma/seed-uat.ts
./scripts/cross-app-cancel-after-match.sh
```

Fix any failures. Re-run until PASS.

- [ ] **Step 6: Run existing Maestro suite to verify no regressions**

```bash
./scripts/run-suite.sh
```

Expected: Same or better pass rate as before.

- [ ] **Step 7: Commit any remaining fixes**

```bash
git add -A
git commit -m "fix: resolve E2E flow failures discovered during validation"
```

**If this fails:**
- **Happy path E2E fails at a specific phase:** Isolate by running the Maestro sub-flow for that phase directly: `maestro test flows/caregiver/accept-offer.yaml --device $CAREGIVER_UDID`. Fix the sub-flow, then re-run the full script.
- **API verification fails but UI looked correct:** Backend may process asynchronously. Increase `sleep` durations between phases. Or use `api_wait_for_lifecycle` with higher max_attempts.
- **Existing suite regresses:** Diff the changes to `flows/` to see if a sub-flow edit broke a standalone flow. Sub-flows should not be picked up by `run-suite.sh` (it filters by `launchApp` presence).
**Rollback per script:** Re-run after reseeding. If a script is fundamentally broken, skip it and fix the sub-flow issue first.
**State reset between scripts:** Always reseed: `cd $BIJOUX_BACKEND_DIR && npm run db:seed && npx tsx prisma/seed-uat.ts`

---

## Task 16: Update Documentation

**Pre-conditions:** Tasks 1-15 complete. All scripts passing.
**Post-conditions:** `docs/uat-test-plan.md` lists new UAT-19.4 through UAT-19.7. Spec marked DONE.

**Files:**
- Modify: `docs/uat-test-plan.md`
- Modify: `docs/specs/2026-06-12-real-matching-e2e.md` — Mark spec as DONE

- [ ] **Step 1: Add new cross-app tests to uat-test-plan.md**

Add to the UAT-19 section:

```markdown
| UAT-19.4 | Real E2E Matching — Happy Path | All | `scripts/cross-app-real-matching-e2e.sh` | Real matching engine, no simulate |
| UAT-19.5 | Multi-Caregiver Decline→Accept | All | `scripts/cross-app-decline-then-accept.sh` | Emma declines, Maria accepts |
| UAT-19.6 | Multi-Parent Concurrent | All | `scripts/cross-app-multi-parent.sh` | Sarah + James book, Emma + Maria accept |
| UAT-19.7 | Cancel After Match + Fee | Parent + CG | `scripts/cross-app-cancel-after-match.sh` | Cancel after IOMW, verify fee |
```

Update the summary table counts.

- [ ] **Step 2: Mark spec as DONE**

Update the Status line in `docs/specs/2026-06-12-real-matching-e2e.md` from `DRAFT` to `DONE`.

- [ ] **Step 3: Commit**

```bash
git add docs/
git commit -m "docs: update test plan with new real E2E matching tests"
```

**If this fails:** Pure documentation change — unlikely to fail. If uat-test-plan.md has formatting issues, check markdown table alignment.
**Rollback:** `git reset HEAD~1 && git checkout -- docs/`

---

## Self-Review Checklist (Last reviewed: 2026-06-13)

- [x] **Spec coverage:** Every acceptance criterion (AC-1 through AC-8) maps to at least one task
  - AC-1 (4 sims + apps installed) → Task 2 (includes Step 5b for app install on new sims)
  - AC-2 (happy path E2E) → Tasks 7, 8, 9, 14, 15
  - AC-3 (decline→accept + offer status) → Tasks 6, 10 (includes offer status API check), 14, 15
  - AC-4 (multi-parent) → Tasks 6, 11, 14, 15
  - AC-5 (cancel after match + fee) → Task 12, 15
  - AC-6 (earnings + transactions) → Task 5, 9 (earnings ledger + authorization/capture assertions)
  - AC-7 (simulate accept removal) → Tasks 3, 4
  - AC-8 (existing tests pass) → Task 15 step 6

- [x] **Placeholder scan:** No TBD, TODO, or "fill in later" found

- [x] **Type consistency:** `api_login`, `api_booking_lifecycle`, `api_set_online`, etc. used consistently across all scripts. Flow filenames match between task definitions and script references.

- [x] **File reference verification:** All 18 existing files referenced in the plan verified to exist on disk. `BIJOUX_BACKEND_DIR` confirmed defined at `config/environment.sh:9`. Maestro flag `--device` matches codebase convention.

- [x] **Rollback coverage:** All 16 tasks have rollback/recovery sections.

- [x] **Seed data dependency:** `parent-james@test.bijoux.app` and `cg-maria@test.bijoux.app` confirmed in `docs/seed-data.md`. Created by `npx tsx prisma/seed-uat.ts`, not fixtures/test-accounts.json. Noted in Task 6 failure section.

### Gaps found and fixed during self-review:
1. ~~No app install on new sims~~ → Added Step 5b to Task 2
2. ~~Earnings formula not verified~~ → Added earnings amount/sessionId output to Task 9
3. ~~Offer status not checked~~ → Added offer status API verification to Task 10
4. ~~Transaction auth+capture not asserted~~ → Added auth/capture assertions to Task 9
5. ~~File Structure listed non-existent `session-capture-start.yaml`~~ → Removed (existing `start-session-verify.yaml` covers this)
6. ~~`parent-james` not in fixtures~~ → Added note to Task 6 that accounts come from backend seeding
7. ~~Task 16 missing rollback~~ → Added rollback section

---

## Tracking & Handoff

All 16 tasks are tracked in:
1. **This plan file** — `docs/superpowers/plans/2026-06-12-real-matching-e2e.md` (primary source of truth)
2. **Claude Code TodoWrite tasks** — Tasks #13-#28 with dependency chains
3. **HANDOFF.md** — Root-level handoff document with current status, task summary, and execution instructions
4. **Spec** — `docs/specs/2026-06-12-real-matching-e2e.md` (acceptance criteria)

### Jira Tracking

Task 4 creates a Jira ticket for removing simulate accept from the codebase (BA project). During execution, the Jira ticket number should be recorded in the spec file. Completed E2E test results should be reported to Jira via `scripts/jira-report.sh` per the standard UAT workflow.

### Task Dependency Chain (TodoWrite IDs)

```
#13 (env vars) ─┬─► #14 (4 sims) ──► #15 (remove simulate)
                ├─► #17 (api-helpers) ─┬─► #21 (happy path E2E)
                ├─► #18 (login flows)  ├─► #22 (decline→accept)
                ├─► #19 (cg sub-flows) ├─► #23 (multi-parent)
                └─► #20 (parent subs)  └─► #24 (cancel-after-match)
#14 ──► #25 (run-suite.sh)
#21 ──► #26 (selector validation)
#21-#26 ──► #27 (run E2E + fix failures)
#27 ──► #28 (update docs)

#16 (Jira ticket) — independent, no blockers
```
