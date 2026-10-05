# Claude Instructions Audit — Design

**Status:** Ready
**Last reviewed:** 2026-10-05
**Format-version:** 2
**Execution:** derived — see the status render

Origin tags: `N` new in this bundle; `C, <bundle> D-n` carried from another
bundle with the namespace qualified.

## Decision log

### D-1: The deliverable sits at local value, with one repo-local mechanism  (N)

**Decision:** This bundle's altitude is local value: verdicts on this
operator's own instruction files, applied as edits. One piece is a mechanism
(the word-budget guard, D-5) filling a seam planwright's instruction-hygiene
doctrine already names. Nothing here is doctrine, and every rule that lives at
doctrine or capability altitude in planwright is routed there (D-9) rather than
shadowed or re-stated.

**Alternatives considered:**
- Treat the audit as a doctrine deliverable (an "instruction earns its place"
  rule promoted to planwright). Rejected because: the rule already exists
  there, in instruction-hygiene; what is missing is its application to
  surfaces planwright does not own.
- A pure one-off diet with no mechanism. Rejected because: the repo-root file
  breached its documented ceiling severalfold through months of accretion
  (inventory, 2026-09-24); a ceiling with no guard is how the current state
  arose.

**Chosen because:** The seed claims pin an audit with per-rule verdicts, not a
framework change, and the mid-flow signal (the regrowth) is answered by one
small guard, which is the right altitude for a repo-specific budget.

### D-2: Review doctrine has one source, planwright's, and the taxonomy is planwright's  (N)

**Decision:** The user-global file stops carrying copies of validation-rigor,
discovery-rigor, finding-categorization and refactor-instinct; each becomes a
pointer with the resolution path. The dotfiles review skills resolve those docs
at run time and follow them. The skills that apply findings to their own
branch adopt four buckets and act-then-review for Needs-sign-off findings;
`/code-review` keeps severity tiers because it never touches another author's
branch, and `/peer-review` keeps its prompt because its replies reach people.
A skill whose drain scope differs from planwright's records the override in
the skill with its reason. Act-then-review on a branch the skill pushes is
accepted: the change is reviewable in the pull request before merge. Skills
locate planwright through the enabled version's install path, and a document
that does not resolve halts the skill. The contract checker pins the pointer
and drops the retired-bucket guards.
*(Amended at kickoff 2026-09-25: taxonomy scoped to local-apply skills; root resolution and halt-on-miss added.)*

**Alternatives considered:**
- Point at planwright but keep three buckets for the dotfiles skills as a
  declared scoping. Rejected because: two taxonomies stay live in one session,
  which is the exact confusion the two bucket-count observations recorded.
- Keep a local copy and re-sync it now, with a diff check against the plugin.
  Rejected because: the copy is what drifted; a diff check adds a second
  mechanism to maintain a duplicate.

**Chosen because:** One law governs every skill that cites it, the operator's
own Review Workflows text already describes planwright's act-then-review
behaviour, and the resolution script is the documented reference form.

### D-3: Mergeable is enough; behind-by-zero is not a precondition  (N)

**Decision:** The currency condition for a ready flip in the user-global
file becomes "no conflicts with the base"; CI green and the review cadence
stay. The sync-push-re-run ritual is removed. The two planwright mechanisms
that enforce the stricter posture (the ready-guard hook denying a branch that
is behind, the convergence merge into worker branches) are seed items for
planwright, not worked around here; until they change, a hook denial is
reported to the operator.
*(Amended at kickoff 2026-09-25: only the currency condition changes; hook denials reported.)*

**Alternatives considered:**
- Keep the rule and remove only the ceremony prose, letting the hook enforce.
  Rejected because: the hook is the part that bites (it denies the operator's
  own flips in every repo), so the prose change alone changes nothing.
- Keep everything. Rejected because: the invocation names this as the
  example of a rule applied to the operator's detriment.

