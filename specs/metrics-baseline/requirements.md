# Claude Code Usage Metrics Baseline Requirements

## Purpose

- The system shall capture a structured baseline snapshot of current Claude Code
  usage metrics so that the improvements tracked in
  `project_improvement_plan` (memory) can be re-measured later against the
  same methodology and the deltas attributed to specific changes.

## Snapshot artifact

- The system shall produce a tracked encrypted file at
  `specs/metrics-baseline/snapshots/baseline-YYYY-MM.md.age` containing the
  metrics defined below. The initial snapshot is
  `baseline-2026-04.md.age`.
- The encrypted snapshot artifact shall be tracked in git, not stored only in
  memory, so that future re-runs can diff against it without depending on
  memory persistence.
- Any plaintext `baseline-YYYY-MM.md` may exist only transiently during local
  generation, review, or encryption, and shall not be committed to git.
- The snapshot shall be self-contained: it does not require access to the
  source JSONL corpus to be interpreted later.

## Required dimensions

Every volume and friction metric below shall be reportable along **all** of:

- **Per project** (tecpan, paycalc-services, dotfiles, etc.), not only as a
  global aggregate.
- **Per machine** (personal vs work), as a first-class split.
- **Main-thread vs subagent.** The 52% subagent share documented in
  `project_subagent_volume` must be preserved as a first-class split, not
  folded silently into a single number.

A metric reported only as a global aggregate is incomplete.

## Required metrics

The snapshot shall record, at minimum:

- **Corpus scope.** Date range, machines included, dominant model, and
  conversation-count metrics: per-project conversation counts, total
  conversation count, and daily conversation counts within the window (one
  number per day). These conversation-count metrics shall also be emitted
  under the required dimensions above: per project, per machine, and
  main-thread vs subagent, with subagent conversations counted as
  subagent-thread conversations for that split rather than folded into
  main-thread totals. Global aggregates may be included in addition to,
  not instead of, those breakdowns.
- **Tool-call volumes.** Total tool calls under the dimensions above.
- **Top 10 tools by volume**, separately for main-thread and subagent.
- **Per-tool error rate.** Errors / calls for each tool, normalized so a
  drop in errors cannot be confused with a drop in usage.
- **Friction tallies.** Wasted-call counts per category, including at minimum:
  Edit `old_string` mismatches (called out as its own line, not folded into a
  generic "Edit mismatches"), pre-commit / push hook failures broken down by
  hook name, file path mistakes, user rejections, GH GraphQL errors, and any
  other categories surfaced. Plus the overall wasted-call total and its
  share of all tool usage.
- **Permission prompts.** Count of permission prompts triggered, split by
  approve vs deny outcome, and split by tool. This is the measurement target
  for improvement-plan items #3 (deny rules) and #4 (permission pruning).
- **Stuck-loop sessions.** Count of sessions containing ≥3 consecutive
  same-tool calls where each errored.
- **Underused features.** Agent/subagent share, Plan mode invocation count,
  subagent invocations broken down by subagent type (Explore, Plan,
  general-purpose, custom), memory file inventory at snapshot time.
- **Slash command usage.** Counts for the top 10 slash commands (review, commit,
  etc.) **and** their success rate (did the invocation reach its terminal
  action — commit landed, PR created, threads resolved — or bail mid-flow).
- **MCP tool usage.** Counts per MCP server (Gmail, GCal, etc.), so
  integrations that fail to earn their keep are visible.
- **Hot-file re-reads.** Top 20 most-re-read files per project per session.
  This is the signal that drove the Wave B reframing of item #11; tracking
  it lets us see whether project-scoped CLAUDE.md files reduce re-reads.
- **Conversation outcomes.** For each session, did it end with a commit /
  push / PR / nothing? Plus the derived "tool calls per shipped commit"
  ratio per project.
- **Interaction style indicators.** Median user turns per conversation,
  median tool calls per conversation, interrupt rate, tool-rejection rate.

The snapshot **may** also record (cheap to include, useful as secondary
signals; do not block on these):

