# Bijoux Testing Infrastructure — Design Spec

**Date:** 2026-06-10
**Owner:** michael gamble
**Status:** Draft

---

## Problem

The bijoux platform has three front-end applications — parent iOS app (1,112 unit tests), caregiver iOS app (291 unit tests), and admin web portal (~50 unit tests) — with zero UI automation, zero cross-app integration tests, and no automated UAT capability. UAT plans are defined in CLAUDE.md but none have been written or executed for the 9 completed iOS epics or 12 completed backend epics. Testing each app manually after every change doesn't scale, and cross-app flows (parent books, caregiver accepts, admin verifies) can only be validated by a human running three apps simultaneously.

## Solution

A dedicated `polygentic/bijoux-testing` repository that enables Claude Code to autonomously execute full UAT suites across all three applications. Maestro drives iOS app automation via declarative YAML flows, Claude in Chrome drives admin portal automation via structured prompts, and a shell-based orchestrator ties them together with backend lifecycle management and Jira reporting.

## Done When

1. `bijoux-testing` repo exists on GitHub with CLAUDE.md, orchestration scripts, and flow directories
2. Claude Code can run `flows/parent/login.yaml` against the parent app in a booted simulator and get a pass/fail result
3. Claude Code can run `flows/caregiver/login.yaml` against the caregiver app in a second booted simulator and get a pass/fail result
4. Claude Code can navigate the admin portal login page via Claude in Chrome and verify the dashboard loads
5. Claude Code can execute a cross-app flow: parent creates booking → backend processes match → caregiver receives offer → admin portal shows session
6. Test results are posted to Jira BA project as comments on UAT task tickets, with screenshots attached on failure
7. Bug tickets are auto-created in BA project for failures not linked to existing UAT tasks
8. Both iOS apps have accessibility identifiers on all interactive elements (buttons, fields, cards, toggles) and key assertion targets (labels, status text, balances)
9. The full UAT suite can run autonomously — Claude reads CLAUDE.md, stands up backend, builds apps, runs all flows, reports to Jira, and tears down — without human intervention

## Out of Scope

- CI/CD pipeline integration (GitHub Actions) — future phase
- Physical device testing — simulator only
- Performance/load testing
- Caregiver Veriff integration testing (mock-only in app)
- Caregiver Support/chat testing (mock-only in app)
- Backend unit/integration test execution (already handled in bijoux-backend)
- Snapshot/visual regression testing
- Push notification testing

---

## Architecture

### Repository: `polygentic/bijoux-testing`

```
bijoux-testing/
├── CLAUDE.md                      # Agent playbook for autonomous UAT runs
├── .gitignore
├── config/
│   ├── environment.sh             # Simulator UDIDs, bundle IDs, backend URL
│   └── simulators.sh              # Create/boot/teardown named simulators
├── scripts/
│   ├── orchestrate.sh             # Full run: backend → build → test → report → cleanup
│   ├── backend-up.sh              # docker compose up + healthy check + seed
│   ├── backend-down.sh            # docker compose down
│   ├── build-parent.sh            # xcodebuild + install parent app on simulator
│   ├── build-caregiver.sh         # xcodebuild + install caregiver app on simulator
│   ├── jira-report.sh             # Post results to Jira (comment, screenshot, bug)
│   └── jira-helpers.sh            # Shared functions: create issue, add comment, attach file
├── fixtures/
│   ├── test-accounts.json         # Parent + caregiver + admin test credentials
│   └── expected-states.json       # Known-good states for assertion reference
├── flows/
│   ├── parent/                    # Maestro YAML — parent app UAT flows
│   │   ├── onboarding.yaml
│   │   ├── login.yaml
│   │   ├── signup-and-otp.yaml
│   │   ├── quick-booking.yaml
│   │   ├── scheduled-booking.yaml
│   │   ├── matching-flow.yaml
│   │   ├── active-session.yaml
│   │   ├── session-summary.yaml
│   │   ├── profile-management.yaml
│   │   ├── activity-history.yaml
│   │   └── payment-methods.yaml
│   ├── caregiver/                 # Maestro YAML — caregiver app UAT flows
│   │   ├── onboarding.yaml
│   │   ├── login.yaml
│   │   ├── setup-wizard.yaml
│   │   ├── go-online.yaml
│   │   ├── accept-offer.yaml
│   │   ├── active-session.yaml
│   │   ├── earnings.yaml
│   │   └── profile-edit.yaml
│   ├── admin/                     # Claude in Chrome prompt scripts — admin portal
│   │   ├── login.md
│   │   ├── dashboard-kpis.md
│   │   ├── user-management.md
│   │   ├── caregiver-approval.md
│   │   ├── booking-detail.md
│   │   ├── session-detail.md
│   │   └── pricing-config.md
│   └── cross-app/                 # Multi-app orchestrated scenarios
│       ├── full-booking-lifecycle.md
│       ├── caregiver-onboard-to-first-job.md
│       └── payment-end-to-end.md
├── results/                       # .gitignored — screenshots, logs, run reports
│   └── .gitkeep
└── docs/
    └── accessibility-id-conventions.md
```

