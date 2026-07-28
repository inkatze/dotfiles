Do a comprehensive code review on a PR and draft review comments for me to submit. Discovery is augmented by a non-Anthropic model backend (codex or gemini, chosen by machine profile the same way `/panel-review` does it): the backend adds a different-lineage discovery angle, then acts as an adversarial skeptic against surviving findings so false positives are less likely to reach comments on someone else's PR. Validation and comment drafting stay local in this Claude session, where repo grounding and your voice are the advantage.

## Steps

### 1. Checkout the PR

If `$ARGUMENTS` contains a PR number or URL, use it. Otherwise, ask.

```bash
gh pr checkout <number>
```

Note the current branch before checking out so we can return to it at the end.

### 2. Get PR and repo info

```bash
gh pr view --json number,baseRefName,title,body,author -q '{number: .number, base: .baseRefName, title: .title, author: .author.login}'
gh repo view --json owner,name -q '.owner.login + " " + .name'
```

### 3. Check for a Jira ticket

Extract a Jira ticket key from the branch name, PR title, or PR body (e.g., `PROJ-123`). If a key is found, fetch the ticket using the Jira MCP tools (`getJiraIssue`) and note the description, acceptance criteria, and any relevant details. If no key is found or Jira tools are unavailable, skip this step.

### 4. Get the full diff

```bash
git diff <base>...HEAD
```

If the diff is large, review file-by-file using `git diff <base>...HEAD -- <path>`.

### 5. Generate findings via parallel lens fan-out + backend discovery pass

Apply the canonical spec in CLAUDE.md `Discovery Rigor (Issue Identification)`. We are leaving comments on someone else's PR, so dribbling findings across multiple reviews is worse here than in self-review and false positives have a higher cost. Discovery runs two angles in parallel: Claude's per-lens Explore fan-out and one holistic pass from a non-Anthropic backend. A different training distribution catches what Claude's would miss; the merged, deduped list is what maximizes coverage on a PR you only want to review once.

a. **Run project tooling once.** Linters, formatters, type checkers, static analyzers, complexity / duplication meters, dead-code detectors, security scanners. Discover via `lefthook.yml`, CI workflows, `mise.toml` tasks, language config files, and the SessionStart `tool-discovery` summary if present in this session's context. Capture the output; it becomes shared input for every lens agent and for the backend.

