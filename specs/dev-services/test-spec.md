# Dev Services — Test Spec

**Status:** Draft
**Last reviewed:** 2026-08-04
**Format-version:** 2
**Execution:** derived — see the status render

Coverage mix: of twenty requirements, thirteen verify as `[test]`, three as
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

### REQ-B1.4 — No provisioning off the Linux host [test]

The existing macOS matrix jobs run unmodified and continue to pass, which
demonstrates the guard holds: those jobs execute the `services` role, so a
missing or wrong guard would surface there as an attempt to install apt
packages on macOS.

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

### REQ-D1.1 — No consuming-project identifiers committed [test + design-level]

Test: the scanner rules from Task 1 run over this bundle's own commits in the
pre-commit hook, and the bundle's artifacts passing that hook is the
verification. Design-level: the carve-out is reviewed for scope — the
identifiers appear in the scanner configuration and nowhere else in the diff.
That review is not redundant with the test, because the scanner cannot flag
the one file it is allowed to name them in, so its own carve-out is precisely
the blind spot a human has to check.

### REQ-D1.2 — Scanner rules block reintroduction [test]

Positive case: a staged change introducing one of the identifiers is
confirmed to fail the pre-commit hook. This is a test of the guard itself,
and is run once by deliberate mutation — a rule nobody has watched reject
something is a rule being trusted on faith.

### REQ-D1.3 — Allowlist scoped and self-retiring [test]

Negative case: a staged edit to an already-tracked file containing one of the
identifiers is confirmed to pass the hook. Reviewed alongside it: the
allowlist entry names the successor hygiene bundle as its removal condition
in an adjacent comment.

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

### REQ-E1.4 — macOS matrix unaffected [test]

The existing macOS matrix jobs pass unchanged. Their job definitions are
asserted untouched by this bundle's diff.
