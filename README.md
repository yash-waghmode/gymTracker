# GymTracker

Technical foundation for a fitness tracker supporting personal training and gym
buddies. The current application is a minimal shell; product features are intentionally
deferred.

Read [AGENTS.md](AGENTS.md) for the canonical product scope, architecture direction,
data-ownership invariant, and autonomous development workflow.

## Requirements

- Node.js 20.9 or newer
- npm

## Local setup

Install dependencies and start the development server:

```bash
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

The shell builds without Supabase credentials. When Supabase-backed work begins, copy
`.env.example` to `.env.local` and replace its placeholders. Variables prefixed with
`NEXT_PUBLIC_` are included in browser code and must contain only browser-safe values.
`SUPABASE_SECRET_KEY` is server-only and must never use that prefix or be imported into
client components. Local environment files are ignored by Git.

No external Supabase project is provisioned by this repository.

## Verification

```bash
npm run lint
npm run typecheck
npm run format:check
npm run build
```