### Tool Stack

| Tool | Target | Purpose | Install |
|------|--------|---------|---------|
| Maestro MCP | Both iOS apps | Declarative YAML test flows: tap, type, assert, screenshot | `curl -Ls "https://get.maestro.dev" \| bash` then `claude mcp add maestro -- maestro mcp` |
| Claude in Chrome | Admin portal | Browser automation: navigate, read DOM, fill forms, screenshot | Already configured |
| xcrun simctl | Simulator lifecycle | Boot, install, launch, screenshot, terminate | Built into Xcode |
| xcodebuild | iOS app builds | Compile both apps for simulator targets | Built into Xcode |
| Jira REST API v3 | Test reporting | Post results, attach screenshots, create bug tickets | `curl` + API token at `~/.config/bijoux/jira.env` |
| docker compose | Backend lifecycle | Start/stop Postgres, Redis, MinIO for local backend | Already installed |

**Not used:**
- XcodeBuildMCP — `xcodebuild` via Bash is sufficient; fewer moving parts
- AXe — Maestro covers the same need (accessibility-based interaction) with declarative YAML
- Computer Use — too slow for autonomous runs; Maestro + Claude in Chrome cover all surfaces
- ios-simulator-mcp — overlaps with Maestro

### Simulator Configuration

Two named simulators running concurrently for cross-app flows:

| Simulator | Name | App | Bundle ID |
|-----------|------|-----|-----------|
| 1 | `bijoux-parent` | bijouxParentApp | `polygentic.bijouxParentApp` |
| 2 | `bijoux-care` | bijouxCaregiverApp | `polygentic.bijouxCaregiverApp` |

Created once via `xcrun simctl create`, UDIDs stored in `config/environment.sh`. The `config/simulators.sh` script auto-detects the latest installed iOS runtime and creates simulators using iPhone 16 Pro device type (or falls back to the newest available iPhone device type).

---

## Maestro Flow Design

### Flow Structure

Each YAML flow maps to one UAT scenario. Flows are self-contained — they launch the app fresh with `clearState: true` and don't depend on state from other flows.

### Element Targeting

Flows use `accessibilityIdentifier` values via the `id:` selector for interactive elements, and text-based `assertVisible` / `tapOn` for stable display text.

### Naming Convention for Accessibility Identifiers

Format: `{screen}-{element}-{type}`

Examples:
- `login-email-field`
- `login-password-field`
- `login-submit-button`
- `home-request-now-card`
- `home-schedule-card`
- `onboarding-get-started-button`
- `matching-cancel-button`
- `profile-edit-button`
- `tab-home`, `tab-activity`, `tab-profile`

### Jira Mapping

Each flow includes a front-matter comment with the Jira UAT task ID:

```yaml
# jira: BA-XXX
# uat: UAT-1.1 Onboarding — Happy Path
appId: polygentic.bijouxParentApp
---
- launchApp:
    clearState: true
- assertVisible: "Get Started"
```

### Example Flow — Parent Login

```yaml
# jira: BA-XXX
# uat: UAT-2.1 Login — Valid Credentials
appId: polygentic.bijouxParentApp
---
- launchApp:
    clearState: true
- assertVisible: "Get Started"
- tapOn: "Get Started"
- assertVisible: "Welcome back"
- tapOn:
    id: "login-email-field"
- inputText: "parent@test.bijoux.app"
- tapOn:
    id: "login-password-field"
- inputText: "Test1234!"
- tapOn:
    id: "login-submit-button"
- assertVisible: "Good morning"
```

### Cross-App Flows

Cross-app flows use markdown prompts that Claude reads and executes step by step. They interleave Maestro runs, backend API calls, and browser checks:

```markdown
## Full Booking Lifecycle

### Prerequisites
- Backend running and seeded
- Both simulators booted with apps installed
- Admin portal running at localhost:3001

### Steps
1. Run `flows/parent/login.yaml` on bijoux-parent simulator
2. Run `flows/parent/quick-booking.yaml` on bijoux-parent simulator
3. Hit backend: POST /api/v1/matching/admin/simulate-accept
4. Run `flows/caregiver/accept-offer.yaml` on bijoux-care simulator
5. Run `flows/parent/matching-flow.yaml` on bijoux-parent simulator
6. Open admin portal → Sessions page → verify new session row exists
7. Run `flows/caregiver/active-session.yaml` on bijoux-care simulator
8. Run `flows/parent/active-session.yaml` on bijoux-parent simulator
9. Verify payment transaction appears in admin portal Transactions page
10. Screenshot final state of all three surfaces
```

