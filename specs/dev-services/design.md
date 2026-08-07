# Dev Services — Design

**Status:** Ready
**Last reviewed:** 2026-08-05
**Format-version:** 2
**Execution:** derived — see the status render

Origin-tag legend: `N` — new to this bundle. `C, <namespace> <id>` — carried
from another bundle's decision, foreign namespace qualified.

## Decision log

### D-1: The layer lives in the `services` role, platform-guarded  (N)

**Decision:** The declared dev-services layer is implemented in the repo's
existing `services` role, with an `os_family` guard so it provisions on Linux
hosts and nothing elsewhere. It does not live in the Linux platform
role.

**Alternatives considered:**

- The Linux platform role, alongside the apt package declarations. Rejected
  because: it couples a capability that is deliberately general (REQ-B1.1) to
  a single platform role, so a future non-Linux consumer would need the layer
  moved rather than extended. It also inflates a role whose declarations
  already run to several hundred lines.
- A new role dedicated to dev services. Rejected because: it creates a third
  home for the same concern. The repo already has a role named `services`,
  invoked cross-platform from the top-level playbook, with a `mise` task
  whose description is literally "Install database services" — a new role
  would leave that one holding an unrelated remnant and a now-false
  description.

**Chosen because:** the `services` role is already named for exactly this
concern and already wired cross-platform, so the layer lands where a reader
looks for it. Its current contents are macOS-only in substance despite
running everywhere, which means adding a platform guard is a correction the
role needs regardless of this bundle. The engineering doctrine's first rung —
prefer the existing structure over a parallel one invented beside it —
resolves this without needing the other two rungs.

### D-2: Valkey rather than Redis  (N)

**Decision:** The cache/session server is `valkey-server` from the
distribution archive, not `redis-server`.

**Alternatives considered:**

- `redis-server` from the distribution archive. Rejected because: it sits in
  `universe`, which carries no Canonical security-maintenance commitment, and
  the `esm-apps` tier that would cover universe is unavailable on this host
  (Ubuntu Pro is unattached). The repo's entire apt-first rationale rests on
  the claim that "apt packages are patched by unattended-upgrades"; a
  universe package weakens that claim precisely where it matters, on an
  always-on host. Its one genuine advantage — matching the consuming
  project's CI image exactly — is real but does not outweigh the maintenance
  posture.
- Redis from an upstream vendor apt repository. Rejected because: it adds a
  third-party archive and a second security stream to maintain, for a
  development-only cache.
- Either engine in a container. Rejected because: no container runtime exists
  on this host, and adopting one to run a single service that apt packages
  natively inverts the cost.

**Chosen because:** `valkey-server` is in `main` (section `database`,
Canonical-maintained, carrying an Ubuntu SRU revision), so it sits on the
supported security stream the repo's packaging doctrine depends on, and it is
the distribution's default choice for this role. Its licence is BSD-3-Clause.
The compatibility risk this creates is real but bounded and was researched
rather than assumed: the consuming stack's Redis client documents first-party
Valkey support at the version range already in use. Task 4 verifies that
against a running server rather than trusting the claim.

### D-3: PostgreSQL from the distribution archive, no version pin  (N)

**Decision:** PostgreSQL comes from the distribution archive at whatever
major version it ships, with no third-party repository and no pin to match
any consumer's CI.

**Alternatives considered:**

- Pinning an older major from the PostgreSQL project's own apt repository to
  match the consuming project's CI image. Rejected because: it adds a
  third-party archive and its own security stream, and it solves a
  divergence the consumer can close on its side at no cost to this repo.
- Tracking the consumer's CI version as a declared variable so the divergence
  is at least visible from tracked config. Rejected during elicitation as
  ceremony: the divergence is recorded here in D-3, which is where a reader
  looks for the reasoning.

**Chosen because:** the distribution archive keeps the service on the same
security-maintenance stream as everything else the host installs, which is
the property the repo's packaging doctrine optimises for. A development
database engine running one major ahead of a consumer's CI is a known and
acceptable divergence for local work; the consumer's CI remains the
authority on what its supported version is.

### D-4: Unix socket with peer authentication; `pg_hba.conf` untouched  (N)

**Decision:** Local database access uses the Unix socket with the
distribution's default `peer` authentication. Ansible provisions the server
and a database role matching the invoking account, and does not modify
`pg_hba.conf` at all.

**Alternatives considered:**