**Chosen because:** Where CI runs on the pull request's merge ref, as it does
in this repository, a mergeable branch that is behind produces the same merge
commit whether or not the head is synced first, so the ritual buys a re-run
and nothing else. Accepted gap: a green result from before the base moved
does not cover later base changes; the operator syncs when those matter.

### D-4: The review commands become skills with a shared reference directory  (N)

**Decision:** Each review command becomes `roles/claude/files/skills/<name>/SKILL.md`,
materialized into `~/.claude/skills/` as one symlink per tracked entry (each
skill directory and the shared directory), with shared mechanics in a sibling
`review-shared/` directory linked by relative path and read at the step that
needs them. The commands directory symlink is retired. Per-entry links rather
than one directory link, because `~/.claude/skills/` is already a real
directory holding content this repository does not own. The link task globs
the tracked skills directory, links an entry only when its destination is
absent or already a link into this repository (failing otherwise), prunes its
own links whose target is gone, and removes the commands path only when it is
a link into this repository. Rollback is a revert plus a run of the Claude
role on each host. Every converted skill keeps its name and flags; whether
it is slash-only or model-invocable follows its caller (D-16).
*(Amended at kickoff 2026-09-25: per-entry links, link policy, invocation mode.)*
*(Amended at extension 2026-10-05: the slash-only-for-all sentence replaced
by the pointer to D-16.)*

**Alternatives considered:**
- Keep commands and add a tracked reference directory read by absolute path.
  Rejected because: it relies on an undocumented placement for non-command
  prose and keeps the legacy form for new work.
- Keep commands and inline one trimmed copy per file. Rejected because: the
  duplication the inventory measured (a full copy of the three-pass
  restatement in every command, near-identical nested handoffs, repeated
  GraphQL reply-and-resolve blocks across the thread-draining commands) is
  the cost being removed.

**Chosen because:** The skills page documents supporting files linked by
relative path and loaded lazily, which is exactly the point-of-use pattern the
shared blocks need, and the plugins page recommends skills for new work while
keeping commands supported. Cross-skill sharing of one file is undocumented;
a plain file read by path works regardless, and the shared directory is a
sibling on purpose so a relative link resolves from every skill.

### D-5: A repo-local word-budget checker, thresholds set by rule  (N)

**Decision:** A new script under the Claude role's scripts directory counts
words per instruction surface in the C locale and enforces warn and error
thresholds, wired into lefthook and run as a step in the contract checker's
CI job, with warnings surfaced as annotations. Thresholds are derived from
the surface's declared size by the formula in REQ-G1.3 and recorded beside
it. It ships green with thresholds derived from current sizes; each task that
changes or adds a surface re-derives or declares that surface's thresholds.
*(Amended at kickoff 2026-09-25: formula, counting method, CI placement.)*

**Alternatives considered:**
- Reuse planwright's `check-instructions.sh`. Rejected because: it is bound to
  the plugin's skills/doctrine layout and manifest grammar; adapting it costs
  more than a small repo-local counter.
- Line counts. Rejected because: reflow-gameable; planwright's doctrine
  settles on words for the same reason.
- No guard, a documented ceiling only. Rejected because: that is the current
  state.

**Chosen because:** The measured claim that instruction-following degrades
with load is the reason for the whole audit; a deterministic proxy on every
commit is the cheapest way to keep the diet's result.

### D-6: The outbound-message rule is always-loaded gating law  (N)

**Decision:** "No message to another human without the operator approving the
exact text and recipient" lives in the user-global file, with exactly two
exceptions (an explicit go-ahead for a message or for a run's named scope;
replies to automated reviewers, defined mechanically). A run with no
operator present drafts such a message into its handoff instead of sending
it, and a recipient is never guessed. The Slack recipient-resolution and
confirmation mechanics move to the shared directory, and the fixed-template
exemption is removed. Replies to bots are publicly visible and follow the
untrusted-comment rule.
*(Amended at kickoff 2026-09-25: go-ahead scope, unattended runs, bot definition.)*

