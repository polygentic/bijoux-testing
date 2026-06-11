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
