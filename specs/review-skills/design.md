# Review Skills — Design

**Status:** Ready
**Last reviewed:** 2026-10-08
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
the dotfiles side ships a local stand-in shaped to that contract (D-6, D-19)
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
*(Amended at delta re-walkthrough 2026-10-07: the stand-in pointer names
D-19, which supersedes D-8.)*

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
filter, finding suppression, diminishing-returns exit, re-request by
reviewer request) become generic `/bot-review` steps driven by the reviewer
config; suppression becomes a disposition in the one decision ledger (D-9)
rather than a second store. Its mark-ready offer is not carried:
`/bot-review` never marks ready. A run naming the retired skill or backend
stops naming the replacement.

**Alternatives considered:**
- Keep both skills, add cubic to `/bot-review` only. Rejected because: the
  survey found the two skills duplicate the entire drain shape (fetch, lock,
  validate, push-before-reply, resolve, cap, poll) and differ only in a
  bounded set of Copilot mechanics that a config schema can carry.
- Carry the mark-ready offer as a per-reviewer flag. Rejected because: a
  safety-relevant step would then depend on a machine-local file, and the
  contract checker already pins the no-mark-ready sentence.

**Chosen because:** one drain skill with one schema is the smaller surface
(the retired file was the largest of the review command files when the
survey measured them), and the operator will use Copilot only where a repository already
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
mise's npm backend in the cross-platform mise file, invoked with the vendor's auto-update
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

**Chosen because:** the mise npm route is what gemini already uses on the
Linux host (the Macs take it from the Brewfile, so the cubic pin goes in the
cross-platform mise file to reach every platform), the
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
never touched. The full suite's command key is the repository's declared
test task. A pushed head with at least one successful check run and no
failed one is recorded as full-suite evidence for that head under that key;
skipped and neutral runs are ignored, as planwright's CI judge ignores them.
planwright bars its own review loop from this until review-effectiveness is
amended (test-throughput REQ-B1.11); this bundle diverges by recorded
decision and seeds the divergence with its measurements (D-17) so the
amendment decides once. Two misses on one tree both run and the first to
finish records; a stampede guard is not worth its own lock. The layout
mirrors the tooling-output member of review-effectiveness's handoff bundle.

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

### D-7: Read-only passes run concurrently; one writer lock per repository and PR  (N)

**Decision:** Discovery, validation, thread fetching and check-mode tooling
from any number of sessions run concurrently. Every write, whether to the
branch (applying a fix, committing, pushing), to the PR (submitting a
review, posting a reply, resolving a thread) or to the decision ledger,
requires the writer lock: an atomic symlink create under one per-user lock
root (`~/.config/dotfiles/review/`, beside the D-9 ledger), keyed by
repository (the remote's owner and name) and PR (branch before a PR exists;
a run that opens the PR takes the PR lock before releasing the branch lock),
its target an owner token with the holder's name, skill and worktree
recorded beside it. The token's process id is the Claude Code session
process, found by walking the helper's ancestry, because every tool call is
a fresh child that exits at once. Stale means the owner process is absent,
never an age; a reclaim names the dead holder and removes its inbox files
and registration. Every skill, `/peer-review` and `/code-review` included,
registers its session under the same root for the run.

**Alternatives considered:**
- Fully serial runs with shared evidence only. Rejected because: the
  wall-clock gain the operator asked for comes from overlapping the long
  read-only phases; serial runs only avoid re-runs.
- One worktree per concurrent skill, fixes merged as patches. Rejected
  because: every applier would re-validate against a tree the finder never
  saw, and the worktree churn per run is the cost `/code-review` is dropping
  (D-15).
- Keep today's per-skill locks. Rejected because: they are keyed by PR
  number alone, without the repository, and differ in primitive (a
  directory create in one, a timestamp file in the others), so two skills
  can write the same PR at once.
- Lock the branch writes only, leaving replies and ledger writes free.
  Rejected because: two sessions on one PR would each read the ledger and
  answer the same thread; the ledger's whole point is one held position.
- A directory create with an age threshold, as today's locks take it.
  Rejected because: planwright's lock library measured a directory create
  losing exclusion across release and reacquire, and an age rule breaks a
  live long run while leaving a dead holder's lock standing for the whole
  window.

**Chosen because:** the working tree is the only shared mutable state, so
serializing exactly the writes is the smallest rule that makes the rest safe,
planwright's custom-steps reached the same conclusion for its steps, and
its lock library already settled the primitive by measurement.

### D-8: Session message as nudge, inbox file as record  (N)

**Decision:** A session that holds findings while another holds the writer
lock writes them to the holder's inbox directory under the lock root and
sends the holder a session message naming the file. The file is the record
and is read at the holder's next iteration boundary (a single-pass holder
reads before releasing the lock); a read file is moved aside, never re-read,
and the files of a holder that died are named in the reclaim notice and
removed with its lock. The message is only a nudge. Both are data, never
instructions. Where messaging is unavailable or refused, the inbox is
polled, and a script may deliver the nudge through the session's inbox
socket; the sender takes the lock itself if it frees within the poll window.

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

