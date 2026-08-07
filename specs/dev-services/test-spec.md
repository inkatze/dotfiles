# Dev Services — Test Spec

**Status:** Ready
**Last reviewed:** 2026-08-05
**Format-version:** 2
**Execution:** derived — see the status render

Coverage mix: of twenty-two requirements, fifteen verify as `[test]`, three as
`[design-level]`, one as `[manual]`, and three carry mixed tags (two
`[test + design-level]`, one `[test + manual]`). That ratio
is a direct consequence of Task 6 — without a Linux CI job, every requirement
in this bundle would verify only by observation against a single host, which
is the condition idempotency defects hide in.

Two pins are deliberately weak and are marked as such rather than dressed up:
REQ-C1.3 and REQ-E1.3. Their entries say why.

### REQ-A1.1 — PostgreSQL installed, running, enabled [test]

The CI job asserts, after provisioning, that the PostgreSQL unit reports both
`active` and `enabled`. The same assertion runs against the physical host in
Task 7.

### REQ-A1.2 — Valkey installed, running, enabled [test]

The CI job asserts the Valkey unit reports both `active` and `enabled`.

### REQ-A1.3 — Loopback binding only [test]

The CI job enumerates listening sockets (`ss -ltn`) after provisioning and
asserts that neither service's port appears bound to any non-loopback
address. A wildcard bind (`0.0.0.0` or `::`) fails the assertion, which is
the specific regression this guards: both engines' upstream defaults differ
from the distribution's, so a packaging change could silently widen the bind.

### REQ-A1.4 — Passwordless local PostgreSQL access [test]

The CI job connects over the Unix socket as the unprivileged invoking user,
with no password supplied and no credential file present, then creates a
scratch database, runs a trivial migration against it, and drops it. The
absence of any `PGPASSWORD` or `.pgpass` in the job environment is part of
the fixture, not incidental: it is what makes the test prove REQ-A1.4 rather
than merely exercise a connection.

### REQ-A1.5 — Passwordless local Valkey access [test]

The CI job issues a ping on loopback with no credentials and asserts a
successful reply.

### REQ-B1.1 — Declaration drives the lifecycle [test + design-level]

Test: the CI job's successful provisioning of two dissimilar services from
one declared list exercises all four lifecycle steps through the declaration.
Design-level: "adding an entry requires no task edit" is a structural
property of the implementation, verified by review against D-5 rather than
by execution — a test could only demonstrate it by adding a third service the
bundle does not want.

### REQ-B1.2 — Declaration carries the required fields [design-level]

Reviewed against the declaration as written: every entry carries package
name, unit name, and expected listen address and port. The verification is
the artifact's existence and completeness.

### REQ-B1.3 — Bespoke setup referenced from the declaration [design-level]

Reviewed: each service whose setup exceeds the shared lifecycle is traceable
from its declaration entry to that setup. The requirement is about
discoverability, which is a property of the artifact rather than of a run.

### REQ-B1.4 — No provisioning on non-Linux hosts [test]

A `services` entry is added to the macOS CI matrix by Task 2, and its passing
run is the verification: the job executes the role on macOS, so a missing or
wrong Linux guard surfaces there as an attempt to install apt packages on
macOS. The entry runs at `strict_idempotency: true`, so the role is also held
to the same convergence bar as REQ-C1.1.

This pin was rewritten at kickoff. It previously claimed the *existing* matrix
jobs already executed the `services` role; they do not — the role had no matrix
entry at all, so the stated verification could not run. The new entry is what
makes the claim true, and it gives the role its first CI coverage on either
platform. The reverse direction — that the role's macOS-only content no longer
runs on Linux — is asserted on the host in Task 7, since no macOS runner can
demonstrate it.

### REQ-B1.5 — Stale declarations corrected [test]

A repository-wide search asserts that no tracked configuration comment or
documentation file still states database services are out of scope. Pinned as
`[test]` rather than `[manual]` because the assertion is a grep with an exact
expected result, which is cheaper to run than to re-review.

### REQ-C1.1 — Second run reports no changes [test]

The CI job's idempotency re-run. A second provisioning pass reporting any
changed task fails the job.

### REQ-C1.2 — Safe against an already-provisioned host [test]

Covered by the same idempotency re-run, and this is not a coincidence worth
glossing over: the second pass on a CI runner *is* a run against a host where
the services are already installed and running, which is precisely
REQ-C1.2's condition. The assertion that no data directory is destroyed is
strengthened on the physical host in Task 7, where the data directory has
contents that would be missed if lost.

### REQ-C1.3 — Convergence after a partial failure [manual]

Verified by deliberately interrupting a provisioning run on the host and
confirming the next run converges with no manual cleanup. Not automated:
reproducing a representative partial failure in CI means injecting a fault at
a chosen step, and the resulting test would verify the injection point rather
than the property. This is the weaker of the two weak pins, and it is
accepted as such for a development-services bundle.

### REQ-D1.1 — No consuming-project identifiers committed [design-level]

