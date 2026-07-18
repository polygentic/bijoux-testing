# Bijoux Testing Infrastructure — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a dedicated `bijoux-testing` repo that enables Claude Code to autonomously run UAT suites against the parent iOS app, caregiver iOS app, and admin web portal — with Jira reporting.

**Architecture:** A new GitHub repo with Maestro YAML flows for iOS automation, Claude in Chrome markdown prompts for admin portal automation, shell scripts for orchestration/backend lifecycle, and Jira REST API integration for test result reporting. Both iOS apps get accessibility identifiers added as a prerequisite.

**Tech Stack:** Maestro CLI + MCP, Claude in Chrome (existing), xcrun simctl, xcodebuild, Jira REST API v3 via curl, docker compose, bash scripts.

**Spec:** `docs/superpowers/specs/2026-06-10-bijoux-testing-infrastructure-design.md`

---

## File Structure

### New repo: `bijoux-testing/`

| File | Responsibility |
|------|---------------|
| `CLAUDE.md` | Agent playbook — orchestration sequence, paths, credentials, failure handling |
| `.gitignore` | Ignore results/, .DS_Store, *.env |
| `config/environment.sh` | Simulator UDIDs, bundle IDs, repo paths, backend URL |
| `config/simulators.sh` | Create/boot/shutdown named simulators with auto-detected runtime |
| `scripts/backend-up.sh` | docker compose up + pg_isready wait + migrate + seed |
| `scripts/backend-down.sh` | docker compose down |
| `scripts/build-parent.sh` | xcodebuild + simctl install for parent app |
| `scripts/build-caregiver.sh` | xcodebuild + simctl install for caregiver app |
| `scripts/jira-helpers.sh` | Shared bash functions: create_issue, add_comment, attach_file, transition_issue |
| `scripts/jira-report.sh` | Parse Maestro output, post results per flow to Jira |
| `scripts/orchestrate.sh` | Full autonomous run: backend → build → test → report → cleanup |
| `fixtures/test-accounts.json` | Test credentials for parent, caregiver, admin |
| `fixtures/expected-states.json` | Known-good assertion values pinned from seed |
| `flows/parent/onboarding.yaml` | Maestro flow: onboarding happy path |
| `flows/parent/login.yaml` | Maestro flow: parent login |
| `flows/parent/signup-and-otp.yaml` | Maestro flow: signup + OTP verification |
| `flows/parent/quick-booking.yaml` | Maestro flow: request now booking |
| `flows/parent/scheduled-booking.yaml` | Maestro flow: scheduled booking |
| `flows/parent/profile-management.yaml` | Maestro flow: edit profile |
| `flows/parent/activity-history.yaml` | Maestro flow: activity tab |
| `flows/caregiver/onboarding.yaml` | Maestro flow: caregiver onboarding |
| `flows/caregiver/login.yaml` | Maestro flow: caregiver login |
| `flows/caregiver/setup-wizard.yaml` | Maestro flow: caregiver setup wizard |
| `flows/caregiver/go-online.yaml` | Maestro flow: toggle online |
| `flows/caregiver/profile-edit.yaml` | Maestro flow: edit caregiver profile |
| `flows/admin/login.md` | Claude in Chrome prompt: admin login |
| `flows/admin/dashboard-kpis.md` | Claude in Chrome prompt: verify dashboard KPIs |
| `flows/admin/user-management.md` | Claude in Chrome prompt: user list + detail |
| `flows/cross-app/full-booking-lifecycle.md` | Orchestrated cross-app scenario |
| `results/.gitkeep` | Placeholder for test artifacts |
| `docs/accessibility-id-conventions.md` | Naming conventions for accessibility identifiers |

### Modified in `bijoux-ios/` (parent app)

| File | Change |
|------|--------|
| All view files in `Features/` and `Navigation/` | Add `.accessibilityIdentifier()` modifiers |

### Modified in `bijouxCaregiverApp/` (caregiver app)

| File | Change |
|------|--------|
| All view files in `Features/` and `Navigation/` | Add `.accessibilityIdentifier()` modifiers |

---

## Task 1: Install Maestro CLI and Configure MCP

**Files:**
- None created — system-level install

- [ ] **Step 1: Install Maestro CLI**

```bash
curl -Ls "https://get.maestro.dev" | bash
```

- [ ] **Step 2: Verify Maestro is installed**

```bash
maestro --version
```

Expected: Version number printed (e.g., `Maestro 1.x.x`)

- [ ] **Step 3: Add Maestro MCP to Claude Code**

```bash
claude mcp add maestro -- maestro mcp
```

- [ ] **Step 4: Verify MCP is registered**

```bash
claude mcp list
```

Expected: `maestro` appears in the list.

- [ ] **Step 5: Download iOS simulator runtime (if needed)**

```bash
xcodebuild -downloadPlatform iOS
```

Expected: iOS 26.5 runtime downloads and installs. This may be a large download. If already installed, this is a no-op.

---

## Task 2: Create `bijoux-testing` Repository

**Files:**
- Create: `bijoux-testing/.gitignore`
- Create: `bijoux-testing/results/.gitkeep`
- Create: `bijoux-testing/docs/accessibility-id-conventions.md`

- [ ] **Step 1: Create the repo directory**

```bash
mkdir -p /Users/polygentic/Documents/dev/bijoux-testing
cd /Users/polygentic/Documents/dev/bijoux-testing
git init && git branch -M main
```

- [ ] **Step 2: Create .gitignore**

Create file `bijoux-testing/.gitignore`:

```
# Test artifacts
results/
!results/.gitkeep

# macOS
.DS_Store
.AppleDouble
.LSOverride

# Environment / secrets
*.env
.env.*

# Xcode build artifacts
DerivedData/
build/

# Maestro output
~/.maestro/tests/

# Editor
*.swp
*.swo
*~
.idea/
.vscode/
```

- [ ] **Step 3: Create results directory with .gitkeep**

```bash
mkdir -p results
touch results/.gitkeep
```

- [ ] **Step 4: Create accessibility ID conventions doc**

Create file `docs/accessibility-id-conventions.md`:

```markdown
# Accessibility Identifier Conventions

## Format

`{screen}-{element}-{type}`

## Types

| Suffix | Use For |
|--------|---------|
| `-field` | Text input fields (BijouxTextField, TextField) |
| `-button` | Tappable buttons (BijouxButton, Button) |
| `-card` | Tappable card areas (NavigationLink with card label) |
| `-toggle` | Toggle switches |
| `-picker` | Picker controls |
| `-tab` | Tab bar items |
| `-label` | Display-only text used in assertions |
| `-link` | Text-style navigation links |

## Screen Prefixes

### Parent App
| Screen | Prefix |
|--------|--------|
| OnboardingView | `onboarding-` |
| LoginView | `login-` |
| CreateAccountView | `signup-` |
| OTPVerificationView | `otp-` |
| ProfileSetupView | `profile-setup-` |
| HomeView | `home-` |
| MainTabView | `tab-` |
| QuickBookingView | `quick-booking-` |
| ScheduledBookingView | `scheduled-booking-` |
| MatchingFlowView | `matching-` |
| SearchingView | `searching-` |
| CaregiverMatchedView | `matched-` |
| CaregiverArrivedView | `arrived-` |
| VerificationView | `verification-` |
| ActiveSessionView | `active-session-` |
| EndJobConfirmationView | `end-job-` |
| SessionSummaryView | `summary-` |
| ActivityListView | `activity-` |
| ProfileHubView | `profile-hub-` |
| EditProfileView | `edit-profile-` |
| PreferencesView | `preferences-` |
| ChangePasswordView | `change-password-` |
| PaymentMethodPickerView | `payment-picker-` |

### Caregiver App
| Screen | Prefix |
|--------|--------|
| OnboardingView | `onboarding-` |
| LoginView | `login-` |
| CreateAccountView | `signup-` |
| OTPVerificationView | `otp-` |
| SetupWizardView | `setup-` |
| HomeView / HomeDashboardView | `home-` |
| MainTabView | `tab-` |
| PreAcceptOfferView | `offer-` |
| PostAcceptOfferView | `post-accept-` |
| EnRouteView | `en-route-` |
| ArrivedView | `arrived-` |
| InProgressView | `in-progress-` |
| CompletedView | `completed-` |
| SessionVerificationView | `verification-` |
| EarningsView | `earnings-` |
| ActivityView | `activity-` |
| PreferencesView | `preferences-` |
| ProfileEditView | `edit-profile-` |

## Examples

```
login-email-field
login-password-field
login-submit-button
login-signup-link
home-request-now-card
home-schedule-card
tab-home
tab-activity
tab-profile
matching-cancel-button
summary-done-button
summary-rating-label
profile-hub-logout-button
```
```

