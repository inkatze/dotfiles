Do a comprehensive code review on a PR and draft review comments for me to submit.

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

### 5. Generate findings via parallel lens fan-out

Apply the canonical spec in CLAUDE.md `Discovery Rigor (Issue Identification)`. We are leaving comments on someone else's PR, so dribbling findings across multiple reviews is worse here than in self-review and false positives have a higher cost.

a. **Run project tooling once.** Linters, formatters, type checkers, static analyzers, complexity / duplication meters, dead-code detectors, security scanners. Discover via `lefthook.yml`, CI workflows, `mise.toml` tasks, language config files, and the SessionStart `tool-discovery` summary if present in this session's context. Capture the output; it becomes shared input for every lens agent.

b. **Spawn one `Explore` sub-agent per canonical lens, in parallel.** Default is to spawn for all 9 lenses; only skip a lens when it is genuinely n/a for the diff, and record the reason for the lens-coverage table. Each sub-agent receives:
   - The full diff (or relevant slice for large diffs)
   - The tooling output from (a)
   - A narrow brief: "find issues in this diff for ONE lens only: `<lens>`. Be exhaustive within your lens. Severity-pruning is forbidden. If no findings, return `none` with a one-line reason. Cite linter / type-checker rules when they fire."
   - The lens's specific concerns, copied verbatim from CLAUDE.md `Discovery Rigor (Issue Identification)`.

c. **Coordinator merges and dedupes.** A finding hitting two lenses gets one row with both lens labels. Apply the **review-mode refactor instinct** filter (CLAUDE.md `Refactor Instinct`): drop refactor flags that are not anchored in tool output and do not represent this-PR-makes-it-worse. Pre-existing mess unrelated to the diff is out of scope, and especially so on someone else's PR.

d. **Jira AC lens** (when a ticket was found in step 3): walk acceptance criteria; flag missing or inconsistent items.

e. **Self-critique pass (mandatory).** Re-scan the diff and the merged list. Assume the list is incomplete. Add what you find under-represented.

### 6. Validate every finding: three passes minimum (different angle each)

Apply the canonical rigor in CLAUDE.md `Validation Rigor (Issue Identification)`. For each potential issue:

- **Read first.** The full source file to understand context, plus callers and related modules.
- **Pass 1: direct reproduction.** When the issue concerns runtime behavior, reproduce it. Failing test, repro script, trace through the code with concrete inputs, or construct an input that triggers the bug. Inability to reproduce is a strong signal of a false positive.
- **Pass 2: orthogonal angle.** A different lens: callers and what they assume, related code paths and side effects, project conventions, sibling implementations, existing test coverage.
- **Pass 3: outside-in angle.** Sources outside the diff: `git log` / `git blame` for the why-it-is-the-way-it-is, repo-wide search for similar patterns, and for text/research-based claims (API correctness, spec compliance, deprecated patterns, security claims, library behavior) consult official docs, the library's own source/tests, deepwiki MCP, GitHub issues, RFCs, web search. Note what was checked.

Drop or downgrade items where the three passes do not converge. We are leaving comments on someone else's PR, so false positives have a higher cost here than in self-review.

### 7. Present results as the canonical lens-coverage table plus two findings tables

Lens-coverage table from CLAUDE.md `Discovery Rigor (Issue Identification)` first, then the findings split per CLAUDE.md `Finding Categorization`. Both tables always appear; if a bucket is empty, print a single `none` row.

**Auto-applicable** (mechanical, tool-grounded; the PR author could merge these without discussion):

| # | Lens | File:Line | Finding | Rule cited | Validation passes | Recommendation | Draft comment |
|---|---|---|---|---|---|---|---|

- **Rule cited**: the linter / type-checker / formatter rule that grounds the finding. Mandatory for this table.
- **Draft comment**: usually a one-liner referencing the rule (e.g. "ruff F401: unused import"). See step 8 tone requirements.

**Needs human attention** (judgment, design, refactor, bugs, naming, anything that needs a real conversation with the author):

| # | Lens | File:Line | Finding | Severity | Confidence | Validation passes | Recommendation | Draft comment |
|---|---|---|---|---|---|---|---|---|

- **Severity**: blocker / concern / suggestion / nit. Prefix the draft comment with the severity tag when not obvious.
- **Confidence**: high / medium / low.
- **Recommendation**: post inline / post as PR-level comment / defer / dismiss / etc.
- **Draft comment**: literal inline comment text. See step 8 tone requirements (constructive, specific, why not just what, no em-dashes, sounds human).

### 8. Follow the standard review workflow

Let me choose: all at once or one by one, with progress tracking. Present each comment draft for my approval. I may want to adjust wording.

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

After completing the workflow, check if any part of these instructions seem outdated, incorrect, or misaligned with the current project's tooling or workflow. If something looks off, flag it and offer a ready-to-use prompt I can paste into a new dotfiles session to update this command.

$ARGUMENTS
