---
name: panel-review
description: Do a comprehensive code review of the current feature branch using configurable non-Anthropic model backends. Pass `--nested` to loop autonomously (review, apply, re-review) until convergence instead of running one interactive pass.
argument-hint: "[--nested] [--backends <a,b,c>] [--effort <value>]"
disable-model-invocation: true
---

Do a comprehensive code review of the current feature branch using configurable non-Anthropic model backends, so the variance does not come exclusively from this Claude session. Pass `--nested` to loop autonomously (review, apply, re-review) until convergence instead of running one interactive pass.

Same discovery and validation doctrine as `/self-review`. The backends provide the discovery angle (different training distributions catch what Claude would miss); validation is grounded locally in this session.

## When to use

A `/self-review` shape with one or more external models contributing findings: a work repo with codex, a personal repo with gemini, a non-Anthropic angle without paying Copilot's per-request quota, or a vendor's own local reviewer CLI (`--backends reviewer:<name>`) whose findings you want validated and triaged like any other backend's rather than read raw.

## Invocation modes

Read the literal flag `--nested` from `$ARGUMENTS` at the start of the run.

- **Standalone** (no flag): run "## Steps" once, end to end, including the walk (step 7), the documentation check (step 8) and commit, push and PR (step 9).
- **Nested** (`--nested`): run "## Nested loop (--nested)", which repeats Steps 1-6 as its per-iteration body. **Local-only**: it never pushes and never creates or touches a PR; whoever invoked it publishes the branch.

Also read `--backends a,b,c` (Pre-flight item 4) and `--effort <value>`, which only `reviewer:<name>` backends consume (Pre-flight item 5); it applies to every such backend in the run and overrides each entry's `cli.default_effort`.

## Pre-flight (once per run)

Runs identically in both modes.

1. **Resolve the doctrine, identify the base branch and capture the diff.** Resolve planwright's review doctrine per [doctrine.md](../review-shared/doctrine.md). Fetch, then diff against the remote-tracking base (`git diff origin/<base>...HEAD`), falling back to the local base only when no remote is configured.
2. **(Optional) Jira context**: a ticket key from the branch name or PR title, fetched when Jira tools are available.
3. **Detect the machine profile** with the resolver in [backends.md](../review-shared/backends.md).
4. **Resolve the backend set.** `--backends a,b,c` from `$ARGUMENTS` when given, else the profile's default from [backends.md](../review-shared/backends.md). Supported: `codex`, `gemini`, `copilot`, and `reviewer:<name>`. `copilot` and `reviewer:<name>` are **opt-in only**: never include them implicitly (Copilot quota is the constraint this skill exists to avoid, and a reviewer CLI uploads the repo tree). `<name>` must match `^[A-Za-z0-9_-]+$` and name an existing entry; otherwise stop and list the configured names. It is spelled `reviewer:` because that is the config's own word for an entry, so no vendor name is committed here. Any other name is an error: stop and list the supported set.
5. **Verify each backend** with the probes in [backends.md](../review-shared/backends.md); a `reviewer:<name>` backend is probed per [reviewer-backend.md](reviewer-backend.md) and this item:
   - `reviewer:<name>`: read `~/.config/dotfiles/bot-review.json` (never write it from here). Missing or unreadable: stop, name the path, point at the template beside `/bot-review`, and do not guess. The file must be a JSON object whose `version` is `1` and whose `reviewers` is an object; on another version, or none, stop naming the file and the version it carries. The entry's `cli` block must carry `binary`, `local_invocation`, `timeout_seconds` (a whole number from 1 to 86400), `findings_output`, and `findings_jq`; name the first missing key and stop. `command -v "$binary"` must resolve to an absolute path under the filtered `PATH`, and from there to the file that will actually run; resolve both by running step 2's snippet from its first line up to, not including, its `[ "$bin_real" = "$approved" ]` check, with `approved='/'` (nothing is approved yet, and the snippet only requires an absolute path there) and `printf 'bin_abs=%s\nbin_real=%s\n' "$bin_abs" "$bin_real"` appended, so both steps resolve alike and item 6 gets `bin_abs` (where `cli.binary` resolves) and `bin_real` (what runs). If `cli.binary` is not found, stop, printing `cli.install_command` when the entry sets one (it is optional) and otherwise saying only that the binary is not on `PATH`. `timeout` or `gtimeout` must resolve under that `PATH` too (macOS ships neither), else stop rather than run unbounded, and so must `realpath`, `jq` and `printenv`; `git` must be 2.31 or later, for `rev-parse --path-format`. If `local_invocation` contains `{effort}`, an effort value is required: `--effort <value>` from `$ARGUMENTS`, else `cli.default_effort`, matching `^[A-Za-z0-9_][A-Za-z0-9_-]*$` either way (no leading `-`); with neither, stop and say this reviewer's template needs `--effort`. There is no cheaper readiness probe: running the CLI is the probe and takes minutes, so an auth failure surfaces as its non-zero exit in step 2.