**Alternatives considered:**
- Move the whole Slack section out with the rule inside it. Rejected because:
  a rule that gates an outward-facing act must be loaded before the acting
  step, which a point-of-use file cannot guarantee.
- Scope the rule to Slack only. Rejected because: the operator asked for
  any channel, and PR comments reach humans the same way.

**Chosen because:** planwright's safety floor (gating law is never deferred)
applies to this file the same way it applies to a skill body.

### D-7: The repo-root file keeps rules; rationale moves to docs notes  (N)

**Decision:** Every narrative section of the root `CLAUDE.md` collapses to its
rules plus a one-line pointer; the why moves to `docs/<topic>.md` (a new
directory) or stays in the script header or spec that already carries it. The
claude-context ceiling is kept, and that bundle gets an expression-only
amendment for its stale paths and its missing header lines (format
version and the mirrored status). Its content requirements that this bundle
makes false are marked superseded by this bundle rather than rewritten.
*(Amended at kickoff 2026-09-25: superseded content requirements.)*

**Alternatives considered:**
- Delete the rationale outright. Rejected because: the collected why is
  useful as a browsable set; commit messages are not browsable.
- Raise the ceiling and keep the file as a design log. Rejected because:
  the file loads every session in this repo; a design log belongs elsewhere.

**Chosen because:** The claude-context scope gate already says what belongs
in the file; this restores it without losing the record.

### D-8: Neutral labels for other repositories  (N)

**Decision:** The bundle names only this repository and planwright. The
operator's personal project is "the project repo"; employer repositories are
"the work repos". Live instruction files are scrubbed of external names;
frozen bundles are left as records. The names come from the existing
machine-local identifier file under `~/.config/dotfiles/` (the one
`scripts/gitleaks-identifier-rules.sh` reads), so the check can exist in the
public repository without carrying the names it checks for. The check is a
review-time grep over the live instruction files and this bundle only, run
from the contract checker's suite and by hand at task review; it never
blocks a commit, so it does not revive the identifier guard `specs/dev-services`
retired. It never prints a matched name (file and line only), and a missing
identifier file produces a visible warning rather than a silent pass.
*(Amended at kickoff 2026-09-25: reuse the existing identifier file; scoped review-time check.)*

**Alternatives considered:**
- Scrub the frozen bundles too. Rejected because: their anchors change,
  each needs a changelog and re-anchor, and history keeps the names anyway.

**Chosen because:** This repository is public; names of other people's
projects are not this repository's to publish, and the operator asked for it.

### D-9: planwright-owned items are seeded into planwright, not overlaid  (N)

**Decision:** Every rule this audit found wanting that lives in planwright
(ready-guard posture, convergence merge, fetch hang guards, skill drifts,
doctrine passages lagging scripts, the `review_sequence` predicate) is
written as one pending note into planwright's pending-notes directory for its
own `/spec-draft`. No doctrine shadow or config overlay is added here.

**Alternatives considered:**
- Overlay what can be overlaid. Rejected because: almost nothing in scope
  has a knob in the planwright version audited, this repository's
  `.gitignore` blocks the tracked overlay layer, and a doctrine shadow cannot
  change the scripts that enforce the rules.
- Record only, carry over by hand. Rejected because: a list the operator
  must remember to carry is the memory burden the autopilot reflex names.

**Chosen because:** The customization boundary puts general capabilities in
core behind default-preserving knobs; a mergeable-is-enough ready guard and a
skippable convergence merge are capabilities other adopters would plausibly
want, so they graduate through planwright's own drafting, not a local patch.

### D-10: Verdicts by cluster, recorded as decided rules, evidence held as a snapshot  (N)

**Decision:** The inventory was extracted by read-only workers per surface,
then clustered by decision axis; the operator decided per cluster, dropping to
per-item only where a cluster split. Verdicts are stated as REQs. The
per-rule tables are a dated snapshot with a re-check trigger (REQ-K1.1).

**Alternatives considered:**
- Decide per rule. Rejected because: several hundred inventory rows; the
  interview would not converge in one session.
