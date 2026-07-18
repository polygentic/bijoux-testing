# Handoff — Bijoux Testing Infrastructure

## What This Is

This repo will be the autonomous UAT testing infrastructure for the bijoux platform — three apps tested by Claude Code without human intervention:

- **Parent iOS app** (`/Users/polygentic/Documents/dev/bijoux-ios`)
- **Caregiver iOS app** (`/Users/polygentic/Documents/dev/bijouxCaregiverApp`)
- **Admin web portal** (`/Users/polygentic/Documents/dev/bijouxAdmin`)
- **Backend API** (`/Users/polygentic/Documents/dev/bijoux-backend`)

---

## Bug Fix Handoff — UAT Run 2026-06-16

Generated from E2E test results: `results/e2e-run-2026-06-16.json`
Jira project: BA | All tickets have fix recommendations in comments.

**Results:** 55 pass, 13 fail, 4 not testable out of 72 total tests across 4 layers.
**Bugs filed:** 16 (1 SEV-1, 4 SEV-2, 7 SEV-3, 3 L1/infra, 1 DONE)

### Repo Assignment Summary

| Repo | Bugs | Count |
|------|------|-------|
| bijoux-backend | BA-281, BA-282, BA-284, BA-285, BA-287, BA-288 | 6 |
| bijouxAdmin | BA-278, BA-279, BA-280, BA-282, BA-283, BA-284, BA-286, BA-288, BA-289 | 9 |
| bijoux-testing | BA-274 | 1 |
| bijoux-ios (parent) | — | 0 |
| bijouxCaregiverApp | — | 0 |

Note: BA-275 and BA-276 are caused by BA-274 (cascade). BA-277 is DONE. BA-282, BA-284, BA-288 span both backend and admin.

### Dependency Order

1. **bijoux-testing** (BA-274) — unblocks L1 re-testing
2. **bijoux-backend** (BA-281, BA-282, BA-284, BA-285, BA-287, BA-288) — unblocks admin frontend fixes
3. **bijouxAdmin** (all 9 bugs) — some depend on backend endpoints existing
4. Re-run full E2E suite to validate

---

## Backend Session Handoff (bijoux-backend)

Copy everything below the line into the backend Claude Code session:

---

### BACKEND FIX INSTRUCTIONS

Fix 6 bugs from UAT run 2026-06-16. Jira tickets have full context. Do not make changes beyond what's described. Commit each fix individually. Push after each commit.

#### BA-281 [SEV-3] — Offer status 'Cancelled' for accepted offers on booking completion
https://polygentic.atlassian.net/browse/BA-281

When a session completes, ALL offers (including the accepted one) get bulk-updated to 'cancelled'. The accepted offer should be preserved or marked 'completed'.

**File:** `src/modules/session/service.ts` lines ~277-296

Current code:
```typescript
await prisma.matchOffer.updateMany({
  where: {
    matchRequestId: matchRequest.id,
    status: { in: ['pending', 'accepted'] },
  },
  data: { status: 'cancelled' },
});
```

Fix — split into two updates:
```typescript
// Cancel only pending offers
await prisma.matchOffer.updateMany({
  where: { matchRequestId: matchRequest.id, status: 'pending' },
  data: { status: 'cancelled' },
});
// Mark accepted offer as completed
await prisma.matchOffer.updateMany({
  where: { matchRequestId: matchRequest.id, status: 'accepted' },
  data: { status: 'completed' },
});
```

Also check `adminOverrideSession` / force-complete in `src/modules/admin/service.ts` (~line 1330) for the same pattern.

#### BA-282 [SEV-2] — Caregiver reactivation endpoint missing
https://polygentic.atlassian.net/browse/BA-282

No `PUT /trust/caregivers/:id/reactivate` endpoint. The frontend Reactivate button calls the approve endpoint which may fail.

**File:** `src/modules/trust/routes.ts` — insert after suspend route (~line 156)

```typescript
// PUT /api/v1/trust/caregivers/:id/reactivate — Admin: reactivate suspended caregiver
app.put(
  '/caregivers/:id/reactivate',
  { preHandler: [requireAuth(opts.env), requireRole('admin')] },
  async (request, reply) => {
    const params = parseBody(caregiverIdParamSchema, request.params);
    const result = await reactivateCaregiver(deps, params.id);
    return reply.send(result);
  },
);
```

