# Claude Code Usage Metrics Baseline Design Decisions

Decisions specific to capturing a durable baseline of current Claude Code usage
metrics so that the improvements in `project_improvement_plan` (memory) can be
measured against a fixed reference point after they ship.

## Status

- **Wave:** 0 (prerequisite). This spec must produce its first snapshot before
  any improvement-plan item that is expected to move metrics is implemented.
  Items already shipped (e.g., the AGENTS.md → CLAUDE.md rename in tecpan) are
  acknowledged as pre-baseline and recorded as such in the snapshot's
  methodology section.
- **Decisions resolved:** 2026-04-08.

## Context

The improvement plan currently lives as prose in memory and was driven by an
ad-hoc analysis of ~463 conversations across two machines. The friction
numbers (~650 wasted calls/month, 52% subagent tool-call share, etc.) exist
only as memory entries. Memory is point-in-time and not structured for diffing.
Without a tracked baseline, any future "did this help?" question becomes
unanswerable except by re-running the analysis from scratch and comparing
against fuzzy recollections.

## Mechanism: tracked snapshot files, not memory

Snapshots are committed under `specs/metrics-baseline/snapshots/` as encrypted
`baseline-YYYY-MM.md.age` files. Only the encrypted `.age` artifact is tracked
in git so snapshots survive memory pruning without committing plaintext.
Plaintext markdown may exist only as local working material and must never be
committed. Memory entries remain the prose / narrative form; the encrypted
snapshot is the structured, comparable form.

Snapshots are append-only: each re-measurement adds a new file rather than
overwriting an earlier one. This preserves the trajectory.

## Schema, not just numbers

The first snapshot defines a schema by example. Every subsequent snapshot must
fill in the same fields with the same definitions, even if a number is zero,
so that diffs are meaningful. The schema covers: corpus scope, tool-call
volumes (main vs subagent split), top tools, friction tallies by category,
underused features, slash command usage, interaction style indicators.

## Dimensions are first-class, not aggregates

Every volume and friction metric is reported along three dimensions:
per-project, per-machine (personal vs work), and main-thread vs subagent.
A global aggregate is not enough. If tecpan's friction drops by 200 wasted
calls and paycalc's stays flat, we need to *see* that — otherwise the
improvement plan can't attribute deltas to specific changes, and we're back
to recollection-based "did this help?"

This applies to every required metric in `requirements.md`, including
ones where the breakdown looks redundant at snapshot time. Comparability
across future snapshots requires that the dimensions be filled in
consistently from the start.

## Metric coverage rationale

The required metrics map directly onto the improvement-plan items they need
to evaluate:

- **Per-tool error rate** normalizes friction against volume so a drop in
  errors cannot be confused with a drop in usage.
- **Permission prompts (approve/deny, per tool)** is the measurement target
  for items #3 (deny rules) and #4 (permission pruning). Without this,
  those items have no observable effect.
- **Hook failure breakdown by hook name** is the target for item #2
  (PostToolUse auto-format hook). A generic "pre-commit failures" tally
  cannot show which specific hook stopped firing.
- **Edit `old_string` mismatch rate** is the single largest friction
  category in the existing memory analysis and deserves its own line.
- **Slash command success rate** (not just count) is the target for item
  #6 (fix `/copilot-review` GraphQL errors). Counting invocations alone
  cannot show whether they completed.
- **Hot-file re-reads** is the signal that drove the Wave B reframing of
  item #11 (claude-context). It is the most direct measure of "did
  repo-scoped CLAUDE.md context reduce redundant exploration."
- **Conversation outcomes and tool-calls-per-shipped-commit** is the
  closest objective proxy for end-to-end efficiency available from JSONL
  alone.
- **Stuck-loop sessions** captures the friction signal that hurts most
  subjectively but is invisible in raw wasted-call totals.
- **Subagent type breakdown** lets us evaluate Plan mode underuse and the
  superpowers / Explore subagent shifts independently of total subagent
  volume.
- **MCP tool usage** lets integrations that fail to earn their keep
  surface naturally, without having to instrument them individually.

Marginal-but-cheap metrics (time-of-day, file-type breakdown, TodoWrite
usage, token/cost) are listed as optional because they add insight at near-
zero cost but should not block the snapshot if they prove fiddly to compute.

