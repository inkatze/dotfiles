# Dev Services — Tasks

**Status:** Ready
**Last reviewed:** 2026-08-05
**Format-version:** 2
**Execution:** derived — see the status render

Task 1 comes first deliberately: it is the hygiene guard, and placing it
ahead of every other commit means the rest of this bundle is written under
its protection rather than audited after the fact (D-8).

## Tasks

### Task 1 — Hygiene guard

- **Deliverables:** custom secret-scanner rules in the repo's `gitleaks`
  configuration matching the private project identifiers; a path-scoped
  allowlist covering their pre-existing tracked occurrences, annotated in the
  file with the successor hygiene bundle as its removal condition; the
  untracked machine-local identifier file the rules are generated from; a
  tracked generator script that reads that file and writes the rule block,
  refusing visibly when the file is absent, empty, or unparseable; new cases
  in the repo's existing custom-rule test harness rather than a parallel one,
  covering both the positive (a new identifier is flagged) and negative (an
  allowlisted path is not) directions; plus a row for the file in the repo
  guide's machine-local table naming its reader and what it holds.
- **Done when:** a staged commit introducing one of the identifiers fails the
  repo's pre-commit hook; a staged edit to an already-tracked file containing
  one passes; the allowlist entry names its removal condition in a comment;
  the identifier file is untracked, mode 0600, and absent from `git
  status`; and the generator refuses visibly, with a non-zero exit, for each
  of an absent, an empty, and an unparseable source file rather than emitting
  a narrower rule set.
- **Dependencies:** none
- **Citations:** D-8, D-9 · REQ-D1.1, REQ-D1.2, REQ-D1.3, REQ-D1.4, REQ-D1.5
- **Estimated effort:** half day

### Task 2 — Declaration and shared lifecycle

- **Deliverables:** a defaults file for the `services` role declaring the
  service list, each entry carrying package name, unit name, and expected
  listen address and port; platform-guarded tasks driving install, enable,
  start and reachability verification from that list; guards on the role's
  pre-existing macOS-only tasks so they no longer run on Linux; and a
  `services` entry in the macOS CI matrix with `strict_idempotency: true`,
  which is what makes REQ-B1.4's guard executable rather than reviewed.
- **Done when:** all four lifecycle steps are driven from the declaration with
  no per-service branching in task control flow; adding an entry to the list
  requires no edit to any task file; a macOS host provisions none of the
  declared services; a Linux host no longer receives the role's macOS-only
  content, and specifically no longer has `~/.my.cnf` created; the new matrix
  entry passes twice with zero changed tasks on the second run; and no
  pre-existing matrix entry or shared step definition is modified.
- **Dependencies:** 1
- **Citations:** D-1, D-5 · REQ-B1.1, REQ-B1.2, REQ-B1.4, REQ-E1.4
- **Estimated effort:** 1 day

### Task 3 — PostgreSQL

- **Deliverables:** the PostgreSQL server declared in the service list; a
  database role matching the invoking OS account with database-creation
  privilege, created idempotently using `ansible.builtin` only.
