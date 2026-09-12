# GymTracker

Technical foundation for a fitness tracker supporting personal training and gym
buddies. The current application is a minimal shell; product features are intentionally
deferred.

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

The migration in `supabase/migrations` creates profiles, exercises, routines, shared
session context, session participants, individually owned workouts, workout exercises,
and sets. Creating a session automatically adds its creator as the first participant,
so a normal solo workout uses the same model as a future shared workout.

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
3. Set the Auth site URL and allowed redirect URL to the deployed equivalent of
   `http://localhost:3000/auth/confirm`.
4. For token-hash email confirmation, set the confirmation template link to
   `{{ .SiteURL }}/auth/confirm?token_hash={{ .TokenHash }}&type=email`.
5. Link and push migrations with the Supabase CLI only after reviewing the target.

The application never uses a secret/service key for ordinary user operations. Database
RLS policies authorize those requests from the authenticated user's JWT.

## Verification

```bash
npm run lint
npm run typecheck
npm run format:check
npm run db:test:postgres
npm run build
```
