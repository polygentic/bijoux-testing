# Handoff — Bijoux Testing Infrastructure

## What This Is

This repo will be the autonomous UAT testing infrastructure for the bijoux platform — three apps tested by Claude Code without human intervention:

- **Parent iOS app** (`/Users/polygentic/Documents/dev/bijoux-ios`)
- **Caregiver iOS app** (`/Users/polygentic/Documents/dev/bijouxCaregiverApp`)
- **Admin web portal** (`/Users/polygentic/Documents/dev/bijouxAdmin`)
- **Backend API** (`/Users/polygentic/Documents/dev/bijoux-backend`)

## What Was Decided

A full brainstorming and spec-driven-development process produced:

- **Spec:** `docs/superpowers/specs/2026-06-10-bijoux-testing-infrastructure-design.md`
- **Plan:** `docs/superpowers/plans/2026-06-10-bijoux-testing-infrastructure.md`

Key decisions made:
- **Maestro MCP** for iOS app automation (declarative YAML flows)
- **Claude in Chrome** for admin portal automation (already configured)
- **Jira REST API v3** for test reporting (token verified and stored at `~/.config/bijoux/jira.env`)
- **Fully autonomous** — Claude runs the full suite unattended, reports to Jira
- **Local backend** — docker compose + seed, not staging
- **All three apps** from day one
- **Existing Jira project BA** — no new board needed

## How to Execute

### Step 1: Initialize this repo

```
ACTIVATE: IMPLEMENTER
```

Then invoke the plan:

```
Execute the implementation plan at docs/superpowers/plans/2026-06-10-bijoux-testing-infrastructure.md using subagent-driven-development.
```

### Step 2: The plan has 15 tasks

| Task | What | Where |
|------|------|-------|
| 1 | Install Maestro CLI + MCP | System-level |
| 2 | Create repo structure (.gitignore, dirs, conventions doc) | This repo |
| 3 | Config + simulator scripts | This repo |
| 4 | Backend + build scripts | This repo |
| 5 | Jira helper scripts | This repo |
| 6 | Test fixtures | This repo |
| 7 | Accessibility identifiers — parent app | bijoux-ios (sibling repo) |
| 8 | Accessibility identifiers — caregiver app | bijouxCaregiverApp (sibling repo) |
| 9 | Maestro flows — parent app | This repo |
| 10 | Maestro flows — caregiver app | This repo |
| 11 | Admin portal flows (Claude in Chrome) | This repo |
| 12 | Cross-app flow | This repo |
| 13 | CLAUDE.md agent playbook | This repo |
| 14 | Orchestrate script | This repo |
| 15 | End-to-end validation | All repos |

Tasks 7 and 8 modify sibling repos (adding `.accessibilityIdentifier()` to SwiftUI views). The plan has exact file paths and identifier names for every view in both apps.

### Step 3: After execution

Once all tasks are done, you can run the full UAT suite:

```bash
./scripts/orchestrate.sh
```

Or tell Claude: "run UAT"

## Prerequisites Already Done

- [x] Jira API token verified and stored at `~/.config/bijoux/jira.env`
- [x] Jira email: `michael@polygentic.com`
- [x] Jira project BA confirmed (project ID 10069, cloud ID b218a2e4-2e02-42c8-b10b-9cf5509de93d)
- [x] Jira API v3 search endpoint: `/rest/api/3/search/jql` (NOT `/search` — deprecated)
- [x] Jira transitions: To Do (11) → In Progress (21) → Done (31)
- [x] Jira issue types: Epic (10093), Story (10092), Task (10090), Bug (10091), Subtask (10094)
- [x] GitHub CLI authenticated as `polygentic`
- [x] Claude in Chrome MCP configured
- [x] All four codebases explored (test counts, view inventories, accessibility gaps documented)

---

## Active Project: Real Multi-Simulator E2E Matching Flow

**Status:** PLANNED — awaiting execution
**Spec:** `docs/specs/2026-06-12-real-matching-e2e.md`
**Plan:** `docs/superpowers/plans/2026-06-12-real-matching-e2e.md`
**Skill:** Use `superpowers:subagent-driven-development` to execute

### What This Does

Tests the full real matching flow across 4 iOS simulators (2 parent, 2 caregiver) — no simulate accept, real matching engine, real offer delivery, real session lifecycle through booking → match → IOMW → arrival → session start → session end → rating → payment verification.

### Task Tracker

