# Pair-Flow — Design

**Status:** Draft
**Last reviewed:** 2026-05-22

## Architecture: five layers

```
+-------------------------+   L5  Cross-session awareness
|  Inbox + dashboard      |       inbox files, tmux popup, macOS notifications
+-----------+-------------+
            |
+-----------+-------------+   L4  Orchestration
|  /orchestrate           |       stateless step machine, reads tasks.md
+-----------+-------------+
            |
+-----------+-------------+   L3  Autonomous resolution
|  Agent-resolvable       |       /polish, /panel-pairing recognize new bucket
+-----------+-------------+
            |
+-----------+-------------+   L2  Task execution
|  /execute-task          |       TDD, mix ci, /polish, draft PR
+-----------+-------------+
            |
+-----------+-------------+   L1  Spec lifecycle
|  /spec-draft, /spec-    |       drafts and signs off the contract
|  kickoff, /resume       |
+-------------------------+
```

Each layer is independently shippable. L5 and L1 ship first because they unlock the rest with the smallest blast radius.

## Decision log

### D-1: `tasks.md` is canonical state; no parallel `state.json`

**Decision:** The spec's `tasks.md` doubles as the orchestration state record. Sections: `Completed`, `In progress` (with phase + last-activity), `Awaiting input`, `Deferred`, `Out of scope`. Skills that change state update `tasks.md` as a side effect.

**Alternatives considered:**
- Separate `~/.claude/orchestrator/{repo}/state.json` substrate. Rejected because it creates a second source of truth that can drift from the spec, and the user's existing workflow (asking a fresh session "what's left based on the specs and progress so far") already proves the spec is sufficient.

**Chosen because:** Single source of truth. Version controlled. Already battle-tested as a resumption substrate by the user's manual workflow. Degrades gracefully (stale "in progress" entries are recoverable from PR state and git log).

**Reversed by:** —

### D-2: Two-brief model — kickoff is contract, handover is optional cache

**Decision:** The kickoff brief (`specs/{feature}/kickoff-brief.md`) is the durable contract between human and agent at spec time. The handover brief (`{worktree}/.claude/handover.md`) is an optional cache of non-obvious in-flight context that does not fit in `tasks.md`. `/resume` reads kickoff + `tasks.md` + git + PR; layers handover if present.

**Alternatives considered:**
- Handover-brief-first design where every session exit auto-writes a brief and the next session refuses to start without one. Rejected because it makes the system brittle (missing or stale brief becomes a hard failure) and adds friction the spec system already absorbs.
- No handover at all. Rejected because some context genuinely doesn't fit in `tasks.md` ("I considered approach P and rejected because Q"), and a freeform brief is the lightest way to capture it.

**Chosen because:** Robust under partial failure. Spec is always correct; handover is best-effort. Matches the user's existing mental model.

### D-3: `Agent-resolvable` bucket predicate

**Decision:** Findings qualify for the new `Agent-resolvable` bucket if and only if all five hold: (a) failing test exists that fails for the finding's reason on current code, (b) test passes after the fix, (c) full project CI passes after the fix, (d) the fix is aligned with the active kickoff brief, (e) the fix is not in a hard-disqualifier zone (security primitives, migrations, public API contracts, secrets, CI configuration).

**Alternatives considered:**
- Loosen `Auto-applicable` predicate instead of adding a fourth bucket. Rejected because the existing predicate is well-designed for "mechanical, no behavior change" and changing it would muddy that contract.
- Per-finding judgment instead of a fixed predicate. Rejected because per-finding judgment is what produces the 85% Needs human judgment rate observed in transcripts.

**Chosen because:** Captures the user's stated risk tolerance ("agents should resolve issues the way a human would, with regression tests and validation") without weakening any existing bucket.

**Open calibration:** The predicate is initial; the line between `Agent-resolvable` and `Needs sign-off` will be calibrated by accepting/rejecting agent-resolved changes over a few weeks. See Task 13 (end-to-end validation).

### D-4: Solo vs multi-reviewer behavior split

