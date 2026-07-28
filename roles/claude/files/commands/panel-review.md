Do a comprehensive code review of the current feature branch using configurable non-Anthropic model backends, so the variance does not come exclusively from this Claude session. Pass `--nested` to loop autonomously (review, apply, re-review) until convergence instead of running one interactive pass.

Same Discovery + Validation rigor as `/self-review`. The backends provide the discovery angle (different training distributions catch what Claude would miss); validation is grounded locally in this session.

## When to use

You want a `/self-review` shape but with one or more external models contributing findings. Common cases:

- ChatGPT Enterprise users on a work repo (Codex CLI as a fast frontier-OpenAI backend).
- Personal repos (local Ollama models from different lineages: Alibaba's Qwen2.5-Coder, OpenAI's gpt-oss).
- Any time you want a non-Anthropic angle without paying GitHub Copilot's per-request quota.

For the standard Claude-only review, use `/self-review`. For autonomous looping (review, apply, re-review until convergence, draining only Auto-applicable items) instead of one interactive pass, pass `--nested`; see "Invocation modes" below. `--nested` is also what makes this skill a *nestable* review skill for planwright's `review_sequence` config knob (an ordered list of `--nested`-invocable review skills that `/execute-task`'s convergence phase runs; the default is `[polish]`), so you can add `panel-review` alongside or instead of `/polish --nested` there.

## Invocation modes

Read the literal flag `--nested` from `$ARGUMENTS` at the start of the run.

- **Standalone** (no flag): run "## Steps" once, end to end, including the interactive review workflow (step 7), the documentation check (step 8), and commit + push + PR (step 9). Ends by handing the review to you directly.
- **Nested** (`--nested`): run "## Nested loop (--nested)" below. It repeats "## Steps" 1-6 (the discovery + validation pipeline) as its per-iteration body, auto-applies only Auto-applicable items, and hands off Needs sign-off / Needs human judgment items when it exits. **Local-only**, same contract as `/polish` and `/self-review --nested`: it never pushes and never creates or touches a PR. The invoking skill (or a standalone `/panel-review` / `/self-review` run afterward) owns publishing the branch.

Record the resolved mode in every iteration summary when nested.

## Pre-flight (once per run)

Runs identically in both modes.

1. **Identify base branch and capture the diff** (same as `/self-review` step 1).
2. **(Optional) Jira ticket** (same as `/self-review` step 2).
3. **Detect repo profile.** Work or personal, driven by an untracked, machine-local
   signal so no employer identifiers live in this tracked, public file. Set
   `PANEL_REVIEW_PROFILE=work` on work machines (e.g. a fish universal variable or
   shell rc); anything else (unset or any other value) resolves to `personal`:

   ```bash
   case "${PANEL_REVIEW_PROFILE:-personal}" in
     work) echo work ;;
     *)    echo personal ;;
   esac
   ```

4. **Resolve the backend set.** If `$ARGUMENTS` contains `--backends a,b,c`, use those (comma-separated). Otherwise use the profile table default:

   | Profile | Default backends |
   |---|---|
   | work | `codex` |
   | personal / alt | `gemini` |

   Supported backends: `codex`, `gemini`, `qwen-coder`, `gpt-oss`, `copilot`. `copilot` is **opt-in only** via `--backends`; do not auto-include it (the GitHub quota is the original constraint and including it implicitly defeats the point). `deepseek-r1` was retired: it is a reasoning model that emits `<think>` chain-of-thought blocks the panel prompt cannot reliably suppress, and ~2x wall-clock vs `qwen-coder`. `gpt-oss:20b` replaces it as a different-lineage second slot (OpenAI training, instruction-tuned, no reasoning trace). The Ollama models remain available via `--backends` for variance panels when wanted.