**File:** `src/modules/trust/service.ts` — add after `suspendCaregiver` (~line 330):

```typescript
export async function reactivateCaregiver(
  deps: TrustServiceDeps,
  caregiverProfileId: string,
): Promise<{ status: string; isApproved: boolean }> {
  const profile = await deps.prisma.caregiverProfile.findUnique({
    where: { id: caregiverProfileId },
    select: { id: true, status: true },
  });
  if (!profile) throw new NotFoundError('CaregiverProfile');
  if (profile.status !== 'suspended') {
    throw new BadRequestError('Only suspended caregivers can be reactivated');
  }
  await deps.prisma.caregiverProfile.update({
    where: { id: caregiverProfileId },
    data: { status: 'approved', isApproved: true },
  });
  return { status: 'approved', isApproved: true };
}
```

Don't forget to export from service and import in routes.

#### BA-284 [SEV-3] — Backend missing hasRating filter for sessions
https://polygentic.atlassian.net/browse/BA-284

**File:** `src/modules/admin/schemas.ts` lines 84-87 — add hasRating:
```typescript
export const adminSessionsQuerySchema = paginationQuerySchema.extend({
  status: z.enum(['not_started', 'in_progress', 'completed', 'disputed']).optional(),
  caregiverProfileId: z.string().uuid().optional(),
  hasRating: z.enum(['true', 'false']).optional(),
});
```

**File:** `src/modules/admin/service.ts` — in `listSessionsAdmin` (~line 729), add to the `where` builder:
```typescript
if (input.hasRating === 'true') {
  where.rating = { not: null };
} else if (input.hasRating === 'false') {
  where.rating = null;
}
```

#### BA-285 [SEV-2] — Missing GET /admin/incidents/:id endpoint
https://polygentic.atlassian.net/browse/BA-285

Backend has list and resolve but no detail endpoint. Frontend calls `GET /admin/incidents/{id}` which 404s.

**File:** `src/modules/admin/routes.ts` — insert after GET /incidents list route (after line ~341):
```typescript
// GET /api/v1/admin/incidents/:id — Incident detail
app.get(
  '/incidents/:id',
  { preHandler: [requireAuth(opts.env), requireRole('admin')] },
  async (request, reply) => {
    const { id } = parseBody(idParamSchema, request.params);
    const incident = await getIncidentDetailAdmin(deps, id);
    return reply.send({ incident });
  },
);
```

**File:** `src/modules/admin/service.ts` — add new function:
```typescript
export async function getIncidentDetailAdmin(deps: AdminServiceDeps, incidentId: string) {
  const incident = await deps.prisma.caregiverIncident.findUnique({
    where: { id: incidentId },
    include: {
      caregiverProfile: { select: { id: true, firstName: true, lastName: true } },
    },
  });
  if (!incident) throw new NotFoundError('Incident');
  return {
    id: incident.id,
    type: incident.type,
    description: incident.description,
    caregiverProfileId: incident.caregiverProfileId,
    caregiverProfile: incident.caregiverProfile,
    bookingId: incident.bookingId,
    latitude: incident.latitude,
    longitude: incident.longitude,
    resolvedAt: incident.resolvedAt?.toISOString() ?? null,
    resolutionNotes: incident.resolutionNotes,
    createdAt: incident.createdAt.toISOString(),
  };
}
```

Export from service, import in routes.

#### BA-287 [SEV-1] — Caregiver approval bypasses BG/IDV prerequisite check
https://polygentic.atlassian.net/browse/BA-287

**File:** `src/modules/trust/service.ts` — `approveCaregiver` function (lines 283-304)

Add validation before the update at line ~298:
```typescript
// ADD before the prisma.caregiverProfile.update call:
const bgCheck = await deps.prisma.backgroundCheck.findFirst({
  where: { caregiverProfileId },
  orderBy: { createdAt: 'desc' },
  select: { status: true },
});
const idvResult = await deps.prisma.idvResult.findFirst({
  where: { caregiverProfileId },
  orderBy: { createdAt: 'desc' },
  select: { status: true },
});
if (!bgCheck || bgCheck.status !== 'clear') {
  throw new BadRequestError('Background check must be clear before approval');
}
if (!idvResult || idvResult.status !== 'approved') {
  throw new BadRequestError('Identity verification must be approved before approval');
}
```