- [ ] **Step 5: Create directory structure**

```bash
mkdir -p config scripts fixtures flows/parent flows/caregiver flows/admin flows/cross-app docs
```

- [ ] **Step 6: Initial commit**

```bash
git add .gitignore results/.gitkeep docs/accessibility-id-conventions.md
git commit -m "chore: initialize bijoux-testing repo with structure and conventions"
```

- [ ] **Step 7: Create GitHub repo and push**

```bash
gh repo create polygentic/bijoux-testing --private --source=. --push
```

---

## Task 3: Config and Simulator Scripts

**Files:**
- Create: `bijoux-testing/config/environment.sh`
- Create: `bijoux-testing/config/simulators.sh`

- [ ] **Step 1: Create environment.sh**

Create file `config/environment.sh`:

```bash
#!/usr/bin/env bash
# Bijoux Testing — Environment Configuration
# Source this file before running any test scripts.

# --- Repo Paths ---
export BIJOUX_PARENT_DIR="/Users/polygentic/Documents/dev/bijoux-ios"
export BIJOUX_CAREGIVER_DIR="/Users/polygentic/Documents/dev/bijouxCaregiverApp"
export BIJOUX_ADMIN_DIR="/Users/polygentic/Documents/dev/bijouxAdmin"
export BIJOUX_BACKEND_DIR="/Users/polygentic/Documents/dev/bijoux-backend"
export BIJOUX_TESTING_DIR="/Users/polygentic/Documents/dev/bijoux-testing"

# --- Bundle IDs ---
export PARENT_BUNDLE_ID="polygentic.bijouxParentApp"
export CAREGIVER_BUNDLE_ID="polygentic.bijouxCaregiverApp"

# --- Xcode Schemes ---
export PARENT_SCHEME="bijouxParentApp"
export CAREGIVER_SCHEME="bijouxCaregiverApp"

# --- Simulator Names ---
export PARENT_SIM_NAME="bijoux-parent"
export CAREGIVER_SIM_NAME="bijoux-care"

# --- Derived Data ---
export PARENT_DERIVED_DATA="/tmp/bijoux-build-parent"
export CAREGIVER_DERIVED_DATA="/tmp/bijoux-build-caregiver"

# --- Backend ---
export BACKEND_URL="http://localhost:3000/api/v1"

# --- Admin Portal ---
export ADMIN_URL="http://localhost:3001"

# --- Jira ---
export JIRA_ENV_FILE="/Users/polygentic/.config/bijoux/jira.env"

# --- Simulator UDIDs (populated by simulators.sh) ---
export PARENT_UDID=""
export CAREGIVER_UDID=""

# Load Jira credentials if available
if [[ -f "$JIRA_ENV_FILE" ]]; then
    set -a
    source "$JIRA_ENV_FILE"
    set +a
fi

# Load simulator UDIDs if simulators exist
_resolve_udid() {
    xcrun simctl list devices -j 2>/dev/null \
        | python3 -c "
import sys, json
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    for d in devices:
        if d['name'] == '$1' and d['state'] != 'Shutdown':
            print(d['udid'])
            sys.exit(0)
        elif d['name'] == '$1':
            print(d['udid'])
            sys.exit(0)
" 2>/dev/null
}

PARENT_UDID=$(_resolve_udid "$PARENT_SIM_NAME")
CAREGIVER_UDID=$(_resolve_udid "$CAREGIVER_SIM_NAME")
export PARENT_UDID CAREGIVER_UDID
```

- [ ] **Step 2: Create simulators.sh**

Create file `config/simulators.sh`:

```bash
#!/usr/bin/env bash
# Bijoux Testing — Simulator Management
# Usage: ./config/simulators.sh [create|boot|shutdown|delete]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/environment.sh"

# Auto-detect latest iOS runtime
get_latest_runtime() {
    xcrun simctl list runtimes -j \
        | python3 -c "
import sys, json
data = json.load(sys.stdin)
ios_runtimes = [r for r in data.get('runtimes', []) if r['name'].startswith('iOS') and r['isAvailable']]
if ios_runtimes:
    # Sort by version descending
    ios_runtimes.sort(key=lambda r: r['version'], reverse=True)
    print(ios_runtimes[0]['identifier'])
else:
    print('NONE', file=sys.stderr)
    sys.exit(1)
"
}

# Auto-detect best iPhone device type
get_device_type() {
    xcrun simctl list devicetypes -j \
        | python3 -c "
import sys, json
data = json.load(sys.stdin)
# Prefer iPhone 16 Pro, fall back to newest iPhone
preferred = ['iPhone-16-Pro', 'iPhone-16', 'iPhone-15-Pro', 'iPhone-15']
for pref in preferred:
    for dt in data.get('devicetypes', []):
        if pref in dt['identifier']:
            print(dt['identifier'])
            sys.exit(0)
# Fallback: last iPhone in list
for dt in reversed(data.get('devicetypes', [])):
    if 'iPhone' in dt['identifier']:
        print(dt['identifier'])
        sys.exit(0)
print('NONE', file=sys.stderr)
sys.exit(1)
"
}

create_simulators() {
    local runtime device_type
    runtime=$(get_latest_runtime)
    device_type=$(get_device_type)
    echo "Using runtime: $runtime"
    echo "Using device type: $device_type"

    # Create parent simulator
    if xcrun simctl list devices -j | python3 -c "
import sys, json
data = json.load(sys.stdin)
for devices in data['devices'].values():
    for d in devices:
        if d['name'] == '$PARENT_SIM_NAME':
            sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
        echo "Simulator '$PARENT_SIM_NAME' already exists"
    else
        local parent_udid
        parent_udid=$(xcrun simctl create "$PARENT_SIM_NAME" "$device_type" "$runtime")
        echo "Created '$PARENT_SIM_NAME': $parent_udid"
    fi

    # Create caregiver simulator
    if xcrun simctl list devices -j | python3 -c "
import sys, json
data = json.load(sys.stdin)
for devices in data['devices'].values():
    for d in devices:
        if d['name'] == '$CAREGIVER_SIM_NAME':
            sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
        echo "Simulator '$CAREGIVER_SIM_NAME' already exists"
    else
        local care_udid
        care_udid=$(xcrun simctl create "$CAREGIVER_SIM_NAME" "$device_type" "$runtime")
        echo "Created '$CAREGIVER_SIM_NAME': $care_udid"
    fi
}

boot_simulators() {
    source "$SCRIPT_DIR/environment.sh"  # re-resolve UDIDs
    if [[ -n "$PARENT_UDID" ]]; then
        xcrun simctl boot "$PARENT_UDID" 2>/dev/null || true
        echo "Booted $PARENT_SIM_NAME ($PARENT_UDID)"
    else
        echo "ERROR: $PARENT_SIM_NAME not found. Run: $0 create" >&2
        exit 1
    fi
    if [[ -n "$CAREGIVER_UDID" ]]; then
        xcrun simctl boot "$CAREGIVER_UDID" 2>/dev/null || true
        echo "Booted $CAREGIVER_SIM_NAME ($CAREGIVER_UDID)"
    else
        echo "ERROR: $CAREGIVER_SIM_NAME not found. Run: $0 create" >&2
        exit 1
    fi
    open -a Simulator
}

shutdown_simulators() {
    source "$SCRIPT_DIR/environment.sh"
    [[ -n "$PARENT_UDID" ]] && xcrun simctl shutdown "$PARENT_UDID" 2>/dev/null || true
    [[ -n "$CAREGIVER_UDID" ]] && xcrun simctl shutdown "$CAREGIVER_UDID" 2>/dev/null || true
    echo "Simulators shut down"
}

delete_simulators() {
    source "$SCRIPT_DIR/environment.sh"
    [[ -n "$PARENT_UDID" ]] && xcrun simctl delete "$PARENT_UDID" 2>/dev/null || true
    [[ -n "$CAREGIVER_UDID" ]] && xcrun simctl delete "$CAREGIVER_UDID" 2>/dev/null || true
    echo "Simulators deleted"
}

case "${1:-}" in
    create)   create_simulators ;;
    boot)     boot_simulators ;;
    shutdown) shutdown_simulators ;;
    delete)   delete_simulators ;;
    *)        echo "Usage: $0 {create|boot|shutdown|delete}" >&2; exit 1 ;;
esac
```

- [ ] **Step 3: Make scripts executable**

```bash
chmod +x config/environment.sh config/simulators.sh
```

- [ ] **Step 4: Test simulator creation**

```bash
cd /Users/polygentic/Documents/dev/bijoux-testing
./config/simulators.sh create
./config/simulators.sh boot
```

Expected: Two simulators created and booted. Simulator.app opens showing both.

- [ ] **Step 5: Commit**