- Blanket `trust` for loopback TCP. Rejected because: it removes
  authentication entirely for every local process, including access as the
  superuser role. On a host that runs autonomous agents and is reached over a
  remote shell, the local trust boundary is load-bearing in a way it is not
  on a single-user laptop.
- `trust` scoped to the developer's own role only, leaving the superuser on
  `scram-sha-256`. Rejected because: although the blast radius is materially
  smaller, it still requires the repo to own, template and converge a
  `pg_hba.conf` deviation across PostgreSQL major upgrades — a permanent
  maintenance obligation taken on to avoid a two-line change in a consumer.
- A generated password on the role, supplied to the consumer by environment
  variable. Rejected because: it violates REQ-A1.4 as written, and it
  introduces a secret into a bundle whose posture is that dev services carry
  none — pulling in the secrets-and-configuration decision domain this
  bundle otherwise does not touch.

**Note on the transport.** This decision governs how a consumer
authenticates, not what the server listens on. PostgreSQL keeps the
distribution's default loopback TCP listener; REQ-A1.3 constrains the
*interface* (loopback only), not the transport. A TCP connection from the
box still works — it is simply subject to `scram-sha-256` and so cannot be
made with an empty password, which is exactly the refusal that motivated
this decision.

**Chosen because:** it is the only option requiring no deviation from the
distribution's shipped configuration, so there is nothing to template,
converge, or keep correct — which makes REQ-C easier to satisfy rather than
harder. It is the Debian/Ubuntu idiom, so the engineering doctrine's first
rung resolves it. And peer authentication is real authentication, binding the
database role to a kernel-verified OS identity, where `trust` is the absence
of authentication expressed as a configuration directive. The cost is a
consumer-side edit — connect over the socket rather than TCP — which is
recorded in Out of scope and is the consuming project's to make.

### D-5: A declared service list drives the shared lifecycle only  (N)

**Decision:** Tracked role variables declare each service's package name,
unit name, and expected listen address and port. The shared lifecycle —
install, enable, start, verify reachability — is driven entirely from that
list. Setup beyond the lifecycle stays bespoke per service, but is referenced
from the declaration.

**Alternatives considered:**

- A fully declarative layer where every per-service concern is expressed as
  declaration data. Rejected because: the services differ too much for the
  abstraction to be honest. Cluster initialization, authentication posture,
  and config-file ownership have no shared shape between a relational
  database and a key-value cache, so a schema covering both would be a union
  of unrelated fields pretending to be a pattern.
- Per-service task files with no shared declaration at all. Rejected
  because: it is what REQ-B1.1 exists to prevent — adding a service would
  mean editing control flow rather than adding data.

**Chosen because:** it factors out exactly the part that genuinely
generalises and stops there. The lifecycle is identical for every service;
the setup is not. Referencing the bespoke setup from the declaration keeps
the "what does this service actually need" question answerable from one
place without forcing dissimilar things into one shape.

### D-6: `ansible.builtin` only; no `community.postgresql`  (N)

**Decision:** All provisioning uses `ansible.builtin` modules. The
`community.postgresql` collection is not adopted; the database role is
created idempotently via guarded commands with explicit existence checks.

**Alternatives considered:**

- Adopting `community.postgresql` for its `postgresql_user` /
  `postgresql_db` modules. Rejected because: this repo deliberately runs
  `ansible-core` on Linux, documents that the only collection it uses beyond
  `ansible.builtin` is `community.general`, and ships no `requirements.yml`.
  Adopting a second collection means a bootstrap step on the host, a matching
  install step in CI, and a dependency-management surface the repo has so far
  avoided — for two tasks whose idempotency is a one-line existence query.

**Chosen because:** the dependency-adoption checklist does not favour it. The
gap it closes is small and the standard tooling covers it; the doctrine's
own guidance is to prefer an existing dependency or the standard library when
the gap is small. **Recorded discrepancy, not resolved here:** on the target
host, `ansible` currently resolves to a batteries-included distribution in the
mise-managed Python, carrying `community.postgresql` already, rather than to
the `ansible-core` the repo declares. That drift between declared and actual
tooling is real and belongs to whatever bundle owns the Ansible bootstrap; this
bundle simply does not depend on it either way.

### D-7: The CI job pins the runner image, not `ubuntu-latest`  (N)

**Decision:** The verification job runs on an explicitly pinned Ubuntu runner
image matching the target host's release, not on the `ubuntu-latest` alias.
The target host's release was read from the host at kickoff: Ubuntu 26.04 LTS
(`resolute`), so the pin is the 26.04 runner label.

**Alternatives considered:**