#### BA-288 [SEV-3] — Missing Set BG/IDV Status endpoints
https://polygentic.atlassian.net/browse/BA-288

Note: Force Complete and Mark Disputed buttons already exist in frontend. The session override endpoint also exists. The missing pieces are BG/IDV manual status override endpoints.

**File:** `src/modules/trust/routes.ts` — add:
```typescript
// PUT /api/v1/trust/caregivers/:id/bg-status
app.put(
  '/caregivers/:id/bg-status',
  { preHandler: [requireAuth(opts.env), requireRole('admin')] },
  async (request, reply) => {
    const params = parseBody(caregiverIdParamSchema, request.params);
    const body = parseBody(setBgStatusBodySchema, request.body);
    const result = await setBgCheckStatus(deps, params.id, body.status, body.reason);
    return reply.send(result);
  },
);

// PUT /api/v1/trust/caregivers/:id/idv-status
app.put(
  '/caregivers/:id/idv-status',
  { preHandler: [requireAuth(opts.env), requireRole('admin')] },
  async (request, reply) => {
    const params = parseBody(caregiverIdParamSchema, request.params);
    const body = parseBody(setIdvStatusBodySchema, request.body);
    const result = await setIdvStatus(deps, params.id, body.status, body.reason);
    return reply.send(result);
  },
);
```

Add corresponding schemas (status enum + reason string) and service functions that create/update BackgroundCheck and IdvResult records.

---

## Admin Portal Session Handoff (bijouxAdmin)

Copy everything below the line into the admin portal Claude Code session:

---

### ADMIN PORTAL FIX INSTRUCTIONS

Fix 9 bugs from UAT run 2026-06-16. Jira tickets have full context. Do not make changes beyond what's described. Commit each fix individually. Push after each commit.

Some fixes depend on new backend endpoints (BA-282, BA-284, BA-288). Implement the frontend hooks/UI now — they'll work once the backend session deploys the endpoints.

#### BA-278 [SEV-2] — Audit log crashes with TypeError null.slice()
https://polygentic.atlassian.net/browse/BA-278

**File:** `src/app/(dashboard)/audit-log/page.tsx`

Line 44 — add null guard:
```typescript
// Before:
{ key: 'actor', header: 'Actor', render: (row) => row.actor?.email || (row.actorId as string).slice(0, 8) + '...' },
// After:
{ key: 'actor', header: 'Actor', render: (row) => row.actor?.email || (row.actorId ? (row.actorId as string).slice(0, 8) + '...' : '-') },
```

Line 47 — add null guard:
```typescript
// Before:
{ key: 'resourceId', header: 'Resource ID', render: (row) => <span className="font-mono text-xs">{(row.resourceId as string).slice(0, 8)}...</span> },
// After:
{ key: 'resourceId', header: 'Resource ID', render: (row) => <span className="font-mono text-xs">{row.resourceId ? (row.resourceId as string).slice(0, 8) + '...' : '-'}</span> },
```

#### BA-279 [SEV-3] — Children tab shows 'No children registered'
https://polygentic.atlassian.net/browse/BA-279

Root cause is in the backend (API returns `childCount` but no `children` array). The primary fix is backend-side. But add a frontend fallback:

**File:** `src/app/(dashboard)/users/[id]/page.tsx` around line 143

If `profile?.children` is empty/undefined but childCount > 0, show the count:
```typescript
{(profile?.children?.length ?? 0) > 0 ? (
  <DataTable columns={childColumns} data={(profile?.children ?? []) as (Child & Record<string, unknown>)[]} emptyMessage="No children registered." />
) : (
  <p className="text-zinc-500 py-4">
    {(profile as any)?.childCount > 0
      ? `${(profile as any).childCount} child(ren) registered (detail view requires backend update)`
      : 'No children registered.'}
  </p>
)}
```

#### BA-280 [SEV-3] — Incidents caregiver column always shows '-'
https://polygentic.atlassian.net/browse/BA-280

API returns flat `caregiverName` string but frontend checks nested `caregiverProfile` object.

**File:** `src/app/(dashboard)/incidents/page.tsx` line 20

```typescript
// Before:
render: (row) => row.caregiverProfile ? `${row.caregiverProfile.firstName} ${row.caregiverProfile.lastName}` : '-',
// After:
render: (row) => (row as any).caregiverName || (row.caregiverProfile ? `${row.caregiverProfile.firstName} ${row.caregiverProfile.lastName}` : '-'),
```

