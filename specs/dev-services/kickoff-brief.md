# Dev Services — Kickoff Brief

**Spec path:** `specs/dev-services/`
**Spec commit at walkthrough start:** `af998a12e5c0e8d8fe4a0e2be9e7a5c91c3e6c55`
**Walkthrough date:** 2026-08-04
**Mode:** First activation (Status Draft, no prior brief)
**Validator outcome (pre-flight):** `spec-validate.sh specs/dev-services` — 0 errors, 0 warnings
**Format-version:** 2 (execution status derived, not stored)
**Config:** `commit_on_kickoff: true`, `mark_spec_pr_ready_on_kickoff: true`, `kickoff_ready_ci_wait: 10m` — all core defaults; no repo-local planwright override file is present

---

## 2. Goal & glossary

### Restatement

This bundle makes the always-on Linux host able to run a development loop
locally, by standing up PostgreSQL and Valkey as declared, boot-persistent,
loopback-only services reachable with no credential step. It does that through
a service list in tracked role variables rather than a provisioning script, so
a second service is a declaration rather than a rewrite. It is the successor
`specs/linux-migration` named when it pushed every long-running service out of
its own scope.

Three things ride along because the central change would otherwise be unsafe
or unverifiable: correcting the tracked config and documentation that still
assert database services are out of scope, a secret-scanner backstop against
private project identifiers entering a public repo, and a Linux CI job (the
repo today has no execution coverage for Linux at all).

### What it rules out

The access/remote-shell layer (spun out as a successor bundle), any identity
provider, consuming-project configuration, remote reachability of either
service, backup and retention of development data, a container runtime, the
`linux` role's *full* CI execution gap, and scrubbing identifiers already
present in tracked artifacts and git history. The authoritative list is
`requirements.md` `### Out of scope`, mirrored in `tasks.md` `## Out of scope`.

### What it assumes

- `unattended-upgrades` is live on the host, which is what gives D-2's
  `main`-versus-`universe` argument its force.
- The host is Ubuntu specifically, not Debian generally. Confirmed at
  walkthrough (see the resolved terms below).
- The consuming development loop is Elixir/Ecto-shaped. Inferred from
  REQ-A1.4's "create, migrate and drop" and the `redix` research entry; the
  consuming project itself is deliberately unnamed per REQ-D1.1.

### Implicit terms surfaced, and their resolutions

Five terms the bundle used but never bound. Three were forks put to the human;
two were resolved from evidence and reported rather than asked.

| Term | Resolution | How |
|---|---|---|
| "private project identifiers" | Supplied by an untracked machine-local file under `~/.config/dotfiles/`, generated into the rule block by a tracked script. Minted REQ-D1.4, REQ-D1.5, D-9 | Human decision, selector |
| "reachability verification" | A bind assertion that the declared address and port are listening. Protocol-level proof stays per-service under REQ-B1.3. Clarified in REQ-B1.1 | Human decision, selector |
| "the Linux dev host" (vs the `os_family` guard) | The wording moved, not the mechanism: REQ-B1.4 now reads "only on Linux hosts", matching what D-1 chose and argued for | Human decision, selector |
| target distribution release | Ubuntu 26.04 LTS, codename `resolute`; inventory alias `server`. Pins D-7's runner label to the 26.04 image | Resolved from the host; recorded in D-7 and Sources |
| "local development loop" | Left unbound deliberately. It scopes no deliverable: REQ-A1.4's Done-when is proved by the scratch create/migrate/drop cycle regardless of which client drives it | Resolved from the bundle |

### Spec edits applied in this section

Consolidated list (all applied on `planwright/dev-services/spec`):

1. `requirements.md` — REQ-B1.1 gained the meaning of reachability
   verification; REQ-B1.4 reworded; REQ-D1.4 and REQ-D1.5 minted; Sources
   gained the target-host inspection entry; Changelog entry added.
2. `design.md` — D-9 minted; D-7 gained the resolved release pin; D-1 prose
   widened to match REQ-B1.4.
3. `tasks.md` — Task 1 deliverables, Done-when, and citations extended for the
   machine-local source file, the generator, and the repo-guide table row.
