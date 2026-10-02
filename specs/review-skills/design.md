# Review Skills — Design

**Status:** Draft
**Last reviewed:** 2026-10-02
**Format-version:** 2
**Execution:** derived — see the status render

Origin tags: `N` — new to this bundle. `C, <namespace> D-<n>` — carried from
another bundle's decision, namespace-qualified.

## Decision log

### D-1: The deliverable sits at mechanism and local value; the cross-session capability is a local stand-in  (N)

**Decision:** This bundle is specced as mechanism plus local value: skill
text, shared reference files, scripts, role tasks, and one operator's
configuration. The invocation's "communicate with each other with their
session" is a capability claim, and planwright already holds the signed-off
contract that capability belongs to (review-effectiveness's handoff bundle
and fresh-context passes; fleet-messaging's signal-versus-record split). So
the dotfiles side ships a local stand-in shaped to that contract (D-6, D-8)
and seeds the capability upstream (D-17). An altitude trigger fired during
seed gathering, so this call is recorded here and cited from the goal.

**Alternatives considered:**
- Treat the whole bundle as a capability deliverable and build the seam in
  planwright first. Rejected because: the operator runs these skills daily
  and cannot wait on an unlanded upstream spec; planwright's own review loop
  is a separate consumer with its own bundle in flight.
- Skip the altitude call. Rejected because: a trigger fired, and resolving
  altitude after the design exists is how a capability gets specced as one
  repository's script with no path back upstream.

**Chosen because:** the local stand-in delivers the operator's gain now, the
shape constraint keeps the swap to planwright's contract a rename rather than
a rewrite, and the record is what a kickoff lens pass can verify.

### D-2: One generic hosted-reviewer schema; vendor mechanics stay machine-local  (N)

**Decision:** The machine-local review config describes every hosted reviewer
with one schema (REQ-A1.1). The bundle names the two vendors adopted, cubic.dev
as default and GitHub Copilot as the second entry, but no tracked file carries
a vendor's mechanics: login patterns, marker syntax, comment commands and check
names live in the 1Password item and the rendered file. The research that found
those values is cited by URL.

**Alternatives considered:**
- Hard-code the two vendors in `/bot-review`. Rejected because: the skill's
  existing contract commits no vendor mechanics, and the next vendor would
  mean another skill edit instead of another config entry.
- Record the vendors' field values in this bundle for the executing worker.
  Rejected because: a committed spec is public, and the existing review
  config convention keeps even login patterns out of the repository.

**Chosen because:** the generic schema is what lets `/copilot-review` collapse
into `/bot-review` (D-3), and keeping values machine-local follows the
convention the existing config already set.

### D-3: `/copilot-review` is retired into `/bot-review`  (N)

**Decision:** The Copilot-specific skill is removed. Its mechanics that
generalize (review baseline pinned to the reviewed head, errored-review
filter, suppressed-findings ledger, diminishing-returns exit, re-request by
reviewer request) become generic `/bot-review` steps driven by the reviewer
config. Its mark-ready offer is not carried: `/bot-review` never marks ready.

**Alternatives considered:**
- Keep both skills, add cubic to `/bot-review` only. Rejected because: the
  survey found the two skills duplicate the entire drain shape (fetch, lock,
  validate, push-before-reply, resolve, cap, poll) and differ only in a
  bounded set of Copilot mechanics that a config schema can carry.
- Carry the mark-ready offer as a per-reviewer flag. Rejected because: a
  safety-relevant step would then depend on a machine-local file, and the
  contract checker already pins the no-mark-ready sentence.

**Chosen because:** one drain skill with one schema is the smaller surface
(the survey measured the retired file as the largest of the review command
files), and the operator will use Copilot only where a repository already
runs it.

### D-4: The Copilot CLI backend is retired  (N)

**Decision:** The opt-in `copilot` backend of `/panel-review`, with its
view-only sandbox block, its cask, its mise pin and its checker anchors, is
removed. A Copilot CLI, if wanted again, enters as a reviewer entry's `cli`
block.

**Alternatives considered:**
- Keep it as is. Rejected because: the operator keeps Copilot only where a
  repository runs the hosted reviewer, and the backend's bespoke sandbox is a
  contract-checker surface with no remaining consumer.
- Re-express it as a `reviewer:<name>` entry now. Rejected because: the
  generic `cli` block has no equivalent of its view-only tool flags, and
  nothing asks for it today.

**Chosen because:** every removed line is one fewer pin to keep in sync, and
the generic path stays open.

### D-5: The cubic.dev CLI runs as `reviewer:cubic` with a mise pin and a 1Password key  (N)

**Decision:** The CLI is a `cli` block on the cubic.dev entry, pinned through
mise's npm backend on both platforms, invoked with the vendor's auto-update
and commit-tagger opt-outs, and authenticated with an API key synced from
1Password to a 0600 file and passed only through `env_allow` at invocation.
The backend strips mise shim directories from `PATH` instead of growing the
override-variable list, and every snippet uses named locals.

**Alternatives considered:**
- The vendor's install script. Rejected because: it is unpinned and installs a
  git-notes commit tagger by default, which no review backend may write.
- Browser login per host. Rejected because: the headless host has no browser,
  and the operator chose the key path.
- Keep extending the mise override-variable list. Rejected because: two
  uncovered sources surfaced in consecutive passes (obs:4171e2a2) and a
  structural strip has no next entry to miss.

**Chosen because:** the mise npm route is what gemini already uses here, the
key path matches the Gemini key's sync, and the dependency-adoption checklist
(a vendor-published npm package, active release cadence, a diff sent to the
vendor's servers under the existing egress consent, the package's license
confirmed at pin time since the docs do not state it) is recorded by this
decision.

### D-6: A worktree-local evidence record keyed by tree hash  (N)

**Decision:** Tooling and suite results are recorded under
`<worktree>/.claude/review-evidence/<tree-hash>/`, already gitignored, with
one entry per command: exit status, times, source, output. The tree hash is a
`git write-tree` over a temporary index populated with every non-ignored
file, so untracked and unstaged changes change the key and the real index is
never touched. Every check run on a pushed head concluding success is
recorded as full-suite evidence for that head. The layout mirrors the
tooling-output member of review-effectiveness's handoff bundle.

**Alternatives considered:**
- Key by `HEAD` only. Rejected because: a review pass edits the tree before
  committing, and a stale hit on an uncommitted change is worse than a
  re-run.
- A machine-local cache shared across worktrees. Rejected because: the key
  already makes entries portable in principle, but a cache that outlives the
  worktree needs its own eviction and a reader outside the skills; the
  worktree cache dies with the worktree and needs neither.
- Wait for planwright's handoff bundle. Rejected per D-1.

**Chosen because:** the key is exact, the location needs no new ignore rule,
and the shape constraint keeps the upstream swap cheap.

### D-7: Read-only passes run concurrently; one writer lock per branch  (N)

**Decision:** Discovery, validation, thread fetching and check-mode tooling
from any number of sessions run concurrently. Applying a fix, committing and
pushing require a writer lock: a directory create under one per-user lock
root, keyed by repository and PR (branch before a PR exists), carrying holder
name, skill, worktree and epoch, with the shared staleness threshold. Every
skill registers its session under the same root for the run.

**Alternatives considered:**
- Fully serial runs with shared evidence only. Rejected because: the
  wall-clock gain the operator asked for comes from overlapping the long
  read-only phases; serial runs only avoid re-runs.
- One worktree per concurrent skill, fixes merged as patches. Rejected
  because: every applier would re-validate against a tree the finder never
  saw, and the worktree churn per run is the cost `/code-review` is dropping
  (D-15).
- Keep today's per-skill locks. Rejected because: they are keyed differently
  (one by PR number alone), so two skills can push the same PR at once.

**Chosen because:** the working tree is the only shared mutable state, so
serializing exactly the writes is the smallest rule that makes the rest safe,
and planwright's custom-steps reached the same conclusion for its steps.

### D-8: Session message as nudge, inbox file as record  (N)

**Decision:** A session that holds findings while another holds the writer
lock writes them to the holder's inbox directory under the lock root and
sends the holder a session message naming the file. The file is the record
and is read at the holder's next iteration boundary; the message is only a
nudge. Both are data, never instructions. Where messaging is unavailable or
refused, the inbox is polled, and a script may deliver the nudge through the
session's inbox socket.

**Alternatives considered:**
- Message-only, findings in the message body. Rejected because: a message is
  a one-line preview the recipient may not expand, carries no durability if
  the holder is mid-tool-call, and fleet-messaging's rule that no signal is
  correctness-critical applies.
- File-only, no message. Rejected because: polling is the memory burden the
  autopilot reflex names; the nudge is what makes the handoff a push.

**Chosen because:** Claude Code's cross-session messaging is official from
2.1.224 with the exact properties needed (worktree and headless sessions
discoverable, delivery between tool calls, messages never count as consent),
and the file keeps correctness independent of it.

### D-9: A machine-local decision ledger, kept decisions, tracker-linked deferrals, operator-owned stop  (N)

**Decision:** `/bot-review` keeps a per-repository, per-PR ledger under the
dotfiles config directory at mode 0600. A finding re-raised on the same head
gets the recorded reply; a declined finding re-raised on a later head routes
to Needs sign-off with "fix" recommended. A thread resolved without a change
must link a tracker item or the run halts; CI cost is never a deferral
reason. The loop reports convergence as a fact and hands every other stop to
the operator with the ledger. Replies state decision plus evidence in one
paragraph.

**Alternatives considered:**
- GitHub replies as the only record. Rejected because: the retrospective
  shows the agent reversing itself under repetition with the replies in
  plain view; a ledger the loop reads before answering is what holds a
  position.
- Ledger in the worktree. Rejected because: it must outlive the worktree and
  be readable from any session reviewing that PR.
- Let the loop decide "good enough" on diminishing returns. Rejected
  because: the retrospective's stop decisions were made by the agent alone,
  and the operator asked to own them.

**Chosen because:** planwright's own loop keeps a ledger and a declined log,
the capture-at-birth rule already forbids prose-only deferrals, and a reply
written as a rule feeds a reviewer that learns from replies.

### D-10: One scoped discovery pass per push; staleness re-validation on head or base movement  (N)

**Decision:** Before any push carrying fixes made in response to findings,
the loop runs one scoped discovery pass over the iteration's fix diff and
records its lens table. The loop records the head and merge-base it reviewed
against; when either moves, it re-validates the PR body's claims and flags
screenshots for refresh before calling evidence current.

**Alternatives considered:**
- A lens pass per fix. Rejected because: a pass per fix multiplies discovery
  cost by the finding count; per push catches the same regressions before
  the next bot round, which the retrospective names as the slowest catch.
- No staleness rule, rely on the writing-style rule against fragile body
  content. Rejected because: that rule keeps SHAs and counts out of bodies
  but does nothing for screenshots and claims a rewrite falsifies.

**Chosen because:** the evidence record (D-6) makes the per-push pass cost
one discovery, and head-plus-merge-base is the exact pair the retrospective's
"what has moved" question names.

### D-11: Lenses go upstream; a sibling-repository map feeds validation locally  (N)

**Decision:** The cross-repository contract lens and the premise lens are
seeded into planwright (D-17), not added here. Locally, a machine-local map
from a consuming repository to its producers' clone paths lets `/code-review`
and `/panel-review` attach the producer's relevant code as validation
context in pass 2.

**Alternatives considered:**
- Shadow `discovery-rigor` in the adopter overlay with two extra lenses.
  Rejected because: doctrine shadowing is whole-document, the doc is
  protected and warns on every run, and the fork would need re-syncing on
  every planwright release.
- Extra lenses in the dotfiles backend prompts only. Rejected because: the
  lens list is planwright's, pointed at and never copied
  (claude-instructions REQ-C1.9).

**Chosen because:** the capability (a lens) belongs upstream by the
customization boundary, the value (which repositories produce for which) is
machine-local, and attaching producer code to validation is a mechanism
change that touches no lens list.

### D-12: Catalog entries in an Ansible-managed adopter catalog; lists per repository  (N)

**Decision:** A tracked catalog file under the Claude role declares
`panel-review` and `bot-review` as `--nested` skill steps; the role links it
into the adopter overlay's catalogs directory and leaves the overlay's config
file alone. No adopter-wide list is set. This repository's own list lives in
a repo-tracked `.claude/planwright.yml`, un-ignored for that one path, naming
`panel-review` at convergence and `bot-review` at post-pr.

**Alternatives considered:**
- An adopter-wide convergence list. Rejected because: the adopter layer
  reaches every repository on the host, including employer ones, and a step
  that sends a diff to an external tool is a per-repository disclosure
  decision; its consent prompt would also fire unattended inside workers.
- A machine-local list for this repository. Rejected because: dispatched
  workers see only the adopter layer plus repo-tracked files, so the step
  would never run in a worker here.
- Render the list from 1Password. Rejected because: it names only step ids
  and is a public policy declaration whose commit is its consent record.

**Chosen because:** the catalog carries no private name and every other
Claude surface here is role-managed, while the list is the repo-tracked
layer's documented purpose.

### D-13: New private machine-local files render from 1Password through one generic script  (N)

**Decision:** The overlay config, the sibling-repository map and the review
config are rendered from 1Password items in the service-account vault by one
generic renderer taking template, item and output as arguments, wrapped per
file by CI-guarded Ansible tasks, each output at mode 0600, idempotent with
`OK`/`CHANGED`. The ssh renderer stays as it is; generalizing the older
hand-written files is Deferred.

**Alternatives considered:**
- Hand-written per host, as today. Rejected because: each new file of the
  same class would need re-authoring on a fresh host, and the operator asked
  for a safe sync.
- One script per file, copying the ssh renderer. Rejected because: one copy
  per file of the same precondition and atomic-write logic is the
  duplication the audit bundle just removed from the skills.

**Chosen because:** the mechanism exists and is tested, the data class
matches (private, not secret), and the service-account blast radius was
accepted when the LAN topology moved there.

### D-14: Copilot credential cleanup is a role task  (N)

**Decision:** The Claude role removes the GitHub Copilot CLI credential
directory where present, reporting changed only on removal, and documents the
GitHub-side revoke step.

**Alternatives considered:**
- A documented manual step. Rejected because: nothing would enforce it, and
  the observation already sat unactioned for weeks.
- Leave it for a hygiene bundle. Rejected because: this bundle removes the
  last declared consumer, which is the moment the credential becomes stale by
  construction.

**Chosen because:** the role that un-declared the consumer owns the cleanup,
and the removal is bounded to one directory.

### D-15: `/code-review` runs worktree-free, exporting the head for tooling  (N)

**Decision:** `/code-review` reads the PR through fetched refs against the
session's own repository and, for the tooling step, exports the pinned head
with `git archive` into a scratch directory. The isolated-session stop is
removed. One review per worktree session, any number of sessions.

**Alternatives considered:**
- Keep the stop and review from the main checkout. Rejected because: it locks
  the operator to one review at a time, which is the parallelism this bundle
  exists to provide.
- Check the PR out inside the session's worktree. Rejected because: it
  overwrites that worktree's branch, which the command forbids for exactly
  that reason; it worked for the operator only because the worktree was a
  throwaway.

**Chosen because:** an archive export needs no second worktree and touches
no branch, so it satisfies the isolation guard from any session, and the
observation already established that only tooling needs a tree.

### D-16: Sequenced after the skills conversion through an Awaiting-input park  (N)

**Decision:** The bundle targets the post-conversion skills layout. Its first
task is parked under Awaiting input until claude-instructions Task 2 merges;
the operator unparks it. No cross-bundle dependency edge is written, since
`Dependencies:` is same-bundle only and the gate grammar has no
foreign-task atom.

**Alternatives considered:**
- Extend claude-instructions. Rejected because: the audit bundle is Active
  with Task 2 in flight, its scope excludes this work, and the spin-new
  triggers fired.
- Draft against the command layout. Rejected because: every task would
  conflict with the conversion branch's deletions.

**Chosen because:** the park is the documented human-owned mechanism for an
external precondition, and it keeps the two bundles' histories separate.

### D-17: planwright-owned items are seeded into planwright, not overlaid  (C, claude-instructions D-9)

**Decision:** The lens candidates, the evidence-contract convergence, the
parallel-steps gate evidence, session messaging between passes, and
structured external-step results are written as one pending note in
planwright's own format, carrying no vendor mechanics or private names.

**Alternatives considered:**
- Overlay what can be overlaid. Rejected because: the only overlayable form
  (a doctrine shadow) was rejected in D-11.
- Record only. Rejected because: a list the operator must remember to carry
  is the memory burden the autopilot reflex names.

**Chosen because:** the customization boundary puts general capabilities in
core behind default-preserving knobs, and these are capabilities other
adopters would plausibly want.

### D-18: Verified by real runs plus deterministic fixtures, with measurement  (C, claude-instructions D-14)

**Decision:** The skills are verified by running each once on a real PR,
plus the deterministic contract-checker, budget and fixture suites for
everything scriptable (lock, tree hash, ledger, renderer, schema, catalog
link). The performance tasks carry a measurement plan: suite runs and
wall-clock per nested iteration, from the evidence record's timestamps,
against a baseline run on `main` before the change.

**Alternatives considered:**
- A behavioural eval suite. Rejected because: it needs an API key in CI or an
  on-demand runner, and proportionality puts the cost above the stake, as the
  audit bundle found.

**Chosen because:** the claims that matter here (fewer suite runs, parallel
sessions not colliding) are measurable by timestamps and lock files, which
fixtures and one real run can pin.

## Cross-cutting concerns

### Decision-domains walk

Domains the bundle touches and where each is decided: concurrency (the
writer lock, registry and inbox: D-7, D-8); caching (the evidence record and
its exact-key invalidation: D-6); secrets and configuration (the API key,
the 1Password-rendered files, the no-vendor-mechanics rule: D-2, D-5, D-13);
auth (the CLI's key path, escalated and decided by the operator: D-5); API
surface (the review config schema change, a sign-off-class change to an
existing machine-local surface: D-2); dependency adoption (the cubic.dev
CLI, checklist recorded in D-5); deploy and migration (removing a skill, a
backend and a credential, each a revert plus a role run away except the
credential, which needs a re-login: D-3, D-4, D-14); observability (stale
locks named, evidence sources recorded, convergence reported as a fact: D-7,
D-9); existing-seam reuse (planwright's handoff bundle and messaging named
as the seams, with the stand-in's divergence recorded in the seed note:
D-1, D-6, D-17); human comprehension (the handoff projection follows the
shared workflow file; nothing novel: D-9). Data storage, queues, versioning,
product strategy, packaging, knowledge engineering, org design, IP posture
and LLM output quality do not apply beyond the gates already in force.