| # | Task | Status | Blocked By | Files |
|---|------|--------|------------|-------|
| 1 | Add test account env vars | pending | — | `config/environment.sh` |
| 2 | Expand to 4 simulators | pending | 1 | `config/environment.sh`, `config/simulators.sh` |
| 3 | Remove all simulate accept refs | pending | 1, 2 | `scripts/cross-app-booking-lifecycle.sh`, flows/ |
| 4 | File Jira ticket (remove simulate) | pending | — | Jira API |
| 5 | Create API helper library | pending | 1 | `scripts/lib/api-helpers.sh` |
| 6 | Login flows for James + Maria | pending | 1 | `flows/parent/login-james.yaml`, `flows/caregiver/login-maria.yaml` |
| 7 | Caregiver sub-flows (go-online, IOMW) | pending | 1 | `flows/caregiver/go-online.yaml`, `flows/caregiver/iomw.yaml` |
| 8 | Parent sub-flows (verify-matched, rate) | pending | 1 | `flows/parent/verify-matched.yaml`, `flows/parent/rate-session.yaml` |
| 9 | Happy path E2E script | pending | 5, 6, 7, 8 | `scripts/cross-app-real-matching-e2e.sh` |
| 10 | Decline-then-accept script | pending | 5, 6, 7 | `scripts/cross-app-decline-then-accept.sh`, `flows/caregiver/decline-offer.yaml` |
| 11 | Multi-parent concurrent script | pending | 5, 6, 7, 8 | `scripts/cross-app-multi-parent.sh` |
| 12 | Cancel-after-match script | pending | 5, 7 | `scripts/cross-app-cancel-after-match.sh` |
| 13 | Update run-suite.sh | pending | 2 | `scripts/run-suite.sh` |
| 14 | Selector validation (inspect real UI) | pending | 6, 7, 8, 9 | All sub-flows |
| 15 | Run E2E + fix failures | pending | 9-14 | All scripts |
| 16 | Update documentation | pending | 15 | `docs/uat-test-plan.md`, spec |

### Acceptance Criteria (from spec)

- **AC-1:** 4 simulators boot with apps installed
- **AC-2:** Happy path E2E passes (book → match → session → payment)
- **AC-3:** Decline-then-accept (Emma declines, Maria accepts)
- **AC-4:** Multi-parent concurrent bookings (Sarah + James)
- **AC-5:** Cancel after match with fee verification
- **AC-6:** Earnings and payment verified via API
- **AC-7:** Zero simulate accept references remain
- **AC-8:** All existing 38 Maestro flows still pass

### How to Execute (for a new session)

```bash
# Read the plan
cat docs/superpowers/plans/2026-06-12-real-matching-e2e.md

# Execute using subagent-driven-development
# Tell Claude: "Execute the plan at docs/superpowers/plans/2026-06-12-real-matching-e2e.md using subagent-driven-development"
```

### Global State Reset (between E2E runs)

```bash
cd /Users/polygentic/Documents/dev/bijoux-backend && npm run db:seed && npx tsx prisma/seed-uat.ts
xcrun simctl terminate "$PARENT_UDID" polygentic.bijouxParentApp 2>/dev/null || true
xcrun simctl terminate "$CAREGIVER_UDID" polygentic.bijouxCaregiverApp 2>/dev/null || true
```

### Critical Rules

- **NEVER use simulate accept** — no `POST /matching/admin/simulate-accept`, no "Simulate Accept" button
- **Always reseed** backend between E2E script runs
- **Selectors are best-guess** — Task 14 validates them against real UI; they will need updates

---

## Prerequisites Not Yet Done

- [ ] Maestro CLI installed (`curl -Ls "https://get.maestro.dev" | bash`)
- [ ] Maestro MCP added to Claude Code (`claude mcp add maestro -- maestro mcp`)
- [ ] iOS simulator runtime matching Xcode 26.5 installed (`xcodebuild -downloadPlatform iOS`)
- [ ] This repo initialized as a git repo and pushed to GitHub

## Critical Context

- **Both iOS apps have ZERO accessibility identifiers today.** Tasks 7 and 8 add ~88 and ~68 identifiers respectively. This is a blocker for all Maestro flows.
- **The parent app CLAUDE.md has a two-role workflow** (PLANNER / IMPLEMENTER). When working in bijoux-ios for Task 7, activate IMPLEMENTER.
- **The caregiver app uses xcodegen** (`project.yml` generates the Xcode project). Build command: `xcodebuild build -scheme bijouxCaregiverApp`.
- **Backend test accounts** all use password `Test1234!`. Parent: `parent-sarah@test.bijoux.app`. Caregiver: `cg-emma@test.bijoux.app`. Admin: `admin@bijoux.app`.
- **Admin portal API URL**: `http://localhost:3000/api/v1` (backend) — admin runs on port 3001 by default.
- **Jira search API changed**: Use `GET /rest/api/3/search/jql?jql=...` not `POST /rest/api/3/search`.