- Inventory as a task after sign-off. Rejected because: the operator wanted
  the verdicts taken in the drafting session.

**Chosen because:** planwright's interaction-style bounds each pass to a
few questions, and the spec format wants decided rules over enumerated
counts; clustering satisfies both.

### D-11: The shell rule states the measured reality  (N)

**Decision:** Three lines replace the contradicting pair: the Bash tool runs
bash on Linux and zsh on macOS and cannot be pointed at fish; commands written
for the operator use fish syntax; mise-managed tools run through `fish -c`.

**Alternatives considered:**
- Keep only the mise-wrapping rule. Rejected because: the operator wanted the
  fish-syntax expectation for commands they run themselves kept.
- Configure fish as the tool's shell. Rejected because: not possible; the
  shells the docs list do not include fish, and open upstream issues
  confirm the login shell is ignored (both as of 2026-09-24).

**Chosen because:** A rule the tool cannot follow is resolved fresh every
session; stating the reality removes the resolution.

### D-12: The kickoff flip stays, as a stated exception  (N)

**Decision:** planwright keeps marking the spec PR ready on a clean kickoff
(the knob stays at its default), and the user-global rule gains one clause
naming that as the single exception.
*(Amended at extension 2026-10-05: in a solo repository the agent also
flips under D-17; the kickoff flip is the single configured flip kept in a
work or collaborative repository.)*

**Alternatives considered:**
- Set the knob to false on every host. Rejected because: it re-introduces a
  manual un-draft step the operator must remember, for a PR whose sign-off
  the operator just gave.

**Chosen because:** The exception already exists in behaviour; the rule
should say so rather than contradict it.

### D-13: The inventory lives machine-locally, uncommitted  (N)

**Decision:** The inventory tables are stored under
`~/.config/dotfiles/claude-instructions-inventory/` (directory mode 0700,
files 0600), the
documented machine-local directory, and cited from this bundle as a Source.
They are working evidence for the executing tasks and need no operator
review.
*(Amended at kickoff 2026-09-25: directory mode 0700, files 0600.)*

**Alternatives considered:**
- Commit a scrubbed copy under the bundle as research. Rejected because:
  the operator preferred not to commit it, and scrubbing eight hundred lines
  of paths and names by hand is where a leak would slip through.
- Keep only the cluster ledger. Rejected because: the per-rule rows are what
  the executing tasks act on.

**Chosen because:** Absence degrades visibly (a task that needs the tables
and cannot find them says so and re-extracts), which is the documented
contract for that directory.

### D-14: No behavioural eval suite for the skills  (N)

**Decision:** The converted skills are verified by running each one once on a
real pull request after conversion, recorded as manual verification, plus the
deterministic budget and contract checks. No fixture-driven prompt-eval suite
is added.

**Alternatives considered:**
- Adopt planwright's kept prompt-eval convention. Rejected because: it needs
  an API key in CI or an on-demand runner, and the surfaces here change
  rarely; proportionality puts the cost above the stake.

**Chosen because:** The decision-domains catalog's LLM-output-quality domain
asks that the choice be made explicitly rather than defaulted; the choice is
manual verification with deterministic proxies on every commit.

### D-15: The merged `/bot-review` command joins the conversion  (N)

**Decision:** The command that merged during drafting is inventoried against
the same method and treated as one more review skill in D-4's conversion; it
gets no separate task and no gate.

**Alternatives considered:**
- A later re-inventory task gated on its merge. Rejected because: the merge
  happened before the bundle was written, so the gate was already met.

**Chosen because:** It follows its siblings' shape exactly (three buckets,
a Maintenance section, restated validation, a distinct nested drain scope
that stays as its own recorded override under REQ-B1.2).

### D-16: Model invocation is scoped by caller, not disabled across the board  (N)