- `ubuntu-latest`. Rejected because: that alias still resolves to the
  previous LTS, which ships different major versions of both services. A
  green result there would demonstrate that the provisioning works against
  packages the target host does not have — the least useful kind of passing
  test, because it looks like coverage.
- A container step pinning the distribution independently of the runner
  image. Rejected because: it adds a layer to reproduce a property the
  pinned runner label already provides.

**Chosen because:** the job's purpose is to exercise the same packages the
host will install. Pinning the image is the cheapest way to make the CI
signal mean what a reader will assume it means. The cost — a pinned label
needs a deliberate bump when the host's release moves — is the intended
behaviour, since that bump is exactly when the provisioning should be
re-verified.

### D-8: Hygiene guard first, with a self-retiring allowlist  (N)

> **Superseded 2026-08-07**, in the half that mandates the rules. REQ-D1.2
> through REQ-D1.5 are retired; see the retirement note in `requirements.md`.
> The body below is left intact as the record of what was chosen and why.
>
> Read the paragraph further down beginning "match an identifier without
> containing a pattern for it": this decision *saw* that it necessarily writes
> the private identifiers into a tracked file in a public repo, weighed it, and
> accepted it on the grounds that they already appear in published git history.
> That is the same trade the retirement declines — not on new information, but
> on a different judgement of an acknowledged cost. Recorded plainly because a
> future reader should see a decision reversed on its merits rather than
> assume the risk was overlooked.
>
> The ordering half of this decision (hygiene guard first, before any other
> commit) is moot rather than wrong: Task 1 did land first, and did ship.

**Decision:** Secret-scanner rules for the private project identifiers land
as this bundle's first task, before any other commit. They are paired with a
path-scoped allowlist covering the identifiers' pre-existing tracked
occurrences, annotated with the successor hygiene bundle as its removal
condition.

**Alternatives considered:**

- No tooling; vocabulary discipline in the bundle only. Rejected because: it
  leaves the rule enforceable only by memory and review, which is the failure
  mode the repo's existing custom scanner rules were added to prevent.
- Rules with no allowlist. Rejected because: the identifiers already appear
  in tracked files, so editing any of them for an unrelated reason would fail
  the hook. That converts a hygiene guard into an obstacle and invites it
  being disabled.
- Scrubbing the existing occurrences first, so no allowlist is needed.
  Rejected for this bundle because: the scrub raises a question this bundle
  has no mandate to answer — the identifiers are already in published git
  history, so a working-tree scrub does not retract them. That belongs to the
  successor hygiene bundle.

**The self-contradiction, and why it is accepted.** A scanner rule cannot
match an identifier without containing a pattern for it, so this decision
necessarily writes the private identifiers into a tracked file in a public
repo — which is what REQ-D1.1 otherwise forbids. Worse, it consolidates what
are currently scattered prose mentions into a clean, labelled, greppable list,
which is easier to harvest than the status quo. This was surfaced by the
drafting self-critique pass rather than discovered later, and resolved
deliberately: REQ-D1.1 carries an explicit, narrow carve-out for the scanner
configuration alone. The reasoning is that the identifiers already appear in
tracked artifacts and in published git history, so the list adds precision
rather than new information, and a guard that cannot name what it guards
against is not a guard. Two alternatives were weighed and rejected: an
untracked machine-local rule file (protects only machines that have it, and
degrades silently on a fresh checkout or in CI), and obfuscating the patterns
so they match without spelling the names (reversible in seconds, and it
trades real maintainability for the appearance of protection). If the
successor hygiene bundle concludes with a history rewrite or with making the
repo private, this carve-out becomes moot and should be removed with the
allowlist.

**Chosen because:** placing the guard first means every subsequent commit in
this bundle is covered by it, rather than audited after the fact — the
guard-infrastructure-first ordering the accumulator recorded as a gap during
the migration bundle. The allowlist is scoped to known paths, so a new file
still fires, and its annotation makes it a visible marker for the successor
bundle rather than a silent permanent exemption.

### D-9: The identifier set lives in an untracked machine-local file  (N)

