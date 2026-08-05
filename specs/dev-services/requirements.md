# Dev Services — Requirements

**Status:** Ready
**Last reviewed:** 2026-08-05
**Format-version:** 2
**Execution:** derived — see the status render

## Goal

Give the Linux host a declared dev-services layer, so that a local
development loop running on that machine has the database and cache servers
it needs without any manual provisioning step. The host is the always-on
machine the migration bundle prepared; this bundle is the successor that
`specs/linux-migration` explicitly deferred to when it placed every
long-running service out of its own scope. The layer is driven by a declared
service list rather than a per-project provisioning script, so a second
consumer is a declaration rather than a rewrite. *(Cites: the invocation
(Sources), specs/linux-migration (Sources), drafting-session decision
(2026-08-03).)*

Two things this bundle deliberately is not. It is not an access-path spec:
reaching the host is a separate concern with its own decision space, spun out
per the fold rule and recorded in Out of scope. And it is not a
project-configuration spec: the layer stands services up, and the projects
that consume them configure themselves.

## Scope

### In scope

- A declared dev-services layer in the repo's existing `services` role,
  platform-guarded, driving install, enable, start and reachability
  verification for every declared service.
- A PostgreSQL server and a Valkey server on the Linux host, both bound to
  loopback, both starting at boot, both reachable by a local development
  loop with no credential step.
- Correction of the tracked repo config and documentation that currently
  assert database services are out of scope.
- A public-repo hygiene backstop: secret-scanner rules preventing private
  project identifiers from entering this repo's committed artifacts, with a
  documented, self-retiring allowlist for the identifiers' pre-existing
  occurrences.
- A CI job executing the provisioning on a pinned Linux runner, asserting
  service reachability and idempotency.

### Out of scope

- **The remote-shell / access layer.** Reaching this host — the transport,
  the session-persistence model, and the host's `sshd` posture — is a
  successor bundle. It is a different external interface, independently
  ownable, and forces decisions orthogonal to service provisioning, so the
  spin-new triggers fire rather than the fold recommendation. That bundle
  also inherits the live socket-activation conflict recorded in the
  observations accumulator, which this bundle deliberately leaves
  unconsumed.
- **Any identity provider.** The consuming application's OIDC flow points at
  an instance this bundle does not stand up. Provisioning one would pull in
  a tenant-bootstrap path and generated credentials, both of which sit
  outside this bundle's no-secrets posture.
- **Consuming-project configuration.** A consumer connecting over TCP with
  no password will be refused by the authentication posture recorded in
  D-4, and must connect over the Unix socket instead. That edit belongs to
  the consuming project and is deliberately not tracked here.
- **Remote reachability of the services.** Both bind to loopback. Exposing
  either over the LAN or the tailnet would require per-service
  authentication and is a separate decision.
- **Backup, snapshot, or retention of development data.** Development
  databases are disposable; recreation is the recovery path.
- **A container runtime.** No service in this bundle needs one, and adopting
  one is a decision with its own weight.
- **Closing the `linux` role's full CI execution gap.** The job this bundle
  adds is scoped to the declared dev-services tasks. The broader gap — that
  role's total absence of execution coverage — stays open, and the
  observation recording it stays live rather than being consumed here.
- **Scrubbing the private identifiers already present in this repo's
  tracked artifacts and git history.** The backstop added here guards new
  commits only. The scrub, and the harder question of what to do about
  content already published, belong to the successor hygiene bundle.

## REQ-A — Service availability

- **REQ-A1.1** A PostgreSQL server SHALL be installed on the Linux dev host
  from the distribution's apt archive, and SHALL be running and enabled to
  start at boot.
  *(Cites: the invocation (Sources), D-3, drafting-session decision
  (2026-08-03).)*
- **REQ-A1.2** A Valkey server SHALL be installed on the Linux dev host from
  the distribution's apt archive, and SHALL be running and enabled to start
  at boot.
  *(Cites: the invocation (Sources), D-2, drafting-session decision
  (2026-08-03).)*
- **REQ-A1.3** Both services SHALL listen on the loopback interface only,
  and SHALL NOT accept connections on any non-loopback interface.
  *(Cites: drafting-session decision (2026-08-03).)*
- **REQ-A1.4** A local unprivileged account SHALL be able to connect to
  PostgreSQL and create, migrate and drop databases without supplying a
  password and without an out-of-band credential step.
  *(Cites: D-4, drafting-session decision (2026-08-03).)*