```bash
git add config/
git commit -m "feat: add environment config and simulator management scripts"
git push origin main
```

---

## Task 4: Backend and Build Scripts

**Files:**
- Create: `bijoux-testing/scripts/backend-up.sh`
- Create: `bijoux-testing/scripts/backend-down.sh`
- Create: `bijoux-testing/scripts/build-parent.sh`
- Create: `bijoux-testing/scripts/build-caregiver.sh`

- [ ] **Step 1: Create backend-up.sh**

Create file `scripts/backend-up.sh`:

```bash
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
```

- [ ] **Step 2: Create backend-down.sh**

Create file `scripts/backend-down.sh`:

```bash
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
```

- [ ] **Step 3: Create build-parent.sh**

Create file `scripts/build-parent.sh`:

```bash
#!/usr/bin/env bash
# Build and install parent app on simulator
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/environment.sh"

if [[ -z "$PARENT_UDID" ]]; then
    echo "ERROR: Parent simulator not found. Run: config/simulators.sh create" >&2
    exit 1
fi

echo "=== Building parent app ==="
xcodebuild build \
    -project "$BIJOUX_PARENT_DIR/bijouxParentApp.xcodeproj" \
    -scheme "$PARENT_SCHEME" \
    -destination "platform=iOS Simulator,id=$PARENT_UDID" \
    -derivedDataPath "$PARENT_DERIVED_DATA" \
    -quiet \
    CODE_SIGNING_ALLOWED=NO

# Find the .app bundle
APP_PATH=$(find "$PARENT_DERIVED_DATA" -name "bijouxParentApp.app" -type d | head -1)
if [[ -z "$APP_PATH" ]]; then
    echo "ERROR: Could not find built .app bundle" >&2
    exit 1
fi

echo "Installing on simulator $PARENT_SIM_NAME ($PARENT_UDID)..."
xcrun simctl install "$PARENT_UDID" "$APP_PATH"

echo "=== Parent app installed ==="
```

- [ ] **Step 4: Create build-caregiver.sh**

Create file `scripts/build-caregiver.sh`:

```bash
#!/usr/bin/env bash
# Build and install caregiver app on simulator
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/environment.sh"

if [[ -z "$CAREGIVER_UDID" ]]; then
    echo "ERROR: Caregiver simulator not found. Run: config/simulators.sh create" >&2
    exit 1
fi

echo "=== Building caregiver app ==="
xcodebuild build \
    -project "$BIJOUX_CAREGIVER_DIR/bijouxCaregiverApp.xcodeproj" \
    -scheme "$CAREGIVER_SCHEME" \
    -destination "platform=iOS Simulator,id=$CAREGIVER_UDID" \
    -derivedDataPath "$CAREGIVER_DERIVED_DATA" \
    -quiet \
    CODE_SIGNING_ALLOWED=NO

# Find the .app bundle
APP_PATH=$(find "$CAREGIVER_DERIVED_DATA" -name "bijouxCaregiverApp.app" -type d | head -1)
if [[ -z "$APP_PATH" ]]; then
    echo "ERROR: Could not find built .app bundle" >&2
    exit 1
fi

echo "Installing on simulator $CAREGIVER_SIM_NAME ($CAREGIVER_UDID)..."
xcrun simctl install "$CAREGIVER_UDID" "$APP_PATH"

echo "=== Caregiver app installed ==="
```

- [ ] **Step 5: Make scripts executable**

```bash
chmod +x scripts/backend-up.sh scripts/backend-down.sh scripts/build-parent.sh scripts/build-caregiver.sh
```

- [ ] **Step 6: Commit**

```bash
git add scripts/
git commit -m "feat: add backend lifecycle and iOS build scripts"
git push origin main
```

---

## Task 5: Jira Helper Scripts

**Files:**
- Create: `bijoux-testing/scripts/jira-helpers.sh`
- Create: `bijoux-testing/scripts/jira-report.sh`

- [ ] **Step 1: Create jira-helpers.sh**

Create file `scripts/jira-helpers.sh`:

```bash
#!/usr/bin/env bash
# Jira REST API helper functions
# Source this file — do not run directly.

_jira_curl() {
    curl -s \
        -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
        -H "Content-Type: application/json" \
        "$@"
}

jira_validate_token() {
    local status
    status=$(_jira_curl -o /dev/null -w "%{http_code}" "${JIRA_BASE_URL}/rest/api/3/myself")
    if [[ "$status" != "200" ]]; then
        echo "ERROR: Jira authentication failed (HTTP $status). Check ~/.config/bijoux/jira.env" >&2
        return 1
    fi
    echo "Jira authentication OK"
}

jira_add_comment() {
    local issue_key="$1"
    local comment_text="$2"
    _jira_curl \
        -X POST \
        "${JIRA_BASE_URL}/rest/api/3/issue/${issue_key}/comment" \
        -d "$(python3 -c "
import json, sys
print(json.dumps({
    'body': {
        'type': 'doc',
        'version': 1,
        'content': [{
            'type': 'paragraph',
            'content': [{
                'type': 'text',
                'text': sys.argv[1]
            }]
        }]
    }
}))
" "$comment_text")" > /dev/null
}

jira_attach_file() {
    local issue_key="$1"
    local file_path="$2"
    curl -s \
        -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
        -X POST \
        -H "X-Atlassian-Token: no-check" \
        -F "file=@${file_path}" \
        "${JIRA_BASE_URL}/rest/api/3/issue/${issue_key}/attachments" > /dev/null
}

jira_create_bug() {
    local summary="$1"
    local description="$2"
    local severity="${3:-SEV-3}"
    _jira_curl \
        -X POST \
        "${JIRA_BASE_URL}/rest/api/3/issue" \
        -d "$(python3 -c "
import json, sys
print(json.dumps({
    'fields': {
        'project': {'key': '${JIRA_PROJECT_KEY}'},
        'summary': sys.argv[1],
        'issuetype': {'id': '10091'},
        'labels': [sys.argv[3]],
        'description': {
            'type': 'doc',
            'version': 1,
            'content': [{
                'type': 'paragraph',
                'content': [{
                    'type': 'text',
                    'text': sys.argv[2]
                }]
            }]
        }
    }
}))
" "$summary" "$description" "$severity")"
}

jira_transition_to_done() {
    local issue_key="$1"
    _jira_curl \
        -X POST \
        "${JIRA_BASE_URL}/rest/api/3/issue/${issue_key}/transitions" \
        -d '{"transition":{"id":"31"}}' > /dev/null
}
```

- [ ] **Step 2: Create jira-report.sh**

Create file `scripts/jira-report.sh`:

```bash
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
```

- [ ] **Step 3: Make scripts executable**

```bash
chmod +x scripts/jira-helpers.sh scripts/jira-report.sh
```

- [ ] **Step 4: Test Jira helpers**

```bash
cd /Users/polygentic/Documents/dev/bijoux-testing
source config/environment.sh
source scripts/jira-helpers.sh
jira_validate_token
```

Expected: `Jira authentication OK`

- [ ] **Step 5: Commit**

```bash
git add scripts/jira-helpers.sh scripts/jira-report.sh
git commit -m "feat: add Jira helper functions and test reporting script"
git push origin main
```

---

## Task 6: Test Fixtures

**Files:**
- Create: `bijoux-testing/fixtures/test-accounts.json`
- Create: `bijoux-testing/fixtures/expected-states.json`

- [ ] **Step 1: Create test-accounts.json**

Create file `fixtures/test-accounts.json`:

```json
{
  "parent": {
    "email": "parent-sarah@test.bijoux.app",
    "password": "Test1234!",
    "firstName": "Sarah",
    "lastName": "Mitchell"
  },
  "caregiver": {
    "email": "cg-emma@test.bijoux.app",
    "password": "Test1234!",
    "firstName": "Emma",
    "lastName": "Rodriguez"
  },
  "admin": {
    "email": "admin@bijoux.app",
    "password": "Test1234!",
    "name": "Admin"
  },
  "newParentSignup": {
    "firstName": "Test",
    "lastName": "Parent",
    "email": "uat-parent-{{timestamp}}@test.bijoux.app",
    "password": "Test1234!"
  },
  "newCaregiverSignup": {
    "firstName": "Test",
    "lastName": "Caregiver",
    "email": "uat-caregiver-{{timestamp}}@test.bijoux.app",
    "password": "Test1234!"
  }
}
```

- [ ] **Step 2: Create expected-states.json**

Create file `fixtures/expected-states.json`:

```json
{
  "parentLogin": {
    "greetingContains": "Good",
    "tabCount": 3,
    "tabs": ["Home", "Activity", "Profile"]
  },
  "caregiverLogin": {
    "tabCount": 4,
    "tabs": ["Home", "Activity", "Earnings", "Preferences"]
  },
  "adminDashboard": {
    "kpiCards": ["Active Sessions", "Revenue (MTD)", "Caregivers Online", "Pending Approval"],
    "sidebarLinks": ["Dashboard", "Bookings", "Sessions", "Caregivers", "Users", "Transactions", "Incidents", "Audit Log"]
  },
  "onboarding": {
    "parentGetStartedText": "Get Started",
    "caregiverGetStartedText": "Get Started"
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add fixtures/
git commit -m "feat: add test account fixtures and expected state assertions"
git push origin main
```

---

## Task 7: Add Accessibility Identifiers — Parent App

**Files:**
- Modify: `/Users/polygentic/Documents/dev/bijoux-ios/bijouxParentApp/Features/Onboarding/OnboardingView.swift`
- Modify: `/Users/polygentic/Documents/dev/bijoux-ios/bijouxParentApp/Features/Auth/LoginView.swift`
- Modify: `/Users/polygentic/Documents/dev/bijoux-ios/bijouxParentApp/Features/Auth/CreateAccountView.swift`
- Modify: `/Users/polygentic/Documents/dev/bijoux-ios/bijouxParentApp/Features/Auth/OTPVerificationView.swift`
- Modify: `/Users/polygentic/Documents/dev/bijoux-ios/bijouxParentApp/Features/ProfileSetup/ProfileSetupView.swift`
- Modify: `/Users/polygentic/Documents/dev/bijoux-ios/bijouxParentApp/Features/Home/HomeView.swift`
- Modify: `/Users/polygentic/Documents/dev/bijoux-ios/bijouxParentApp/Navigation/MainTabView.swift`
- Modify: `/Users/polygentic/Documents/dev/bijoux-ios/bijouxParentApp/Features/Booking/QuickBookingView.swift`
- Modify: `/Users/polygentic/Documents/dev/bijoux-ios/bijouxParentApp/Features/Booking/ScheduledBookingView.swift`
- Modify: `/Users/polygentic/Documents/dev/bijoux-ios/bijouxParentApp/Features/MatchingFlow/MatchingFlowView.swift`
- Modify: `/Users/polygentic/Documents/dev/bijoux-ios/bijouxParentApp/Features/MatchingFlow/SearchingView.swift`
- Modify: `/Users/polygentic/Documents/dev/bijoux-ios/bijouxParentApp/Features/MatchingFlow/CaregiverMatchedView.swift`
- Modify: `/Users/polygentic/Documents/dev/bijoux-ios/bijouxParentApp/Features/MatchingFlow/CaregiverArrivedView.swift`
- Modify: `/Users/polygentic/Documents/dev/bijoux-ios/bijouxParentApp/Features/MatchingFlow/VerificationView.swift`
- Modify: `/Users/polygentic/Documents/dev/bijoux-ios/bijouxParentApp/Features/MatchingFlow/ActiveSessionView.swift`
- Modify: `/Users/polygentic/Documents/dev/bijoux-ios/bijouxParentApp/Features/MatchingFlow/EndJobConfirmationView.swift`
- Modify: `/Users/polygentic/Documents/dev/bijoux-ios/bijouxParentApp/Features/MatchingFlow/SessionSummaryView.swift`
- Modify: `/Users/polygentic/Documents/dev/bijoux-ios/bijouxParentApp/Features/Activity/ActivityListView.swift`
- Modify: `/Users/polygentic/Documents/dev/bijoux-ios/bijouxParentApp/Features/Profile/ProfileHubView.swift`
- Modify: `/Users/polygentic/Documents/dev/bijoux-ios/bijouxParentApp/Features/Profile/EditProfileView.swift`
- Modify: `/Users/polygentic/Documents/dev/bijoux-ios/bijouxParentApp/Features/Profile/PreferencesView.swift`
- Modify: `/Users/polygentic/Documents/dev/bijoux-ios/bijouxParentApp/Features/Profile/ChangePasswordView.swift`
- Modify: `/Users/polygentic/Documents/dev/bijoux-ios/bijouxParentApp/Features/Booking/PaymentMethodPickerView.swift`

This task adds `.accessibilityIdentifier()` modifiers to every interactive element and key assertion target in the parent app. The pattern is consistent — append the modifier after the existing view. No behavioral changes.

- [ ] **Step 1: Add identifiers to OnboardingView.swift**

In `/Users/polygentic/Documents/dev/bijoux-ios/bijouxParentApp/Features/Onboarding/OnboardingView.swift`, add to the BijouxButton on line 62:

```swift
BijouxButton("Get Started", style: .primary) {
    onGetStarted()
}
.accessibilityIdentifier("onboarding-get-started-button")
```

- [ ] **Step 2: Add identifiers to LoginView.swift**

In `/Users/polygentic/Documents/dev/bijoux-ios/bijouxParentApp/Features/Auth/LoginView.swift`:

```swift
// Email field (~line 67-72) — add after closing paren:
.accessibilityIdentifier("login-email-field")

// Password field (~line 89-95) — add after closing paren:
.accessibilityIdentifier("login-password-field")

// Log In button (~line 124-133) — add after closing brace:
.accessibilityIdentifier("login-submit-button")

// Sign Up link (~line 144) — add after closing brace:
.accessibilityIdentifier("login-signup-link")
```

- [ ] **Step 3: Add identifiers to CreateAccountView.swift**

In `/Users/polygentic/Documents/dev/bijoux-ios/bijouxParentApp/Features/Auth/CreateAccountView.swift`:

```swift
// First Name field — .accessibilityIdentifier("signup-first-name-field")
// Last Name field — .accessibilityIdentifier("signup-last-name-field")
// Email field — .accessibilityIdentifier("signup-email-field")
// Password field — .accessibilityIdentifier("signup-password-field")
// Confirm Password field — .accessibilityIdentifier("signup-confirm-password-field")
// Continue/Create Account button — .accessibilityIdentifier("signup-continue-button")
// Back button — .accessibilityIdentifier("signup-back-button")
// Log In link — .accessibilityIdentifier("signup-login-link")
```

- [ ] **Step 4: Add identifiers to OTPVerificationView.swift**

```swift
// Each digit TextField (index 0-5) — .accessibilityIdentifier("otp-digit-\(index)-field")
// Verify button — .accessibilityIdentifier("otp-verify-button")
// Resend button — .accessibilityIdentifier("otp-resend-button")
```

- [ ] **Step 5: Add identifiers to ProfileSetupView.swift**

```swift
// First Name — .accessibilityIdentifier("profile-setup-first-name-field")
// Last Name — .accessibilityIdentifier("profile-setup-last-name-field")
// Phone — .accessibilityIdentifier("profile-setup-phone-field")
// Street — .accessibilityIdentifier("profile-setup-street-field")
// Street 2 — .accessibilityIdentifier("profile-setup-street2-field")
// City — .accessibilityIdentifier("profile-setup-city-field")
// State — .accessibilityIdentifier("profile-setup-state-field")
// ZIP — .accessibilityIdentifier("profile-setup-zip-field")
// Continue/Confirm button — .accessibilityIdentifier("profile-setup-continue-button")
// Back button — .accessibilityIdentifier("profile-setup-back-button")
// Add Child button — .accessibilityIdentifier("profile-setup-add-child-button")
```

- [ ] **Step 6: Add identifiers to HomeView.swift**

```swift
// Active session card button — .accessibilityIdentifier("home-active-session-card")
// Request Now card — .accessibilityIdentifier("home-request-now-card")
// Schedule card — .accessibilityIdentifier("home-schedule-card")
// Greeting text — .accessibilityIdentifier("home-greeting-label")
```

- [ ] **Step 7: Add identifiers to MainTabView.swift**

Each tab item in the ForEach gets an identifier. Add to the tab content view:

```swift
// Inside the ForEach, on each tab's content view:
.accessibilityIdentifier("tab-\(tab.rawValue)")
```

This produces `tab-home`, `tab-activity`, `tab-profile`.

- [ ] **Step 8: Add identifiers to QuickBookingView.swift**

```swift
// Use Current Location button — .accessibilityIdentifier("quick-booking-current-location-button")
// Duration picker — .accessibilityIdentifier("quick-booking-duration-picker")
// Payment method button — .accessibilityIdentifier("quick-booking-payment-button")
// Request Caregiver button — .accessibilityIdentifier("quick-booking-submit-button")
```

- [ ] **Step 9: Add identifiers to ScheduledBookingView.swift**

```swift
// DatePicker — .accessibilityIdentifier("scheduled-booking-date-picker")
// Duration picker — .accessibilityIdentifier("scheduled-booking-duration-picker")
// Use Current Location button — .accessibilityIdentifier("scheduled-booking-current-location-button")
// Payment method button — .accessibilityIdentifier("scheduled-booking-payment-button")
// Schedule Booking button — .accessibilityIdentifier("scheduled-booking-submit-button")
```

