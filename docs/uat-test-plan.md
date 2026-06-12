# Bijoux UAT Test Plan

## Overview

Comprehensive user acceptance testing for the Bijoux platform covering the parent iOS app, caregiver iOS app, admin web portal, and cross-app integration flows.

**Automation tools:**
- iOS apps: Maestro CLI (YAML flows)
- Admin portal: Claude-in-Chrome (markdown instruction files)
- Cross-app: Executable bash scripts orchestrating Maestro + API calls (`scripts/*.sh`)

**Test data:** See `docs/seed-data.md` for all required accounts, profiles, and data.

---

## Test Suite Index

### UAT-1: Onboarding

| ID | Test | App | File | Automation |
|----|------|-----|------|------------|
| UAT-1.1 | Parent Onboarding — Happy Path | Parent | `parent/onboarding.yaml` | Maestro |
| UAT-1.2 | Caregiver Onboarding — Happy Path | Caregiver | `caregiver/onboarding.yaml` | Maestro |

### UAT-2: Authentication — Login

| ID | Test | App | File | Automation |
|----|------|-----|------|------------|
| UAT-2.1 | Parent Login — Valid Credentials | Parent | `parent/login-valid.yaml` | Maestro |
| UAT-2.2 | Parent Login — Invalid Email Format | Parent | `parent/login-invalid-email.yaml` | Maestro |
| UAT-2.3 | Parent Login — Wrong Password | Parent | `parent/login-wrong-password.yaml` | Maestro |
| UAT-2.4 | Parent Login — Empty Fields | Parent | `parent/login-empty-fields.yaml` | Maestro |
| UAT-2.5 | Caregiver Login — Valid Credentials | Caregiver | `caregiver/login-valid.yaml` | Maestro |
| UAT-2.6 | Caregiver Login — Invalid Credentials | Caregiver | `caregiver/login-invalid.yaml` | Maestro |

### UAT-3: Authentication — Signup

| ID | Test | App | File | Automation |
|----|------|-----|------|------------|
| UAT-3.1 | Parent Signup — Happy Path | Parent | `parent/signup-happy-path.yaml` | Maestro |
| UAT-3.2 | Parent Signup — Duplicate Email | Parent | `parent/signup-duplicate-email.yaml` | Maestro |
| UAT-3.3 | Parent Signup — Weak Password | Parent | `parent/signup-weak-password.yaml` | Maestro |
| UAT-3.4 | Caregiver Signup — Happy Path | Caregiver | `caregiver/signup-happy-path.yaml` | Maestro |
| UAT-3.5 | Caregiver Signup — Duplicate Email | Caregiver | `caregiver/signup-duplicate-email.yaml` | Maestro |
| UAT-3.6 | Caregiver Setup Wizard — Complete | Caregiver | `caregiver/setup-wizard.yaml` | Maestro |

### UAT-4: Home & Navigation

| ID | Test | App | File | Automation |
|----|------|-----|------|------------|
| UAT-4.1 | Parent Home — Dashboard Content | Parent | `parent/home-dashboard.yaml` | Maestro |
| UAT-4.2 | Parent Home — Tab Navigation | Parent | `parent/tab-navigation.yaml` | Maestro |
| UAT-4.3 | Caregiver Home — Dashboard Content | Caregiver | `caregiver/home-dashboard.yaml` | Maestro |
| UAT-4.4 | Caregiver Home — Tab Navigation | Caregiver | `caregiver/tab-navigation.yaml` | Maestro |
| UAT-4.5 | Caregiver — Go Online/Offline | Caregiver | `caregiver/go-online-offline.yaml` | Maestro |

### UAT-5: Booking

| ID | Test | App | File | Automation |
|----|------|-----|------|------------|
| UAT-5.1 | Parent Quick Booking — Form Entry | Parent | `parent/quick-booking-form.yaml` | Maestro |
| UAT-5.2 | Parent Scheduled Booking — Form Entry | Parent | `parent/scheduled-booking-form.yaml` | Maestro |
| UAT-5.3 | Parent Booking — Cancel During Matching | Parent | `parent/booking-cancel-matching.yaml` | Maestro |