- **REQ-A1.5** A local unprivileged account SHALL be able to connect to the
  Valkey server on loopback without supplying credentials.
  *(Cites: drafting-session decision (2026-08-03).)*

## REQ-B — Declaration model

- **REQ-B1.1** The shared service lifecycle — install, enable, start, and
  reachability verification — SHALL be driven by a declared service list in
  tracked role variables. Adding or removing a service SHALL NOT require
  editing task control flow. Reachability verification SHALL assert that the
  service is listening at its declared address and port; protocol-level
  connection proof is per-service setup under REQ-B1.3, not part of the
  shared lifecycle.
  *(Cites: D-5, drafting-session decision (2026-08-03), kickoff §2 (2026-08-04).)*
- **REQ-B1.2** Each declared service SHALL carry, in its declaration, at
  minimum: its package name, its service unit name, and the address and port
  it is expected to listen on.
  *(Cites: REQ-B1.1, D-5.)*
- **REQ-B1.3** Per-service setup beyond the shared lifecycle (cluster
  initialization, authentication configuration, config-file management) MAY
  be bespoke rather than declaration-driven, but SHALL be referenced from the
  declaration so the full setup for a service is discoverable from one place.
  *(Cites: D-5, drafting-session decision (2026-08-03).)*
- **REQ-B1.4** The layer SHALL provision only on Linux hosts, and SHALL leave
  existing macOS host behaviour unchanged. The `services` role's pre-existing
  macOS-only tasks SHALL additionally be guarded to macOS, so that no host
  provisions content intended for the other platform.
  *(Cites: D-1, drafting-session decision (2026-08-03), kickoff §2
  (2026-08-04), kickoff §5 (2026-08-05).)*
- **REQ-B1.5** Tracked repo config and documentation that currently assert
  database services are out of scope SHALL be corrected to describe the
  declared layer.
  *(Cites: drafting-session decision (2026-08-03).)*

## REQ-C — Convergence

- **REQ-C1.1** A second consecutive run of the provisioning SHALL report
  zero changed tasks.
  *(Cites: specs/linux-migration (Sources), drafting-session decision
  (2026-08-03).)*
- **REQ-C1.2** Provisioning SHALL be safe against a host where the services
  are already installed and running: it SHALL NOT destroy existing data
  directories and SHALL NOT restart a healthy service in the absence of a
  config change.
  *(Cites: drafting-session decision (2026-08-03).)*
- **REQ-C1.3** A run that fails partway SHALL leave the host in a state a
  subsequent run converges from, with no manual cleanup step.
  *(Cites: drafting-session decision (2026-08-03).)*

## REQ-D — Public-repo hygiene

- **REQ-D1.1** No artifact this bundle commits to this repo SHALL name the
  consuming project, its repository, its features, or its file paths. The
  secret-scanner configuration is the sole exception: a rule cannot match an
  identifier without containing a pattern for it, so REQ-D1.2's rules and
  REQ-D1.3's allowlist MAY name them. That exception SHALL NOT extend to any
  other artifact.
  *(Cites: D-8, drafting-session decision (2026-08-03), drafting-session
  decision (2026-08-04).)*
- **REQ-D1.2** The repo's pre-commit secret scanner SHALL carry rules
  matching the private project identifiers, so a commit reintroducing one
  fails the hook rather than depending on review to catch it.
  *(Cites: D-8, drafting-session decision (2026-08-03).)*
- **REQ-D1.3** The rules added under REQ-D1.2 SHALL carry a documented,
  path-scoped allowlist covering the identifiers' pre-existing tracked
  occurrences, so editing those files for unrelated reasons does not fail
  the hook. The allowlist SHALL name the successor hygiene bundle as the
  condition for its removal.
  *(Cites: REQ-D1.2, D-8, drafting-session decision (2026-08-03).)*
- **REQ-D1.4** The identifier set the REQ-D1.2 rules are built from SHALL be
  supplied by an untracked, machine-local file, and SHALL NOT be stored in
  this repo outside the scanner configuration REQ-D1.1 carves out. A source
  file that is absent, empty, or unparseable SHALL surface as a visible
  refusal to proceed, never as a silently narrower rule set.
  *(Cites: REQ-D1.1, REQ-D1.2, D-9, kickoff §2 (2026-08-04).)*