- [ ] **Step 10: Add identifiers to matching flow views**

```swift
// SearchingView:
// Cancel Search button — .accessibilityIdentifier("searching-cancel-button")

// CaregiverMatchedView:
// Cancel button — .accessibilityIdentifier("matched-cancel-button")

// CaregiverArrivedView:
// Start Identity Verification button — .accessibilityIdentifier("arrived-verify-button")

// VerificationView:
// Capture/Retry button — .accessibilityIdentifier("verification-capture-button")

// ActiveSessionView:
// Home/Minimize button — .accessibilityIdentifier("active-session-home-button")
// End Job button — .accessibilityIdentifier("active-session-end-button")

// EndJobConfirmationView:
// Confirm End Job button — .accessibilityIdentifier("end-job-confirm-button")
// Continue Session button — .accessibilityIdentifier("end-job-continue-button")

// SessionSummaryView:
// Done button — .accessibilityIdentifier("summary-done-button")
// Star rating — .accessibilityIdentifier("summary-rating-label")
```

- [ ] **Step 11: Add identifiers to profile views**

```swift
// ProfileHubView:
// Edit Profile link — .accessibilityIdentifier("profile-hub-edit-link")
// Preferences link — .accessibilityIdentifier("profile-hub-preferences-link")
// My Children link — .accessibilityIdentifier("profile-hub-children-link")
// Change Password link — .accessibilityIdentifier("profile-hub-password-link")
// Log Out button — .accessibilityIdentifier("profile-hub-logout-button")

// EditProfileView:
// First Name — .accessibilityIdentifier("edit-profile-first-name-field")
// Last Name — .accessibilityIdentifier("edit-profile-last-name-field")
// Phone — .accessibilityIdentifier("edit-profile-phone-field")
// Street — .accessibilityIdentifier("edit-profile-street-field")
// City — .accessibilityIdentifier("edit-profile-city-field")
// State — .accessibilityIdentifier("edit-profile-state-field")
// ZIP — .accessibilityIdentifier("edit-profile-zip-field")
// Save Changes — .accessibilityIdentifier("edit-profile-save-button")

// PreferencesView:
// Save Preferences — .accessibilityIdentifier("preferences-save-button")

// ChangePasswordView:
// Current Password — .accessibilityIdentifier("change-password-current-field")
// New Password — .accessibilityIdentifier("change-password-new-field")
// Confirm Password — .accessibilityIdentifier("change-password-confirm-field")
// Update Password — .accessibilityIdentifier("change-password-submit-button")
```

- [ ] **Step 12: Build to verify no compilation errors**

```bash
cd /Users/polygentic/Documents/dev/bijoux-ios
xcodebuild build \
    -project bijouxParentApp.xcodeproj \
    -scheme bijouxParentApp \
    -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
    -quiet \
    CODE_SIGNING_ALLOWED=NO
```

Expected: BUILD SUCCEEDED

- [ ] **Step 13: Run existing unit tests to verify no regressions**

```bash
xcodebuild test \
    -project bijouxParentApp.xcodeproj \
    -scheme bijouxParentApp \
    -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
    -quiet
```

Expected: All 1,112 tests pass.

- [ ] **Step 14: Commit and push (in bijoux-ios repo)**

```bash
cd /Users/polygentic/Documents/dev/bijoux-ios
git checkout -b feat/accessibility-identifiers
git add bijouxParentApp/
git commit -m "feat: add accessibility identifiers to all interactive views for UAT automation"
git push -u origin feat/accessibility-identifiers
```

---

## Task 8: Add Accessibility Identifiers — Caregiver App

**Files:**
- Modify: `/Users/polygentic/Documents/dev/bijouxCaregiverApp/bijouxCaregiverApp/Features/Auth/LoginView.swift`
- Modify: `/Users/polygentic/Documents/dev/bijouxCaregiverApp/bijouxCaregiverApp/Features/Auth/CreateAccountView.swift`
- Modify: `/Users/polygentic/Documents/dev/bijouxCaregiverApp/bijouxCaregiverApp/Features/Auth/OTPVerificationView.swift`
- Modify: `/Users/polygentic/Documents/dev/bijouxCaregiverApp/bijouxCaregiverApp/Features/Setup/SetupWizardView.swift`
- Modify: `/Users/polygentic/Documents/dev/bijouxCaregiverApp/bijouxCaregiverApp/Features/Home/HomeView.swift`
- Modify: `/Users/polygentic/Documents/dev/bijouxCaregiverApp/bijouxCaregiverApp/Features/Home/HomeSubviews.swift`
- Modify: `/Users/polygentic/Documents/dev/bijouxCaregiverApp/bijouxCaregiverApp/Features/Home/PreAcceptOfferView.swift`
- Modify: `/Users/polygentic/Documents/dev/bijouxCaregiverApp/bijouxCaregiverApp/Features/Home/PostAcceptOfferView.swift`
- Modify: `/Users/polygentic/Documents/dev/bijouxCaregiverApp/bijouxCaregiverApp/Features/Home/SessionVerificationView.swift`
- Modify: `/Users/polygentic/Documents/dev/bijouxCaregiverApp/bijouxCaregiverApp/Navigation/MainTabView.swift`
- Modify: `/Users/polygentic/Documents/dev/bijouxCaregiverApp/bijouxCaregiverApp/Features/Earnings/EarningsView.swift`
- Modify: `/Users/polygentic/Documents/dev/bijouxCaregiverApp/bijouxCaregiverApp/Features/Preferences/PreferencesView.swift`
- Modify: `/Users/polygentic/Documents/dev/bijouxCaregiverApp/bijouxCaregiverApp/Features/Preferences/ProfileEditView.swift`

Same pattern as Task 7 — append `.accessibilityIdentifier()` modifiers. No behavioral changes.

- [ ] **Step 1: Add identifiers to auth views**

```swift
// LoginView:
// Email field — .accessibilityIdentifier("login-email-field")
// Password field — .accessibilityIdentifier("login-password-field")
// Sign In button — .accessibilityIdentifier("login-submit-button")
// Sign Up link — .accessibilityIdentifier("login-signup-link")

// CreateAccountView:
// First Name — .accessibilityIdentifier("signup-first-name-field")
// Last Name — .accessibilityIdentifier("signup-last-name-field")
// Email — .accessibilityIdentifier("signup-email-field")
// Password — .accessibilityIdentifier("signup-password-field")
// Confirm Password — .accessibilityIdentifier("signup-confirm-password-field")
// Continue/Create Account — .accessibilityIdentifier("signup-continue-button")
// Back — .accessibilityIdentifier("signup-back-button")
// Log In link — .accessibilityIdentifier("signup-login-link")

// OTPVerificationView:
// Digit fields — .accessibilityIdentifier("otp-digit-\(index)-field")
// Verify button — .accessibilityIdentifier("otp-verify-button")
// Resend button — .accessibilityIdentifier("otp-resend-button")
```

- [ ] **Step 2: Add identifiers to SetupWizardView.swift**

```swift
// Step 0 — Personal:
// First Name — .accessibilityIdentifier("setup-first-name-field")
// Last Name — .accessibilityIdentifier("setup-last-name-field")
// Phone — .accessibilityIdentifier("setup-phone-field")
// PhotosPicker — .accessibilityIdentifier("setup-photo-picker")

// Step 1 — Address:
// Street — .accessibilityIdentifier("setup-street-field")
// Apt/Suite — .accessibilityIdentifier("setup-street2-field")
// City — .accessibilityIdentifier("setup-city-field")
// State picker — .accessibilityIdentifier("setup-state-picker")
// ZIP — .accessibilityIdentifier("setup-zip-field")
// DOB DatePicker — .accessibilityIdentifier("setup-dob-picker")

// Step 3 — Preferences (each toggle):
// .accessibilityIdentifier("setup-pref-stairs-toggle")
// .accessibilityIdentifier("setup-pref-outdoor-toggle")
// .accessibilityIdentifier("setup-pref-cats-toggle")
// .accessibilityIdentifier("setup-pref-dogs-toggle")

// Navigation:
// Continue/Get Started — .accessibilityIdentifier("setup-continue-button")
// Back — .accessibilityIdentifier("setup-back-button")
```

- [ ] **Step 3: Add identifiers to home and session views**