---

## Accessibility Identifier Strategy

### Current State

- Parent app: **0** accessibility identifiers across ~20 screens
- Caregiver app: **1** accessibility label (password toggle in BijouxTextField)

### Required Coverage

Every element that Maestro needs to interact with or assert on must have an `accessibilityIdentifier`. This includes:

| Element Type | Examples | Estimated Count (Parent) | Estimated Count (Caregiver) |
|-------------|----------|--------------------------|---------------------------|
| Buttons | Login, Sign Up, Get Started, Cancel, Save | ~30 | ~25 |
| Text fields | Email, Password, Name, Phone, Address | ~20 | ~15 |
| Cards / tappable areas | Request Now, Schedule, session cards | ~15 | ~10 |
| Tab bar items | Home, Activity, Profile | 3 | 3-4 |
| Status/display text | Greeting, balance, session timer, status chips | ~15 | ~10 |
| Toggle/switches | Preferences, visibility toggle | ~5 | ~5 |
| **Total** | | **~88** | **~68** |

### Implementation Approach

One PR per app. Each PR adds `.accessibilityIdentifier("identifier")` modifiers to SwiftUI views. No behavioral changes. The modifier is purely additive — it sets a property that's only read by accessibility tools and test frameworks.

```swift
// Before
BijouxButton("Log In", style: .primary) { await login() }

// After
BijouxButton("Log In", style: .primary) { await login() }
    .accessibilityIdentifier("login-submit-button")
```

### Design System Components

For reusable components (BijouxButton, BijouxTextField, BijouxCard), identifiers are set at the call site, not inside the component. This keeps identifiers unique per screen.

---

## Orchestration — Full Autonomous Run

### Sequence

```
1. BACKEND SETUP
   ├── cd /Users/polygentic/Documents/dev/bijoux-backend
   ├── docker compose up -d
   ├── Wait for postgres healthy (pg_isready loop)
   ├── npx prisma migrate deploy
   └── npx tsx prisma/seed.ts

2. iOS BUILD + DEPLOY
   ├── xcodebuild -project .../bijouxParentApp.xcodeproj
   │     -scheme bijouxParentApp
   │     -destination 'platform=iOS Simulator,id=<PARENT_UDID>'
   │     -derivedDataPath /tmp/bijoux-build-parent
   │     -quiet
   ├── xcrun simctl install <PARENT_UDID> /tmp/bijoux-build-parent/.../bijouxParentApp.app
   ├── xcodebuild -project .../bijouxCaregiverApp.xcodeproj
   │     -scheme bijouxCaregiverApp
   │     -destination 'platform=iOS Simulator,id=<CARE_UDID>'
   │     -derivedDataPath /tmp/bijoux-build-caregiver
   │     -quiet
   └── xcrun simctl install <CARE_UDID> /tmp/bijoux-build-caregiver/.../bijouxCaregiverApp.app

3. ADMIN PORTAL
   └── cd /Users/polygentic/Documents/dev/bijouxAdmin && npm run dev &

4. SINGLE-APP FLOWS
   ├── maestro test flows/parent/*.yaml --device <PARENT_UDID>
   ├── maestro test flows/caregiver/*.yaml --device <CARE_UDID>
   └── Claude in Chrome: execute each flows/admin/*.md prompt

5. CROSS-APP FLOWS
   └── For each flows/cross-app/*.md:
       ├── Read prompt file
       ├── Execute steps (maestro + curl + browser)
       └── Screenshot at each checkpoint

6. REPORTING
   ├── Parse pass/fail per flow
   ├── For each flow with a jira: tag:
   │   ├── POST /rest/api/3/issue/{key}/comment (pass/fail + evidence)
   │   └── On failure: POST /rest/api/3/issue/{key}/attachments (screenshot)
   ├── For failures without a jira: tag:
   │   ├── POST /rest/api/3/issue (create Bug in BA)
   │   ├── Set severity: SEV-3 default, SEV-2 if core flow
   │   └── Attach screenshot + repro steps
   └── Write results/YYYY-MM-DD-run.md summary

7. CLEANUP
   ├── xcrun simctl shutdown <PARENT_UDID>
   ├── xcrun simctl shutdown <CARE_UDID>
   ├── Kill admin portal dev server
   └── docker compose down (in bijoux-backend)
```

### CLAUDE.md Playbook

The `bijoux-testing/CLAUDE.md` encodes the orchestration sequence above as the agent's playbook. When Claude is told "run UAT" or "run full test suite", it follows this playbook. The CLAUDE.md also includes:

- Paths to all sibling repos (parent app, caregiver app, admin portal, backend)
- Simulator names and how to resolve UDIDs from `config/environment.sh`
- Jira credentials location (`~/.config/bijoux/jira.env`)
- How to source credentials and make Jira API calls
- Failure handling: if a build fails, skip that app's flows and report the build failure to Jira
- Idempotency: the orchestrator can be re-run safely (docker compose up is idempotent, seed uses upserts)

---

## Jira Integration

### Credentials

Stored at `/Users/polygentic/.config/bijoux/jira.env` (chmod 600, outside any git repo):

```
JIRA_EMAIL=michael@polygentic.com
JIRA_API_TOKEN=<token>
JIRA_BASE_URL=https://polygentic.atlassian.net
JIRA_CLOUD_ID=b218a2e4-2e02-42c8-b10b-9cf5509de93d
JIRA_PROJECT_KEY=BA
```

### API Details

- **Endpoint:** Jira Cloud REST API v3
- **Auth:** Basic auth (`email:token`)
- **Search:** `GET /rest/api/3/search/jql?jql=...` (v3 endpoint — `/search` is deprecated)
- **Create issue:** `POST /rest/api/3/issue`
- **Add comment:** `POST /rest/api/3/issue/{issueIdOrKey}/comment`
- **Attach file:** `POST /rest/api/3/issue/{issueIdOrKey}/attachments` (multipart, `X-Atlassian-Token: no-check` header)
- **Transition:** `POST /rest/api/3/issue/{issueIdOrKey}/transitions` with `{ "transition": { "id": "31" } }` for Done

### Reporting Logic

**On pass:**
```
Comment: "UAT-X.Y PASSED — 2026-06-10T14:30:00Z"
Action: If all UATs in the group pass, transition task to Done (31)
```

**On fail:**
```
Comment: "UAT-X.Y FAILED — 2026-06-10T14:30:00Z\nStep: tapOn login-submit-button\nExpected: assertVisible 'Good morning'\nActual: Screen shows 'Invalid credentials'"
Attachment: screenshot-login-fail-2026-06-10.png
Action: Do NOT transition. If no existing bug linked, create Bug in BA with:
  - Summary: "BUG: Login — invalid credentials not handled"
  - Issue type: Bug (10091)
  - Severity label: SEV-3 (default) or SEV-2 (core flow)
  - Description: Repro steps from YAML flow, expected vs actual, screenshot
```

### BA Project Reference

| Property | Value |
|----------|-------|
| Project key | BA |
| Project ID | 10069 |
| Cloud ID | b218a2e4-2e02-42c8-b10b-9cf5509de93d |
| Issue types | Epic (10093), Story (10092), Task (10090), Bug (10091), Subtask (10094) |
| Transitions | To Do (11) → In Progress (21) → Done (31) |

---

## Dependencies & Prerequisites

### Before any flows can run:

1. **Maestro CLI installed** — `curl -Ls "https://get.maestro.dev" | bash`
2. **Maestro MCP added to Claude Code** — `claude mcp add maestro -- maestro mcp`
3. **iOS 26.5 simulator runtime installed** — `xcodebuild -downloadPlatform iOS` (currently missing; Xcode 26.5 requires it)
4. **Two named simulators created** — via `xcrun simctl create`
5. **Accessibility identifiers added to both iOS apps** — blocker for all Maestro flows
6. **Backend running locally** — docker compose + seed
7. **Admin portal running locally** — `npm run dev`
8. **Jira API token valid** — already verified and stored

### Dependency order:

```
iOS simulator runtime install ──┐
                                ├──► Create simulators ──► Build apps ──► Run flows
Accessibility identifier PRs ───┘
Maestro install ─────────────────────────────────────────────────────────► Run flows
Backend + Admin portal ──────────────────────────────────────────────────► Run flows
Repo creation + scripts ─────────────────────────────────────────────────► Run flows
```

---

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Maestro can't interact with SwiftUI elements reliably | Flows fail intermittently | Test with a single flow first before writing all flows; fall back to AXe + Computer Use if Maestro proves unreliable |
| iOS 26.5 simulator runtime is large download / slow | Delays initial setup | Can be done in background; one-time cost |
| Accessibility identifiers are tedious to add (~156 across both apps) | Blocks all Maestro flows | Mechanical work, no risk to app behavior; can be parallelized across apps |
| Cross-app flows are fragile (timing, state dependencies) | False negatives | Add explicit waits/retries at state transitions; use backend polling instead of fixed delays |
| Jira API token expires | Reporting fails silently | Token has long TTL; add token validation check at orchestration start |
| Backend seed data changes break flow assertions | Flows fail | Pin expected values in `fixtures/expected-states.json`; update when seed changes |
| Claude in Chrome browser automation is less deterministic than Maestro | Admin portal tests flake | Keep admin flows simple and focused; use DOM selectors not coordinates |