- **REQ-D1.5** The REQ-D1.2 rules SHALL be generated from the REQ-D1.4 source
  file by a tracked, re-runnable generator, so that regenerating after the
  identifier set changes is a command rather than a hand edit. The generator's
  output SHALL be deterministic for a given set, independent of the order the
  source file lists it in, so that regeneration on any machine reproduces the
  committed block exactly.
  *(Cites: REQ-D1.2, REQ-D1.4, D-9, kickoff §2 lens F1 (2026-08-04), kickoff
  sign-off lens L1 (2026-08-05).)*

## REQ-E — Verification

- **REQ-E1.1** A CI job SHALL execute the dev-services provisioning on a
  Linux runner pinned to the same distribution release as the target host,
  and SHALL assert each declared service is running and reachable at its
  declared address and port.
  *(Cites: D-7, obs:93650670, drafting-session decision (2026-08-03).)*
- **REQ-E1.2** That job SHALL re-run the provisioning and SHALL fail if the
  second run reports any changed task.
  *(Cites: REQ-C1.1, D-7, obs:93650670.)*
- **REQ-E1.3** That job SHALL require no secrets, and SHALL fetch nothing
  from an authenticated or private source. Its unauthenticated toolchain
  bootstrap (the automation runner and version manager the existing matrix
  jobs already install) and the distribution package archive are the only
  network access permitted.
  *(Cites: drafting-session decision (2026-08-03).)*
- **REQ-E1.4** No existing entry in the macOS CI matrix, and no step
  definition shared across that matrix, SHALL be modified by this bundle. A
  new matrix entry covering the `services` role is permitted and is required
  by REQ-B1.4's verification; every pre-existing entry SHALL continue to pass
  unchanged.
  *(Cites: REQ-B1.4, drafting-session decision (2026-08-03), kickoff §5
  (2026-08-05).)*

## Changelog

- **2026-08-03** — Bundle drafted via `/spec-draft`. Elicited from the
  invocation plus the observations accumulator; fold-detection run against
  all five existing bundles with no fold, and the access-layer half of the
  invocation spun out as a successor bundle per the spin-new triggers.
- **2026-08-04** — Drafting self-critique pass. Four findings, all
  dispositioned: REQ-E1.3 reworded (it forbade network access its own task
  required); Task 6 clarified to a separate CI job (the existing matrix sets
  its runner at job level and cannot host it); D-4 gained a transport note
  (REQ-A1.3 constrains the interface, not the transport); and REQ-D1.1
  gained a narrow carve-out for the scanner configuration, which cannot match
  an identifier without containing a pattern for it. The carve-out's
  reasoning and its rejected alternatives are recorded in D-8.
- **2026-08-04** — `/spec-kickoff` first activation, section 2. Three implicit
  terms resolved into decisions: REQ-B1.1 gained the meaning of "reachability
  verification" (a bind assertion; protocol proof is per-service under
  REQ-B1.3); REQ-B1.4 was reworded from "nothing on hosts other than the Linux
  dev host" to "only on Linux hosts", so the requirement describes the
  `os_family` mechanism D-1 chose rather than a narrower one; and REQ-D1.4 was
  minted, with D-9, to pin the identifier set to an untracked machine-local
  file. The target host's release was resolved from the host itself
  (Ubuntu 26.04 LTS, `resolute`) and recorded in D-7 and the Sources.
  The mid-walk lens pass over that delta returned three findings, all
  applied: Task 1's completion condition presumed a rule generator no
  deliverable produced, so REQ-D1.5 was minted and D-9 records why a
  generator beat hand-authoring and beat having the hook read the source file
  directly; REQ-D1.4 was widened from an absent source file to an absent,
  empty, or unparseable one, since an absence check alone passes the other
  two; and D-1's prose was widened to match the reworded REQ-B1.4.
- **2026-08-05** — `/spec-kickoff` sections 3–5. Two grounded findings, both
  applied. REQ-B1.4's verification was a dead path: its test-spec entry
  claimed the existing macOS CI matrix executed the `services` role, and that
  matrix has no `services` entry at all, so the stated check could not run.
  Task 2 now adds one at `strict_idempotency: true`, giving the role its first
  CI coverage on either platform, and REQ-E1.4 was restated as a decided rule
  (no pre-existing entry or shared step is modified) rather than a claim that
  the matrix is untouched. Separately, the role's `my.cnf` symlink task
  carries no platform guard and so runs on the Linux host today; REQ-B1.4 was
  extended to require the pre-existing macOS-only tasks be guarded to macOS,
  with Task 2 owning the fix and Task 7 asserting it on the host.