```swift
// HomeSubviews.swift — HomeDashboardView:
// Online toggle — .accessibilityIdentifier("home-online-toggle")
// Active job card — .accessibilityIdentifier("home-active-job-card")
// Greeting text — .accessibilityIdentifier("home-greeting-label")

// PreAcceptOfferView:
// Accept button — .accessibilityIdentifier("offer-accept-button")
// Decline button — .accessibilityIdentifier("offer-decline-button")

// PostAcceptOfferView:
// I'm On My Way button — .accessibilityIdentifier("post-accept-iomw-button")

// HomeSubviews — EnRouteView:
// I've Arrived button — .accessibilityIdentifier("en-route-arrived-button")

// HomeSubviews — ArrivedView:
// Verify Identity button — .accessibilityIdentifier("arrived-verify-button")

// SessionVerificationView:
// Capture/Retry button — .accessibilityIdentifier("verification-capture-button")

// HomeSubviews — InProgressView:
// End Job button — .accessibilityIdentifier("in-progress-end-button")

// HomeSubviews — CompletedView:
// Done button — .accessibilityIdentifier("completed-done-button")
```

- [ ] **Step 4: Add identifiers to MainTabView, Earnings, Preferences, ProfileEdit**

```swift
// MainTabView — each tab:
// .accessibilityIdentifier("tab-home")
// .accessibilityIdentifier("tab-activity")
// .accessibilityIdentifier("tab-earnings")
// .accessibilityIdentifier("tab-preferences")

// EarningsView:
// Period filter — .accessibilityIdentifier("earnings-period-picker")
// Earnings amount — .accessibilityIdentifier("earnings-total-label")

// PreferencesView:
// Edit Profile link — .accessibilityIdentifier("preferences-edit-profile-link")
// Change Password link — .accessibilityIdentifier("preferences-change-password-link")
// Log Out button — .accessibilityIdentifier("preferences-logout-button")

// ProfileEditView:
// First Name — .accessibilityIdentifier("edit-profile-first-name-field")
// Last Name — .accessibilityIdentifier("edit-profile-last-name-field")
// Phone — .accessibilityIdentifier("edit-profile-phone-field")
// Bio — .accessibilityIdentifier("edit-profile-bio-field")
// Street — .accessibilityIdentifier("edit-profile-street-field")
// City — .accessibilityIdentifier("edit-profile-city-field")
// State — .accessibilityIdentifier("edit-profile-state-field")
// ZIP — .accessibilityIdentifier("edit-profile-zip-field")
// Years Experience — .accessibilityIdentifier("edit-profile-experience-stepper")
// Save Changes — .accessibilityIdentifier("edit-profile-save-button")
```

- [ ] **Step 5: Build to verify no compilation errors**

```bash
cd /Users/polygentic/Documents/dev/bijouxCaregiverApp
xcodebuild build \
    -project bijouxCaregiverApp.xcodeproj \
    -scheme bijouxCaregiverApp \
    -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
    -quiet \
    CODE_SIGNING_ALLOWED=NO
```

Expected: BUILD SUCCEEDED

- [ ] **Step 6: Run existing unit tests**

```bash
xcodebuild test \
    -project bijouxCaregiverApp.xcodeproj \
    -scheme bijouxCaregiverAppTests \
    -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
    -quiet
```

Expected: All 291 tests pass.

- [ ] **Step 7: Commit and push (in bijouxCaregiverApp repo)**

```bash
cd /Users/polygentic/Documents/dev/bijouxCaregiverApp
git checkout -b feat/accessibility-identifiers
git add bijouxCaregiverApp/
git commit -m "feat: add accessibility identifiers to all interactive views for UAT automation"
git push -u origin feat/accessibility-identifiers
```

---

## Task 9: Maestro Flows — Parent App

**Files:**
- Create: `bijoux-testing/flows/parent/onboarding.yaml`
- Create: `bijoux-testing/flows/parent/login.yaml`
- Create: `bijoux-testing/flows/parent/profile-management.yaml`

Starting with the three foundational flows. More flows are added incrementally after validating Maestro works with the app.

- [ ] **Step 1: Create onboarding.yaml**

Create file `flows/parent/onboarding.yaml`:

```yaml
# jira: BA-XXX
# uat: UAT-1.1 Parent Onboarding — Happy Path
appId: polygentic.bijouxParentApp
---
- launchApp:
    clearState: true
- assertVisible: "Get Started"
- assertVisible: "bijoux"
- takeScreenshot: results/parent-onboarding-start
- tapOn:
    id: "onboarding-get-started-button"
- assertVisible: "Welcome back"
- takeScreenshot: results/parent-onboarding-complete
```

- [ ] **Step 2: Create login.yaml**

Create file `flows/parent/login.yaml`:

```yaml
# jira: BA-XXX
# uat: UAT-2.1 Parent Login — Valid Credentials
appId: polygentic.bijouxParentApp
---
- launchApp:
    clearState: true
- tapOn:
    id: "onboarding-get-started-button"
- assertVisible: "Welcome back"
- tapOn:
    id: "login-email-field"
- inputText: "parent-sarah@test.bijoux.app"
- tapOn:
    id: "login-password-field"
- inputText: "Test1234!"
- takeScreenshot: results/parent-login-filled
- tapOn:
    id: "login-submit-button"
- assertVisible:
    text: "Good"
    timeout: 10000
- takeScreenshot: results/parent-login-success
```

- [ ] **Step 3: Create profile-management.yaml**

Create file `flows/parent/profile-management.yaml`:

```yaml
# jira: BA-XXX
# uat: UAT-7.1 Parent Profile — View and Navigate
appId: polygentic.bijouxParentApp
---
- launchApp:
    clearState: true
- tapOn:
    id: "onboarding-get-started-button"
- tapOn:
    id: "login-email-field"
- inputText: "parent-sarah@test.bijoux.app"
- tapOn:
    id: "login-password-field"
- inputText: "Test1234!"
- tapOn:
    id: "login-submit-button"
- assertVisible:
    text: "Good"
    timeout: 10000
- tapOn:
    id: "tab-profile"
- assertVisible: "Sarah"
- takeScreenshot: results/parent-profile-hub
- tapOn:
    id: "profile-hub-edit-link"
- assertVisible: "Save Changes"
- takeScreenshot: results/parent-edit-profile
- back
- tapOn:
    id: "profile-hub-preferences-link"
- assertVisible: "Save Preferences"
- takeScreenshot: results/parent-preferences
```

- [ ] **Step 4: Test one flow with Maestro**

```bash
cd /Users/polygentic/Documents/dev/bijoux-testing
source config/environment.sh
maestro test flows/parent/onboarding.yaml --device "$PARENT_UDID"
```

Expected: Flow runs, taps "Get Started", navigates to login screen. PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/polygentic/Documents/dev/bijoux-testing
git add flows/parent/
git commit -m "feat: add parent app Maestro flows — onboarding, login, profile"
git push origin main
```

---

## Task 10: Maestro Flows — Caregiver App

**Files:**
- Create: `bijoux-testing/flows/caregiver/onboarding.yaml`
- Create: `bijoux-testing/flows/caregiver/login.yaml`
- Create: `bijoux-testing/flows/caregiver/profile-edit.yaml`

- [ ] **Step 1: Create onboarding.yaml**

Create file `flows/caregiver/onboarding.yaml`:

```yaml
# jira: BA-XXX
# uat: UAT-1.2 Caregiver Onboarding — Happy Path
appId: polygentic.bijouxCaregiverApp
---
- launchApp:
    clearState: true
- assertVisible: "Get Started"
- takeScreenshot: results/caregiver-onboarding-start
- tapOn:
    id: "onboarding-get-started-button"
- assertVisible: "Welcome back"
- takeScreenshot: results/caregiver-onboarding-complete
```

- [ ] **Step 2: Create login.yaml**

Create file `flows/caregiver/login.yaml`:

```yaml
# jira: BA-XXX
# uat: UAT-2.2 Caregiver Login — Valid Credentials
appId: polygentic.bijouxCaregiverApp
---
- launchApp:
    clearState: true
- tapOn:
    id: "onboarding-get-started-button"
- assertVisible: "Welcome back"
- tapOn:
    id: "login-email-field"
- inputText: "cg-emma@test.bijoux.app"
- tapOn:
    id: "login-password-field"
- inputText: "Test1234!"
- takeScreenshot: results/caregiver-login-filled
- tapOn:
    id: "login-submit-button"
- assertVisible:
    text: "Good"
    timeout: 10000
- takeScreenshot: results/caregiver-login-success
```

- [ ] **Step 3: Create profile-edit.yaml**

Create file `flows/caregiver/profile-edit.yaml`:

```yaml
# jira: BA-XXX
# uat: UAT-7.2 Caregiver Profile — View and Navigate
appId: polygentic.bijouxCaregiverApp
---
- launchApp:
    clearState: true
- tapOn:
    id: "onboarding-get-started-button"
- tapOn:
    id: "login-email-field"
- inputText: "cg-emma@test.bijoux.app"
- tapOn:
    id: "login-password-field"
- inputText: "Test1234!"
- tapOn:
    id: "login-submit-button"