**Decision:** In solo repos (tecpan, dotfiles), `Agent-resolvable` auto-applies. In multi-reviewer repos (paycalc), `Agent-resolvable` surfaces for human review with evidence (failing-then-passing test, CI output, kickoff alignment) attached. Determination is per-repo via a config marker (see D-15).

**Alternatives considered:**
- Always require human approval. Rejected; the user explicitly wants autonomy in solo repos.
- Always auto-apply. Rejected; multi-reviewer repos have peer review for reasons that outlast our process.

**Chosen because:** Matches the existing review topology of the user's repos. The Discovery Rigor + Validation Rigor work already done is the warrant for autonomy in solo repos.

### D-5: Stateless orchestrator step machine

**Decision:** `/orchestrate` does not maintain process-internal state. Each invocation reads `tasks.md`, computes the next legal move, performs it, updates `tasks.md`, exits. Multiple invocations across sessions / hosts / scheduled runs accumulate naturally.

**Alternatives considered:**
- Long-running orchestrator process. Rejected because Claude Code is interactive and tied to a session; process longevity is not a primitive we have.
- LangGraph / Crew-AI for stateful orchestration. Rejected; pulling in a second agent framework duplicates concerns and increases debugging surface.

**Chosen because:** Survives session boundaries by construction. No state to corrupt. Compatible with scheduled remote agent runners.

### D-6: Codex-only default for `/panel-*` (provisional)

**Decision:** Codex is the default backend on all profiles for `/panel-review` and `/panel-pairing`, contingent on the panel-* underuse investigation (Task 1).

**Alternatives considered:**
- Codex + one Ollama model for variance. Rejected per user direction; simplification preferred for v1.
- Keep current `codex,qwen-coder` (work) / `qwen-coder,gpt-oss` (personal) split. Rejected per user direction.

**Chosen because:** User instruction. Variance comes back as an opt-in via the existing `--backends` flag if needed.

**Provisional:** May be reversed if the Task 1 investigation reveals codex is unreliable or low-yield.

### D-7: `/spec-kickoff` is a didactic walkthrough, not a checklist

**Decision:** `/spec-kickoff` walks the spec section by section, restating in the agent's own words, surfacing implicit domain term definitions, and posing Socratic checks (slicing sanity, edge cases, decision rationale) at each step. The output is rich enough that any downstream agent operates from the brief without re-reading the spec.

**Alternatives considered:**
- Structured questionnaire. Rejected because it forces user reflection without surfacing agent misreads.
- Pure restatement (no questions). Rejected because it doesn't verify that the user shares the understanding.

**Chosen because:** The user explicitly framed this as "thorough, methodical, didactic" and the value is in the questions surfacing things neither party realized needed to be said.

**Quality gate:** First implementation will be evaluated on whether elicitation surfaces things the user did not already know. If not, the design is wrong and the questions need sharpening.

### D-8: Gherkin optional within `test-spec.md`, not mandatory

**Decision:** Gherkin (`Given / When / Then`) scenarios are permitted as a format within `test-spec.md` when behaviors benefit from explicit state/trigger/outcome separation. Not introduced as a separate runner. Not required for any REQ.

**Alternatives considered:**
- Mandate Gherkin across all test-spec entries. Rejected; design decisions and reference material don't fit Gherkin shape.
- Reject Gherkin entirely. Rejected; the format genuinely helps for edge-case enumeration and stakeholder communication.
- Adopt an Elixir Gherkin runner (cabbage, white-bread). Rejected; adds tooling for marginal value when ExUnit already runs tests.

**Chosen because:** Additive, low cost, only used where useful.

### D-9: Skill hooks update `tasks.md` as side effects

**Decision:** `/execute-task` updates `tasks.md` when implementation starts, when a PR opens, and when execution halts. `/orchestrate` updates `tasks.md` when picking a task. A PostToolUse or webhook-triggered hook updates `tasks.md` when a PR merges. The discipline is not the human's job.

**Alternatives considered:**
- Manual maintenance. Rejected; would silently drift, undermining `tasks.md` as state.
- A daemon that syncs `tasks.md` from GitHub. Rejected; needs a long-running process we don't have.

