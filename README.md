# GymTracker

A mobile-first solo fitness tracker: manage routines, log sets in kilograms,
finish workouts, and inspect private training history and exercise records.
Private Gym Circles, one-time Circle invitations, and shared-session ownership are
supported. Broader multiplayer workflows remain deferred.

Read [AGENTS.md](AGENTS.md) for the canonical product scope, architecture direction,
data-ownership invariant, and autonomous development workflow.

## Requirements

- Node.js 20.9 or newer
- npm
- PostgreSQL command-line tools for the lightweight database test
- Docker-compatible container runtime for the full local Supabase stack (optional)

## Local setup

Install dependencies and start the development server:

```bash
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

The app builds without Supabase credentials. To exercise authentication, copy
`.env.example` to `.env.local` and replace its placeholders. Variables prefixed with
`NEXT_PUBLIC_` are included in browser code and must contain only browser-safe values.
`SUPABASE_SECRET_KEY` is reserved for narrowly scoped server administration and is not
used by normal application requests. Local environment files are ignored by Git.

No external Supabase project is provisioned by this repository.

## Database development

The migrations in `supabase/migrations` create profiles, exercises, routines, private
Gym Circles, members and invitations, shared session context, session participants,
individually owned workouts, workout exercises, and sets. Creating a session
automatically adds its creator as the first participant, so a normal solo workout uses
the same model as a future shared workout.

With Docker running, use the repo-local Supabase CLI:

```bash
npm run db:start
npm run db:reset
npm run db:lint
npm run db:test
npm run db:types
```

`db:types` refreshes the checked-in database type definitions after a schema change.
Without Docker, `npm run db:test:postgres` creates a disposable PostgreSQL cluster in
`/tmp`, applies the migration, exercises the RLS ownership rules, and removes the
cluster afterward. It requires `initdb`, `pg_ctl`, and `psql` on `PATH`.

To use a hosted Supabase project later:

1. Create or choose the project outside this repository.
2. Add its URL and publishable key to `.env.local`; keep its secret key server-only.
3. Set the Auth site URL to `http://localhost:3000` and allow the app's
   `/auth/confirm?next=...` callback URL as a redirect (use the actual origin later).
4. For token-hash email confirmation, set the confirmation template link
   to `{{ .RedirectTo }}&token_hash={{ .TokenHash }}&type=email`, so invitation
   context survives sign-up and confirmation.
5. Link and push migrations with the Supabase CLI only after reviewing the target.

The application never uses a secret/service key for ordinary user operations. Database
RLS policies authorize those requests from the authenticated user's JWT.

## Gym Circle data foundation

An authenticated user can own and belong to multiple private Circles. Creating one
atomically records the authenticated caller as its owner and first member. Members can
read only their Circles and those Circles' membership rows. Membership tables are not
directly writable by authenticated clients: identity-deriving database functions handle
creation, leaving, and owner-only deletion. A non-owner may leave; an owner must delete
the Circle, which cascades only its membership rows. Neither action changes personal
workout history, and Circle membership grants no workout or set access.

The `/app/circles` screens list memberships, create and open Circles, show current
members, and expose owner deletion or non-owner leaving as appropriate. Owners can
create, copy, and revoke one-time invitation links on the Circle detail page. The
`/invite/[token]` route previews a valid Circle invitation, sends unauthenticated
visitors through sign-in, and accepts it before opening the joined Circle. Invitation
delivery, shared Circle workouts, goals, reactions, nudges, and feeds remain out of scope.

Circle owners can create one-time bearer invitations through the server data layer.
The database stores only a SHA-256 digest of each 64-character random credential;
credentials expire after seven days and can be revoked before acceptance. Acceptance
derives the recipient from the authenticated session, atomically adds membership, and
consumes the invite. Invite record IDs and Circle IDs are not join credentials, and
authenticated clients cannot list the invitation table directly. Owner-only listing
returns active invite IDs and expiration times, never credentials or digests. A
bearer-token preview reveals the Circle name only while the invite is active or the
viewer is already a member. The generated link is held in page memory only; after
leaving the page it cannot be recovered, though unused links can still be revoked.
When hosting the app, redact `/invite/*` paths and auth `next` parameters from
infrastructure access logs; those URLs carry the invitation credential.

Circle member identity is limited to the existing profile display name. A restricted
database function returns only user IDs and display names when the authenticated caller
currently belongs to the requested Circle; direct profile reads remain self-only. Users
can set their own Circle display name from `/app/profile`. Email and training data are
never part of the Circle identity response.

## Verification

```bash
npm run lint
npm run typecheck
npm run format:check
npm test
npm run db:test:postgres
npm run build
```

Browser verification uses a disposable PostgreSQL database plus a test-only HTTP
adapter for Supabase Auth/PostgREST. The real application authenticates cookies and
calls the actual SQL functions under `authenticated` RLS; no production auth bypass
or service key is used. This verifies the UI and database together, but does not
replace a final smoke test against real Supabase Auth/PostgREST and email delivery.

```bash
PLAYWRIGHT_BROWSERS_PATH=node_modules/.cache/ms-playwright npx playwright install chromium
PLAYWRIGHT_BROWSERS_PATH=node_modules/.cache/ms-playwright npm run test:browser
```

The browser test builds and runs the production application. It requires PostgreSQL
tools, available ports 3100 and 54329, and no other Next.js process using this checkout.
Test data is temporary and removed on shutdown. Browser traces/screenshots are ignored
under `test-results/`.

## Solo training behavior

- `/app`: start/resume, routines, recent history, and completed workouts this week.
- `/app/routines`: create, edit, reorder, and delete routines.
- `/app/workout`: start a routine or free workout. Repeated starts resume the active workout.
- `/app/workout/[id]`: log/edit/remove sets, add exercises, see previous performance,
  and intentionally finish. Logged sets survive navigation and refresh; unsubmitted
  fields remain in memory only. No offline queue is promised.
- `/app/history` and `/app/progress`: completed training and exercise records.
- `/app/circles`: private Circle creation, membership, leaving, and owner deletion.
- `/app/profile`: account, sign out, and private custom exercises.

The additive `20260912000200_solo_training.sql` migration installs 25 common
exercises, a workout-title snapshot, and transactional `save_routine`,
`start_workout`, and `change_workout` functions. These run as the authenticated
caller under RLS, derive ownership from `auth.uid()`, and lock writes against
completion. Finishing requires at least one saved set and is idempotent. A solo
session ends with its workout; personal completion never ends a multi-participant
session. Completed set data is read-only. Deleting a routine preserves its workout
history and title. Apply both migrations before using the UI.

PR definition: heaviest completed set per exercise; more reps at that weight wins
ties. Zero kilograms represents bodyweight/unloaded movements, where reps break
ties. The first valid performance establishes a record; identical performances do
not earn another record. Records are derived from completed history, never stored
separately. No estimated 1RM formula is used. Weekly counts use Monday–Sunday in
the browser's timezone; dates also display in that timezone.

The server validates 0–1500 kg (up to 3 decimals), 1–1000 integer reps, UUIDs,
names, and routine size. The database independently validates RPC inputs and
ownership. No client-supplied owner ID is accepted by application actions.

Current scaling tradeoff: the data boundary reads the owner's normalized training
rows in explicit pages to avoid silent 1000-row truncation. Views derive progress
in memory. For large histories, replace these with scoped queries/aggregations and
paginated screens while preserving the same PR semantics. Offline synchronization,
reopening finished workouts, account deletion, and multiplayer UX are later work.