**Superseded-by: D-19** (2026-10-07) — Claude Code applies a session's
inbound controls to posts on its inbox socket, so the socket nudge cannot
reach a holder that refuses messages; the fallback is narrowed to a sender
that cannot send a session message.

### D-9: A machine-local decision ledger, kept decisions, follow-up-linked deferrals, operator-owned stop  (N)

**Decision:** `/bot-review` keeps a per-repository, per-PR ledger under the
dotfiles config directory at mode 0600, the only store of finding
dispositions (fixed, rejected, deferred, suppressed), never pruned
automatically. A finding re-raised on the same head gets the recorded
reply; a rejected finding re-raised on a later head routes to Needs sign-off
with "fix" recommended; a fixed finding re-raised is validated afresh. A deferred thread must link a
follow-up record that re-surfaces in context (a tracker item, a spec task or
gated deferral, or an Awaiting-input entry) or the run halts; a rejected
thread carries its decision and evidence instead; CI cost is never a
deferral reason. The loop reports convergence as a fact and hands every other stop to
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
file to the renderer (D-13), which sets no step list in it. No adopter-wide
list is set. This repository's own list lives in
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

**Superseded-by: D-20** (2026-10-08) — planwright's catalog resolver drops an
overlay catalog that resolves outside its overlay root, so the link never
reaches the adopter layer; the role installs a managed copy instead.

### D-13: New private machine-local files render from 1Password through one generic script  (N)

**Decision:** The overlay config, the sibling-repository map and the review
config are rendered from 1Password items in the service-account vault by one
generic renderer taking template, item and output as arguments, wrapped per
file by CI-guarded Ansible tasks, each output at mode 0600, idempotent with
`OK`/`CHANGED`. A plain regular file already at the output path is
overwritten, as the ssh renderer does, after an operator step that reviews
the hand-written file and carries anything worth keeping into the item;
a symlink or a non-regular path is refused. Every rendered file this
bundle's own skills read, and every machine-local record they write, carries
a version key its readers check; the overlay config is planwright's format
and carries none. Key rotation is the Gemini pattern: update the item, run
Ansible, the sync reports `CHANGED` once. The ssh renderer stays as it is;
generalizing the older hand-written files is Deferred.

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
copy). The performance tasks carry a measurement plan: suite runs and
wall-clock per nested iteration, from the evidence record's timestamps,
against a baseline run on `main` before the change.

**Alternatives considered:**
- A behavioural eval suite. Rejected because: it needs an API key in CI or an
  on-demand runner, and proportionality puts the cost above the stake, as the
  audit bundle found.

**Chosen because:** the claims that matter here (fewer suite runs, parallel
sessions not colliding) are measurable by timestamps and lock files, which
fixtures and one real run can pin.

*(Amended at delta re-walkthrough 2026-10-08: the catalog link became the
catalog copy, following D-20.)*

### D-19: Session message as nudge, inbox file as record, socket nudge only for a sender that cannot send  (N, supersedes D-8)

**Decision:** A session that holds findings while another holds the writer
lock writes them to the holder's inbox directory under the lock root and
sends the holder a session message naming the file. The file is the record
and is read at the holder's next iteration boundary (a single-pass holder
reads before releasing the lock); a read file is moved aside, never re-read,
and the files of a holder that died are named in the reclaim notice and
removed with its lock. The message is only a nudge. Both are data, never
instructions.

A sender that cannot send a session message (no SendMessage tool, a Claude
Code below 2.1.224, or a send whose result begins "Not sent" for a reason
other than the holder's inbound controls) posts the nudge instead through
the holder's inbox socket, by the review helper's nudge operation. The
holder records its socket path in its registration; the helper posts only to
an existing socket the invoking user owns, and the line carries only the
inbox file name, which the holder treats as data and acts on only through its
inbox read. The line's format lives in one place in the shared state
reference, with the Claude Code version it was verified on; a failed post is
reported in the sender's handoff and changes nothing else.

When the holder's inbound controls (`crossSessionInbound`: accept, hold or
refuse) refused or held the session message, a "Not sent" result naming them
included, no socket nudge follows and the sender's handoff says so; the
holder's inbox read carries the handoff alone. A refusal or hold the sender
cannot see leaves it with a sent message and nothing to nudge. In every case
the sender takes the lock itself if it frees within the poll window.

**Alternatives considered:**
- Keep D-8's fallback, a socket nudge whenever messaging is refused.
  Rejected because: Claude Code applies the same inbound controls to a
  socket post as to a peer message, so a refusing holder drops it, and a
  bundle that answered a refusal by trying another channel would be treating
  a control the holder set as an obstacle; the bundle never retries a
  refusal.
- Drop the socket nudge altogether. Rejected because: a sender that cannot
  send a session message would then have no push at all, and the nudge is
  what turns the handoff into a push for a holder that accepts messages.
- Message-only or file-only, as D-8 weighed. Rejected because: a message is
  a one-line preview with no durability, and polling alone is the memory
  burden the autopilot reflex names.