Also update the `CaregiverIncident` type in `src/types/api.ts` to include `caregiverName?: string`.

#### BA-282 [SEV-2] — Caregiver Reactivate button calls approve endpoint
https://polygentic.atlassian.net/browse/BA-282

Depends on backend BA-282 (new `/trust/caregivers/:id/reactivate` endpoint).

**File:** `src/hooks/use-caregivers.ts` — add hook:
```typescript
export function useReactivateCaregiver(id: string) {
  return useSwrMutation<void>(`/trust/caregivers/${id}/reactivate`, 'put');
}
```

**File:** `src/app/(dashboard)/caregivers/[id]/page.tsx`
- Import `useReactivateCaregiver`
- Add: `const { trigger: reactivate, isMutating: reactivating } = useReactivateCaregiver(id);`
- Add state: `const [reactivateOpen, setReactivateOpen] = useState(false);`
- Add handler:
```typescript
async function handleReactivate() {
  try {
    await reactivate(undefined as never);
    toast({ title: 'Caregiver reactivated' });
    setReactivateOpen(false);
    mutate();
  } catch {
    toast({ title: 'Error', description: 'Failed to reactivate.', variant: 'destructive' });
  }
}
```
- Change the Reactivate button (line ~111) from `setApproveOpen(true)` to `setReactivateOpen(true)`
- Add a separate ConfirmationModal for reactivation wired to `handleReactivate`

#### BA-283 [SEV-2] — Price Override: missing lifecycle guard + field name mismatch
https://polygentic.atlassian.net/browse/BA-283

**File:** `src/app/(dashboard)/bookings/[id]/page.tsx`

Line 115 — add lifecycle guard:
```typescript
{!['completed', 'cancelled'].includes(booking.lifecycle) && (
  <Button variant="outline" onClick={() => setPriceOpen(true)}>
    <DollarSign className="mr-2 h-4 w-4" /> Price Override
  </Button>
)}
```

Line 77 — fix field name to match backend schema (`priceOverrideCents` not `amountCents`):
```typescript
// Before:
await priceOverride({ amountCents, reason: overrideReason });
// After:
await priceOverride({ priceOverrideCents: amountCents, reason: overrideReason });
```

**File:** `src/types/api.ts` line ~565 — update type:
```typescript
export interface PriceOverridePayload {
  priceOverrideCents: number;  // was: amountCents
  reason: string;
}
```

#### BA-284 [SEV-3] — Sessions rating filter display bug
https://polygentic.atlassian.net/browse/BA-284

**File:** `src/app/(dashboard)/sessions/page.tsx` lines 88-95

Fix the SelectValue to render labels instead of raw values:
```typescript
<Select value={filters.hasRating ?? 'all'} onValueChange={(v) => updateFilter('hasRating', v === 'all' ? undefined : v)}>
  <SelectTrigger className="w-32">
    <SelectValue>
      {filters.hasRating === 'true' ? 'Has Rating' : filters.hasRating === 'false' ? 'No Rating' : 'All'}
    </SelectValue>
  </SelectTrigger>
  <SelectContent>
    <SelectItem value="all">All</SelectItem>
    <SelectItem value="true">Has Rating</SelectItem>
    <SelectItem value="false">No Rating</SelectItem>
  </SelectContent>
</Select>
```

Backend also needs the `hasRating` query param support (see backend BA-284).

#### BA-286 [SEV-3] — Caregiver invite fails (Content-Type with empty body)
https://polygentic.atlassian.net/browse/BA-286

**File:** `src/lib/api-client.ts` lines 52-55

Only set Content-Type when there's a body:
```typescript
// Before:
const headers: Record<string, string> = {
  'Content-Type': 'application/json',
  ...(options.headers as Record<string, string>),
};
// After:
const headers: Record<string, string> = {
  ...(options.headers as Record<string, string>),
};
if (options.body) {
  headers['Content-Type'] = 'application/json';
}
```

#### BA-288 [SEV-3] — Missing admin UI for Set BG/IDV Status
https://polygentic.atlassian.net/browse/BA-288

Correction from original ticket: Force Complete and Mark Disputed buttons DO exist in `sessions/[id]/page.tsx` (lines 79-88), gated to `session.status === 'in_progress'`. These are not missing.