**Chosen because:** Pushes the discipline into the skills, which already touch git/PR.

### D-10: Inbox substrate via shared filesystem

**Decision:** Inbox lives at `~/.claude/inbox/` synced across hosts via iCloud Drive or Syncthing. Each file is one session's current state. Writers: every skill that changes state. Readers: tmux popup and status segment.

**Alternatives considered:**
- HTTP server hosting state. Rejected; needs a host, auth, deployment.
- Git-backed (commit state to a config repo). Rejected; commit cadence too coarse for live state.
- Push channel (Pushover, ntfy). Deferred to a later layer; the file substrate is what push would read.

**Chosen because:** Zero infrastructure. Sync mechanism already in place on the user's machines.

### D-11: Bundling rule for multi-task PRs

**Decision:** `/orchestrate` may bundle consecutive ready tasks into a single PR when all hold: (a) tasks touch the same module or context, (b) tasks share dependencies, (c) combined diff is likely to stay under ~700 lines (estimated from spec citations + git history of similar tasks).

**Alternatives considered:**
- Always one task per PR. Rejected; tecpan history shows the user already bundles when tasks are tightly related.
- Bundle aggressively up to some line ceiling. Rejected; module/dependency cohesion is more important than line count.

**Chosen because:** Matches observed user behavior. The 700-line ceiling is calibrated from tecpan's PR size distribution (300–900 typical).

### D-12: `/panel-pairing` demoted to escalation; `/polish` is the default convergence loop

**Decision:** `/polish` runs as the inner convergence loop of `/execute-task`. `/panel-pairing` runs only as an escalation when extra rigor is warranted (security-adjacent, large diff, novel area) or when explicitly invoked by the user.

**Alternatives considered:**
- Run `/panel-pairing` on every task. Rejected; external backends are slow, and the panel-* underuse evidence suggests cost > yield by default.
- Retire `/panel-pairing` entirely. Deferred until Task 1 investigation lands.

**Chosen because:** Keeps the variance benefit available when needed without paying for it on every task.

### D-13: `/polish` opens a draft PR on convergence (standalone mode)

**Decision:** When `/polish` is invoked standalone (not nested in `/execute-task`), it opens a draft PR after converging. When nested, the parent owns PR creation.

**Alternatives considered:**
- Standalone `/polish` stays local-only. Rejected; the user often wants a draft PR after polishing manual changes, and the missing step is friction.
- Always open PR even when nested. Rejected; would create double PRs.

**Chosen because:** Removes a manual handoff step in the common standalone case without breaking the nested case.

### D-14: Scheduled remote agent runner for non-implementation orchestration moves

**Decision:** A scheduled remote agent (via the existing `/schedule` skill) runs periodically (e.g., hourly) and performs orchestration moves that do not require an interactive session: check PR merge status, mark Completed, pick the next ready task and post inbox entry, reconcile stale `In progress` entries. It does not implement code.

**Alternatives considered:**
- macOS launchd / cron locally. Rejected; doesn't reach across hosts and duplicates the existing scheduled-agent primitive.
- No background runner; everything happens interactively. Rejected; user wants "while you're asleep, advance the bookkeeping."

**Chosen because:** Uses an existing primitive. Cross-host by construction.

### D-15: Spec format requirements for orchestration

**Decision:** For a spec to be orchestratable, each task in `tasks.md` shall have: a stable ID, a `Done when:` condition unambiguous enough for an agent to evaluate, explicit `Dependencies:`, and `Citations:`. Repo-level metadata (e.g., `repo-class`) is handled separately per D-19, not embedded in the spec bundle.

**Alternatives considered:**
- Looser format with agent inference. Rejected; the org/ retrospective shows agent inference fails on prose-only specs.
- Embedding repo-level metadata per spec. Initially considered (`Repo-class:` line in `tasks.md` or a top-level `specs/spec-config.yml`). Reversed by D-19: the metadata is per-repo, not per-spec, and putting it in shared repos leaks personal workflow choices.

**Chosen because:** The existing tecpan format is 95% of the way there. The gap is enforcement.

**Reversed (partial) by:** D-19 — the repo-level metadata portion of this decision moved to a user-home config.