### UAT-6: Matching & Session (requires backend state)

| ID | Test | App | File | Automation |
|----|------|-----|------|------------|
| UAT-6.1 | Parent — Matching Searching State | Parent | `parent/matching-searching.yaml` | Maestro |
| UAT-6.2 | Caregiver — Receive Job Offer | Caregiver | `caregiver/job-offer-receive.yaml` | Maestro |
| UAT-6.3 | Caregiver — Accept Job Offer | Caregiver | `caregiver/job-offer-accept.yaml` | Maestro |

### UAT-7: Profile Management

| ID | Test | App | File | Automation |
|----|------|-----|------|------------|
| UAT-7.1 | Parent Profile — View Hub | Parent | `parent/profile-view.yaml` | Maestro |
| UAT-7.2 | Parent Profile — Edit Fields | Parent | `parent/profile-edit.yaml` | Maestro |
| UAT-7.3 | Parent — Preferences | Parent | `parent/preferences.yaml` | Maestro |
| UAT-7.4 | Parent — Children List | Parent | `parent/children-list.yaml` | Maestro |
| UAT-7.5 | Parent — Add Child | Parent | `parent/children-add.yaml` | Maestro |
| UAT-7.6 | Parent — Change Password | Parent | `parent/change-password.yaml` | Maestro |
| UAT-7.7 | Caregiver Profile — View | Caregiver | `caregiver/profile-view.yaml` | Maestro |
| UAT-7.8 | Caregiver Profile — Edit Fields | Caregiver | `caregiver/profile-edit.yaml` | Maestro |
| UAT-7.9 | Caregiver — Preferences | Caregiver | `caregiver/preferences.yaml` | Maestro |
| UAT-7.10 | Caregiver — Emergency Contacts | Caregiver | `caregiver/emergency-contacts.yaml` | Maestro |

### UAT-8: Activity & History

| ID | Test | App | File | Automation |
|----|------|-----|------|------------|
| UAT-8.1 | Parent — Activity History | Parent | `parent/activity-history.yaml` | Maestro |
| UAT-8.2 | Caregiver — Activity History | Caregiver | `caregiver/activity-history.yaml` | Maestro |
| UAT-8.3 | Caregiver — Earnings | Caregiver | `caregiver/earnings.yaml` | Maestro |

### UAT-9: Admin — Authentication

| ID | Test | App | File | Automation |
|----|------|-----|------|------------|
| UAT-9.1 | Admin Login — Valid | Admin | `admin/login.md` | Chrome |
| UAT-9.2 | Admin Login — Invalid | Admin | `admin/login-invalid.md` | Chrome |
| UAT-9.3 | Admin Logout | Admin | `admin/logout.md` | Chrome |

### UAT-10: Admin — Dashboard

| ID | Test | App | File | Automation |
|----|------|-----|------|------------|
| UAT-10.1 | Admin Dashboard — KPI Cards | Admin | `admin/dashboard-kpis.md` | Chrome |
| UAT-10.2 | Admin Dashboard — Recent Activity | Admin | `admin/dashboard-activity.md` | Chrome |

### UAT-11: Admin — User Management

| ID | Test | App | File | Automation |
|----|------|-----|------|------------|
| UAT-11.1 | Admin Users — List & Filter | Admin | `admin/users-list-filter.md` | Chrome |
| UAT-11.2 | Admin Users — Parent Detail | Admin | `admin/user-detail-parent.md` | Chrome |
| UAT-11.3 | Admin Users — Suspend User | Admin | `admin/user-suspend.md` | Chrome |
| UAT-11.4 | Admin Users — Reactivate User | Admin | `admin/user-reactivate.md` | Chrome |
| UAT-11.5 | Admin Users — Issue Credit | Admin | `admin/user-issue-credit.md` | Chrome |
| UAT-11.6 | Admin Users — Issue Refund | Admin | `admin/user-issue-refund.md` | Chrome |