- **Done when:** connecting over the Unix socket as the invoking user
  succeeds with no password, and can create, migrate and drop a scratch
  database; no task in this repo templates, copies, edits or otherwise
  manages `pg_hba.conf`, so the file remains whatever cluster creation
  produced (the distribution generates it at cluster creation rather than
  shipping it as a package conffile, so "unmanaged by us" is the checkable
  form of D-4's intent, not a diff against a packaged default); the server
  accepts no connection on a non-loopback interface.
- **Dependencies:** 2
- **Citations:** D-3, D-4, D-6 · REQ-A1.1, REQ-A1.3, REQ-A1.4
- **Estimated effort:** 1 day

### Task 4 — Valkey

- **Deliverables:** the Valkey server declared in the service list, with its
  loopback binding asserted by the lifecycle's verification step.
- **Done when:** a local client connects on loopback with no credentials and
  receives a successful ping; the server accepts no connection on a
  non-loopback interface; and the consuming stack's Redis client is exercised
  against the running Valkey server rather than assumed compatible, with the
  result recorded. A failure here reopens D-2 rather than being worked
  around.
- **Dependencies:** 2
- **Citations:** D-2 · REQ-A1.2, REQ-A1.3, REQ-A1.5
- **Estimated effort:** 1 day

### Task 5 — Correct the stale declarations

- **Deliverables:** corrections to the tracked comment in the Linux role's
  defaults asserting database services are out of scope, and to the repo
  guide's description of the `services` role.
- **Done when:** no tracked config comment or documentation file states that
  database services are out of scope; the `services` role's description
  matches what it now does.
- **Dependencies:** 2
- **Citations:** REQ-B1.5
- **Estimated effort:** half day

### Task 6 — CI verification job

- **Deliverables:** a **separate** CI job — not an entry in the existing
  matrix, which sets its runner at job level and is therefore macOS-only —
  on a pinned Ubuntu runner image matching the target host's release,
  running the provisioning by tag, followed by an idempotency re-run. The job
  sets the host alias explicitly rather than letting it fall back: with
  nothing declared, the playbook wrapper resolves to the macOS fallback alias
  and emits a warning, which is harmless because `os_family` is what gates
  provisioning, but is a misleading signal to leave in job output.
  Restructuring the existing matrix to take a per-entry runner is explicitly
  not the approach: it would put REQ-E1.4 at risk to save duplicating a few
  setup steps.
- **Done when:** the job asserts every declared service is running, enabled
  and reachable at its declared address and port; a second run reporting any
  changed task fails the job, verified once by deliberate mutation rather
  than assumed; the job declares no secrets; the existing macOS matrix jobs
  are unmodified and still pass.
- **Dependencies:** 3, 4
- **Citations:** D-7 · REQ-E1.1, REQ-E1.2, REQ-E1.3, REQ-E1.4, REQ-C1.1
- **Estimated effort:** 1 day

### Task 7 — Host convergence

- **Deliverables:** two consecutive playbook runs against the physical Linux
  host, with every first-run failure fixed in the repo and committed.
  *Manual: this is a run-and-observe loop on hardware, producing no repo
  artifact a worker can generate. It is recorded as manual here because the
  orchestration selector has no machine-readable way to tell manual tasks
  from agent-executable ones, and would otherwise return this as a ready head
  no worker can satisfy.*
- **Done when:** the second consecutive run reports zero changed tasks and
  zero failures; both services are running and reachable after a host reboot;
  a run interrupted partway is followed by a run that converges with no
  manual cleanup; and the role's macOS-only content is confirmed absent from
  the host, `~/.my.cnf` specifically, which no macOS runner can demonstrate.
- **Dependencies:** 3, 4, 5
- **Citations:** REQ-B1.4, REQ-C1.1, REQ-C1.2, REQ-C1.3
- **Estimated effort:** 1 day

## Awaiting input

- **Task 1** — The guard's mechanism is built, tested and committed, but the
  rules themselves cannot be generated unattended: they are derived from the
  machine-local identifier file REQ-D1.4 requires, that file does not exist on
  this host, and the identifiers it holds are deliberately absent from every
  artifact a worker can read (REQ-D1.1 keeps them out of the bundle, and D-9
  keeps them out of the repo). Inventing a set would produce exactly the
  silently-narrower rule set REQ-D1.4 forbids, so the generator refuses
  instead, which is the behaviour asserted by the tests. **Operator action,
  once:** create `~/.config/dotfiles/private-identifiers`, mode 0600, one
  identifier per line; run `scripts/gitleaks-identifier-rules.sh --write`;
  commit the generated block in `.gitleaks.toml`. Every later run is a
  re-run rather than a question, which is the property D-9 chose the file
  for. Until then REQ-D1.2 and REQ-D1.3 are unsatisfied and Task 1's first
  two Done-when clauses are unmet on this host, so the bundle's remaining
  tasks do not yet ship under the protection D-8 ordered Task 1 first to
  provide.

- **Task 2** — The unit is implemented, converged and pushed as draft PR #100,
  and every clause of its Done-when is verified locally except one: "the new
  matrix entry passes twice with zero changed tasks on the second run" needs
  CI, and **no workflow run was created for the head commit at all**. Sixteen
  minutes after the PR opened, `actions/runs?head_sha=` and `check-suites`
  both report zero, which is not queue latency — GitHub creates the suite
  within seconds even when the run then queues. Actions is enabled
  (`allowed_actions: all`) and the `test` workflow is `active`, the base is
  `main` so the `pull_request` branch filter matches, and other branches
  produced runs earlier today. The leading hypothesis is exhausted Actions
  minutes: the macOS runners this matrix uses bill at a 10x multiplier, and
  today's runs alone total roughly two hours of them. That is unconfirmed —
  the billing endpoint needs the `user` OAuth scope this host's token lacks,
  and re-authorizing a credential is not something an unattended worker
  should do. **Operator action:** check the Actions usage/spending limit for
  the account; if that is the cause, raising the limit and re-running the
  workflow on PR #100 is the whole fix, since nothing about the diff is
  implicated. Everything else is green locally — `mise run lint`,
  `lefthook run pre-commit`, `shellcheck`, and
  `scripts/services-declaration-test.sh` (all assertions, each
  mutation-tested). REQ-E1.4 in particular is verified without CI: the
  workflow diff is nine added lines and zero removed.

## Deferred

(none yet)

## Out of scope

- **The remote-shell / access layer.** A successor bundle, spun out during
  drafting per the spin-new triggers. It also inherits the live
  socket-activation conflict left unconsumed in the observations
  accumulator.
- **Any identity provider.** Standing one up would require a tenant
  bootstrap and generated credentials, both outside this bundle's
  no-secrets posture.
- **Consuming-project configuration.** Connecting over the Unix socket
  rather than TCP is a consumer-side edit, deliberately not tracked in this
  repo.
- **Remote reachability of either service.** Both bind to loopback;
  exposing them would require per-service authentication.
- **Backup or retention of development data.** Development databases are
  disposable.
- **A container runtime.** No service here needs one.
- **The `linux` role's full CI execution gap.** This bundle's job is scoped
  to the declared dev-services tasks; the broader gap stays open and its
  observation stays live.
- **Scrubbing private identifiers already in tracked artifacts and git
  history.** The guard in Task 1 protects new commits only; the scrub
  belongs to the successor hygiene bundle.