b. **Resolve and verify the backend.** Same mechanism as `/panel-review` so the choice tracks the machine, not this tracked, public file. Read the machine profile from `PANEL_REVIEW_PROFILE` (the shared work/personal signal; unset or any non-`work` value resolves to `personal`), then pick the backend from the profile table. A `--backends <name>` token in `$ARGUMENTS` overrides it (code-review supports `codex` or `gemini`; the Ollama / Copilot backends stay `/panel-review`-only). The remaining non-flag `$ARGUMENTS` token is the PR number from step 1.

   ```bash
   case "${PANEL_REVIEW_PROFILE:-personal}" in
     work) echo codex ;;
     *)    echo gemini ;;
   esac
   ```

   | Profile | Default backend |
   |---|---|
   | work | `codex` |
   | personal / alt | `gemini` |

   Verify the resolved backend before using it. Stop with a specific install / auth message if it fails; do not silently fall back to a Claude-only run, since the whole point is the non-Anthropic angle:
   - `codex`: `command -v codex` must succeed and `codex auth status` (or the CLI's readiness probe) must report an authenticated session. Missing: `Codex CLI not installed; mise run osx will install via Brewfile cask 'codex'`. Not authed: `Codex CLI needs auth; run 'codex login'`.
   - `gemini`: `command -v gemini` must succeed and `GEMINI_API_KEY` must be set (dotfiles fish conf.d/gemini.fish exports it from `~/.gemini/.api-key`). Missing: `Gemini CLI not installed; mise run osx will install via Brewfile 'gemini-cli'`. Unset key: `Gemini CLI needs auth; run 'mise run osx' to sync from 1Password or set GEMINI_API_KEY manually`.

c. **Spawn one `Explore` sub-agent per canonical lens, in parallel.** Default is to spawn for all 9 lenses; only skip a lens when it is genuinely n/a for the diff, and record the reason for the lens-coverage table. Each sub-agent receives:
   - The full diff (or relevant slice for large diffs)
   - The tooling output from (a)
   - A narrow brief: "find issues in this diff for ONE lens only: `<lens>`. Be exhaustive within your lens. Severity-pruning is forbidden. If no findings, return `none` with a one-line reason. Cite linter / type-checker rules when they fire."
   - The lens's specific concerns, copied verbatim from CLAUDE.md `Discovery Rigor (Issue Identification)`.

d. **Backend discovery pass.** Invoke the resolved backend **once** with the full diff (or relevant slice) and the tooling output from (a), asking it to walk the 9 canonical lenses and return a findings table. Run it concurrently with the Claude fan-out in (c). Invocation patterns (verify exact flags on first use):
   - **codex**: `codex exec "<prompt>"` (add `--model` etc. as the CLI requires). Capture stdout and parse the table.
   - **gemini**: pipe the prompt via **stdin**, not `-p`. In fish, `gemini -p "$(…)"` splits the multiline prompt across argv and the CLI prints its help instead of answering, so write the prompt to a file and pipe it in the **same `Bash` tool invocation** (fresh shell per call): `gemini -o text [-m <model>] --approval-mode plan < "$prompt_file"`. `-o text` keeps stdout free of the JSON envelope; `--approval-mode plan` forces read-only operation.

   Prompt structure (adapt wording per backend; the substance is the lens walk):
   ```
   Review this diff. Walk every lens below and report findings for each. Severity-pruning is forbidden: a small doc nit and a critical bug must both appear. If a lens has no findings, return `none` with a one-line reason.

   Lenses: the 9 canonical lenses from CLAUDE.md `Discovery Rigor (Issue Identification)`.

   Output ONLY a Markdown table with columns Lens | File:Line | Finding | Rule cited | Severity. No preamble (including `<think>` blocks or reasoning traces), no commentary after the table.

   Project tooling output (shared):
   <tooling output from (a)>

   Diff:
   <full diff or slice>
   ```

   If the backend invocation does **not recover** (final non-zero exit, empty or unparseable output, or lost auth with no successful retry), stop and surface it; do not silently drop it. Judge by final outcome, not by transient quota / rate-limit / retry chatter the CLI prints while it retries internally.

e. **Coordinator merges and dedupes** across the Claude lens agents and the backend pass. Dedupe by `(file, line, root issue)`; a finding surfaced by both angles becomes one row tagged with both sources. A finding hitting two lenses gets one row with both lens labels. Apply the **review-mode refactor instinct** filter (CLAUDE.md `Refactor Instinct`): drop refactor flags that are not anchored in tool output and do not represent this-PR-makes-it-worse. Pre-existing mess unrelated to the diff is out of scope, and especially so on someone else's PR.

f. **Jira AC lens** (when a ticket was found in step 3): walk acceptance criteria; flag missing or inconsistent items. Claude-only, since the backend was not given the ticket.

g. **Self-critique pass (mandatory).** Re-scan the diff and the merged list. Assume the list is incomplete. Add what you find under-represented.

### 6. Validate every finding: three passes minimum (different angle each)

Apply the canonical rigor in CLAUDE.md `Validation Rigor (Issue Identification)`. For each potential issue:

- **Read first.** The full source file to understand context, plus callers and related modules.
- **Pass 1: direct reproduction.** When the issue concerns runtime behavior, reproduce it. Failing test, repro script, trace through the code with concrete inputs, or construct an input that triggers the bug. Inability to reproduce is a strong signal of a false positive.
- **Pass 2: orthogonal angle.** A different lens: callers and what they assume, related code paths and side effects, project conventions, sibling implementations, existing test coverage.
- **Pass 3: outside-in angle.** Sources outside the diff: `git log` / `git blame` for the why-it-is-the-way-it-is, repo-wide search for similar patterns, and for text/research-based claims (API correctness, spec compliance, deprecated patterns, security claims, library behavior) consult official docs, the library's own source/tests, deepwiki MCP, GitHub issues, RFCs, web search. Note what was checked.

Drop or downgrade items where the three passes do not converge. We are leaving comments on someone else's PR, so false positives have a higher cost here than in self-review.

**Adversarial cross-check (backend refutation).** After the three passes leave a set of surviving findings, send each survivor back to the same backend resolved in step 5b, now cast as an independent skeptic: give it the finding, the relevant code, and ask it to argue whether the finding is real or a false positive, and if real whether the severity holds. This attacks the confirmation bias of Claude validating its own discovery, which matters most here because a false-positive comment on someone else's PR costs credibility. Weight the result as one more validation angle, not an override: the backend can only reason over the text you hand it (it cannot check out the PR or run the repo's tests), so a "this is wrong" downgrades or drops a finding only when it converges with a local reason to doubt it, and a "this is real" does not by itself promote a finding Claude's local passes could not ground. Use the same invocation patterns as step 5d (codex on stdout, gemini via stdin). Record the backend's verdict in the finding's `Source` column.