- assertVisible:
    text: "Good"
    timeout: 10000
- tapOn:
    id: "tab-preferences"
- assertVisible: "Emma"
- takeScreenshot: results/caregiver-preferences
- tapOn:
    id: "preferences-edit-profile-link"
- assertVisible: "Save Changes"
- takeScreenshot: results/caregiver-edit-profile
```

- [ ] **Step 4: Test one flow with Maestro**

```bash
cd /Users/polygentic/Documents/dev/bijoux-testing
source config/environment.sh
maestro test flows/caregiver/onboarding.yaml --device "$CAREGIVER_UDID"
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add flows/caregiver/
git commit -m "feat: add caregiver app Maestro flows — onboarding, login, profile"
git push origin main
```

---

## Task 11: Admin Portal Flows (Claude in Chrome)

**Files:**
- Create: `bijoux-testing/flows/admin/login.md`
- Create: `bijoux-testing/flows/admin/dashboard-kpis.md`

- [ ] **Step 1: Create login.md**

Create file `flows/admin/login.md`:

```markdown
# Admin Portal — Login Flow

## Prerequisites
- Admin portal running at http://localhost:3001
- Backend running and seeded (admin@bijoux.app account exists)

## Steps

1. Navigate to http://localhost:3001/login
2. Verify the login page loads — look for an email input field with id="email"
3. Click the email input field and type: admin@bijoux.app
4. Click the password input field (id="password") and type: Test1234!
5. Click the "Sign In" button (button[type="submit"])
6. Wait for redirect to dashboard — verify URL is http://localhost:3001/
7. Verify the sidebar is visible with text "Bijoux Admin"
8. Take a screenshot

## Pass Criteria
- Login form accepts credentials without error
- Redirects to dashboard after login
- Sidebar navigation is visible with "Bijoux Admin" logo text
```

- [ ] **Step 2: Create dashboard-kpis.md**

Create file `flows/admin/dashboard-kpis.md`:

```markdown
# Admin Portal — Dashboard KPIs

## Prerequisites
- Logged in to admin portal (run login.md first)

## Steps

1. Verify URL is http://localhost:3001/ (dashboard)
2. Look for 4 KPI cards with these labels:
   - "Active Sessions"
   - "Revenue (MTD)"
   - "Caregivers Online"
   - "Pending Approval"
3. Verify the "Bookings Today" card is visible
4. Verify the "Recent Activity" card is visible
5. Click the "Caregivers" link in the sidebar (a[href="/caregivers"])
6. Verify the caregivers list page loads — look for a table or data table component
7. Take a screenshot
8. Click the "Dashboard" link in the sidebar to return (a[href="/"])

## Pass Criteria
- All 4 KPI cards are rendered with numeric values (not "Loading...")
- Bookings Today and Recent Activity sections are visible
- Caregivers page loads without error
- Navigation between pages works
```

- [ ] **Step 3: Commit**

```bash
cd /Users/polygentic/Documents/dev/bijoux-testing
git add flows/admin/
git commit -m "feat: add admin portal Claude in Chrome test prompts — login, dashboard"
git push origin main
```

---

## Task 12: Cross-App Flow

**Files:**
- Create: `bijoux-testing/flows/cross-app/full-booking-lifecycle.md`

- [ ] **Step 1: Create full-booking-lifecycle.md**

Create file `flows/cross-app/full-booking-lifecycle.md`:

```markdown
# Cross-App — Full Booking Lifecycle

## Prerequisites
- Backend running and seeded (including test accounts)
- Both iOS simulators booted with apps installed
- Admin portal running at http://localhost:3001
- Parent sim UDID available as $PARENT_UDID
- Caregiver sim UDID available as $CAREGIVER_UDID

## Steps

### Phase 1: Parent Creates Booking
1. Run `maestro test flows/parent/login.yaml --device $PARENT_UDID`
2. On the parent simulator, tap the "Request Now" card (id: home-request-now-card)
3. Verify QuickBookingView loads — look for "Request Caregiver" button
4. Take screenshot: results/cross-app-booking-created

### Phase 2: Backend Creates Match
5. Call backend to simulate caregiver acceptance:
   ```bash
   # First, get the active match request
   source config/environment.sh
   ACCESS_TOKEN=$(curl -s -X POST "$BACKEND_URL/auth/login" \
     -H "Content-Type: application/json" \
     -d '{"email":"parent-sarah@test.bijoux.app","password":"Test1234!"}' \
     | python3 -c "import sys,json; print(json.load(sys.stdin)['accessToken'])")

   # Create booking
   BOOKING_ID=$(curl -s -X POST "$BACKEND_URL/bookings" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $ACCESS_TOKEN" \
     -d '{"type":"request_now","address":"123 Test St, Austin, TX","latitude":30.2672,"longitude":-97.7431}' \
     | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

   # Start matching
   MATCH_ID=$(curl -s -X POST "$BACKEND_URL/matching/start" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $ACCESS_TOKEN" \
     -d "{\"bookingId\":\"$BOOKING_ID\"}" \
     | python3 -c "import sys,json; print(json.load(sys.stdin)['matchRequestId'])")

   # Simulate caregiver accepting
   curl -s -X POST "$BACKEND_URL/matching/admin/simulate-accept" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $ACCESS_TOKEN" \
     -d "{\"requestId\":\"$MATCH_ID\"}"
   ```

### Phase 3: Verify in Admin Portal
6. In admin portal browser, navigate to Sessions page (click "Sessions" in sidebar)
7. Look for a session row — verify it exists
8. Take screenshot: results/cross-app-admin-session

### Phase 4: Caregiver Sees Session
9. Run `maestro test flows/caregiver/login.yaml --device $CAREGIVER_UDID`
10. On caregiver simulator, verify home screen shows an active job or offer
11. Take screenshot: results/cross-app-caregiver-home

## Pass Criteria
- Parent can initiate a booking via the app
- Backend matching produces a caregiver assignment
- Admin portal shows the session
- Caregiver app reflects the matched state
- All screenshots captured without error
```

- [ ] **Step 2: Commit**

```bash
cd /Users/polygentic/Documents/dev/bijoux-testing
git add flows/cross-app/
git commit -m "feat: add cross-app full booking lifecycle flow"
git push origin main
```

---

## Task 13: CLAUDE.md — Agent Playbook

**Files:**
- Create: `bijoux-testing/CLAUDE.md`

- [ ] **Step 1: Create CLAUDE.md**

Create file `CLAUDE.md`:

```markdown
# CLAUDE.md — bijoux-testing

## Purpose

Autonomous UAT testing for the bijoux platform. This repo contains Maestro YAML flows for iOS app automation, Claude in Chrome prompts for admin portal automation, shell scripts for orchestration, and Jira integration for test reporting.

## Quick Start

```bash
# One-time setup
./config/simulators.sh create
./config/simulators.sh boot

# Run full UAT suite
./scripts/orchestrate.sh
```

## Repo Paths

| Repo | Path |
|------|------|
| Parent iOS app | /Users/polygentic/Documents/dev/bijoux-ios |
| Caregiver iOS app | /Users/polygentic/Documents/dev/bijouxCaregiverApp |
| Admin portal | /Users/polygentic/Documents/dev/bijouxAdmin |
| Backend | /Users/polygentic/Documents/dev/bijoux-backend |
| This repo | /Users/polygentic/Documents/dev/bijoux-testing |

## Credentials

Jira API credentials: `~/.config/bijoux/jira.env`
Test account credentials: `fixtures/test-accounts.json`
All test account password: `Test1234!`

## Autonomous UAT Run Sequence

When told "run UAT", "run full test suite", or "run tests", follow this sequence:

### 1. Validate Prerequisites
- Source `config/environment.sh`
- Verify Jira token: `source scripts/jira-helpers.sh && jira_validate_token`
- Verify simulators exist: check $PARENT_UDID and $CAREGIVER_UDID are non-empty
- If simulators missing: run `./config/simulators.sh create`

### 2. Start Backend
- Run `./scripts/backend-up.sh`
- Verify: `curl -s http://localhost:3000/api/v1/pricing/current` returns JSON

### 3. Build and Deploy iOS Apps
- Run `./scripts/build-parent.sh`
- Run `./scripts/build-caregiver.sh`
- Boot simulators: `./config/simulators.sh boot`

### 4. Start Admin Portal
- `cd /Users/polygentic/Documents/dev/bijouxAdmin && npm run dev &`
- Wait for http://localhost:3001 to respond

### 5. Run Single-App Flows
- Run all `flows/parent/*.yaml` with Maestro against $PARENT_UDID
- Run all `flows/caregiver/*.yaml` with Maestro against $CAREGIVER_UDID
- Execute each `flows/admin/*.md` prompt via Claude in Chrome