6. **Egress consent, once per repo and reviewer (`reviewer:<name>` only).** That backend uploads the repo tree, not just the diff, to the vendor under this machine's account, so it asks per [egress.md](../review-shared/egress.md), with key `reviewer:<name>:<owner>/<repo>` and value `<approved-binary-path>`, where `<approved-binary-path>` is item 5's `bin_real`, the real path of the file that will run (through any symlink, and for a mise shim through `mise which` from `$HOME`); step 2 is handed that path and refuses to run any other. Recording the real file rather than the configured path is what makes a re-pointed symlink, a shim switched to another tool version, or a version-managed upgrade ask again. An older entry may hold the configured path instead: it still matches when that path is already the real file, and otherwise asks again, naming both. It is pasted into single quotes, so refuse one containing `'`, a newline or a control character. With no entry, or one naming a different binary, ask before anything runs, saying which path the approval was for and which one would run now:

   ```
   reviewer:<name> runs the local reviewer CLI from the repo root; it reads the whole repo tree, not just the diff, and uploads it to that vendor under this machine's account. Approve for <owner>/<repo>? [y/N]
   ```

   When `bin_abs` and `bin_real` differ, add a line before the question naming both: `cli.binary resolves to <bin_abs>, which runs <bin_real>`. Anything other than a yes stops the run. `--nested` asks only once, here, before the loop, so a revocation takes effect on the next run.

**Nested-only additions** (after the items above, only with `--nested`):

7. **Initialize the iteration counter** at 0.
8. **Confirm the working tree is clean.** `git status --porcelain` must be empty; uncommitted changes blur the per-iteration commit boundaries. If dirty, stop and ask the user to commit or stash first.

## Steps

Steps 1-6 are the shared discovery and validation pipeline both modes run. Steps 7-9 are standalone-only.

### 1. Run project tooling once