5. **Verify each backend.** Stop with a specific install / auth message if any fails; do not silently drop a backend (the user expects the variance the backend provides).

   - `codex`: `command -v codex` must succeed; `codex auth status` (or equivalent: query the codex CLI's own readiness probe) must report an authenticated session. If not authed, stop with `Codex CLI needs auth; run 'codex login'`. If not installed, stop with `Codex CLI not installed; mise run osx will install via Brewfile cask 'codex'`.
   - `gemini`: `command -v gemini` must succeed. The `GEMINI_API_KEY` env var must be set (the dotfiles fish conf.d/gemini.fish exports it from `~/.gemini/.api-key`, which is written by `scripts/claude-gemini-auth-sync.sh` from the 1Password item declared in that script). If `gemini` is missing, stop with `Gemini CLI not installed; mise run osx will install via Brewfile 'gemini-cli'`. If `GEMINI_API_KEY` is unset, stop with `Gemini CLI needs auth; run 'mise run osx' to sync from 1Password (requires the 1Password item UUID to be set in scripts/claude-gemini-auth-sync.sh) or set GEMINI_API_KEY manually`.
   - `qwen-coder` / `gpt-oss`: `curl -sf "${OLLAMA_BASE_URL:-http://localhost:11434}/api/tags"` must return a body containing the model name (`qwen2.5-coder:32b` or `gpt-oss:20b`). If the API does not respond, stop with `Ollama service not running; brew services start ollama` (on the work host; on personal/alt the dotfiles fish conf.d/ollama.fish points OLLAMA_BASE_URL at the work host's LAN IP, see dotfiles `CLAUDE.md` "Cross-host Ollama topology"). If the model is missing, stop with `Model not pulled; ollama pull <name>` (the dotfiles Ansible task pulls both on the work host by default; missing means an opt-out or the cross-host route is not configured).
   - `copilot`: `gh copilot --help` must succeed and the account must have quota. Stop if `gh` is not authenticated or `gh copilot` returns a quota-exhausted error.

**Nested-only additions** (run these after the five items above, only when `--nested` was passed):

6. **Initialize iteration counter** = 0.
7. **Confirm the working tree is clean.** `git status --porcelain` must be empty before the loop starts. Uncommitted changes interfere with per-iteration commit boundaries and make rollback ambiguous. If the tree is dirty, stop and ask the user to commit or stash first.

## Steps

Steps 1-6 are the shared discovery + validation pipeline; both modes run them identically. Steps 7-9 are standalone-only (the nested loop replaces them with its own categorize/apply/handoff cycle, see "Nested loop" below).

### 1. Run project tooling once

Linters, formatters, type checkers, static analyzers, complexity / duplication meters, dead-code detectors, security scanners. Discover via `lefthook.yml`, CI workflows, `mise.toml` tasks, language config files, and the SessionStart `tool-discovery` summary if present in this session's context. Capture the output; it becomes shared input for every backend so all of them ground their findings the same way (this is what makes "tool-grounded" survive backend variance).

### 2. Backend discovery pass

For each backend in the resolved set, invoke it **once** with the full diff, the tooling output from step 1, and a lens-walk prompt covering the 9 canonical lenses from CLAUDE.md `Discovery Rigor (Issue Identification)` plus a 10th **defensive-completeness lens** (panel-specific, listed below). Each invocation is independent; run them in parallel (separate `Bash` tool calls in the same response) when possible.

**Prompt structure to send each backend** (adapt the literal wording per backend's preferences; the substance is what matters):

```
Review this diff. Walk every lens below and report findings for each. Severity-pruning is forbidden: a small doc nit and a critical bug must both be reported in the same pass. If a lens has no findings, return `none` with a one-line reason.

Lenses:
1. Correctness, logic, edge cases (null, empty, max size, concurrency, off-by-one, error paths)
2. Security (injection, auth, data exposure, secret handling, untrusted input)
3. Error handling and failure modes
4. Performance (allocation, IO, complexity, hot paths)
5. Concurrency / state (races, idempotency, ordering, retries)
6. Naming, readability, structure (only flag when this PR worsens it)
7. Documentation (docstrings, READMEs, ADRs, config docs)
8. Tests / verification (coverage of new behavior, missing failing-case tests)
9. Cross-file consistency (broken invariants, sibling-pattern drift)
10. Defensive completeness & consistency (input validation and presence/type/shape guards on every consumed field: numeric-ness, presence, non-empty; symmetric handling across parallel code paths, e.g. a validation gate mirroring its mapper; once a defensive guard exists for one field/case, flag sibling fields/cases that lack it). Report low-reachability and currently-unwired-code-path findings too, but state the reachability in the finding so triage can defer gold-plating quickly. This is the lens that surfaces the fine-grained defensive tail an exhaustive external bot would otherwise raise later.

Output format: ONLY a Markdown table with columns Lens, File:Line, Finding, Rule cited (if any), Severity. No preamble (including `<think>` blocks, "Thinking..." traces, or any reasoning model intermediate output). No commentary, observations, or summaries after the table. The table is the entire response. One row per finding; if a lens has zero findings, emit a row like `| Documentation | n/a | none (one-line reason) | | n/a |` so the empty lens stays visible.

Project tooling output (shared with all backends):
<tooling output from step 1>

Diff:
<full diff or relevant slice>
```

**Per-backend invocation patterns** (verify exact flags on first use; this is illustrative):

- **codex**: `codex exec "<prompt>"` (or the equivalent flag set; the CLI may require `--model` or similar). Codex returns text on stdout; capture and parse the table.
- **gemini**: pipe the prompt via **stdin**, not `-p`. In fish, `gemini -p "$(…)"` / `gemini -p (cat file)` splits the multiline prompt into separate argv entries (and can feed empty stdin), so the CLI prints its help instead of answering — this bit the worker-permission-ergonomics panel pass, which only recovered after switching to stdin. Write the prompt to a file and pipe it in the **same `Bash` tool invocation** (fresh shell per call — same `$$` caveat as the Ollama backends below): `gemini -o text [-m <model>] [--approval-mode plan] < "$prompt_file"`. `-o text` keeps stdout free of the JSON envelope so the table parser sees raw markdown; `-m <model>` pins a specific Gemini model (defaults to whatever the CLI considers current); `--approval-mode plan` forces read-only operation. Stdout carries the model response; capture and parse the table.
- **qwen-coder** and **gpt-oss** (Ollama): **prefer the HTTP API** for programmatic invocation. The base URL is read from `OLLAMA_BASE_URL` (set in fish conf.d/ollama.fish on personal/alt hosts to the work host's LAN IP) and falls back to `http://localhost:11434` on the work host itself. **Write the prompt file and run `curl` in the same `Bash` tool invocation**: the `Bash` tool spawns a fresh shell per call, so `$$` in a later call is a different PID than `$$` in an earlier one; if the write and the read land in separate tool calls, the `--rawfile` path silently points at a file that was never created and `jq` fails.
  ```bash
  prompt_file="/tmp/panel-review-prompt.$$.txt"
  cat > "$prompt_file" <<'PROMPT_EOF'
  <the lens-walk prompt, with tooling output and diff appended>
  PROMPT_EOF
  curl -s "${OLLAMA_BASE_URL:-http://localhost:11434}/api/generate" \
    -d "$(jq -nR --arg model 'qwen2.5-coder:32b' --rawfile prompt "$prompt_file" \
      '{model: $model, prompt: $prompt, stream: false}')" \
    | jq -r '.response'
  ```
  Namespace this prompt file by `$$` (the shell PID), not a fixed name: two concurrent `--nested` runs in different worktrees would otherwise race on the same path, with one run's write landing between the other's write and its `curl` call, scoring the wrong diff. The API returns clean JSON with the response under `.response`. `ollama run <model> "<prompt>"` works as a fallback but emits ANSI escape codes (cursor moves, line clears) intended for an interactive TTY; even when piped, those leak into the output and require post-processing (`sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g' | tr -d '\r'`). The HTTP API path avoids that entirely.
- **Wall-clock estimates on M1 Max 32GB** (one model loaded at a time; Ollama swaps when the second is invoked): `qwen-coder:32b` ~5 min, `gpt-oss:20b` ~3 min (smaller, instruction-tuned, no reasoning chain). qwen-coder at ~19 GB and gpt-oss at ~13 GB can't co-reside in unified memory comfortably, so the panel still serializes in practice; gpt-oss swaps in faster than the retired deepseek-r1:32b did.
- **copilot**: route through `gh copilot` or the chosen Copilot CLI; specifics depend on which CLI variant is current.

If a backend invocation **does not recover** (a final non-zero exit, empty or unparseable output, or auth lost with no successful retry), do **not** silently drop it: stop the run and surface the failure. Judge by the final outcome, not intermediate stderr: do **not** stop on transient quota / rate-limit / retry messages the backend CLI emits while it retries internally if it ultimately returns a valid result. The user invoked this skill specifically for the variance that backend provides; partial runs hide the fact that one source of variance went missing.

### 3. Merge backend findings

Build one normalized list:

- Dedupe by `(file, line, root issue)`. A finding flagged by multiple backends becomes one row with all backend labels tagged in the row.
- Tag every row with which backend(s) surfaced it. This is what lets you see, over time, which backends earn their keep on your code.
- A finding hitting two lenses (one backend assigned `Correctness`, another assigned `Error handling`) gets one row with both lens labels.

Apply the **review-mode refactor instinct** filter (CLAUDE.md `Refactor Instinct`): drop refactor flags not anchored in tool output that do not represent this-PR-makes-it-worse.

### 4. Self-critique pass (mandatory)

Re-scan the merged list with the assumption that it is incomplete. Add what feels under-represented. This is the same anti-silent-pruning guard the canonical Discovery Rigor specifies; backends can self-prune within their own context windows the same way a single coordinator agent can, so the critique pass is load-bearing even with multiple backends.

### 5. Validate every finding with the three-pass rigor

Apply CLAUDE.md `Validation Rigor (Issue Identification)` in full, locally in this Claude session, on every backend-surfaced finding:

- **Pass 1: direct reproduction.** Reproduce runtime claims (failing test, repro script, concrete-input trace).
- **Pass 2: orthogonal angle.** Callers, related paths, project conventions, sibling implementations, existing test coverage.
- **Pass 3: outside-in angle.** `git log` / `git blame`, repo-wide search, official docs, library source / tests, deepwiki MCP, GitHub issues, RFCs, web search for text or research-based claims.

Drop or downgrade items where the three passes do not converge. Backends produce findings; validation grounds them. A finding that survives three passes with high confidence routes to Auto-applicable or Needs sign-off per `Finding Categorization`; lower confidence or genuinely ambiguous resolutions route to Needs human judgment. Each finding lands in exactly one bucket out of three: Auto-applicable, Needs sign-off, or Needs human judgment. The four Auto-applicable conditions and the disqualifiers are in CLAUDE.md `Finding Categorization`. Validation Rigor is a hard gate for findings routed to Auto-applicable, since nested mode applies those without asking.

### 6. Present results

Lens-coverage table from CLAUDE.md `Discovery Rigor (Issue Identification)` first (one row per lens, counts merged across backends, with `none` / `n/a` rows where applicable). Then the **three findings tables in fixed order** per `Finding Categorization`: Auto-applicable, Needs sign-off, Needs human judgment. Each table always appears; empty buckets get a single `none` row.

Findings tables include a `Backend(s)` column so you can see which model surfaced what. Suggested columns: `# | Lens | File:Line | Finding | Rule cited | Backend(s) | Validation passes | Confidence | Recommendation`. Drop columns that are uniformly empty.

### 7. Follow the standard review workflow (standalone only)

Per CLAUDE.md `Code & PR Reviews`: ask which mode (a/b/c/d) and apply progress tracking. Option sets are derived from the bucket per `Finding Categorization`:

- **Auto-applicable**: no question, apply with solution validation.
- **Needs sign-off**: standard `Apply / Skip / Modify` option set across batched and clustered modes.
- **Needs human judgment**: bespoke options per finding (skill authors the actual decision branches; generic timing options are forbidden, see `Finding Categorization` forcing function).

When implementing fixes, apply CLAUDE.md `Validation Rigor (Solutions)`: targeted failing test → fix → confirm pass; wider check (project tests, linters, type checkers); edge / integration / manual when relevant. For non-testable changes, substitute review angles and note why no test was added.

### 8. Documentation check (standalone only)

Before committing, verify documentation affected by the changes is up to date: docstrings, READMEs, requirements / design docs, task / planning files, configuration docs, any prose referencing changed code. Search the repo for references to changed function names, feature names, or concepts. Include doc issues in the review findings alongside code issues.

### 9. Commit, push, PR (standalone only)

After all items are addressed, commit. Then if the review found nothing substantive (or after everything is addressed), offer to push and handle the PR, gracefully reusing an existing one if present (same as `/self-review` step 9, including the push-hook failure handling that forbids `--no-verify`).

## Nested loop (--nested)

Iterate steps 1-6 above autonomously, applying only Auto-applicable items, until none remain. Hand control back when no Auto-applicable items are left to drain (surfacing any Needs sign-off and Needs human judgment items in the final tables) or any safety condition fires. **Local-only**: never pushes, never creates or touches a PR (see "Local-only invariants" below).

### When to use nested mode

You want a hands-off draining pass over `/panel-review`'s findings (review, apply, re-review, repeat) but with non-Anthropic model backends doing the discovery instead of GitHub Copilot, and without babysitting the interactive workflow. Common cases:

- As a planwright `review_sequence` entry, alongside or instead of the default `/polish --nested`.
- Copilot quota is exhausted for the month and you still want draining-style autonomous cleanup.
- You want backend variance (different training distributions) without GitHub's per-request billing model.
- You are starting from a branch with no PR yet and want draining-style cleanup before opening one.

For interactive review of all buckets, run `/panel-review` without `--nested`.

Run "## Pre-flight" items 1-7 above before entering the loop (items 6-7, the iteration counter and clean-tree check, are nested-only and only run when `--nested` was passed).

### Iteration loop

For each iteration (cap = **15**):

**Cap check (run at the start of every iteration, before step (a)).** Read the iteration counter (initialized to 0 in pre-flight; incremented in step (e)). If the counter has reached **15**, do not enter step (a). Trigger the **Iteration cap** stop condition and hand control back. This is the only place the cap is enforced; the increment in (e) does not enforce it itself.

#### a. Generate + validate findings

Run Steps 1-6 above in full: project tooling sweep, parallel backend discovery pass, merge + dedupe, self-critique pass, three-pass Validation Rigor on every finding, categorize + present.

Be more conservative than in standalone mode because nobody is checking the categorization in real time. **When in doubt, route to Needs sign-off or Needs human judgment, never Auto-applicable.** False negatives (a real action-bucket item routed to human) are cheap, costing one extra iteration. False positives (a judgment item auto-applied) silently corrupt the branch.

#### b. Decide loop fate

Branch on the bucket counts from step (a).

- **All three buckets empty.** Success. Exit the loop. Print the final summary noting "panel converged, no findings remain". Do not commit (nothing changed this iteration).
- **Auto-applicable empty, Needs sign-off or Needs human judgment non-empty.** Stop. Trigger **Human attention required** stop condition. Print the latest tables and hand control back. Do not commit, do not auto-apply anything from the populated buckets.
- **Auto-applicable non-empty, regardless of the other buckets.** Proceed to step (c). Items in the other buckets are re-evaluated next iteration; the user addresses them after the loop hands off.

#### c. Apply Auto-applicable items (solution validation rigor)

For each Auto-applicable item, apply CLAUDE.md `Validation Rigor (Solutions)` even though the fix is mechanical:

1. **Pre-fix tool run.** Run the cited tool against the file(s) and confirm the rule actually fires on the current code. If it does not (e.g., the rule was already silenced, the file changed since discovery), drop the item and continue. Do not apply a fix for a rule that does not currently fire.
2. **Apply the fix.**
3. **Post-fix tool run.** Run the cited tool again against the same file(s) and confirm the rule no longer fires.
4. **Wider check.** Run the broader project test suite, linters, and type-checkers. Any failure (even a pre-existing one we surface for the first time) triggers the **Test failure** stop condition.

For non-testable fixes (formatting, typos in comments, doc adjustments), substitute review angles per the canonical doctrine in CLAUDE.md.

#### d. Commit

Land the code, then move on. **Do not push**; nested mode is local-only, the invoking skill (or a follow-up standalone `/panel-review` / `/self-review` run) owns publishing the branch.

1. `git add` only the files actually changed (never `git add -A`).
2. Commit with a message of the form `chore(panel): iter N, <short summary>` (e.g., `chore(panel): iter 1, drop unused imports and fix typos`).
3. Do **not** amend, squash, or rebase. Each iteration is its own commit so you can inspect and revert per-iteration if needed.

#### e. Iteration summary

Print a short summary:

- Iteration N / cap.
- Backends invoked + wall-clock per backend (so you can see which were slow / fast).
- Counts: Auto-applicable applied, Needs sign-off surfaced, Needs human judgment surfaced, dropped at step (c.1) (Auto-applicable rule no longer fires).
- Files touched.
- Commit SHA.
- Test command run + result.

This is what you scroll back through to audit the run. Then increment iteration counter and loop to (a).

### Stop conditions (mandatory human handoff)

If any condition fires, **stop**. Print the latest tables, name the condition, and wait for the user. Do not commit further, do not invoke backends again.

| Condition | Trigger |
|---|---|
| **Human attention required** | Step (b) found Needs sign-off or Needs human judgment items and Auto-applicable is empty. The normal path to handoff. |
| **Test failure** | Any test, linter, type-check, or formatter failed at step (c.4), including pre-existing failures surfaced for the first time. |
| **Loop detection** | A substantively similar finding (same file, same root issue, regardless of which backend surfaced it) has been raised in two consecutive iterations after the prior iteration applied a fix. Indicates the fix is not actually addressing the underlying issue, or that backends are hallucinating consistent false positives. |
| **Backend failure** | A backend invocation in step (a) did **not recover**: a final non-zero exit, empty or unparseable output, or auth lost with no successful retry. Judge by the final outcome, not intermediate stderr: do **not** fire on transient quota / rate-limit / retry notices the backend CLI prints while it retries internally and then still returns a valid result. Stop only on a non-recovered failure, rather than silently dropping the backend; the user invoked this skill specifically for that backend's variance. |
| **Iteration cap** | 15 iterations completed without convergence. |
| **Ambiguity** | A finding is borderline between buckets and the bright-line conditions cannot be confidently asserted across two consecutive iterations. Hand off rather than guessing. |
| **Security-sensitive** | Any Auto-applicable candidate touches auth, secrets, crypto, permissions, IAM, SQL/shell construction, or sandbox boundaries. Per the categorization disqualifiers, the item should already be Needs sign-off; if for any reason it landed in Auto-applicable, stop. |
| **Migrations / data / destructive ops** | Same as above for schema migrations, backfills, deletes, drops, anything irreversible. |
| **Dirty working tree** | Pre-flight found uncommitted changes. Stop before iteration one. |
| **High false-positive ratio** | At least 3 items in the iteration AND more than half were dropped at step (c.1) (rule no longer fires). Backends may be misreading the diff or hallucinating tool output. Pause for re-alignment rather than spamming useless commits. |

### Local-only invariants

These hold at every step:

- **Never** push, create a PR, or mutate anything in this repo's git remote or its PR. "Local-only" here is scoped to git/PR actions specifically (the same convention `/polish` uses), not to network calls in general: step 2's backend discovery pass does send the diff and tooling output to external services (Codex, Gemini, Copilot, or Ollama over `OLLAMA_BASE_URL`) on every iteration; that egress is real and pre-existing (unchanged from the retired `/panel-pairing`), just not a git/PR mutation. Nested mode converges the branch locally; publishing it is the invoking skill's job (or a follow-up standalone `/panel-review` / `/self-review` run).
- **Never** address a Needs sign-off or Needs human judgment item, even if it looks easy. Those are reserved for the post-loop human pass via standalone `/panel-review` or manual fixes.
- **Never** route a finding to Auto-applicable without a specific rule citation. "I am sure this is a typo" does not qualify; "ruff F401: imported but unused" does. The rule citation must come from the project tooling run in step (a), not from a backend's free-form recommendation.
- **Never** silently drop a backend that failed in step (a). The user picked the backend set; partial runs hide which variance source went missing.
- **Never** modify CI configuration, `.env`, secrets, or lockfiles, even on a tool's recommendation.
- **Never** amend, squash, or rebase commits.
- **Never** post anything to chat platforms, tickets, or any remote system.
- **Never** skip step (c.4) (wider test / lint / type-check run). A "simple" fix that breaks an unrelated test is the failure mode this guards against.
- **Never** trust the iteration counter alone for cap enforcement; verify at the top of the iteration via the explicit cap check.

### After the loop

When the nested loop exits (success, human handoff, or any other stop condition), present any remaining Needs sign-off / Needs human judgment items per the "Handoff presentation" rules below, then hand control back (to the invoking skill if nested-of-a-parent, or directly to the user if run standalone with `--nested`).

#### Handoff presentation

Follow the CLAUDE.md `Code & PR Reviews` workflow rules. Do not default to one-by-one; choose the mode that minimizes human effort:

**Clustered decisions first.** Look for items that share a decision axis: same fix template (e.g., "add missing test coverage"), same lens (all doc nits, all naming nits), same scope (all in one module). When a cluster of 3+ items exists, use clustered-decision mode per CLAUDE.md: one `AskUserQuestion` per cluster with cluster-wide actions. For Needs sign-off clusters: `Apply all / Skip all / Pick individually`. For Needs human judgment clusters: bespoke options reflecting the shared axis. List each cluster's members before the question so the user can spot mis-grouped items.

**Batched decisions for the rest.** Items that don't fit a cluster use batched-decision mode: up to 4 findings per `AskUserQuestion` call, each as its own single-select question. Needs sign-off items get `Apply / Skip / Modify`. Needs human judgment items get bespoke options per finding.

**Progress tracking.** Always show a progress indicator (e.g., `[2/5]` or `cluster [1/2]: 4 findings`) so the user knows their position and what's left.

**Skip the workflow choice prompt.** Unlike standalone `/panel-review`, the nested loop has already done the autonomous work and is handing off a small residual set. Don't ask "how do you want to review these?" when the answer is obvious from the item count and clustering shape. Just present them in the best mode.

The user's next move depends on the exit reason:

- On success ("panel converged, no findings remain"): consider running standalone `/panel-review` or `/self-review` to do a final pass and open a PR.
- On Human attention required: address the surfaced items (already presented above), then re-run with `--nested` to drain anything new, then open a PR.
- On Test failure or other safety stops: investigate the named condition. The nested loop does not auto-resume; re-invoke explicitly after the underlying issue is understood.

## Maintenance

After completing the workflow, check if any part of these instructions seems outdated or misaligned with current tooling: backend CLI command syntax changes (Codex flags, Ollama API), new backend options worth adding, changes to model names / sizes, drift from `/self-review`'s discovery shape (which this skill mirrors), changes to `Finding Categorization` thresholds, or stop-condition gaps revealed by a real nested run. If something looks off, flag it and offer a ready-to-use prompt to paste into a new dotfiles session to update this command.

$ARGUMENTS
