<!-- BEGIN:nextjs-agent-rules -->

# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` (resolved from this file's directory; in monorepos the `next` package may not be visible from the repo root) before writing any code. Heed deprecation notices.

This block is written and re-added by `next dev` — verify at `node_modules/next/dist/server/lib/generate-agent-files.js`. Removing it from a diff only re-creates the uncommitted change; committing it with your work keeps the tree clean.

<!-- END:nextjs-agent-rules -->

# GymTracker repository guidance

## Source of truth and current phase

This file is the canonical product and autonomous-work guidance for this repository.
Keep it current as the user makes decisions; avoid duplicate product plans or process
documents. Explicit user instructions govern the current task.

The repository contains the solo training product: routines, workout logging,
history, and basic exercise records, plus private Circle membership and its basic
create/read/leave/delete UI. Invites and broader multiplayer features remain deferred.
Update the README with real setup and verification commands as they become available.
Do not invent commands or claim absent tests pass.

## Product direction

GymTracker is a fitness tracker for solo progress and shared progress between gym
buddies. Optimize for fast workout logging and individually owned personal progress.
People can train together in shared sessions without merging their workout data.
Multiplayer should support accountability, encouragement, shared goals, and shared
training history rather than popularity or global competition. Make privacy
intentional. Social features must serve training, not become an infinite social feed.

### Intended v1 scope

- Authentication.
- Routines and exercises.
- Sets, reps, and weight logging.
- Workout history and basic personal record (PR)/progress tracking.
- Gym Circles, circle membership, and invites.
- Shared workout sessions and shared weekly workout goals.
- Relevant member activity and simple reactions/nudges.
- Basic sharing and privacy preferences.

### Explicitly outside v1

- AI coaching.
- Nutrition/calorie tracking.
- Public social feeds, follower systems, and global leaderboards.
- Chat and payments.
- Wearable integrations and native mobile apps.
- Advanced gamification, yearly Wrapped, and rivalry systems.
- Live location.

Do not add these features without an explicit change in scope from the user.

## Architecture and ownership

The intended stack for later implementation is Next.js, TypeScript, PostgreSQL,
and Supabase for database/auth/storage/realtime where useful. Build a responsive
web app/PWA. Keep infrastructure simple; avoid unnecessary microservices. Choose
versions and tooling when implementation begins, without installing them now.

Critical invariant: a shared training session can contain multiple participants,
but each participant's actual workout and set data remains individually owned.

Carry this invariant through schema design, authorization, APIs, UI, and tests:

- Model shared session context and participation separately from personal workout
  records. Each personal workout and its sets must resolve to an individual owner.
- Circle membership, session participation, or organizing a session must not
  implicitly grant the right to edit another participant's workout/set data.
- Sharing grants visibility according to privacy preferences; it does not transfer
  ownership. Enforce access on the server/database, not only through hidden UI.
- Leaving a circle or session must not transfer or erase personal workout history
  as a side effect. Define lifecycle behavior explicitly when implementing it.
- Verify isolation with multiple users: one participant can log their own sets;
  another cannot mutate them; permitted shared views honor privacy preferences.

## Autonomous operation

- Prefer action over routine implementation questions. Inspect current state,
  make reasonable decisions within the task, and work through ordinary problems
  until the requested outcome is verified.
- The repository boundary is the normal area of authority. Create, edit, move,
  remove, and run repo-local files as needed for the authorized goal. Preserve
  unrelated work and do not modify files outside this repository.
- Ask only when a material unresolved choice or missing authority prevents safe
  progress. Explain the concrete blocker and finish independent work first.
- Obtain explicit user approval for irreversible external actions, production
  deployments, destructive cloud/database operations, or changes outside this repo.
  A local implementation goal alone does not authorize those actions.
- Do not expose, overwrite, or commit secrets. Use ignored local environment files
  and placeholder-only examples. Inspect staged content before committing; ignore
  patterns are not a substitute for reviewing what will be recorded.
- Keep changes focused and documentation lightweight. Avoid speculative frameworks,
  extra services, or process documents with no current purpose.

## Git and verification

- Start by checking `git rev-parse --show-toplevel`, `git status --short --branch`,
  and the relevant diff/history. Confirm Git is rooted in this project before
  staging or committing; never accidentally include sibling projects.
- Preserve existing user changes and history. Do not reset, clean, overwrite,
  or discard work merely to get a clean worktree. Do not rewrite published history
  or push without authorization.
- Use Git as the recovery mechanism. Before substantial destructive changes or
  refactoring, create or preserve a recoverable checkpoint where practical. A
  branch at HEAD does not preserve uncommitted work: review and checkpoint safe,
  relevant changes or otherwise retain a recoverable copy before replacing them.
  Never put secrets in a checkpoint or silently sweep unrelated edits into it.
- Stage explicit paths, review `git diff --cached` and `git diff --cached --check`,
  and make focused local commits when safe and useful. If identity or permissions
  prevent a commit, report that limitation and continue other work; do not change
  global Git configuration or invent an identity.
- Verify changes in proportion to their risk using the actual available checks.
  For implementation, exercise affected behavior and use relevant lint, type,
  build, and test checks when present. Ownership/privacy changes need meaningful
  authorization tests. For documentation, inspect full content, links, diff, and
  repository state. The solo milestone includes unit, PostgreSQL, and browser tests.
- Before handing off, compare the result to the full request, inspect the final
  diff/status, and report exactly what changed, checks run, assumptions, and any
  genuine blocker. Distinguish verified behavior from anything still untested.