**Decision:** `disable-model-invocation: true` protects the human-facing
review skills, those with no `--nested` mode, from being invoked without
anyone asking: they stay slash-only. A skill with a `--nested` mode (its
pinned argument-hint carries the flag) leaves the key unset and is
model-invocable, because a parent skill invokes that mode through the Skill
tool and the key blocks that call. A parent skill is any skill that invokes
a review skill through the Skill tool: its `--nested` mode, or a handoff the
calling skill documents (`/bot-review --local` hands off to `/panel-review`
without `--nested`). The contract checker derives the set from the
argument-hint it already pins per skill (`expected_hint`), not from a
separate list of nested skills, and each model-invocable skill's front-matter
description ends with the sentence REQ-C1.12 fixes. Enforcement is the
description sentence plus each skill's own gates: a permission deny on the
Skill tool would block the parent call too, so it is not used.

**Alternatives considered:**
- Keep the key on every review skill and have a parent skill ask the
  operator to type the nested invocation. Rejected because: the nested mode
  exists so a parent can run the loop unattended; a manual hop defeats it.
- Drop the key on every review skill. Rejected because: `/peer-review` and
  `/code-review` post to humans and have no mode a parent calls; nothing is
  gained by letting the model start them, and the description load is pure
  cost.
- A nested-only sibling skill per family, model-invocable, with the
  interactive skill kept slash-only. Rejected because: the families were
  folded into one skill with a mode on purpose (the legacy observations line
  of 2026-07-14 records the fold; Sources), and two files per family
  re-creates the duplication Task 2 removed.

**Chosen because:** The skills documentation is explicit that the key stops
Claude invoking the skill on its own and that Claude Code blocks the
attempt, so a parent skill's call cannot survive it. Accepted risk: a
model-invocable skill's description is always in context, so it could run
without anyone asking. That matters most for `/panel-review`, which sends
the diff to an external backend on every pass; today its per-repository
upload consent covers only the `reviewer:<name>` backend, so Task 8 extends
the shared egress consent (the `<owner>/<repo>` key `/code-review` already
uses) to `/panel-review`'s default backends, and the work host's override
confirmation stays. `/copilot-review` and `/bot-review` push commits, post
replies and spend a metered vendor quota; the description sentence, the
outbound rule's bot exception, the same-PR lock and each loop's
confirmation-gated or forbidden ready flip bound an unasked run. Early
signal: a review skill in a transcript with no typed invocation and no
parent call.

### D-17: The ready flip follows repository ownership, like a history rewrite  (N)

**Decision:** The user-global Pull Request Lifecycle rule scopes who marks a
pull request ready by repository ownership, borrowing the ownership tests
the Git Conventions apply to a history rewrite (operator-owned; nobody else
working from it; an unknown owner counts as work) and applying them to the
repository, with the three repository kinds REQ-A1.6 defines. In a solo
repository the session that completes the last step of the review cadence
the pull request calls for flips it ready itself once that cadence has run,
CI is green on the current head and the pull request is mergeable,
re-checking each condition of REQ-A1.1 immediately before the flip and
stating the flip in its handoff. In a work or collaborative repository the
flip stays the operator's to request, and planwright's `ready_flip_policy`
is set to `human` there, since its default `unit-owner` flips task pull
requests in every repository. The kickoff spec pull request exception
(D-12) and the operator-confirmed clause stay. A nested loop's convergence
flip keeps its confirmation gate everywhere and never counts as the solo
flip: `/copilot-review --nested` is one step of the cadence, not its end.

**Alternatives considered:**
- Keep the flip operator-requested everywhere. Rejected because: in the
  repositories the operator owns alone, the request is granted every time
  the review cadence and CI have passed, so the rule only adds a manual
  un-draft hop to every solo pull request.
- Let the agent flip everywhere. Rejected because: in a work or
  collaborative repository a draft is a signal to reviewers that the
  operator controls.
- A per-repository setting of this repository's own. Rejected because:
  planwright already has the seam (`ready_flip_policy`, enforced by its
  ready-flip and policy-guard scripts), so the rule names that knob for the
  repositories where the flip is reserved instead of minting a second one;
  and ownership is already how the rewrite scope is judged.