### D-16: Headless invocation (`claude -p`) is v2

**Decision:** v1 ships without headless `claude -p` resumption. Sessions are launched interactively by the user (typing `/resume` in a tmux pane) or by scheduled remote agents (which don't need TTY for bookkeeping moves). Headless invocation for implementation work is deferred until v1 proves stable.

**Alternatives considered:**
- Headless from day one. Rejected; risk of failure modes that are hard to debug when there's no human watching.
- Never headless. Rejected; deferring is appropriate, but the option should remain on the table.

**Chosen because:** Smaller v1 risk surface. Easier to reason about failures when a human is in the loop initially.

### D-17: Orchestrator concurrency via advisory lockfile

**Decision:** `/orchestrate` acquires an advisory lockfile (`{repo}/.claude/orchestrate.lock` or similar) before performing state-changing moves. Lock acquisition failure is a clean no-op (exit with reason logged to inbox), not an error.

**Alternatives considered:**
- No locking. Rejected; multi-host runners could collide.
- Heavyweight locking (e.g., Redis). Rejected; we don't have shared infrastructure beyond a synced filesystem.

**Chosen because:** Cheap, robust to crashes (stale locks can be detected and broken), no new infrastructure.

**Open:** Stale lock detection threshold (e.g., locks older than 1 hour are considered stale) needs calibration after first use.

### D-18: Build only on Claude Code primitives

**Decision:** The entire system is built using Claude Code's existing primitives (skills, hooks, slash commands, scheduled remote agents, file-based state). No second agent framework is introduced. Inspiration may be drawn from Aider, Cline, Plandex, GitHub Spec Kit, BMad Method, but their code or runtimes are not imported.

**Alternatives considered:**
- LangGraph for orchestration. Rejected per the analysis.
- GitHub Spec Kit as a dependency. Rejected; templates can be cherry-picked but a hard dependency adds upgrade risk.

**Chosen because:** Minimizes maintenance surface. Survives Claude Code upgrades. Easy to debug because everything is files and well-known skills.

### D-19: Configuration model — two-file split with agent-maintained local file

**Decision:** Pair-flow configuration lives in two files at the user's home:

- `~/.claude/pair-flow.yml` (tracked in dotfiles, materialized as symlink): schema and defaults. Fields: `panel-backends`, `stale-lock-threshold`, `inbox-heartbeat-interval`, etc.
- `~/.claude/pair-flow.local.yml` (gitignored, agent-maintained, host-local): the `repos:` block keyed by `owner/repo` with per-repo overrides (`repo-class`, `last-confirmed`).

Repo-objective values (`ci-command`, `default-branch`, language) are derived by project inspection (`mix.exs` aliases, `package.json` scripts, `mise.toml` tasks, lefthook hooks, `gh repo view`), not declared in either config file. The SessionStart tool-discovery hook already performs most of this derivation.

Per-spec overrides remain available via a `Config overrides:` frontmatter section in a spec's `requirements.md` for the rare experimental case.

**Alternatives considered:**
- Single config file `specs/spec-config.yml` inside each shared repo. Rejected: leaks personal workflow into shared repos; `repo-class: solo` is meaningless from a collaborator's perspective.
- Per-spec line in `tasks.md`. Rejected: doesn't match the data model (none of the values vary per spec) and creates drift risk across specs in the same repo.
- Single file under `~/.claude/`, tracked in dotfiles, including the `repos:` block. Rejected: dotfiles is published; the `repos:` block would expose which repos the user treats as solo vs multi-reviewer.

**Chosen because:** Clean separation between universal facts (derived from repo) and personal workflow (in user's home). Matches the existing three-layer permissions model in dotfiles. Discovery flow per D-20 makes the local file effectively zero-config.

### D-20: Configuration discovery flow

**Decision:** When a pair-flow skill encounters a repo with no entry in `~/.claude/pair-flow.local.yml`:

1. Identify the repo via `gh repo view --json nameWithOwner`, falling back to parsing `git remote get-url origin`.
2. Infer a default `repo-class` from PR review history (any non-author human reviewer in the last 30 PRs → `multi-reviewer`; otherwise → `solo`).
3. **Always surface the inferred value for confirmation.** Discovery never silently writes — the cost of guessing `solo` on a `multi-reviewer` repo is auto-applying changes that should have gone through review.
4. On user confirmation, append the entry (with `last-confirmed: <today>`) to `~/.claude/pair-flow.local.yml`. Create the file if it does not exist.
5. On subsequent invocations, the entry is present and no prompt fires.

If the file is deleted or corrupted, discovery re-runs from scratch on the next invocation. One prompt per repo encountered; no permanent loss.

**Alternatives considered:**
- Silent inference. Rejected: any miscalibration auto-applies changes in a multi-reviewer repo.
- Require manual setup before any pair-flow skill runs. Rejected: creates a bootstrap step the user must remember on every new machine.

**Chosen because:** Zero-config bootstrap, safe-by-default. Graceful degradation on file loss.

### D-21: PRs are always drafts; no auto-merge, ever

**Decision:** Every PR created by any pair-flow skill (`/polish`, `/execute-task`, `/orchestrate`) shall be a draft PR. The system shall not include auto-merge functionality at any tier (v1, v2, future). Merge is one of the few human actions reserved by the user.

**Alternatives considered:**
- Defer auto-merge as a future feature. Rejected: the user has explicitly stated this is a permanent constraint, not a future capability. Listing it as deferred implies eventual inclusion, which is incorrect.

**Chosen because:** Hard guarantee preserves human control at the merge boundary.

### D-22: Dashboard visual language

**Decision:** The tmux dashboard popup renders inbox entries with the following visual language and sort order:

| State | Color | Meaning |
|---|---|---|
| awaiting-input | red | needs human now |
| stale lock | red, strikethrough | suspected crash, needs cleanup |
| working, very long (>2 hr) | orange | check whether stuck |
| draft-pr-ready | blue | clean handoff for review |
| working, long (>30 min) | yellow | still going, worth a glance |
| working, fresh | green | active, recent activity |
| idle / exited | grey | nothing happening |

Sort order: red → orange → blue → yellow → green → grey. Duration is computed from the entry's `last-heartbeat` and first-seen timestamp.

**Alternatives considered:**
- Flat list with no color. Rejected: the user explicitly asked for long-running task hints.
- Notification-only (no dashboard color). Rejected: notifications miss the long-running case, which is gradual rather than transitional.

**Chosen because:** Glanceable at-a-glance signal. The user can see "one red, two yellows" in a second.

### D-23: Inbox heartbeat mechanism

**Decision:** Each active session writes its inbox entry with a `last-heartbeat` ISO timestamp, refreshed every 30 seconds via a background helper. Entries are considered:

- **Live:** heartbeat within last 60 seconds.
- **Stale:** heartbeat older than 2 minutes — auto-removed by readers (dashboard, status segment) before display.
- **Legacy (no heartbeat field):** aged out at 24 hours as a fallback for entries written by older skill versions.

On clean session exit, the session removes its own entry.

**Alternatives considered:**
- File mtime as the heartbeat. Rejected: mtimes are unreliable across sync mechanisms (iCloud, Syncthing); explicit timestamps in JSON are durable.
- Longer heartbeat interval (5 minutes). Rejected: a crashed session would appear live for too long.
- A daemon managing all heartbeats. Rejected: introduces a long-running process where none is needed.

**Chosen because:** Catches crashes within ~2 minutes (matching the user's instinct that "inactive sessions" should clear quickly), at low cost (30s tick, write a small JSON file).

### D-24: Bundle sizing via Citations + git history (provisional)

**Decision:** `/orchestrate` estimates a candidate bundle's combined diff size by: (1) counting files in each candidate task's `Citations:`; (2) looking up similar past PRs in the same repo via `gh pr list --search` keyed on cited files and module; (3) summing the median PR size of matched past PRs. Bundle is approved if the estimate is ≤ 700 lines and the other D-11 conditions (same module, shared deps) hold.

Estimate-vs-actual is logged for telemetry per D-30 so the heuristic can be tuned.

**Alternatives considered:**
- Conservative (one task per PR; manual bundling only). Rejected: tecpan PR history shows bundling happens organically when tasks are related; the orchestrator should support it natively.
- Author-hint S/M/L during `/spec-draft`. Reserved as a fallback if the citations heuristic proves inaccurate during Task 13's validation.

**Chosen because:** Citations + git history gives a grounded estimate without asking the user to think about line counts during drafting.

**Provisional:** Heuristic accuracy will be measured during Task 13. If consistently off by more than 2x, switch to author-hint mode.

### D-25: `/execute-task` CI retry policy is adaptive

**Decision:** When the project CI run fails, `/execute-task` classifies the failure and acts accordingly:

- **Transient** (network errors, timeouts, known-flaky test patterns, infrastructure errors): retry up to 2 times with exponential backoff.
- **Logic** (assertion failures, type errors, compilation errors, anything reproducible): escalate immediately to `Awaiting input` without retry.

Classification is based on the CI output. Unknown patterns default to "logic" — safer to escalate than to burn retries on a real problem.

**Alternatives considered:**
- Fixed N retries regardless of cause. Rejected: burns time on logic errors that will never pass.
- One try, then escalate immediately. Rejected: too aggressive on transient failures, especially when CI infrastructure is flaky.

**Chosen because:** Matches how a human developer triages CI failures.

### D-26: File-path PreToolUse hook scope

**Decision:** The PreToolUse hook validates file paths for `Read`, `Edit`, and `Write` tool calls. `Bash` invocations with file arguments are out of scope (paths are too hard to parse statically from arbitrary shell). `NotebookEdit` is out of scope for v1 (low usage in transcripts).

**Alternatives considered:**
- All file-touching tools including Bash. Rejected: high false-positive risk on shell path parsing.
- Read + Edit only. Rejected: Write also surfaces path mistakes (typos in new file paths).

**Chosen because:** Targets the three highest-yield tools per the April–May friction data without false positives from Bash heuristics.

### D-27: Kickoff brief invalidation is section-scoped

**Decision:** When a spec file changes after the brief is signed off, only the brief sections tied to the changed content require re-signoff:

- Change to `requirements.md` REQ-X → brief sections referencing REQ-X invalidate.
- Change to `design.md` D-Y → brief sections referencing D-Y invalidate.
- Change to `tasks.md` (reorder, retitle, add, remove) → only the Task graph section invalidates.
- Change to `test-spec.md` → only the Verification section invalidates.

Whole-brief invalidation occurs only on a wholesale spec rewrite (multiple files changed simultaneously beyond a threshold).

**Alternatives considered:**
- Whole-brief invalidation on any change. Rejected: forces re-walkthrough every time `tasks.md` is reorganized, which happens often during execution.
- No invalidation tracking. Rejected: defeats the purpose of the brief as a contract.

**Chosen because:** Less disruptive while preserving contract integrity.

### D-28: Validator reuse via port + symlink

**Decision:** The spec validator that lives near `tecpan/specs/validator-runs.md` is ported into this dotfiles repo at `roles/osx/files/claude/scripts/spec-validate.sh`. Both repos symlink to the canonical location. Future extensions land here; tecpan inherits via symlink.

**Alternatives considered:**
- Write a new validator for pair-flow specs. Rejected: duplicate logic.
- Keep tecpan's validator in tecpan and copy-paste here. Rejected: drift risk.

**Chosen because:** Single source of truth, propagated by the existing Ansible symlink mechanism.

### D-29: PR-merge detection via scheduled runner (no webhook)

**Decision:** Detection of "this PR was merged, mark the task Completed" happens via the scheduled remote agent runner (Task 12) polling GitHub PR state on its cadence (hourly default). No GitHub webhook is configured.

**Alternatives considered:**
- GitHub webhook firing a local hook. Rejected: requires GitHub config, an internet-reachable endpoint (or a polling service), and a secret.
- Manual `/sync-tasks` invocation. Rejected: relies on the user remembering after every merge.

**Chosen because:** The scheduled runner exists anyway for other bookkeeping; PR-merge reconciliation is a near-free additional move. Hourly latency is acceptable for state propagation.

### D-30: Telemetry hybrid layout

**Decision:** Telemetry lives under `specs/metrics-baseline/` in three subdirectories:

- `snapshots/baseline-{YYYY-MM}.md.age` — periodic markdown summaries (monthly cadence). Continues existing pattern.
- `deltas/pair-flow-v1-{milestone}.md.age` — initiative-specific markdown deltas tied to milestones (pre-rollout, post-Task 13, 30-day-post).
- `data/{YYYY-MM}.jsonl.age` — raw structured measurements supporting both summaries.

All three are age-encrypted with the existing key (consistent with the current `baseline-2026-04.md.age` precedent).

Each pair-flow task that introduces measurable behavior shall include a "Measurement plan" line in its `Done when:` enumerating the metric, source, and baseline comparison.

**Alternatives considered:**
- Markdown only (snapshots + deltas, no structured data). Rejected: future analyses cannot re-derive from a one-way summary.
- Snapshots only (no deltas). Rejected: loses initiative attribution.
- New top-level `metrics/` directory. Rejected: yet another top-level concept with no clear win over extending `metrics-baseline/`.
- `~/.claude/telemetry/`. Rejected: not version controlled, lost on machine reset.

**Chosen because:** Builds on existing pattern. Initiative-specific attribution plus raw data enables reproducibility.

## Cross-cutting concerns

### Permissions and security

- New skills, hooks, and tools may require updates to `roles/osx/files/claude/settings.json` permissions. Each task that introduces a new tool call shall list the permission change in its `Done when:`.
- Hooks that execute arbitrary content (e.g., `claude -p` invocation, executing `worktree-bootstrap` scripts) inherit the existing trust model: the user is responsible for trusting the repo before opening it.

### Per-host config differences

- `work`, `personal`, `alt` profiles already exist in the Ansible role. The autonomy system shall use `inventory_hostname` checks where behavior differs (e.g., Ollama daemon binding, MCP secret loading).
- The inbox substrate is host-neutral; sync is the user's responsibility (iCloud Drive on default, Syncthing if preferred).

### Migration and rollback

- Existing tecpan specs do not have kickoff briefs. The user shall opt in per spec via `/spec-kickoff <spec-path>` in retrofit mode.
- Each task that introduces a new skill or hook shall be reversible by removing the file and re-running Ansible. No destructive migrations.

### Telemetry

- The next round's effectiveness shall be measured by re-running the April-style usage analysis on a 30-day window post-implementation. Baseline: 86 tecpan sessions, 65% review-driven, 38 AskUserQuestion calls, 82 file-path mistakes, 0% Auto-applicable fill rate. Target deltas TBD per task.

## What we explicitly deferred or set aside

- **Phone push notifications** (REQ-F4.1). Deferred. Inbox substrate is designed not to preclude it.
- **Headless `claude -p` for implementation resumption** (D-16). v2.
- **Auto-respond to peer review feedback** (`/orchestrate` v2). After v1 trusted.
- **Multi-spec concurrent orchestration**. After single-spec works.
- **Handover-brief auto-write conditions** (D-2). Deferred unless v1 surfaces specific gaps.
- **Migration of work projects** (paycalc). Out of scope for v1; design accommodates multi-reviewer but tecpan/dotfiles are the proving ground.
- **Retirement of `/copilot-pairing` and `/copilot-review`**. Existing user-CLAUDE.md already marks these transitional. No change here.

## Sources

- Conversation between user and Claude on 2026-05-22, captured in this dotfiles repo.
- User-global CLAUDE.md sections: Finding Categorization, Validation Rigor, Discovery Rigor, Refactor Instinct, Review Workflows.
- Project CLAUDE.md (dotfiles) sections on materialization, permissions, hooks, MCP, Ollama topology.
- Existing tecpan spec bundles (`specs/auth`, `specs/infra`, `specs/org`, `specs/settings`).
- Subagent analyses 2026-05-22 (peer review pattern, Auto-applicable fill rate, spec quality correlation, friction & time analysis).