## Explicitly *not* measured

- **Latency.** Out of scope per requirements; noisy and machine-dependent.
- **Context-window or compaction events.** Too noisy at this size; would
  generate signal where there is none.
- **Subjective success rate.** Not objectively recoverable from JSONL.
  Conversation-outcome heuristics (commit / push / PR / nothing) are the
  closest honest proxy and are required instead.

## Encryption: age with SSH-key recipients

The repo is public. Snapshot data (per-project conversation counts,
friction tallies, hot-file lists, MCP usage) should not be world-readable.
Schema and methodology, by contrast, are intentionally public so the
approach is reviewable.

The chosen mechanism is **age** with SSH public keys as recipients, with
exactly these properties:

- **Asymmetric, public-recipient.** The recipient public key is committed
  in plaintext as `recipients.txt`. Anyone — you on either machine, Claude
  in any session, even a fresh clone — can encrypt a new snapshot. Only
  the holder of the matching SSH private key can decrypt. Writes are
  unprivileged, reads are privileged. This is exactly the asymmetry the
  workflow needs.
- **No new key material.** age accepts SSH keys directly:
  `age -R recipients.txt baseline-YYYY-MM.md > baseline-YYYY-MM.md.age`
  to encrypt, `age -i ~/.ssh/<key> -d baseline-YYYY-MM.md.age` to
  decrypt. Both machines already have the SSH key; no new secret to
  manage or sync.
- **File-level, not repo-level.** Only the snapshot data files are
  encrypted (`baseline-*.md.age`). The schema, the four spec files, the
  recipients file, and any helper script remain plaintext and reviewable
  in the public repo. The split between "structure is public, data is
  private" is the whole point.
- **Opaque on GitHub.** The `.age` blob renders as binary in the web UI;
  no accidental leakage via search indexers or web previews.

Alternatives considered and rejected:

- **git-crypt.** Symmetric key, requires `git-crypt unlock` per clone, and
  loses the asymmetric "anyone can write, only you can read" property.
  Also awkward to share the unlock key safely between two machines.
- **sops.** Designed for structured configs (YAML/JSON); overkill for
  markdown and adds a wrapper around the prose.
- **Plain GPG.** Already in use for commit signing, but age is simpler,
  has fewer footguns, and the SSH-key path means zero new key material.
  GPG would also require deciding on key servers, expiration, etc.

A pre-commit guard rejects any staged unencrypted `baseline-*.md` file
under `snapshots/`. This prevents the obvious foot-gun (forgetting to
encrypt and committing the plaintext file) at the only point where it
matters.

## Subagent split is first-class

`project_subagent_volume` documents that the first analysis pass undercounted
tool calls by 52% because it ignored `<session-id>/subagents/` JSONL files.
The schema treats main-thread vs subagent as a required split for every
volume metric. Folding them silently is a regression and is not allowed.

## Methodology recorded inline

Each snapshot embeds its own methodology section: which roots were walked,
which subdirectories were included, the exact date window, any known caveats.
This is what makes a future re-run reproducible without having to reconstruct
how the previous run worked.

## Pre-baseline acknowledgements

Improvements that have already shipped before the baseline is taken
(AGENTS.md → CLAUDE.md rename in tecpan, terraform bump, etc.) are listed in
the snapshot's methodology section as "pre-baseline state." Their effects, if
any, are baked into the baseline numbers and cannot be measured retroactively.
This is a known limitation, not a flaw to fix.

## Automation: deferred

The first snapshot may be produced by a one-off script or even by hand.
Building a reusable metrics tool is explicitly out of scope for this spec.
What matters is that the schema and the artifact exist; tooling can come
later if re-measurement frequency justifies it.

## Snapshot is data; reports are regeneratable views