**Still needed:** Add BG/IDV status controls on caregiver detail page. Depends on backend BA-288 (new endpoints).

**File:** `src/app/(dashboard)/caregivers/[id]/page.tsx` — in the trust info section, add dropdowns or buttons:
```typescript
// BG Check status override
<Button variant="outline" size="sm" onClick={() => setBgStatusOpen(true)}>
  Set BG Status
</Button>

// IDV status override
<Button variant="outline" size="sm" onClick={() => setIdvStatusOpen(true)}>
  Set IDV Status
</Button>
```

Add corresponding hooks in `src/hooks/use-caregivers.ts`:
```typescript
export function useSetBgStatus(id: string) {
  return useSwrMutation<void, { status: string; reason: string }>(`/trust/caregivers/${id}/bg-status`, 'put');
}
export function useSetIdvStatus(id: string) {
  return useSwrMutation<void, { status: string; reason: string }>(`/trust/caregivers/${id}/idv-status`, 'put');
}
```

#### BA-289 [SEV-3] — Credit balance doesn't auto-refresh after issuance
https://polygentic.atlassian.net/browse/BA-289

**File:** `src/app/(dashboard)/users/[id]/page.tsx`

Lines 48-49 — destructure mutate from credit hooks:
```typescript
const { data: creditBalance, mutate: mutateCreditBalance } = useCreditBalance(id);
const { data: creditHistory, mutate: mutateCreditHistory } = useCreditHistory(id);
```

Line 170 — call all mutates on close:
```typescript
<CreditRefundModal open={creditOpen} onClose={() => { setCreditOpen(false); mutate(); mutateCreditBalance(); mutateCreditHistory(); }} prefillUserId={id} />
```

---

## Testing Repo Handoff (bijoux-testing)

This fix will be done in this session directly.

### BA-274 — Maestro XCTest driver crashes on scroll
https://polygentic.atlassian.net/browse/BA-274

BA-275 and BA-276 are caused by this same issue (cascade failures).

Root cause: The `login-submit-button` accessibility ID IS present in the caregiver app. The actual failure is the Maestro XCTest driver crashing on the second `scroll` command.

**File:** `flows/caregiver/login-valid.yaml`

Replace `scroll` commands with keyboard-dismiss taps:
```yaml
# Before:
- scroll
- tapOn: "Welcome Back"
- tapOn: "Enter your password"
- inputText: ${CG_PASSWORD}
- scroll
- tapOn:
    id: "login-submit-button"

# After:
- tapOn: "Welcome Back"
- tapOn: "Enter your password"
- inputText: ${CG_PASSWORD}
- tapOn: "Welcome Back"
- tapOn:
    id: "login-submit-button"
```

After fixing, re-run to validate BA-275 and BA-276:
```bash
./scripts/cross-app-decline-then-accept.sh
./scripts/cross-app-multi-parent.sh
```

---

## Original Infrastructure Documentation

(Preserved from initial handoff)

### Specs and Plans
- **Testing infra spec:** `docs/superpowers/specs/2026-06-10-bijoux-testing-infrastructure-design.md`
- **Testing infra plan:** `docs/superpowers/plans/2026-06-10-bijoux-testing-infrastructure.md`
- **Real matching E2E spec:** `docs/specs/2026-06-12-real-matching-e2e.md`
- **Admin portal E2E spec:** `docs/superpowers/specs/2026-06-15-admin-portal-e2e-integration-design.md`

### Running Tests
```bash
# Full suite
./scripts/run-full-suite.sh

# Layer 4 only (API tests, no Chrome/sims needed)
./scripts/run-full-suite.sh --layer 4

# Individual L1 scripts
./scripts/cross-app-real-matching-e2e.sh
./scripts/cross-app-decline-then-accept.sh
./scripts/cross-app-cancel-after-match.sh
./scripts/cross-app-multi-parent.sh
```

### Test Accounts
All passwords: `Test1234!`
- Parent: `parent-sarah@test.bijoux.app`
- Parent 2: `parent-james@test.bijoux.app`
- Caregiver: `cg-emma@test.bijoux.app`
- Caregiver 2: `cg-maria@test.bijoux.app`
- Admin: `admin@bijoux.app`

### Global State Reset
```bash
cd /Users/polygentic/Documents/dev/bijoux-backend && npm run db:seed && npx tsx prisma/seed-uat.ts
```