### UAT-12: Admin — Caregiver Management

| ID | Test | App | File | Automation |
|----|------|-----|------|------------|
| UAT-12.1 | Admin Caregivers — List & Pipeline | Admin | `admin/caregivers-list.md` | Chrome |
| UAT-12.2 | Admin Caregivers — Detail View | Admin | `admin/caregiver-detail.md` | Chrome |
| UAT-12.3 | Admin Caregivers — Approve | Admin | `admin/caregiver-approve.md` | Chrome |
| UAT-12.4 | Admin Caregivers — Suspend | Admin | `admin/caregiver-suspend.md` | Chrome |
| UAT-12.5 | Admin Caregivers — Initiate BG Check | Admin | `admin/caregiver-bg-check.md` | Chrome |
| UAT-12.6 | Admin Caregivers — Initiate IDV | Admin | `admin/caregiver-idv.md` | Chrome |
| UAT-12.7 | Admin Caregivers — Generate Invite | Admin | `admin/caregiver-invite.md` | Chrome |

### UAT-13: Admin — Booking Management

| ID | Test | App | File | Automation |
|----|------|-----|------|------------|
| UAT-13.1 | Admin Bookings — List & Filter | Admin | `admin/bookings-list.md` | Chrome |
| UAT-13.2 | Admin Bookings — Detail View | Admin | `admin/booking-detail.md` | Chrome |
| UAT-13.3 | Admin Bookings — Cancel Booking | Admin | `admin/booking-cancel.md` | Chrome |
| UAT-13.4 | Admin Bookings — Price Override | Admin | `admin/booking-price-override.md` | Chrome |

### UAT-14: Admin — Session Management

| ID | Test | App | File | Automation |
|----|------|-----|------|------------|
| UAT-14.1 | Admin Sessions — List & Filter | Admin | `admin/sessions-list.md` | Chrome |
| UAT-14.2 | Admin Sessions — Detail View | Admin | `admin/session-detail.md` | Chrome |
| UAT-14.3 | Admin Sessions — Force Complete | Admin | `admin/session-force-complete.md` | Chrome |
| UAT-14.4 | Admin Sessions — Mark Disputed | Admin | `admin/session-mark-disputed.md` | Chrome |

### UAT-15: Admin — Financial

| ID | Test | App | File | Automation |
|----|------|-----|------|------------|
| UAT-15.1 | Admin Transactions — List & Filter | Admin | `admin/transactions-list.md` | Chrome |
| UAT-15.2 | Admin Transactions — Export CSV | Admin | `admin/transactions-export.md` | Chrome |

### UAT-16: Admin — Trust & Safety

| ID | Test | App | File | Automation |
|----|------|-----|------|------------|
| UAT-16.1 | Admin Incidents — List & Filter | Admin | `admin/incidents-list.md` | Chrome |
| UAT-16.2 | Admin Incidents — Detail View | Admin | `admin/incident-detail.md` | Chrome |
| UAT-16.3 | Admin Incidents — Resolve | Admin | `admin/incident-resolve.md` | Chrome |

### UAT-17: Admin — Audit & Settings

| ID | Test | App | File | Automation |
|----|------|-----|------|------------|
| UAT-17.1 | Admin Audit Log — View & Filter | Admin | `admin/audit-log.md` | Chrome |
| UAT-17.2 | Admin Audit Log — Export CSV | Admin | `admin/audit-log-export.md` | Chrome |
| UAT-17.3 | Admin Pricing — View Markets | Admin | `admin/pricing-list.md` | Chrome |
| UAT-17.4 | Admin Pricing — Create Market | Admin | `admin/pricing-create.md` | Chrome |
| UAT-17.5 | Admin Pricing — Edit Market | Admin | `admin/pricing-edit.md` | Chrome |