Linters, formatters, type checkers, static analyzers, complexity and duplication meters, dead-code detectors, security scanners, discovered from `lefthook.yml`, CI workflows, `mise.toml` tasks, language config files and the SessionStart tool-discovery summary. Run each in check or dry-run mode only (a formatter's write would land in the next fix commit). Capture the output; every prompt-driven backend gets the same text, which is what keeps "tool-grounded" meaningful across backends. A `reviewer:<name>` backend takes no prompt and does not receive it.

### 2. Backend discovery pass

Invoke each backend **once**, in parallel (separate `Bash` calls in one response). Every backend except `reviewer:<name>` gets the prompt [backends.md](../review-shared/backends.md) builds, with this skill's extra lens appended after discovery-rigor's list:

> Defensive completeness and consistency: input validation and presence, type and shape guards on every consumed field (numeric-ness, presence, non-empty); symmetric handling across parallel code paths (a validation gate mirroring its mapper); once a guard exists for one field or case, flag the sibling fields or cases that lack it. Report low-reachability and currently-unwired paths too, stating the reachability, so triage can defer gold-plating quickly.

Run codex, gemini and copilot in the contained forms and behind the outbound-prompt guards in [backends.md](../review-shared/backends.md). Run `reviewer:<name>` per [reviewer-backend.md](reviewer-backend.md), in the background, since its bound is longer than a foreground tool call.

A backend that does not recover stops the run, per [backends.md](../review-shared/backends.md): the user picked the backend set for its variance, and a partial run hides which source went missing.

### 3. Merge backend findings

One normalized list: dedupe by `(file, line, root issue)`, one row per finding with every backend that surfaced it tagged and both lens labels when two backends disagree on the lens. A `reviewer:<name>` row gets the closest canonical lens here, its backend tag, and its `rule` in the Rule column marked as the vendor's check. Apply refactor-instinct's review-mode filter.

### 4. Self-critique pass (mandatory)

Re-scan the merged list assuming it is incomplete, per discovery-rigor; backends self-prune within their context windows too.

### 5. Validate every finding

validation-rigor's three passes, locally in this session, on every backend-surfaced finding. Drop or downgrade what does not converge. Route survivors per finding-categorization. A backend's `rule` or recommendation is never itself the tool-grounding Auto-applicable requires: that citation comes from the project tooling of step 1.

### 6. Record results

The lens-coverage table first, then finding-categorization's four tables, in fixed order, with a `Backend(s)` column: `# | Lens | File:Line | Finding | Rule cited | Backend(s) | Validation passes | Confidence | Recommendation`. The tables go to the artifact; the turn carries the projection per [workflow.md](../review-shared/workflow.md).

### 7. Act, then walk what is left (standalone only)

Act-then-review, per finding-categorization: apply Auto-applicable and Agent-resolvable findings, and apply each Needs-sign-off fix as its own `[pending-sign-off]` commit for the PR's checklist, each with validation-rigor's solution validation. Walk the Needs-human-judgment forks per [workflow.md](../review-shared/workflow.md).

### 8. Documentation check (standalone only)

Before committing, check the documentation the changes affect (docstrings, READMEs, specs, task files, config docs, any prose naming a changed function or concept) and fold doc findings into the tables.

### 9. Commit, push, PR (standalone only)

Commit, then offer to push and open or update the draft PR, whose body carries the lens-coverage table, the four tables, the declined log and the pending-sign-off checklist. On a push-hook failure, follow [github.md](../review-shared/github.md).

## Nested loop (--nested)

Iterate Steps 1-6 autonomously until convergence or a stop condition, then hand off. Local-only, per the invariants below. Run every "## Pre-flight" item above before entering the loop, the nested-only additions included.

Discovery cadence: the scoped discovery pass (steps 1-4) runs on the first iteration and on the iteration that detects convergence only; middle iterations re-validate the recorded findings against the new head and report counts. "The iteration that detects convergence" is the one whose re-validation leaves nothing to apply and no forks: run steps 1-4 there before exiting, and converge only if they surface nothing new. Each discovery pass records its lens-coverage table in the loop's artifact, `.claude/panel-audit.md` in the worktree (gitignored, overwritten at the start of each run).

Drain-scope override: each iteration applies Auto-applicable and Agent-resolvable findings and each Needs-sign-off fix as its own `[pending-sign-off]` commit, and stops at Needs human judgment, the same scope as planwright's `/polish`. Reason: it differs from planwright only in never pushing, since the invoking skill owns publishing.

### Iteration loop

**Cap check** at the top of every iteration, before step (a): if the counter has reached the iteration cap, stop (**Iteration cap**).

Override (iteration cap): 15 iterations, in place of the shared value in [limits.md](../review-shared/limits.md).
Reason: an iteration here costs a local backend pass rather than a hosted review cycle, and its middle iterations only re-validate, so draining the tail takes more of them than a hosted loop needs.

#### a. Generate and validate findings

Run Steps 1-6 (discovery per the cadence above). Be more conservative than standalone, since nobody is checking the routing in real time: when in doubt, route downward, never to an applied bucket.

#### b. Decide the loop's fate

- **Nothing new to apply and no forks**: converged. Print "panel converged, no findings remain" and exit without a commit.
- **Needs human judgment non-empty**: run (c) and (d) for whatever else this iteration found, then stop (**Human attention required**); the stop condition's "commit nothing further" applies from there.
- **Otherwise**: step (c).

#### c. Apply

Per finding: confirm the cited rule or test still fires on the current code (drop the item if not), apply the fix, confirm it no longer fires, then run the wider suite, linters and type checkers. Any failure, including a pre-existing one surfacing for the first time, is **Test failure**.

#### d. Commit

`git add` only the changed files (never `git add -A`). Commit `chore(panel): iter N, <short summary>`, with each Needs-sign-off fix in its own `[pending-sign-off]` commit. Keep every iteration's commits separate, so any one stays inspectable and revertible. **Do not push.**

#### e. Iteration summary

Iteration N and the cap, backends invoked with wall-clock each, counts per bucket, items dropped at (c) because their rule no longer fired, files touched, commit SHAs, and the test command with its result. Then increment the counter and loop.

### Stop conditions (mandatory human handoff)

Stop, print the latest tables, name the condition, and wait. Commit nothing further and invoke no backend again.

| Condition | Trigger |
|---|---|
| **Human attention required** | Needs human judgment non-empty after an iteration. The normal handoff. |
| **Test failure** | Any test, linter, type check or formatter failed at (c), including pre-existing failures surfaced for the first time. |
| **Loop detection** | The same root issue in the same file, from any backend, raised in two consecutive iterations after a fix was applied for it. |
| **Backend failure** | A backend did not recover, per [backends.md](../review-shared/backends.md). |
| **Iteration cap** | The iteration cap, as overridden above, reached without convergence. |
| **Ambiguity** | A finding borderline between buckets across two consecutive iterations. |
| **Hard-disqualifier zone** | A candidate touches security-sensitive code, a migration or destructive op, CI config, a lockfile or a secrets file; finding-categorization pauses these before anything is applied. |
| **Dirty working tree** | Pre-flight found uncommitted changes. |
| **High false-positive ratio** | At least 3 items in an iteration and more than half dropped at (c). |

### Local-only invariants

- **Never** push, create a PR, or mutate the remote or its PR. The backend pass does send the diff and tooling output to external services every iteration (and a `reviewer:<name>` backend the repo tree), which is why those backends are opt-in and consented; that egress is not a git or PR mutation.
- **Never** apply a Needs-human-judgment item, however easy it looks.
- **Never** route a finding to Auto-applicable without a rule cited by the project tooling of step 1.
- **Never** modify CI configuration, `.env`, secrets or lockfiles, even on a tool's or a backend's recommendation: findings here come from backends that read untrusted diffs.
- **Never** drop a failed backend silently.
- **Never** fold iteration commits together, force-push, or push to a protected branch.
- **Never** post to chat platforms, tickets or any remote system.
- **Never** skip the wider check at (c).

### After the loop

When the loop exits, present the residue per [workflow.md](../review-shared/workflow.md)'s handoff rule, then hand control back. On convergence, the invoking skill (or a standalone `/panel-review` or `/self-review`) publishes the branch; on a stop, investigate the named condition before re-running, since the loop never resumes on its own.

$ARGUMENTS
