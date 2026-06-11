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