4. `test-spec.md` — REQ-D1.4 and REQ-D1.5 entries added; REQ-B1.4 entry
   retitled; coverage-mix figures re-derived (the figures themselves live in
   `test-spec.md`'s intro, cited rather than copied here).

### Mid-walk lens pass (delta-scoped)

Run at the point of application per `kickoff-verification`, because the delta
minted a REQ and a D-ID. **Path: walked inline, not fanned out** — the doctrine
prefers one sub-agent per lens for a non-trivial delta, and this session
prohibits spawning agents absent an explicit request. Declared rather than
silently substituted.

| Lens | Findings | Notes |
|---|---|---|
| Correctness, logic, edge cases | 1 | F1 — Task 1's Done-when presumed a rule generator no deliverable produced |
| Security | none | D-9 keeps identifiers off the repo, mode 0600, degrades visibly; consistent with the artifact-hygiene rule |
| Error handling and failure modes | 1 | F2 — REQ-D1.4 guarded an absent source file, not an empty or unparseable one |
| Performance | n/a | Spec-text delta; no runtime surface |
| Concurrency / state | n/a | No shared state introduced |
| Naming, readability, structure | none | REQ-D1.4/D1.5 sit in the hygiene group; D-9 numbering sequential |
| Documentation | none | Task 1 carries the repo-guide table row; D-9 points at the existing machine-local convention |
| Tests / verification | none | Both minted REQs pinned; coverage mix re-derived and matching |
| Cross-file consistency | 1 (minor) | F3 — D-1 prose read narrower than the reworded REQ-B1.4 |

**Dispositions — all three applied, none deferred, none declined.**

- **F1 (applied).** REQ-D1.5 minted requiring a tracked, re-runnable
  generator; Task 1 gained it as a deliverable. D-9 records why: hand-authoring
  leaves nothing keeping rules and source in agreement, and having the hook
  read the source file directly — attractive because it would retire D-8's
  carve-out entirely — makes the guard a no-op on any machine or CI runner
  without the file, which is the silent degradation REQ-D1.4 forbids.
- **F2 (applied).** REQ-D1.4 widened to absent, empty, or unparseable; the
  test-spec entry enumerates all three, because an absence check alone passes
  the other two.
- **F3 (applied).** D-1 prose widened to "on Linux hosts".

### Post-lens stale-reference sweep

Run once, after the lens minted REQ-D1.4/REQ-D1.5 and re-scoped REQ-B1.4, and
before any anchor computation. Swept for references to the minted and
re-scoped IDs and for the figures they move: all REQ-B1.4 references reconciled
(the only surviving "hosts other than" is the Changelog quoting the prior
wording, which is intended), both minted IDs cited and pinned, and the
coverage-mix figures re-derived mechanically against `test-spec.md`'s headings
rather than its prose — the first derivation was wrong because entry bodies
also contain bracketed tag tokens, and it was corrected before being recorded.

Validator after all edits: `spec-validate.sh specs/dev-services` — 0 errors,
0 warnings. Every REQ carries at least one test-spec pin.

Signed off: 2026-08-05

---

## 3. Requirements walkthrough

Per-group outcomes. Group intents restated, edge cases probed, decisions
recorded. The consolidated spec-edit list for the whole walkthrough sits at the
end of this section.

### REQ-A — Service availability

**Intent:** two named services exist on the host, survive reboot, listen only
on loopback, and are usable by a local account with no credential step.

Probed and resolved: REQ-A1.4's passwordless access is bound to the OS account
name through D-4's peer authentication, so the database role must match the
invoking account exactly. In CI that account is the runner's; on the host it is
the operator's. The requirement is about the mechanism, not a specific name, and
both satisfy it. Carried as risk 6: a dev loop or agent running under a
*different* account is refused, and nothing in the bundle would surface that
before it happens.

Probed and left as-is: REQ-A1.3's loopback constraint covers the interface and
not the transport, which D-4's transport note already states explicitly. No
edit needed — this was resolved during drafting's own self-critique.

### REQ-B — Declaration model

**Intent:** the lifecycle generalises across services; the per-service setup
does not, and is not forced to.

Two edits, both from section 2: REQ-B1.1 now says what "reachability
verification" asserts (a bind assertion), and REQ-B1.4 now describes the
`os_family` mechanism D-1 chose rather than a narrower one.

One edit from section 5's dead-path check: REQ-B1.4 gained a second sentence
requiring the role's *pre-existing* macOS-only tasks be guarded to macOS. The
role's `my.cnf` symlink task carries no `when:` at all and therefore runs on
the Linux host today, creating a `~/.my.cnf` for a MySQL that is not installed.
D-1 already argued the platform guard is a correction the role needs
regardless; no task owned it until now. Task 2 owns the fix, Task 7 asserts it
on the host.

REQ-B1.5's targets were confirmed to exist rather than assumed: the
out-of-scope assertion lives in the Linux role's defaults, and `mise.toml`
describes the `services` task in terms that become true rather than remain
stale once this bundle lands.

### REQ-C — Convergence

**Intent:** the provisioning is re-runnable, non-destructive, and recoverable.

Probed, no edit: REQ-C1.2's "SHALL NOT restart a healthy service" is satisfiable
because D-4 and D-3 between them leave no config file under this repo's
management for PostgreSQL, so there is no config-change path to trigger a
restart. That is a consequence of D-4 worth naming, since it is what makes REQ-C
cheap rather than hard.

REQ-C1.3 is acknowledged in `test-spec.md` as the weaker of two deliberately
weak pins. Confirmed as accepted rather than reopened.

### REQ-D — Public-repo hygiene

**Intent:** private project identifiers cannot enter this public repo by
accident, and the guard does not become an obstacle that invites disabling.

Two REQs minted here in section 2 (REQ-D1.4, REQ-D1.5) after the mid-walk lens
found Task 1's completion condition presuming a generator nothing produced. The
group now covers the whole chain: what may name the identifiers (D1.1), the
rules (D1.2), the allowlist (D1.3), where the set comes from (D1.4), and how
rules are derived from it (D1.5).

### REQ-E — Verification

**Intent:** the provisioning is exercised somewhere other than the one host it
targets.

One edit: REQ-E1.4 was restated as a decided rule rather than a claim about the
matrix being untouched, because REQ-B1.4's verification now requires adding a
matrix entry. The rule is that no pre-existing entry and no shared step
definition is modified, which is what the requirement was actually protecting.

REQ-E1.3 is the second acknowledged weak pin. Confirmed as accepted.

Signed off: 2026-08-05

---

## 4. Design walkthrough

Every D-ID accounted for. Reconciled ledger:

| D-ID | Disposition | Note |
|---|---|---|
| D-1 | **Amended** | Prose widened from "the Linux host" to "Linux hosts", matching the reworded REQ-B1.4. Decision itself unchanged; the `services` role is still the home |
| D-2 | Confirmed | Valkey over Redis. Rationale intact and independently checkable: the archive read at kickoff confirms `main`, section `database`, Canonical-maintained |
| D-3 | Confirmed | PostgreSQL unpinned from the distribution archive. The unpinned major is what produces risk 3 |
| D-4 | Confirmed | Peer auth over the Unix socket, `pg_hba.conf` untouched. Its transport note already resolves the REQ-A1.3 ambiguity |
| D-5 | Confirmed | Declaration drives the lifecycle only. Section 2's reachability resolution is an application of this decision, not a change to it |
| D-6 | Confirmed | `ansible.builtin` only. Its recorded discrepancy about the host's actual `ansible` is carried as risk 5 |
| D-7 | **Amended** | Gained the resolved release: Ubuntu 26.04 `resolute`, so the pin is the 26.04 runner label rather than an unresolved reference to "the target host's release" |
| D-8 | Confirmed | Hygiene guard first with a self-retiring allowlist. Its self-contradiction section already records the carve-out reasoning and rejected alternatives |
| D-9 | **New** | The identifier set lives in an untracked machine-local file, generated into the rule block by a tracked script. Minted in section 2; gained the generator rationale from the mid-walk lens |

No decision was superseded. No design decision was found to contradict a walked
requirement, so no inconsistency halt fired.

Signed off: 2026-08-05

---

## 5. Verification approach

### Coverage mix

Reviewed against `test-spec.md`'s intro, which is where the figures live and is
cited rather than copied here. The shape: the large majority of requirements
verify as `[test]`, a small group as `[design-level]` where the artifact's
existence and completeness *is* the verification, one as `[manual]`, and three
carry mixed tags. Every requirement carries at least one pin; verified
mechanically rather than by reading.

### Verification ownership

- **`[test]` entries** are owned by CI. Two jobs now: the Linux dev-services job
  Task 6 adds, and the `services` matrix entry Task 2 adds on macOS.
- **`[design-level]` entries** are owned by the reviewer of the PR carrying the
  artifact.
- **`[manual]` entries** are owned by the operator on the physical host, and are
  concentrated in Task 7, which the task itself flags as manual so the
  orchestration selector does not hand it to a worker that cannot satisfy it.

### Dead-path check

This is where the walkthrough's most significant finding surfaced. REQ-B1.4's
pin claimed the existing macOS matrix jobs execute the `services` role and would
therefore catch a missing platform guard. **They do not** — the matrix's entries
cover other roles and `services` is not among them, so the role had no CI
coverage on either platform and the stated verification could not run at all.

Resolved by making the claim true rather than by weakening it: Task 2 adds a
`services` matrix entry at `strict_idempotency: true`. The consequence is
accepted deliberately — the role has never been measured for idempotency, so the
gate may go red on a pre-existing defect, on this bundle's critical path. That
is carried as risk 2. The alternative of re-pinning REQ-B1.4 as design-level was
weighed and declined: a guard that is present but wrong reads identical to one
that is right.

The reverse direction of REQ-B1.4 — that macOS-only content no longer reaches
Linux — cannot be shown by any macOS runner, so it is asserted on the host in
Task 7 instead.

No other pin was found to be dead. The remaining entries' verification paths
were each traced to a job, a reviewer, or the host.

Signed off: 2026-08-05

---

## 6. Task graph

Reconstructed from the `Dependencies:` fields, which are the sole source of
truth; the rendered view is `spec-graph.sh specs/dev-services` and is not copied
here.

```
1 ── 2 ─┬─ 3 ─┬─ 6
        │     │
        ├─ 4 ─┘
        │     │
        └─ 5 ──┴─ 7   (7 depends on 3, 4, 5; 6 depends on 3, 4)
```

**Critical path:** 1 → 2 → 3 → 6, tied in length by 1 → 2 → 3 → 7. Task 3 is on
every longest path, which makes PostgreSQL the schedule-determining work rather
than the CI job. Effort figures are per task in `tasks.md` and cited rather than
restated.

**Parallelism:** Tasks 3, 4 and 5 are mutually independent once Task 2 lands —
the widest point in the graph. Tasks 6 and 7 are also independent of each other.

**Deliberate non-edges**, recorded so nobody "fixes" them later:

1. **5 ↛ 6.** The documentation corrections do not gate the CI job. They are
   independent deliverables and coupling them would serialise the graph for no
   verification benefit.
2. **6 ↮ 7.** The CI job and host convergence neither gate nor duplicate each
   other. CI proves the provisioning against a clean runner with no prior state;
   the host proves it against real hardware that has state and reboots. Making
   either depend on the other would trade a genuine second signal for a longer
   path.
3. **3 ↮ 4.** PostgreSQL and Valkey are independent by construction. This is the
   payoff D-5's declaration model exists to produce, and collapsing it would
   undo the point.
4. **1 → 2 only.** The hygiene guard gates everything transitively through Task
   2 rather than through an edge to every task. D-8's ordering intent is
   satisfied by it being first, not by fanning out edges.

Signed off: 2026-08-05

---

## 7. Risk register

Inputs: risks surfaced during the walk, the two grounded findings from sections
2 and 5, and the decision-domains gap check below.

| # | Risk | Mitigation / early signal |
|---|---|---|
| 1 | The pinned 26.04 runner label may not exist as assumed. The claim comes from research dated before kickoff and was not re-verified against GitHub; if wrong, Task 6 cannot schedule at all | Early signal is immediate and unambiguous: Task 6's first run fails to start rather than failing a check. Fallback is a container step pinning the distribution, which D-7 considered and rejected on cost, not on feasibility |
| 2 | The `services` role has never run in CI. Task 2's new matrix entry runs it at `strict_idempotency: true`, so a pre-existing non-idempotency goes red on the critical path | Early signal is Task 2's own first CI run. Accepted deliberately at kickoff over the softer warn-then-tighten option; the defect would be discovered, not created |
| 3 | D-3 pins no PostgreSQL major, so a future host release upgrade introduces a new cluster rather than migrating the existing one, orphaning development data | Accepted: the bundle's position is that development data is disposable and recreation is the recovery path. Early signal is the host release upgrade itself, which is an operator-initiated event, not a surprise |
| 4 | D-2's Valkey choice rests on client compatibility researched rather than executed | Task 4's Done-when exercises the real client against the running server, and states that a failure reopens D-2 rather than being worked around |
| 5 | D-6 records that the host's `ansible` resolves to a batteries-included distribution rather than the declared `ansible-core`, so the host and CI do not run identical tooling | Early signal is divergence between Task 6 (CI) and Task 7 (host) outcomes. The bundle depends on the collection either way, so the drift is visible rather than load-bearing. Ownership sits with whatever bundle owns the Ansible bootstrap |
| 6 | D-4's peer authentication binds the database role to an exact OS account name. A dev loop, agent, or service running under a different account is refused | Early signal is the first connection attempt from such an account. Adding a role is a one-line change, so the cost of hitting this is low and the failure is loud rather than silent |
| 7 | D-8's carve-out consolidates identifiers currently scattered across prose into one labelled, greppable list, which is easier to harvest than the status quo | Accepted and reasoned in D-8. Retires with the successor hygiene bundle, which the allowlist annotation names as its removal condition |
| 8 | REQ-C1.3 and REQ-E1.3 are weak pins by the bundle's own declaration: a review and a manual exercise, neither of which prevents a later regression | Declared in `test-spec.md` rather than implied, which is the mitigation available at this bundle's proportion. REQ-E1.3's stronger form (a workflow-linting rule) is named there and judged out of proportion |
| 9 | Task 7 is manual and cannot be dispatched to a worker; a selector reading only the graph would return it as a ready head no agent can satisfy | The task block states this inline, which is the only channel available given there is no machine-readable manual flag |

### Decision-domains gap check

Catalog resolved via `resolve-catalog.sh decision-domains` (core seed, no
overlay present). All eleven domains walked against the bundle:

- **Touched and decided:** `data-storage` (D-3), `auth` (D-4 — escalated and
  decided with alternatives, as its always-escalate disposition requires),
  `secrets-config` (D-9), `dependency-adoption` (D-2 and D-6, both running the
  checklist explicitly), `caching` (engine provisioned; the substantive
  questions are the consumer's and recorded as such).
- **Not touched:** `queues-async`, `api-surface`, `concurrency`,
  `observability`, `versioning-scheme`, `deploy-migration`. The design's
  cross-cutting section already names most of these; provisioning a host is not
  a migration and introduces no irreversible step.
- **Touched but not fully decided — one:** `data-storage`. The store itself is
  decided in D-3, but the cluster's lifecycle across a major-version change is
  not. That is now recorded both as risk 3 above and in the design's
  cross-cutting section, satisfying the rule that a catalogued domain the spec
  touches but never decides becomes a named register row.

No open question remains unresolved or unaccepted.

Signed off: 2026-08-05

---

## 8. Sign-off

### Lens review pass (full bundle, first activation)

**Path: walked inline, not fanned out.** `kickoff-verification` prefers one
read-only sub-agent per canonical lens for a non-trivial scope; this session
prohibits spawning agents absent an explicit request, so the walk was inline.
Declared here rather than silently substituted, so a reader knows which
discovery mode produced this table.

| Lens | Findings | Notes |
|---|---|---|
| Correctness, logic, edge cases | 2 | L1 REQ-D1.5 determinism; L2 Task 3's `pg_hba.conf` referent |
| Security | none new | D-4 prefers peer authentication over `trust` and argues why; no secret, credential or generated password introduced; D-8's carve-out reasoned with alternatives. One tooling false positive, below |
| Error handling and failure modes | none | REQ-D1.4 covers absent, empty and unparseable source files; REQ-C1.3 covers partial-failure convergence as a declared weak pin |
| Performance | n/a | Spec bundle; no runtime surface. The two added CI jobs are minutes |
| Concurrency / state | n/a | Provisioning is serial; the bundle introduces no shared mutable state |
| Naming, readability, structure | none | REQ groups coherent; D-IDs and task IDs sequential, stable, none reused |
| Documentation | none | Task 1 adds the machine-local table row; Task 5 owns the stale declarations, and both its targets were confirmed to exist rather than assumed |
| Tests / verification | 1 | L3 the Linux CI job's host-alias fallback |
| Cross-file consistency | none remaining | The stale-reference sweep caught one straggler (the REQ-E1.4 test-spec heading still read "macOS matrix unaffected") and it was retitled |

**Altitude check (REQ-H1.3).** Determined bundle-locally from `requirements.md`
`## Sources`, not from drafting memory: the invocation made no claim about the
deliverable's nature and the bundle carries no altitude D-ID. **Untriggered —
not applicable.** Recorded rather than skipped.

### Findings and dispositions

Every finding across both lens passes is dispositioned. None deferred, none
declined.

| ID | Pass | Finding | Disposition |
|---|---|---|---|
| F1 | Mid-walk | Task 1's Done-when presumed a rule generator no deliverable produced | **Applied** — REQ-D1.5 minted; D-9 records why a generator beat both hand-authoring and having the hook read the source directly |
| F2 | Mid-walk | REQ-D1.4 guarded an absent source file only | **Applied** — widened to absent, empty or unparseable; an absence check alone passes the other two |
| F3 | Mid-walk | D-1 prose narrower than the reworded REQ-B1.4 | **Applied** — widened to "Linux hosts" |
| L1 | Sign-off | REQ-D1.5's byte-for-byte check is order-dependent and would fail spuriously across machines | **Applied** — determinism clause added to the REQ and asserted in its test-spec entry |
| L2 | Sign-off | Task 3 required `pg_hba.conf` byte-identical to "the package default", a referent that does not exist — the distribution generates that file at cluster creation rather than shipping it as a conffile | **Applied** — restated as the checkable form of D-4's intent: no task in this repo manages the file |
| L3 | Sign-off | The Linux CI job inherits the playbook wrapper's macOS fallback alias, emitting a misleading warning | **Applied** — Task 6 sets the alias explicitly |
| L4 | Sign-off | Task 1 would have built a second test harness for the scanner rules; the repo already ships one for the same rule class, written by an earlier bundle | **Applied** — Task 1 extends the existing harness; the test-spec entry says so. Not presented as a fork, because the doctrine's prefer-the-existing-structure rung resolves it without one |

Two further findings were surfaced during the walk itself rather than by a lens
pass, and are recorded in sections 3 and 5: REQ-B1.4's dead verification path,
and the `services` role's unguarded `my.cnf` task. Both are applied.

### Tooling outcome

The repository's own pre-commit scanner was run over the staged bundle as the
pre-flip lint (it is the one hook whose glob covers these files; the YAML
linters do not match a markdown-only change). It initially failed with one
finding, which was investigated rather than waved through: the repo's
`internal-hostname` rule matches dotted `.local`-style names, and the brief's
header quoted a planwright configuration *filename* containing such a segment.
A false positive, resolved by rewording the brief rather than by widening the
scanner's allowlist — that rule's own comment block explicitly declines to
allowlist dotted `.local` names, and weakening a hygiene backstop to make one
sentence convenient would invert the priority. The false-positive class is
recorded as an observation (`obs:d348a65d`) because it will recur for any
planwright artifact naming that file.

Re-run clean afterwards. Validator clean at Draft and again after the flip to
Ready, where its findings are errors rather than warnings.

### Recorded-claim re-derivation

Re-derived mechanically before the anchor, treating bundle content as data:
requirement count, test-spec pin count, unpinned-requirement count, D-ID count,
task count, and the per-tag coverage tally. The tally required correcting once —
the first derivation matched bracketed tag tokens appearing in entry *bodies* as
well as in headings, inflating it — and the corrected figures match
`test-spec.md`'s coverage-mix sentence exactly. Every requirement carries at
least one pin.

### Record

Class: meaning
Lens-pass: the full-bundle Discovery-Rigor pass recorded in this section, seven
findings across two passes, all dispositioned, altitude check not applicable.
Anchor: `fecce5e40273806bfd25dc3f23b3e192e79de088` — computed as
`spec-anchor.sh specs/dev-services`

### Terminal ready-flip — recorded deviation

The spec PR was marked ready **on operator instruction, over an incomplete CI
gate**. Recorded here rather than smoothed over, because the gate exists
precisely to prevent this and a later reader is entitled to know it did not
pass.

State at the moment of the flip: the configured CI wait bound elapsed with the
head commit's check rollup showing the majority of checks completed and
successful, none failed, and three still in progress. The head had not moved.
The gate's own condition — every check completed with overall success — was
therefore **not met**, and the refusal arm had correctly fired, which would
have left the PR draft and recorded a pending flip.

The operator was shown that state, the gate's purpose, and the specific
residual risk (one of the outstanding checks could still fail after the PR is
marked ready), and directed the flip anyway. That is the operator's call to
make; the deviation is recorded, not overridden silently.

Note that the alternative was not free: pushing the refusal note would itself
have moved the head and discarded the in-flight run, so the strict arm carried
its own cost here. Nothing about the sign-off above depends on this step — the
Draft→Ready flip, the lens dispositions, and the anchor all stand on their own,
and the merge remains the human's second key regardless.

---

## 9. Amendment log

(no amendments yet — this bundle's first sign-off is the section above)