The snapshot is the durable, structured *data*. HTML reports (the
existing `personal-usage-report.html` and `usage-report.html` on the
user's Desktop) are *views* over that data, produced by a renderer
script that reads either the decrypted snapshot or the live JSONL
corpus. They are not committed to the repo and not part of this spec's
deliverables.

The schema is intentionally designed so that **two report variants** can
be regenerated from the same snapshot:

- A **full-data variant** with content-derived fields (top bash command
  patterns, top user opener verbs, repo paths, project names) for
  private use.
- An **anonymous / shareable variant** that omits or redacts the same
  fields and renders only the structural sections, suitable for sharing
  without leaking private context.

The fields needed for the full variant — top bash patterns, top opener
verbs, daily conversation counts, per-project and per-machine breakdowns
— are listed in `requirements.md`. The anonymous variant is a strict
subset rendered by the same renderer; no separate schema is required.

Top bash command patterns are content-derived and can leak repo paths
and command-line context. They are only acceptable in the snapshot
because the snapshot is encrypted at rest. If encryption is ever
disabled, the bash-pattern field must be removed from the schema rather
than emitted in plaintext. This constraint is recorded in
`requirements.md` and is non-negotiable.

The renderer itself is deferred (see "Automation: deferred"). What this
spec locks in is that the snapshot contains the data both report
variants need.

## Relationship to claude-context spec

This spec is a sibling, not a parent or child, of `specs/claude-context/`.
The claude-context work (repo-root `CLAUDE.md`) is one of the improvements
that the baseline will eventually be used to evaluate. Producing the baseline
first is a prerequisite for being able to attribute any future delta to that
or any other improvement.

## Decision log

- **Tracked file under `specs/metrics-baseline/snapshots/`, not a memory
  entry.** Memory is unstructured and point-in-time; baselines need to be
  diffable and survive memory pruning.
- **Append-only snapshots, one per re-measurement.** Preserves trajectory and
  prevents accidental loss of historical data.
- **Schema defined by the first snapshot, fixed thereafter.** Comparability
  requires that every future snapshot fill in the same fields with the same
  definitions.
- **Main-thread vs subagent split is mandatory for every volume metric.**
  Documented undercount risk from `project_subagent_volume` makes this
  non-negotiable.
- **Per-project and per-machine dimensions are also mandatory.** Aggregates
  alone make deltas un-attributable to specific improvements or specific
  repos.
- **Required metrics map onto improvement-plan items.** Per-tool error rate,
  permission prompts (approve/deny per tool), hook failures by hook name,
  Edit `old_string` mismatch rate, slash command success rate, hot-file
  re-reads, conversation outcomes, stuck-loop sessions, and subagent type
  breakdown each exist to make a specific plan item measurable. Marginal
  signals (time-of-day, file-type, TodoWrite, token/cost) are optional.
- **Latency, context-window/compaction events, and subjective success rate
  are explicitly not measured.** Out of scope, too noisy, or not recoverable
  from JSONL.
- **Encryption: age with SSH-key recipients, file-level.** Only snapshot
  data files are encrypted (`baseline-*.md.age`); schema and the four spec
  files stay plaintext. The recipient public key is committed in
  `recipients.txt`. Anyone can encrypt a new snapshot; only the SSH
  private-key holder can decrypt. No new key material to manage.
- **Pre-commit guard rejects staged plaintext `baseline-*.md` files** under
  `snapshots/`. Cheap, blocks the only realistic foot-gun.
- **git-crypt, sops, and plain GPG considered and rejected.** git-crypt is
  symmetric and loses the asymmetric write-vs-read property; sops is
  overkill for markdown; plain GPG works but is more ceremony than age and
  brings no advantage here.
- **Methodology recorded inline in each snapshot.** Reproducibility without
  external context.
- **Pre-baseline shipped improvements are acknowledged, not retro-measured.**
  Honest limitation; do not pretend otherwise.
- **Snapshot is data; HTML reports are regeneratable views.** Two report
  variants (full-data and anonymous) are reproducible from the same
  snapshot by the same deferred renderer; no separate schema is needed.
- **Top bash command patterns and top opener verbs are optional, encrypted-only
  metrics.** Worth capturing for full-data report regeneration; bash patterns
  must be removed from the schema rather than emitted in plaintext if
  encryption is ever disabled.
- **Daily conversation counts are required in corpus scope.** Cheap and
  necessary for reproducing the "conversations per day" sparkline both
  report variants render.
- **No automation in this spec.** Schema and first artifact are the deliverable;
  tooling is deferred until re-measurement frequency justifies the cost.