### UAT-18: Admin — Global Search

| ID | Test | App | File | Automation |
|----|------|-----|------|------------|
| UAT-18.1 | Admin Global Search | Admin | `admin/global-search.md` | Chrome |

### UAT-19: Cross-App Integration (Executable Scripts)

| ID | Test | Apps | Script | Sub-flows |
|----|------|------|--------|-----------|
| UAT-19.1 | Full Booking Lifecycle | All | `scripts/cross-app-booking-lifecycle.sh` | parent/login-valid, parent/quick-booking-submit, caregiver/login-valid, caregiver/accept-offer, caregiver/confirm-arrival, caregiver/start-session-verify, parent/confirm-session-start, caregiver/end-session, parent/confirm-session-end + API calls |
| UAT-19.2 | Booking Cancellation — Cross-Platform | Parent + Admin | `scripts/cross-app-booking-cancel.sh` | parent/login-valid + API booking creation + API admin cancellation + parent/activity-history |
| UAT-19.3 | Caregiver Approval — End-to-End | Caregiver + Admin | `scripts/cross-app-caregiver-approval.sh` | API BG check + API IDV + API approve + temporary maestro login flow for cg-pending |

---

## Automation Coverage Summary

| Category | Total Tests | Maestro | Chrome | Orchestration | Manual-Only |
|----------|-------------|---------|--------|---------------|-------------|
| Onboarding | 2 | 2 | — | — | — |
| Auth - Login | 6 | 6 | — | — | — |
| Auth - Signup | 6 | 6 | — | — | — |
| Home & Nav | 5 | 5 | — | — | — |
| Booking | 3 | 3 | — | — | — |
| Matching & Session | 3 | 3 | — | — | — |
| Profile | 10 | 10 | — | — | — |
| Activity & History | 3 | 3 | — | — | — |
| Admin Auth | 3 | — | 3 | — | — |
| Admin Dashboard | 2 | — | 2 | — | — |
| Admin Users | 6 | — | 6 | — | — |
| Admin Caregivers | 7 | — | 7 | — | — |
| Admin Bookings | 4 | — | 4 | — | — |
| Admin Sessions | 4 | — | 4 | — | — |
| Admin Financial | 2 | — | 2 | — | — |
| Admin Trust | 3 | — | 3 | — | — |
| Admin Audit/Settings | 5 | — | 5 | — | — |
| Admin Search | 1 | — | 1 | — | — |
| Cross-App | 3 | — | — | 3 | — |
| **TOTAL** | **78** | **38** | **37** | **3** | **0** |

## Known Limitations

1. **Veriff/Checkr not integrated** — identity verification and background check flows are stubbed. Tests validate the UI flow and API call but not real provider responses. Webhook simulation endpoints are used in cross-app scripts.
2. **Push notifications not built** — not yet implemented in the apps. All state-dependent tests use API polling or `extendedWaitUntil` for the UI to update.
3. **Stripe payments not built** — bypass flags enabled in test environment. Admin transaction list tests validate seeded data, not real charges.
4. **Cross-app timing** — cross-app tests use sequential orchestration (parent action → API check → caregiver action). The matching engine's BullMQ worker processes offers asynchronously, so scripts include wait/retry logic.
5. **Biometric prompts** — iOS Face ID/Touch ID cannot be triggered by Maestro. Veriff biometric step is mocked.

## Execution Prerequisites

1. Backend running and seeded (`docker compose up`, `npm run seed:test`)
2. Parent iOS app installed on simulator (bundle: `polygentic.bijouxParentApp`)
3. Caregiver iOS app installed on simulator (bundle: `polygentic.bijouxCaregiverApp`)
4. Admin portal running at `http://localhost:3001`
5. Maestro CLI v2.6+ installed
6. Test accounts seeded per `docs/seed-data.md`