- Time-of-day / day-of-week distribution of tool-call volume.
- File-type breakdown of Edit / Write volume (which languages dominate).
- TodoWrite / Task tool usage frequency.
- Token / cost per session, if the JSONL exposes it.
- **Top N user opener verbs.** First-word frequency from user messages
  (e.g., "lets" 372, "yes" 214, "fix" 46). Capped at top 20 to keep
  cardinality bounded. Useful for tracking shifts in interaction style.
- **Top N bash command patterns.** Frequency of bash invocations, normalized
  to keep the leading command and notable flags. Useful for spotting
  repeated workflows that should become slash commands or hooks. **Only
  permitted while snapshots are encrypted at rest** — these strings can
  contain repo paths, hostnames, and command-line context. If encryption is
  ever disabled for snapshots, this metric must be removed from the schema
  rather than emitted in plaintext.

## Report regeneration

The snapshot shall capture enough data to regenerate both report variants
the user already produces locally:

- **Full-data report** (e.g., the existing `personal-usage-report.html`),
  which includes per-project breakdowns, top bash command patterns, top
  user opener verbs, and other content-derived signals.
- **Anonymous / shareable report** (e.g., the existing `usage-report.html`
  variant), which renders the same structural sections — overview,
  interaction style, use case breakdown, tool usage patterns, friction
  points — but redacts or omits content-derived fields (bash command
  strings, repo paths, project names) so it can be shared without leaking
  private context.

Both variants are produced by the same renderer reading the same snapshot,
differing only in which fields are included and whether identifiers are
redacted. The renderer itself is out of scope for this spec; the
requirement here is that the snapshot contain sufficient fields for both
variants to be reproducible.

## Methodology section

- The snapshot shall include a "How this was measured" section recording:
  - Which directories were walked (`~/.claude/projects/` and any remote
    history root), explicitly noting that `<session-id>/subagents/` JSONL
    files must be included.
  - The exact date window used.
  - Any known caveats or undercounts.
- The methodology shall be explicit enough that a future re-run can reproduce
  the same numbers given the same corpus.

## Encryption and storage

This repo is public. Snapshot contents include per-project conversation
counts, friction tallies, hot-file lists, and other usage data that should
not be world-readable. Schema and methodology, by contrast, are intentionally
public so the approach is reviewable.

- The snapshot **data files** shall be stored encrypted at rest in the repo
  as `specs/metrics-baseline/snapshots/baseline-YYYY-MM.md.age` using the
  `age` encryption tool.
- An unencrypted `baseline-YYYY-MM.md` file shall **not** be committed under
  any circumstances. A pre-commit guard shall reject any staged plaintext
  `baseline-*.md` file under `specs/metrics-baseline/snapshots/`.
- Authorized recipients shall be declared in
  `specs/metrics-baseline/snapshots/recipients.txt` as one or more SSH public
  keys, committed in plaintext. Anyone (any machine, any Claude session) can
  encrypt a new snapshot using these recipients; only the holder of the
  matching SSH private key can decrypt.
- The schema file (`SCHEMA.md`), the four spec files
  (`requirements.md`, `design.md`, `tasks.md`, `test-spec.md`), and any
  helper script shall remain plaintext. They document structure and
  methodology, not data.
- The encrypt and decrypt commands (using `age -R recipients.txt` to
  encrypt and `age -i ~/.ssh/<key> -d` to decrypt) shall be documented in
  the snapshots directory's `README.md`.

## Re-measurement protocol

- Re-measurement shall be performed on demand. The trigger is an explicit
  request to capture a follow-up baseline so current metrics can be compared
  against the stored baseline. Follow-up snapshots shall be stored as
  additive artifacts at `snapshots/baseline-YYYY-MM.md.age` using the same
  schema.
- Follow-up snapshots shall not overwrite earlier ones. Each is additive.
- Each follow-up snapshot shall fill in every field defined by the schema,
  even if the value is zero, so that diffs across snapshots remain
  structurally comparable.

## Out of scope

- Building a fully automated metrics pipeline. The first snapshot may be
  produced by a one-off script or by hand; only the schema and the artifact
  are required to be durable.
- Performance, latency, or context-window measurements of individual sessions.
- Any change to the existing memory entries. The `project_usage_analysis` and
  `project_subagent_volume` memories remain untouched; the snapshot is the
  durable, structured form, memory remains the prose form.