### 6. Run Cross-App Flows
- Read each `flows/cross-app/*.md` file
- Execute the steps (interleaving Maestro, curl, and browser actions)
- Screenshot at each checkpoint

### 7. Report Results
- Run `./scripts/jira-report.sh results/`
- For each flow with a `# jira:` tag, post pass/fail comment to that ticket
- For failures, attach screenshot to Jira ticket
- For failures without a Jira tag, create a Bug in BA project

### 8. Cleanup
- `./config/simulators.sh shutdown`
- `./scripts/backend-down.sh`
- Kill admin portal dev server

## Failure Handling

- **Build failure**: Skip that app's flows. Report build failure as a Bug in BA.
- **Flow failure**: Continue running remaining flows. Report each failure individually.
- **Backend failure**: Abort all flows. Report infrastructure failure.
- **Jira failure**: Log to results/ file. Don't block test execution on Jira errors.

## Maestro Usage

Run a single flow:
```bash
maestro test flows/parent/login.yaml --device $PARENT_UDID
```

Run all flows for an app:
```bash
maestro test flows/parent/ --device $PARENT_UDID
```

## Jira API

```bash
source config/environment.sh
source scripts/jira-helpers.sh

# Add a comment
jira_add_comment "BA-123" "UAT-1.1 PASSED — 2026-06-10"

# Attach a screenshot
jira_attach_file "BA-123" "results/screenshot.png"

# Create a bug
jira_create_bug "BUG: Login fails on empty email" "Steps: 1. Open app 2. Tap login with empty email" "SEV-3"

# Transition to Done
jira_transition_to_done "BA-123"
```

## Jira Project Reference

| Property | Value |
|----------|-------|
| Project key | BA |
| Issue types | Epic (10093), Story (10092), Task (10090), Bug (10091) |
| Transitions | To Do (11) → In Progress (21) → Done (31) |
| Search endpoint | GET /rest/api/3/search/jql (NOT /search — deprecated) |

## Adding New Flows

1. Create a YAML file in the appropriate `flows/` directory
2. Add `# jira: BA-XXX` and `# uat: UAT-N.N Description` comments at the top
3. Use accessibility identifiers from `docs/accessibility-id-conventions.md`
4. Test locally: `maestro test flows/your-flow.yaml --device $UDID`
5. Commit and push
```

- [ ] **Step 2: Commit**

```bash
cd /Users/polygentic/Documents/dev/bijoux-testing
git add CLAUDE.md
git commit -m "feat: add CLAUDE.md agent playbook for autonomous UAT runs"
git push origin main
```

---

## Task 14: Orchestrate Script

**Files:**
- Create: `bijoux-testing/scripts/orchestrate.sh`

- [ ] **Step 1: Create orchestrate.sh**

Create file `scripts/orchestrate.sh`:

```bash
#!/usr/bin/env bash
# Full autonomous UAT run
# Usage: ./scripts/orchestrate.sh [--skip-build] [--skip-backend]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$REPO_DIR/config/environment.sh"
source "$SCRIPT_DIR/jira-helpers.sh"

SKIP_BUILD=false
SKIP_BACKEND=false
for arg in "$@"; do
    case $arg in
        --skip-build)   SKIP_BUILD=true ;;
        --skip-backend) SKIP_BACKEND=true ;;
    esac
done

RESULTS_DIR="$REPO_DIR/results"
TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
RUN_DIR="$RESULTS_DIR/$TIMESTAMP"
mkdir -p "$RUN_DIR"

echo "==========================================="
echo "  Bijoux UAT Run — $TIMESTAMP"
echo "==========================================="

# --- 1. Validate ---
echo ""
echo "=== Step 1: Validate Prerequisites ==="
jira_validate_token
if [[ -z "$PARENT_UDID" || -z "$CAREGIVER_UDID" ]]; then
    echo "Simulators not found. Creating..."
    "$REPO_DIR/config/simulators.sh" create
    source "$REPO_DIR/config/environment.sh"
fi
echo "Parent simulator: $PARENT_UDID"
echo "Caregiver simulator: $CAREGIVER_UDID"

# --- 2. Backend ---
if [[ "$SKIP_BACKEND" == "false" ]]; then
    echo ""
    echo "=== Step 2: Start Backend ==="
    "$SCRIPT_DIR/backend-up.sh"
fi

# --- 3. Build ---
if [[ "$SKIP_BUILD" == "false" ]]; then
    echo ""
    echo "=== Step 3: Build iOS Apps ==="
    "$SCRIPT_DIR/build-parent.sh" || {
        echo "PARENT BUILD FAILED" >> "$RUN_DIR/errors.txt"
        jira_create_bug "BUG: Parent app build failure" "xcodebuild failed during UAT run $TIMESTAMP" "SEV-2"
    }
    "$SCRIPT_DIR/build-caregiver.sh" || {
        echo "CAREGIVER BUILD FAILED" >> "$RUN_DIR/errors.txt"
        jira_create_bug "BUG: Caregiver app build failure" "xcodebuild failed during UAT run $TIMESTAMP" "SEV-2"
    }
fi

# --- 4. Boot Simulators ---
echo ""
echo "=== Step 4: Boot Simulators ==="
"$REPO_DIR/config/simulators.sh" boot

# --- 5. Run Maestro Flows ---
echo ""
echo "=== Step 5: Run Parent App Flows ==="
for flow in "$REPO_DIR"/flows/parent/*.yaml; do
    echo "  Running: $(basename "$flow")"
    if maestro test "$flow" --device "$PARENT_UDID" --output "$RUN_DIR" 2>&1; then
        echo "  → PASS"
    else
        echo "  → FAIL"
        xcrun simctl io "$PARENT_UDID" screenshot "$RUN_DIR/fail-$(basename "$flow" .yaml).png" 2>/dev/null || true
    fi
done

echo ""
echo "=== Step 6: Run Caregiver App Flows ==="
for flow in "$REPO_DIR"/flows/caregiver/*.yaml; do
    echo "  Running: $(basename "$flow")"
    if maestro test "$flow" --device "$CAREGIVER_UDID" --output "$RUN_DIR" 2>&1; then
        echo "  → PASS"
    else
        echo "  → FAIL"
        xcrun simctl io "$CAREGIVER_UDID" screenshot "$RUN_DIR/fail-$(basename "$flow" .yaml).png" 2>/dev/null || true
    fi
done

# --- 7. Report ---
echo ""
echo "=== Step 7: Report to Jira ==="
"$SCRIPT_DIR/jira-report.sh" "$RUN_DIR"

# --- 8. Cleanup ---
echo ""
echo "=== Step 8: Cleanup ==="
"$REPO_DIR/config/simulators.sh" shutdown
if [[ "$SKIP_BACKEND" == "false" ]]; then
    "$SCRIPT_DIR/backend-down.sh"
fi

echo ""
echo "==========================================="
echo "  UAT Run Complete — Results in $RUN_DIR"
echo "==========================================="
```

- [ ] **Step 2: Make executable**

```bash
chmod +x scripts/orchestrate.sh
```

- [ ] **Step 3: Commit**

```bash
cd /Users/polygentic/Documents/dev/bijoux-testing
git add scripts/orchestrate.sh
git commit -m "feat: add full orchestration script for autonomous UAT runs"
git push origin main
```

---

## Task 15: End-to-End Validation

This task validates the entire pipeline works end-to-end.

- [ ] **Step 1: Run the onboarding flow against the parent app**

```bash
cd /Users/polygentic/Documents/dev/bijoux-testing
source config/environment.sh
./config/simulators.sh boot
maestro test flows/parent/onboarding.yaml --device "$PARENT_UDID"
```

Expected: PASS — app launches, "Get Started" is visible, taps it, navigates to login.

- [ ] **Step 2: Run the login flow against the parent app (requires backend)**

```bash
./scripts/backend-up.sh
maestro test flows/parent/login.yaml --device "$PARENT_UDID"
```

Expected: PASS — logs in with test credentials, sees home screen.

- [ ] **Step 3: Test Jira reporting**

```bash
source scripts/jira-helpers.sh
jira_add_comment "BA-262" "UAT test comment — automated validation. Safe to delete."
```

Expected: Comment appears on BA-262 in Jira.

- [ ] **Step 4: Run the caregiver onboarding flow**

```bash
maestro test flows/caregiver/onboarding.yaml --device "$CAREGIVER_UDID"
```

Expected: PASS

- [ ] **Step 5: Clean up**

```bash
./config/simulators.sh shutdown
./scripts/backend-down.sh
```

- [ ] **Step 6: Final commit with any fixes**

If any adjustments were needed during validation, commit them:

```bash
git add -A
git commit -m "fix: adjustments from end-to-end validation"
git push origin main
```