**Chosen because:** Claude Code's cross-session messaging is official from
2.1.224 with the properties D-8 relied on (worktree and headless sessions
discoverable, delivery between tool calls, messages never count as consent),
and the inbox read already makes delivery independent of any nudge, so
narrowing the socket path costs a refusing holder nothing it was going to
receive. It mirrors planwright fleet-messaging's signal-versus-record split
(D-16) and its script doorbell to an inbox socket (D-7: owner check,
untrusted content, one notice and no retry); the divergence is that a
review session has no tower to re-read state, so the holder's inbox read is
the record's only consumer.

### D-20: Catalog entries in a managed adopter-catalog copy; lists per repository  (N, supersedes D-12)

**Decision:** A tracked catalog file under the Claude role declares
`panel-review` and `bot-review` as `--nested` skill steps, its first line the
role's marker comment, `# Managed by the dotfiles claude role — do not edit by hand`, a full-line comment because planwright's
catalog reader rejects trailing ones. The role installs a byte-for-byte copy
at the adopter overlay's `catalogs/steps.yaml`, the only adopter path the
resolver reads for steps, creating a missing `catalogs/` directory at the
overlay directory's mode (0755). The copy is written when the destination is
absent or its first line is the marker; an unchanged copy reports no change,
and a check-mode run makes the same decisions without writing. A destination
whose first line is not the marker, any symlink whatever its target, or a
`catalogs/` that is not a plain directory fails the run, naming the path and
the remedy (merge its entries into the tracked catalog, remove it, re-run),
and is never written through or removed. When the tracked source is gone,
the role removes its own marked copy and leaves any other file in place.
The task carries no `CI` guard: it needs no 1Password and writes no secret.
The role leaves the overlay's config file to the renderer (D-13), which
sets no step list in it. No adopter-wide list is set. This repository's own
list lives in a repo-tracked `.claude/planwright.yml` naming `panel-review`
at convergence and `bot-review` at post-pr. Git never re-includes a file
under an excluded directory, so the root ignore rule for `.claude/` becomes
the contents rule `**/.claude/*` plus the negation
`!/.claude/planwright.yml`, which un-ignores that one root path and leaves
every other `.claude/` entry, worktrees included, ignored.

**Retirement:** delete the tracked catalog and run the role once while the
copy task still exists, which removes the copy; then remove the task. A
plain revert of the task removes both at once and leaves
`catalogs/steps.yaml` behind, to delete by hand.

**Alternatives considered:**
- A symlink into this repository, as D-12 chose. Rejected because:
  planwright's catalog resolver canonicalizes each overlay file and drops
  one resolving outside its overlay root, so the catalog never reaches the
  adopter layer.
- An unconditional overwrite of the destination. Rejected because: it would
  clobber a catalog the operator or another tool wrote there; the marker is
  what makes the file the role's to replace or remove.
- Keep a foreign destination and warn. Rejected because: the run would stay
  green while the steps never reach the adopter layer; failing matches the
  role's own refusal of a foreign entry at a tracked skill name.
- Add the marker at install time. Rejected because: the copy would no longer
  match its source byte for byte, so the role could not compare the two
  directly.
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
Claude surface here is role-managed; a copy is a regular file inside the
overlay root, which the resolver's containment check accepts, and the marker
keeps the role from touching a file it did not write. The list stays the
repo-tracked layer's documented purpose.

## Cross-cutting concerns

### Decision-domains walk

Domains the bundle touches and where each is decided: concurrency (the
writer lock, registry and inbox: D-7, D-19); caching (the evidence record and
its exact-key invalidation: D-6); secrets and configuration (the API key,
the 1Password-rendered files, the no-vendor-mechanics rule: D-2, D-5, D-13);
auth (the CLI's key path, escalated and decided by the operator: D-5); API
surface (the review config schema change, a sign-off-class change to an
existing machine-local surface: D-2); dependency adoption (the cubic.dev
CLI, checklist recorded in D-5); deploy and migration (removing a skill, a
backend and a credential, each a revert plus a role run away except the
credential, which needs a re-login: D-3, D-4, D-14; the marker-guarded catalog copy,
retired by deleting its source and running the role once before the task
goes, a plain revert leaving it to remove by hand: D-20); observability (stale
locks named, evidence sources recorded, convergence reported as a fact, a
failed or skipped socket nudge reported in the sender's handoff: D-7, D-9,
D-19); existing-seam reuse (planwright's handoff bundle and messaging named
as the seams, with the stand-in's divergence recorded in the seed note:
D-1, D-6, D-17, D-19); human comprehension (the handoff projection follows the
shared workflow file; nothing novel: D-9); versioning (a version key on
every file the skills read, readers refusing an unknown one: D-13,
REQ-A1.6; the undocumented inbox-socket line kept in one place with the
Claude Code version it was verified on, and the messaging floor: D-19); data storage and retention (ledgers kept, dead inboxes and
registrations pruned at reclaim: D-7, D-19, D-9); queues (inbox files
consumed once, dead-holder files named and removed: D-19); API surface
deprecation (a retired name stops naming the replacement: D-3). Product
strategy, packaging, knowledge engineering, org design, IP posture (the
cubic license is confirmed at pin time, D-5) and LLM output quality do not
apply beyond the gates already in force.