- A permission rule asking before `gh pr ready`. Rejected because: it would
  prompt during the kickoff flip planwright performs by configuration and
  in every solo repository, and a prompt the operator always answers yes is
  the hop being removed.

**Chosen because:** The rewrite rule already encodes the ownership
judgement the flip needs, so borrowing its tests keeps the two rules
reading the same facts. The conditions do not change, only who evaluates
them, and they are re-checked at the head immediately before the flip
exactly as before.

## Cross-cutting concerns

### Decision-domains walk

Domains the bundle touches and where each is decided: secrets and
configuration (machine-local inventory, identifier file and the outbound
rule: D-6, D-8, D-13); LLM output quality and evaluation gates (D-5, D-6,
D-14); human comprehension and information UX (the every-turn load and the
repo-root ceiling: D-2, D-7); existing-seam reuse (planwright's resolution
script, its budget doctrine, the existing identifier file: D-2, D-5, D-8);
API surface (names and flags kept, model invocation scoped by caller:
D-4, D-16); organization design (who owns the ready flip, by repository
ownership: D-17, with the kickoff exception D-12); secrets and configuration
and intellectual-property posture (what a model-started review run may
upload, and the consent that gates it: D-16); observability (an unasked run
or an unstated flip: the stated flip of REQ-A1.6 and the risk register);
deploy and migration (the per-host link cutover and its rollback: D-4, and
the kickoff brief's risk register); observability (halt on an unresolved
doctrine document, visible budget warnings: D-2, D-5); dependency adoption
(none new). Authentication and data modeling do not apply.

### The cluster ledger

The verdicts, by cluster, each pointing at the REQ group that records it and
at the inventory table that carries the member rules. Member rules are
described by surface and section, never by count, so the ledger ages with the
decisions rather than with the files.

| Cluster | Verdict | Recorded in |
| --- | --- | --- |
| Main currency (global PR Lifecycle; planwright ready-guard, convergence merge, freshness gate) | Mergeable is enough; freshness gate untouched; planwright parts seeded | REQ-A, REQ-I |
| Review doctrine copies in the global file | Pointer to planwright; four buckets; act-then-review | REQ-B |
| Command boilerplate and per-run ceremony | Skills with a shared directory; Maintenance dropped; lens table once in nested loops; compact empty rows | REQ-C |
| Every-turn load of the global file | Slack mechanics and workflow descriptions out; outbound rule in | REQ-B1.4, REQ-D |
| Repo-root narrative and size | Rules stay, rationale to docs, ceiling kept | REQ-F |
| Incident-reactive rules and contradictions | Rule not story; shell reality; lifecycle vocabulary; kickoff exception | REQ-E, REQ-A1.6 |
| Stale references | Sweep applied whole | REQ-C1.7, REQ-E1.4, REQ-F1.3, REQ-F1.5 |
| The project repo | Contradicting skills fixed, stale state removed, routing guidance trimmed | REQ-H |
| planwright-owned rules | Seed note | REQ-I |
| Regrowth | Word-budget guard; re-check new instruction sources | REQ-G, REQ-K |
| Safety gates through the conversion | Safety mechanics and checker pins kept; model invocation scoped by caller (slash-only without a `--nested` mode) | REQ-C1.2, REQ-C1.10, REQ-C1.12 |
| Ready-flip ownership | The last session of the review cadence flips in a solo repository, once the cadence has run, CI is green and the head is mergeable; operator-requested in a work or collaborative repository | REQ-A1.6 |
| Name hygiene | Neutral labels; review-time check against the existing identifier file | REQ-C1.8, REQ-J1.2 |
| The work repos | Same method, run on the work host | REQ-J |
| Hooks (path-guard, worker-guard, bootstrap) | Keep as they are | no REQ; recorded here |
| Output style | Keep as it is | no REQ; recorded here |
| Machine-local memory files | Out of scope | Scope |