### 7. Present results: lens-coverage table, then severity-grouped findings tables

Lens-coverage table from CLAUDE.md `Discovery Rigor (Issue Identification)` first. Then findings grouped into four severity tiers, each as its own table in fixed order: Blockers, Concerns, Suggestions, Nits. Every tier table always appears; if a tier is empty, print a single `none` row so the empty tier is visible (same anti-silent-pruning guard as the lens-coverage table).

`/code-review` does **not** use the three-bucket categorization (Auto-applicable / Needs sign-off / Needs human judgment) per CLAUDE.md `Finding Categorization`. That split exists as a loop boundary for `/polish` and `/panel-review --nested`, and as a prep step for `/self-review`, `/panel-review`, `/peer-review`, and `/copilot-review`'s local apply loops. `/code-review` only drafts comments for me to submit, so the relevant question is "how important is this and what comment do I post", not "can a robot apply this".

**Blockers** (must address before merge: correctness bugs, security issues, broken tests, missing critical pieces):

| # | Lens | File:Line | Finding | Source | Confidence | Validation passes | Recommendation | Draft comment |
|---|---|---|---|---|---|---|---|---|

**Concerns** (significant issues worth raising but not strict blockers: risky patterns, design concerns, missing test coverage on important paths):

| # | Lens | File:Line | Finding | Source | Confidence | Validation passes | Recommendation | Draft comment |
|---|---|---|---|---|---|---|---|---|

**Suggestions** (improvements the author should consider: naming, structure, refactor opportunities anchored in `Refactor Instinct`'s review-mode bar, doc gaps that aren't required):

| # | Lens | File:Line | Finding | Source | Confidence | Validation passes | Recommendation | Draft comment |
|---|---|---|---|---|---|---|---|---|

**Nits** (small style/cleanup items: typos, tool-grounded linter rules the author can take or leave, formatting):

| # | Lens | File:Line | Finding | Source | Confidence | Validation passes | Recommendation | Draft comment |
|---|---|---|---|---|---|---|---|---|

Column definitions (apply to all four tables):

- **Source**: which discovery angle surfaced it (`Claude`, the backend name, or `both`), plus the backend's refutation verdict from step 6 (e.g. `both; backend: agrees real`, `Claude; backend: calls FP`).
- **Confidence**: high / medium / low (how strongly the three validation passes converged; low-confidence items are usually downgraded or dropped at step 6).
- **Recommendation**: post inline / post as PR-level / defer to follow-up / dismiss.
- **Draft comment**: literal text for the comment we will post (inline or PR-level per the Recommendation). Tone requirements in step 8.

When a tool rule grounds a finding (e.g., `ruff F401`, `tsc TS2304`, `rubocop Style/UnlessElse`), include the rule citation in the Finding column. Tool-grounded items typically land in Nits or Suggestions; severity reflects user-visible impact, not how mechanical the fix is.

### 8. Follow the standard review workflow

Per CLAUDE.md `Code & PR Reviews`, ask whether to (a) take the whole list at once, (b) go one by one, (c) batched decisions, or (d) clustered decisions. For batched mode, the `/code-review` option set is **Post inline / Post as PR-level / Defer to follow-up / Dismiss** (with auto-added "Other" for custom decisions); up to 4 findings per `AskUserQuestion` call. For clustered mode, the cluster-wide option set is **Post all inline / Post all as PR-level / Defer all to follow-up / Dismiss all / Pick individually** (with "Pick individually" dropping into batched mode for that cluster only). Show progress tracking in either mode. Present each comment draft for my approval before it lands in the final list; I may want to adjust wording.

**Comment tone requirements:**
- Constructive and specific
- Prefix with severity when not obvious (e.g., "nit:", "suggestion:", "blocker:")
- Explain the "why", not just the "what"
- Suggest a fix or alternative when possible
- No em-dashes
- Sound natural and human, like me writing the comment myself

### 9. Summary

After all comments are finalized, present a summary of the review with the final approved comments, organized by file. I will submit the review manually.

### 10. Return to original branch

```bash
git checkout <original-branch>
```

## Maintenance

After completing the workflow, check if any part of these instructions seem outdated, incorrect, or misaligned with the current project's tooling or workflow. Watch specifically for backend drift: codex / gemini CLI flag changes, profile-table or `PANEL_REVIEW_PROFILE` changes, and divergence from `/panel-review`'s backend resolution (which this command mirrors, so the two should stay in sync). If something looks off, flag it and offer a ready-to-use prompt I can paste into a new dotfiles session to update this command.

$ARGUMENTS