- **2026-08-05** — `/spec-kickoff` sign-off lens pass (full bundle, first
  activation). Three findings, all applied. REQ-D1.5 gained a determinism
  clause, because a byte-for-byte comparison against a committed block is
  meaningless if the generator's output depends on the order the source file
  happens to list identifiers in. Task 3's completion condition was restated:
  it required `pg_hba.conf` to be byte-identical to "the package default",
  and no such referent exists, since the distribution generates that file at
  cluster creation rather than shipping it as a package conffile — the
  checkable form of D-4's intent is that no task in this repo manages the
  file at all. Task 6 now sets the host alias explicitly rather than
  inheriting the wrapper's macOS fallback, which is harmless but misleading
  in job output. Altitude check recorded as not applicable: the bundle fired
  no altitude trigger at drafting and carries no altitude decision.

## Sources

- **The invocation (2026-08-03).** A request for the servers a local
  development loop needs on the Linux host, together with a modern
  remote-shell client/server for reaching it. The shell half was spun out as
  a successor bundle during Goal & scope; this bundle carries the services
  half only. The invocation also established that the development loop runs
  on the Linux host rather than on a laptop against remote services.
- **`specs/linux-migration` (Status Done).** The bundle that prepared this
  host. Its Out-of-scope section defers every long-running service to a
  successor: *"Deploying any long-running service (media stack rebuild,
  containers, schedulers). Future specs own those; this spec only makes the
  machine ready for them."* This is that successor. Its convergence
  discipline (two consecutive runs, second reporting no changes) is carried
  into REQ-C.
- **`obs:93650670`** — the observation recording that the `linux` role has
  lint and syntax coverage but no execution or idempotency leg, because the
  CI matrix runs entirely on macOS. It framed REQ-E. **Deliberately left
  unconsumed** in `entries/`: the job added here is scoped to the declared
  dev-services tasks, so the gap the observation names stays partly open and
  the fragment remains a live candidate for the bundle that closes it.
- **Research: target-host package metadata (consulted 2026-08-03).**
  `apt-cache show` on the target host: `valkey-server` 9.0.4-0ubuntu0.1,
  section `database` (main), Canonical-maintained; `redis-server`
  5:8.0.5-1, section `universe/misc`, Debian-maintained. `pro status`
  reports Ubuntu Pro unattached, so the `esm-apps` tier carrying universe
  security maintenance is unavailable. Framed D-2.
- **Research: PostgreSQL packaging defaults on Debian/Ubuntu (consulted
  2026-08-03).** The distribution package ships `listen_addresses` at
  localhost, `peer` authentication for Unix-socket connections, and
  `scram-sha-256` for TCP. Framed D-4, and is the reason that decision
  requires no `pg_hba.conf` modification at all.
- **Research: client-library Valkey support (consulted 2026-08-03).** The
  Elixir Redis client `redix`, at v1.6.0, documents itself as interfacing
  with "Redis and Valkey", and has supported the `valkey://` URI schema
  since v1.5.0. Named here because it is a public open-source library rather
  than a private-project identifier, and because D-2 is not independently
  checkable without it; the repo already declares its Erlang and Elixir
  runtimes in `roles/environments/files/mise.toml`, so no new inference
  about any private project is created. Framed D-2's risk assessment.
- **Research: GitHub-hosted runner images (consulted 2026-08-03).** The
  `ubuntu-latest` label still resolves to Ubuntu 24.04; the 26.04 image is
  generally available under its own explicit label. Framed D-7.
- **Target-host inspection (kickoff, 2026-08-04).** Read from the host during
  the section 2 walkthrough: `/etc/os-release` reports Ubuntu 26.04 LTS,
  codename `resolute`; the inventory alias in `~/.config/dotfiles/host` is
  `server`; `apt-cache policy` shows `valkey-server` 9.0.4-0ubuntu0.1 from
  `resolute-updates/main` and `postgresql` 18+290ubuntu1 from `resolute/main`,
  with neither installed. Confirms the 2026-08-03 package-metadata research
  against the live archive, pins D-7's runner label to the 26.04 image, and
  establishes that this bundle provisions onto a host with no prior state for
  either service.