> **Superseded 2026-08-07.** The requirements this decision serves (REQ-D1.2
> through REQ-D1.5) are retired; see the retirement note in `requirements.md`.
> The decision below is left intact as the record of what was chosen and why,
> because the trade it accepted is exactly what the retirement rejects, and a
> future revival would have to re-make it rather than rediscover it.
>
> The pivot is the sentence below that reads "The generated block is committed,
> so the guard works on a fresh checkout and in CI." That is what makes the
> artifact protecting the private identifiers a public list of patterns for
> them, in a public repo. This design weighed it against a hook reading the
> machine-local file at run time and chose the committed block, because the
> alternative degrades silently where the file is absent. Both horns were real;
> the operator declined the one this decision took. `scripts/gitleaks-identifier-rules.sh`
> and its harness cases stay in the repo, unwired, so a revival is a
> regeneration rather than a rewrite.

**Decision:** The private project identifiers the REQ-D1.2 scanner rules are
built from are supplied by an untracked, machine-local file under
`~/.config/dotfiles/`, mode 0600, following the convention the repo guide
already documents for `slack-users.json` and `op-service-account-token`. A
tracked generator script reads it and writes the rule block into
`.gitleaks.toml`; a source file that is absent, empty, or unparseable is a
visible refusal, not a silently narrower rule set. The brief and the repo
guide record the path; the contents stay off the repo entirely.

**Why a generator rather than hand-authored rules.** The kickoff lens pass
surfaced that Task 1's completion condition presumed a generator nothing
produced. Hand-authoring was weighed and rejected: it leaves no mechanism
keeping the rules and the source file in agreement, so the set drifts silently
as identifiers are added. Having the hook read the machine-local file directly
at run time was also rejected — it removes the need for D-8's carve-out
entirely, which is genuinely attractive, but the guard then does nothing at
all on any machine or CI runner without the file, which is the exact
silent-degradation failure REQ-D1.4 exists to forbid. The generated block is
committed, so the guard works on a fresh checkout and in CI; the source file
is what makes regenerating it reproducible.

**Alternatives considered:**

- Operator-supplied at execution time, with no file at all. Rejected because:
  Task 1 could then never run unattended, and every orchestration pass would
  return it as a blocked head. It also leaves nothing on disk for the next
  run, so the same question is asked forever.
- Deriving the set by grepping this repo's tracked files for the occurrences
  the REQ-D1.3 allowlist has to cover anyway. Rejected because: it is
  circular — finding the occurrences requires already knowing the strings —
  and it silently under-covers any identifier not yet committed, which is
  precisely the case the guard exists for.
- A tracked file in the repo. Rejected because: it is what REQ-D1.1 forbids,
  and the D-8 carve-out is deliberately narrow to the scanner configuration.

**Chosen because:** it is the pattern this repo already runs three times over,
so it lands where a reader looks for it, and the machine-local environment
layer is the repo's documented answer to exactly this shape — per-machine
input that must not enter tracked config. It degrades visibly rather than
silently, which is the property the other machine-local files are chosen for
and the one a hygiene guard cannot do without: a guard that quietly matches
fewer identifiers than intended is worse than one that refuses to run.

## Cross-cutting concerns

**Decision domains touched but deliberately not decided here.** The caching
domain's substantive questions — invalidation, staleness tolerance, key design
and eviction — belong to whichever project consumes the cache. This bundle
provisions an engine and decides nothing about how it is used. Data modeling
is likewise the consumer's. Both are named here so their absence reads as a
boundary rather than an oversight.

**Domains not touched at all:** queues and async work, API surface design,
concurrency, observability, and versioning scheme. No decision in this bundle
reaches any of them.

**Secrets and configuration.** This bundle introduces no secret, credential,
or generated password anywhere — a property of D-4 rather than a coincidence.
It does introduce one new configuration source, the machine-local identifier
file of D-9, which is why this domain is touched rather than untouched. It
does not escalate: the domain's disposition is that plain configuration
proceeds when documented, and the file is documented in D-9, required by
REQ-D1.4, and carries a row in the repo guide's machine-local table as a Task 1
deliverable. Its contents are project identifiers, not credentials; the 0600
mode reflects that they are private, not that they are secret.

**Data storage.** Standing up PostgreSQL touches this domain. Which store, and
on what terms, is decided in D-3. What is *not* decided here is the cluster's
lifecycle across a major-version change: D-3 deliberately declines to pin a
major, so a future host release upgrade will introduce a new cluster rather
than migrate the existing one. The bundle's position that development data is
disposable makes that acceptable, but it is a real event with a real date, so
it is carried as a risk-register row rather than left implicit.

**Altitude.** No altitude trigger fired during drafting: the invocation made
no claim about the deliverable's nature, and no mid-flow signal revealed an
unresolved altitude question. Per the proportionality rule, no altitude
decision is recorded, and this note exists only so a reader knows the gate was
walked rather than skipped.