Design-level review of the diff: no artifact this bundle commits names the
consuming project, its repository, its features, or its file paths. There is no
carve-out to scope any more, so the review is the whole of it and the check is
simply that the identifiers appear nowhere.

Was `[test + design-level]` until 2026-08-07. The test half was the scanner
rules from Task 1 running in the pre-commit hook, which is exactly what the
retirement below withdraws — so this is now verified by review, as it was
before this bundle. Stated rather than left as a downgraded tag: the
enforcement genuinely got weaker, and a requirement whose automated half was
removed should say so instead of quietly presenting as still covered.

### REQ-D1.2 — Scanner rules block reintroduction [test]

**Retired (2026-08-07)** — the requirement this verifies is withdrawn with no
successor. Entry kept because stable IDs are never reused and its body is a
frozen record; see the retirement note in `requirements.md`.

Positive case: a staged change introducing one of the identifiers is
confirmed to fail the pre-commit hook. This is a test of the guard itself,
and is run once by deliberate mutation — a rule nobody has watched reject
something is a rule being trusted on faith.

The assertion is added to the repo's existing custom-rule test harness rather
than to a new one. That harness was built for the same class of rule by an
earlier bundle and already covers the flags-a-new-value and
does-not-flag-an-allowlisted-value directions, so the identifier rules extend a
pattern rather than introduce a second one.

### REQ-D1.3 — Allowlist scoped and self-retiring [test]

**Retired (2026-08-07)** — the requirement this verifies is withdrawn with no
successor. Entry kept because stable IDs are never reused and its body is a
frozen record; see the retirement note in `requirements.md`.

Negative case: a staged edit to an already-tracked file containing one of the
identifiers is confirmed to pass the hook. Reviewed alongside it: the
allowlist entry names the successor hygiene bundle as its removal condition
in an adjacent comment.

### REQ-D1.4 — Identifier set stays machine-local [test]

**Retired (2026-08-07)** — the requirement this verifies is withdrawn with no
successor. Entry kept because stable IDs are never reused and its body is a
frozen record; see the retirement note in `requirements.md`.

Positive: the identifier file is present, mode 0600, and reported untracked by
`git status --porcelain --ignored`, so it cannot reach a commit. Negative,
three cases: the generator is run with the source file absent, then empty,
then holding unparseable content, and each is confirmed to exit non-zero with
a message naming the fault rather than emitting a rule set covering fewer
identifiers. The negative cases are the ones that matter — a hygiene guard
that degrades quietly is indistinguishable from one that works, and the
failure is invisible precisely when it is most costly. The empty and
unparseable cases are enumerated separately because an absent-file check
alone passes both.

### REQ-D1.5 — Rules are generated, not hand-written [test]

**Retired (2026-08-07)** — the requirement this verifies is withdrawn with no
successor. Entry kept because stable IDs are never reused and its body is a
frozen record; see the retirement note in `requirements.md`.

The generator is run against the source file and its output is confirmed to
match the rule block committed in `.gitleaks.toml` byte for byte. That
assertion is the whole requirement: if regenerating reproduces what is
committed, the rules are derived rather than drifted, and a future identifier
addition is a re-run instead of a hand edit. It also fails if someone edits
the generated block directly, which is the drift this requirement exists to
catch.

Determinism is asserted alongside it, because the byte-for-byte check is only
meaningful if the output does not depend on incidental input order: the
generator is run twice against the same set listed in two different orders,
and both runs must produce identical output. Without that, the same identifier
set on two machines fails the comparison for no real reason, and the check
would be abandoned as flaky rather than trusted.

### REQ-E1.1 — CI job asserts reachability on a pinned runner [test]

The job's own successful run is the verification. The pin is checked as part
of it: the job asserts the runner's distribution release matches the target
host's, so the label silently changing meaning surfaces as a failure rather
than as a quietly less useful pass.

### REQ-E1.2 — Idempotency failure actually fails the job [test + manual]

Test: the gate runs on every CI execution. Manual: its failure behaviour is
confirmed once by deliberately introducing a non-idempotent task and
observing the job go red. An idempotency gate that has never been seen to
fail is indistinguishable from one that cannot.

### REQ-E1.3 — No secrets, no authenticated fetches [design-level]

Reviewed against the job definition: no `secrets` context is referenced, and
every network fetch is either the unauthenticated toolchain bootstrap the
existing matrix jobs already perform or the distribution package archive.
This is the second weak pin — a review confirms what the definition says
today, and nothing prevents a later edit from adding either. A stronger form
would be a workflow-linting rule, which is out of proportion for this bundle
and is noted here so the gap is visible rather than implied.

### REQ-E1.4 — No pre-existing matrix entry modified [test]

Every pre-existing macOS matrix entry passes unchanged. The assertion is
stated as a rule rather than a count: this bundle's diff modifies no entry
that existed before it and no step definition shared across the matrix. The
one permitted change is the added `services` entry REQ-B1.4's verification
requires, which is a new job rather than a modification to an existing one.
