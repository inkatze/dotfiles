Drive a third-party automated PR-review bot to a clean, documented state on the current PR: every finding replied to and resolved, including the ones we reject. Multi-vendor: the config names one or more reviewers, each with its own hosted-bot mechanics and/or its own local pre-push CLI, and detects up front whether the hosted bot can even reach this repo before drawing conclusions from its absence. Pass `--reviewer <name>` to pick one (default from config otherwise), `--local` to force the CLI path, `--nested` to loop the PR drain autonomously, or `--dry-run` to fetch and triage without posting, resolving, or labeling anything.

## Config

Read `~/.config/dotfiles/bot-review.json` (mode 0600, read-only from this command; you write it by hand). The example at `bot-review.config.example.json` (same directory as this file) shows the shape with placeholder values.

**Terminology**: a config **reviewer** entry configures one underlying third-party **bot** shipped by some **vendor**; the three words name the same thing at different distances (the config key, the thing that posts comments, the company that makes it) and this file uses whichever is clearest in context, never a fourth term for the same referent.

**Missing or unreadable config: stop and say so.** Name the expected path and point at the example. Do not guess a bot login, label name, check name, or marker format; a wrong guess either misses every finding or, worse, acts on someone else's.

Shape: a map of named reviewers plus a default, because one bot may not be installed on every repo you use this from, and a second reviewer (or a CLI-only fallback for the same reviewer) needs to be reachable without editing this file:

```json
{
  "default": "<name>",
  "reviewers": {
    "<name>": {
      "login_pattern": "...",
      "opt_in_label": "...", "opt_out_label": "...",
      "gating_checks": ["...", "..."],
      "requirement_level_hint": "...",
      "addressed_marker_format": "...",
      "finding_key_regex": "...",
      "build_id_regex": "...",
      "repo_config_path": "...",
      "cli": { "binary": "...", "install_command": "...", "local_invocation": "...", "timeout_seconds": 600, "findings_output": "...", "invocation_notes": "..." }
    }
  }
}
```

`cli.invocation_notes` is optional and purely for you: free-text reminders about the real CLI's flags. No step in this file reads it.

**Select a reviewer** via `--reviewer <name>` from `$ARGUMENTS`, else `default`. If `--reviewer` names a key not present under `reviewers`, or if `default` itself doesn't name an existing key, stop and say so; do not guess or fall through to some other entry. **A reviewer entry needs only what its intended use requires**: hosted mechanics (`login_pattern`, `opt_in_label`, `opt_out_label`, `gating_checks`, `requirement_level_hint`, `addressed_marker_format`, `finding_key_regex`, `build_id_regex`, `repo_config_path`) with no `cli` is valid for a bot you never run locally; `cli` with no hosted mechanics is valid for a bot with no GitHub App at all, or one blocked by an org's policy, and is reachable only via `--local`.

For a PR-drain mode (standalone, `--nested`, `--dry-run`) on a reviewer with no hosted mechanics configured, stop and say the selected reviewer has no hosted mechanics; suggest `--local` if it has a `cli`. For `--local` on a reviewer with no `cli` configured, stop and say the selected reviewer has no local CLI; suggest a drain mode if it has hosted mechanics. Do not silently fall back between the two.

If a required key for the invoked mode is missing on the selected reviewer, name that specific key and stop.

## Invocation modes

Read `--reviewer <name>`, `--local`, `--nested`, `--dry-run`, and `--base <ref>` (Local mode only, see there) from `$ARGUMENTS`. `--local` is mutually exclusive with `--nested` (the local CLI pass has no PR to loop against): if both are present, stop immediately and say so, the same never-silently-fall-back posture as the reviewer-validation rules above. `--dry-run` combines with either PR-drain mode.

- **Standalone** (no flags): one interactive pass over "## Steps" below.
- **`--nested`**: "## Nested loop" below, autonomous, bounded by an iteration cap and stop conditions.
- **`--local`**: "## Local mode" below, skips Pre-flight and Steps entirely (no PR, no `gh api` calls at all).
- **`--dry-run`**: fetches and triages normally, prints every table and every drafted reply/resolution/label-add, and stops there. No `pulls/comments/.../replies` POST, no `issues/comments` POST, no `resolveReviewThread` mutation, no label mutation. Combined with `--nested`, runs exactly one iteration and reports what iteration two would have done.

## Pre-flight (standalone and `--nested`)

1. **PR and repo info.** `gh pr view --json number,isDraft,labels,headRefOid` and `gh repo view --json owner,name`.

2. **Availability detection, before anything else about labels or drafts.** A drain against a bot that was never installed on this org looks identical, from inside this command, to a drain against a bot that is installed but suppressed, and the fix for each is the opposite of the other. Check, in order:
   - Does any name in the selected reviewer's `gating_checks` appear at all in `gh pr checks <n>` (present, in any state, not necessarily passing)?
   - Has any comment on this PR (either endpoint, see Steps 1) ever been authored by a login matching `login_pattern`? This check may reuse Step 1's fetch when Step 1 has already run in this pass; it needs only a match, not the authoritative paginated count, so on its own (before Step 1) a single unpaginated page is enough to look for one hit.
   - Is `opt_in_label` even defined on the repo? `--search` matches by substring, so a similarly-named label would falsely say yes: `gh label list --json name --jq '.[] | select(.name == "<opt_in_label>")'` for an exact match, independent of whether it's applied to this PR. Skip this check (treat as non-conclusive, not as "absent") when the reviewer has no `opt_in_label` configured at all.

   **A failed check is not the same as a check that ran and found nothing.** If any of the three `gh` calls itself errors (network, auth, rate limit) rather than returning a clean empty/negative result, do not fold that into "signal absent": surface the failed call and stop, or retry once, before concluding anything about installation. Only a call that *ran* and returned nothing counts toward the "none of the three hold" conclusion below.

   If **none** of the three hold, the bot is almost certainly not installed for this org. Say so plainly, and if the selected reviewer has a `cli` configured, **offer** the local path instead (`y/N`; on yes, fall into "## Local mode" for this run; on no, stop — there is nothing else for a PR-drain mode to do against a bot that isn't reachable). If it has no `cli` either, say plainly that there is no usable path for this reviewer on this repo, and stop. **Do not add the opt-in label speculatively** to see if it wakes something up that was never there: this exact mistake (build a workaround, when the fix was one label on an already-installed bot) is the origin story for this command; adding a label to an org where the bot has no App installed is the same mistake in reverse.

   If at least one signal holds, the bot is reachable; continue to step 3.

   **Fourth, informational signal, never decisive: the reviewer's own repo-local config file.** If `repo_config_path` is configured, check whether it exists in the target repo: `gh api repos/<o>/<r>/contents/<repo_config_path> --jq '.content' | base64 --decode` (a 404 on the `gh api` call means it doesn't exist here, which is not itself a signal either way; the Contents API returns the file base64-encoded in a `content` field, never raw text, so the decode step is not optional — printing the undecoded JSON envelope would show base64, not the config). If it exists, print the decoded contents as an extra data point: a repo can carry a valid opt-in label and an installed App and still have this file disable the bot for itself, which the three signals above cannot catch (they detect *reachability*, not a repo-local override). This command does not parse the file: its schema is vendor-specific and none is configured here, so print it and let you read it rather than guessing at a field path that might not exist. Absence of the file, or of `repo_config_path` itself, means nothing beyond "no extra signal available" and never overrides the three-signal conclusion above.

3. **Explain why a review might still look absent, on a repo where the bot is reachable.**
   - `opt_in_label` present → review is (or will be) active regardless of draft state or `opt_out_label`. Opt-in wins.
   - No `opt_in_label`, `opt_out_label` present → review is suppressed. Say so plainly; do not offer to remove someone else's label.
   - No `opt_in_label`, no `opt_out_label`, PR is a draft → most vendors skip drafts by default. If the reviewer has an `opt_in_label` configured, **offer** (never silently apply) to add it as the override: `y/N`, and only proceed on an explicit yes. If the reviewer has no `opt_in_label` configured at all, say plainly that most vendors skip drafts by default and there is no override label to offer for this reviewer; report `requirement_level_hint` if configured and move on.
   - No `opt_in_label`, no `opt_out_label`, PR is not a draft → default vendor behavior is unknown to this command.

   **Report the requirement-level hint and the opt-in label together, never the level alone as decisive.** Observed on a real run: a review executed at a level its own metadata described as nominally excluded, because the opt-in label was present and overrode it. Treating the level as the last word would have reported "this shouldn't have run" about a review that, correctly, did.

4. **Gating checks are not a drain signal, ever.** `gh pr view --json statusCheckRollup`, filtered to `gating_checks`. Report each by name and state, but **state plainly, every run, that a passing check does not mean every finding was replied to and resolved.** Observed directly: both configured checks reporting SUCCESS while findings sat unresolved underneath them. Nothing in this file, including the nested loop's convergence condition, ever treats check state as a proxy for drain completeness.

5. **Same-PR lock, standalone and `--nested` alike.** Two runs against the same PR (two worktrees, two sessions, a standalone run overlapping a `--nested` run) can otherwise both fetch the same unresolved finding and both reply/resolve it. Lock mirrors `/copilot-review`'s nested pre-flight: `lockfile=/tmp/bot-review-lock.<number>`; if it exists and its recorded epoch is under 30 minutes old, stop and say another run appears active on this PR; otherwise write the current epoch (`date +%s`) and proceed. Refresh it (recompute `now=$(date +%s)` and rewrite the file with that fresh value, never reuse an old one) at the top of every `--nested` iteration and, for a long-running standalone pass, before each expensive step. No unlock step; it ages out on its own rather than depending on every exit path to clear it. `--nested` additionally starts an iteration counter at 0.

## Steps (standalone and the `--nested` loop body)

### 1. Fetch both endpoints, always

```bash
gh api --paginate repos/<o>/<r>/issues/<n>/comments || { echo "fetch failed: issues/comments"; exit 1; }
gh api --paginate repos/<o>/<r>/pulls/<n>/comments || { echo "fetch failed: pulls/comments"; exit 1; }
```

`--paginate` is not optional: `gh api` caps a single page well below what a long-running PR can accumulate, and an unpaginated read silently undercounts rather than erroring, which is exactly the single-endpoint failure step 1 exists to prevent. Filter both to the selected reviewer: `author.login` matched against `login_pattern` as a regex. Count each source **before** any filtering by resolution state, and report both counts (`N_description_level` from `issues/comments`, `N_inline` from `pulls/comments`) up front, every run. A single-endpoint read that reports "3 findings" when the other endpoint carries 7 more is the exact failure this step exists to prevent; the two counts are the check on that, not the merged total. This is the authoritative accounting fetch; Pre-flight step 2's existence check is a separate, cheaper probe and does not need to re-run this in full.

### 2. Fetch resolution state via GraphQL

```bash
gh api graphql --paginate -f query='
  query($owner: String!, $repo: String!, $number: Int!, $endCursor: String) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $number) {
        reviewThreads(first: 100, after: $endCursor) {
          pageInfo { hasNextPage endCursor }
          nodes {
            id
            isResolved
            path
            line
            comments(first: 20) {
              nodes { databaseId body author { login } }
            }
          }
        }
      }
    }
  }
' -f owner='OWNER' -f repo='REPO' -F number=NUMBER || { echo "fetch failed: reviewThreads"; exit 1; }
```

`gh api graphql --paginate` walks `reviewThreads`' `pageInfo`/`endCursor` for you (verify the current `gh` version supports `--paginate` on `graphql`; on an older `gh`, loop the cursor by hand). This is the same undercount risk as Step 1's REST calls, just on the GraphQL side: a PR with more than 100 review threads would otherwise silently lose resolution data for the rest. The per-thread `comments(first: 20)` cap has no equivalent pagination here; a thread with more than 20 comments only matters for finding the *first* comment (used below), so the cap is acceptable there, but note it rather than assuming it never bites.

Build the map from the **first comment in each thread**: `comments.nodes[0].databaseId` (REST comment id) → `{threadId: id, isResolved}`. Neither REST endpoint knows about resolution; this query is the only source for it. The comment's REST `id` and the thread's `id` (the threadId) are different values on different objects; resolving with the wrong one fails confusingly rather than loudly, so keep them in clearly-named variables, never reuse one for the other. Drop any inline finding whose thread is already `isResolved: true` from further processing (already handled by a prior pass), but keep its count in the step-1 totals.

### 3. Anchor every surviving inline finding

Anchor = `(path, original_line, original_commit_id)` from the `pulls/comments` object, never the comment body and never `line`/`commit_id` (which shift as the diff moves). This is what survives the bot rewording a re-raised finding: measured median text similarity across confirmed repeats is around 0.29, so a text-keyed dedupe silently re-litigates closed items.

### 4. Anchor every surviving description-level finding (no line to anchor to)

`issues/comments` findings carry no path/line. If the selected reviewer's `finding_key_regex` is configured, extract the vendor's own stable finding key from the comment body and use it as the anchor; this has been confirmed against a real bot that embeds one in an HTML comment specifically so its own re-review can recognize an addressed finding. **If it is not configured, say so and fall back to a best-effort anchor** (file path mentioned in the body, if any, plus a truncated first sentence) **and state the limitation out loud**: without a vendor-supplied key, a reworded re-raise of the same description-level finding may be treated as new. Recommend setting `finding_key_regex` once you know whether the vendor embeds one, rather than silently trusting the fallback.

### 5. Skip already-acknowledged description-level findings

Before treating a description-level finding as new, search existing `issues/comments` authored by the viewer for `addressed_marker_format` with this finding's key already substituted in. If found, it was handled by a prior pass; skip it (idempotent re-run, same reasoning as `/copilot-review`'s already-handled pre-check).

### 6. Freshness: the bot may edit its summary comment in place rather than posting a new one

**Confirmed, not hypothetical.** A real bot's summary comment showed `created_at` and `updated_at` roughly an hour apart after a re-review, with no new comment posted. A freshness check keyed on `created_at` misses the entire re-review. If `build_id_regex` is configured, extract it from the latest reviewer-authored `issues/comments` entry, and use **that**, never `created_at`/`updated_at`, to tell a fresh re-review apart from silence; "## Nested loop" polls on it. Without `build_id_regex`, this command cannot tell an edited-in-place re-review from no re-review at all; say so once rather than assuming silence means nothing changed.

### 7. Triage every surviving finding

Read the referenced code first. Apply CLAUDE.md `Validation Rigor (Issue Identification)` in full (three passes, different angle each) before accepting the bot's claim, and apply the same rigor to any fix it suggests before trusting it: these bots' suggested diffs can be subtly wrong and can contradict a prior round's suggestion on the same PR.

Classify per CLAUDE.md `Finding Categorization`:
- **Auto-applicable**: bot flagged something tool-grounded and mechanical (cite the linter/formatter/type-checker rule); fix is a rename/reformat/drop-unused/similar; no behavior change; all three passes converged.
- **Needs sign-off**: a real issue with one clear fix that isn't mechanical, or a **rejection** (dismissing the finding needs a human decision before we tell the bot we disagree).
- **Needs human judgment**: passes didn't converge, or genuinely ambiguous, or multiple valid resolutions.

Present all three tables, in fixed order, `none` row on any empty bucket. Suggested columns: `# | Source (description-level / inline) | Anchor | Bot's finding | What we found | Validation passes | Disposition | Draft reply`.

### 8. Address items (standalone only; `--nested` replaces this with its own loop step)

Follow CLAUDE.md `Code & PR Reviews` (ask which mode: a/b/c/d, with progress tracking). Option sets per bucket, same as every other review command here: Auto-applicable applies with the terse reply; Needs sign-off gets `Apply / Skip / Modify` (`Apply` here means "land the fix"; use `Modify` if you'd rather defer-with-reply than either land or silently drop, since a deferral is a legitimate third outcome, not just "skip"); Needs human judgment gets bespoke options per finding. Apply CLAUDE.md `Validation Rigor (Solutions)` to anything that touches code.

### 9. Commit and push, if anything was applied — before replying to anyone

**Land the code first, then talk about it.** If step 10 replied and resolved before this push, and this push then failed, findings would sit marked resolved on GitHub with no fix actually landed on the remote, and no later pass would re-detect them as unresolved: silent loss of work, the exact race `/copilot-review` documents and designs against. So this step runs first, even though it's numbered after triage.

Standalone: ask, same push-hook-failure handling as the sibling commands (never `--no-verify`, diagnose before retrying). On a push failure here, stop before step 10 entirely: nothing has been said to GitHub yet, so there is nothing to unwind, and surfacing the failure plainly is strictly better than a reply/resolve that would misrepresent an unlanded fix as done. `--nested`: see below, same ordering.

### 10. Reply to and resolve (or acknowledge) every disposed finding

This is the requirement most worth enforcing: an unreplied finding is not handled, whatever bucket it started in. **Confirmed this is worth enforcing**: on a real bot, a finding that was replied-to and resolved was moved into a suppressed section on the next review ("won't be reposted"), rather than being re-raised. Skipping the reply on a finding you're keeping open forfeits that suppression and invites the bot to raise it again next pass.

**Already-handled pre-check, inline findings too.** Step 5 already does this for description-level findings (search for a posted ack marker before treating one as new); apply the same idea to inline findings, since a prior pass's `resolveReviewThread` mutation can fail silently (network blip, a stale or wrong threadId, a concurrent resolve) while its reply POST succeeded. Before triaging an inline finding, check whether the thread already carries a reply from the viewer. If so, do not post a second reply: just re-attempt the resolve mutation for that thread.

**Re-fetch once before the whole batch, not once per finding.** A push in between passes can change comment ids, and a stale id 404s on the reply call, but re-running Step 1's full paginated fetch separately for every disposed finding multiplies an expensive call by the finding count on exactly the large PRs where it's already costly. Re-fetch `pulls/comments` once, immediately before starting this step's reply loop. If an individual reply POST still 404s mid-batch (id shifted after this refetch, e.g. a concurrent push), retry that one anchor's lookup, not the whole batch. **If the retried lookup can't find the anchor at all** (the comment was deleted, or a force-push renumbered lines and superseded the thread), treat the finding as no longer present: skip it, note it once in the pass summary, and move on rather than retrying indefinitely.

**Shell quoting rules** (same reasoning as `/peer-review` and `/copilot-review`'s replies, which have been bitten by this): a drafted reply body routinely contains backticks (code spans) and `$`-prefixed text (env vars, template placeholders) that a single-quoted `-f body='...'` breaks or mangles. Construct the body as an inline single-quoted bash heredoc (`<<'EOF'`) in the same `Bash` invocation that posts it, never a hand-typed `-f body='...'` literal. Both code blocks below (inline and description-level) follow this shape. Fall back to a temp file only when the body is genuinely too large to inline.

**Every mutation below is error-guarded** (`||`): a reply that posts but whose resolve then fails must not read as success, and must not cause a duplicate reply on the next pass (that's what the already-handled pre-check above is for).

**Inline findings:**
```bash
body=$(cat <<'EOF'
REPLY_BODY (multi-line ok; backticks and $vars stay literal)
EOF
)
gh api repos/<o>/<r>/pulls/<n>/comments/<comment_id>/replies -f body="$body" \
  || { echo "reply failed for comment <comment_id>"; exit 1; }
```
Then resolve, using the **threadId from the step-2 GraphQL map, never the comment id**:
```bash
gh api graphql -f query='
  mutation($threadId: ID!) {
    resolveReviewThread(input: { threadId: $threadId }) { thread { isResolved } }
  }
' -f threadId='THREAD_ID' \
  || { echo "resolve failed for thread THREAD_ID (reply already posted; next pass's already-handled pre-check will retry the resolve, not re-reply)"; exit 1; }
```

**Description-level findings (no thread to resolve):** post a top-level comment embedding the ack marker with this finding's key:
```bash
body=$(cat <<'EOF'
REPLY_BODY

<!-- bot-review-ack:FINDING_KEY -->
EOF
)
gh api repos/<o>/<r>/issues/<n>/comments -f body="$body" \
  || { echo "ack post failed for FINDING_KEY"; exit 1; }
```
(substitute the real `addressed_marker_format` from config; the marker literal above is illustrative). This is the only "resolved" signal that exists for a finding with no thread, so a later pass's step 5 depends on it being posted exactly as configured.

**Rejections get a reply too**, explaining what was checked and why the concern doesn't apply (cite the three validation passes), same posting mechanics as an applied fix.

**Deferrals** (Needs sign-off items you chose not to land) get a reply stating plainly that this is deferred to a follow-up, not fixed now, same posting mechanics; resolve/acknowledge exactly as any other disposed finding, since a stated deferral is a complete disposition and should not stay open just because no code changed.

**`--dry-run`:** print the reply body and which mutation would run, for every case above, and stop; post nothing, resolve nothing.

## Nested loop (`--nested`)

Cap = **10** iterations (arbitrary; raise it in this file if a real run needs more, rather than overriding at the call site). Refresh the same-PR lock at the top of every iteration.

**Drain scope: this is deliberately neither `/panel-review`'s nor `/copilot-review`'s.** `/panel-review --nested` drains only Auto-applicable, which would leave this loop unable to converge: a bot drain's deliverable is *dispositions*, and a rejection or a deferral is a complete disposition even though no code moves. `/copilot-review --nested` auto-lands its "valid" bucket wholesale, which is too aggressive for Needs sign-off here (security-sensitive code, migrations, CI config, lockfiles all disqualify into that bucket per CLAUDE.md `Finding Categorization`, and this loop must never auto-land those). So, per iteration, auto-process:

- **Auto-applicable**: apply the fix now; it gets pushed and replied-to below in the same order Steps 9-10 use.
- **Needs sign-off**: **reply and resolve (or acknowledge) with an explicit stated deferral. Never apply the code change in this bucket while nested.** This is what lets the loop reach zero unresolved without auto-landing anything that CLAUDE.md's disqualifiers would route to human sign-off in the first place.
- **Needs human judgment**: stop the loop immediately (**Human attention required**), print the tables, hand back.

When in doubt about a disposition, route to Needs human judgment rather than guessing; a false negative costs one extra iteration, a false positive silently mishandles someone's finding.

Per iteration: run "## Steps" 1-7. If Needs human judgment is non-empty, stop and hand back per the disposition above. Otherwise, **run step 9 before step 10** (push before reply, same reasoning as standalone mode — never the reverse):

**Path A — an Auto-applicable fix landed this iteration:**
1. Capture `push_head` (`git rev-parse HEAD` after committing) before pushing, so the poll below can confirm a fresh review actually targets the commit this iteration pushed rather than crediting this loop for some concurrent actor's unrelated push.
2. Commit, push (`git push origin <branch>`, never `--force`, never a protected branch). **This makes `--nested` here not local-only**, unlike `/polish` or `/panel-review --nested`: a hosted bot needs a new head to re-review, the same reasoning `/copilot-review --nested` documents for itself. **On a push failure** (hook rejection, non-fast-forward, network error): trigger **Push failure**, stop before step 10 — the applied fix is committed locally and safe, but nothing has been replied to or resolved yet, so there is nothing to unwind.
3. Run step 10 (reply + resolve) for everything in Auto-applicable and Needs sign-off, referencing `push_head`'s short SHA in Auto-applicable replies.

**Path B — no Auto-applicable fix (every item was a rejection or a deferral, nothing to push):**
1. Run step 10 (reply + resolve/acknowledge) for everything in Needs sign-off. No commit, no push.
2. Whether the bot re-reviews an unchanged HEAD after only reply/resolve activity (no push) is vendor-specific; observe on a real run.

**Either path, then poll** for the next review keyed on `build_id_regex` changing, **never on check state and never on `created_at`/`updated_at`** (both confirmed unreliable in "## Pre-flight" step 4 and "## Steps" step 6), **and matched to `push_head`** on Path A (a review whose commit doesn't match `push_head` is a concurrent actor's, not this iteration's, and does not count). **Pace the poll to the vendor, not to a fixed short interval**: a real run measured full review cycles at 6m45s and 7m22s; polling every 30 seconds against that would be mostly wasted calls, and the harness's own Bash-tool sleep restrictions rule out a raw multi-minute `sleep` regardless — poll the same way `/copilot-review --nested`'s own poll step does (background the wait, or an until-loop bounded by a timeout), not with a blocking sleep. Wait at least several minutes before the first check, then poll at a multi-minute cadence, bounded by a timeout appropriate to the vendor.

- If the poll times out with no new `build_id`, trigger **No response** and stop.
- If `build_id_regex` is configured but has not matched *any* reviewer-authored comment across the whole poll window (as opposed to matching nothing new), the regex itself is probably wrong for this vendor's current comment format: trigger **No response** but say so specifically (format drift, not silence) rather than letting it read as a normal timeout.

**Stop conditions** (print the latest tables, name the condition, hand back; do not commit further):

| Condition | Trigger |
|---|---|
| Human attention required | Needs human judgment non-empty after a drain pass |
| Test failure | Any test/lint/type-check failed after applying a fix |
| Push failure | Step 9's push failed (hook rejection, non-fast-forward, network error) on an iteration that applied an Auto-applicable fix |
| Loop detection | The same anchor is re-raised as unresolved in two consecutive iterations after we applied a fix to it. **Known limitation, not yet resolved** (queued as an open design question — see the command's Maintenance-adjacent open items rather than assuming this fires reliably): an inline anchor includes `original_commit_id`, which changes on every push, so a fix-then-re-raise of the same underlying issue on the new commit will not match its own pre-fix anchor. Treat the iteration cap as the real backstop until this is redesigned. |
| No response | Pushed or acted, then the freshness poll timed out with no new build id, or the configured `build_id_regex` never matched anything across the poll window (format drift) |
| Iteration cap | 10 iterations without convergence |
| Ambiguity | A finding is borderline between buckets across two consecutive iterations |
| Security-sensitive / migrations | Per CLAUDE.md `Finding Categorization` disqualifiers, if either lands in Auto-applicable by mistake |
| Dirty working tree | Uncommitted changes found before iteration one |

**Convergence is zero unresolved findings against the current HEAD, never a check-state read.** Restated because it's the trap: a real run showed both gating checks green with findings still open underneath.

**Transient failures on any other `gh`/GraphQL call in this loop** (a label check, a poll, a reply, a resolve) — rate limits, brief network errors — are not enumerated with their own stop condition; retry once, and if it still fails, treat it as the nearest applicable condition above (a failed reply/resolve is a push-adjacent failure to surface, not a silent skip).

**Never** force-push, push to a protected branch, mark the PR ready, or merge. Those stay reserved human actions; this loop's only PR-lifecycle mutation is the optional opt-in-label add from Pre-flight step 3, and that one is confirmation-gated on every run, never automatic.

## Local mode (`--local`)

No PR, no `gh api` calls at all. Runs the selected reviewer's own pre-push CLI against the working tree. Also the path Pre-flight step 2 offers when the hosted bot isn't reachable on this repo at all (App not installed on this org, or blocked by org policy on someone else's repo), which is the main reason a reviewer entry with `cli` and no hosted mechanics is valid. `--dry-run` has no effect here beyond what this mode already does: it never posts to a PR in the first place, so there is nothing extra to suppress.

1. Resolve the selected reviewer's `cli.binary` on `PATH`; if missing, print `cli.install_command` and stop.
2. Resolve base/head: base defaults to the current branch's usual base (the repo's default branch), or a `--base <ref>` argument if given; head is the working tree as-is (uncommitted included). No PR is consulted for this, matching this mode's own "no `gh api` calls at all."
3. Invoke `cli.local_invocation` with `{base}` and `{head}` substituted, adapting flag names to the real CLI's current `--help` output before first use (the config's invocation string is illustrative, not verified against any specific CLI). **`{effort}` is a known open item, not a defined placeholder**: nothing in this file specifies where its value comes from (a new `--effort` flag, a `cli.default_effort` config key, or dropping it from the template entirely are the live options); do not invent a value for it. If a reviewer's `local_invocation` uses `{effort}`, leave it unsubstituted and say so rather than guessing, until this is resolved. Bound the invocation with `cli.timeout_seconds`. On a non-zero exit or a timeout, print stderr (or "timed out after `cli.timeout_seconds`s") and stop; do not proceed to step 4's parse against partial or absent output.
4. Parse findings per `cli.findings_output` (e.g. `stdout-json`, or a `file:<path>` the CLI writes to). Present as `File:Line | Finding | Severity`; no bucket categorization here, since nothing is applied automatically in this mode. **A zero exit does not guarantee parseable output**: if `stdout-json` doesn't parse, or a `file:<path>` the CLI was supposed to write is missing or empty, stop and say so rather than presenting an empty or partial findings table as "no findings."
5. If the user wants a finding acted on, apply CLAUDE.md `Validation Rigor (Solutions)` the same as any other fix; there is no PR yet, so nothing gets replied to or resolved.

## Naming

`bot-review` was chosen because it describes the workflow shape, not a product, and no mainstream automated PR reviewer (CodeRabbit, Cubic, Greptile, Korbit, Qodo, Sourcery, DeepSource, Bito, and similar) ships a CLI or a Claude Code skill under this name. This file cannot verify that against your actual vendors, because vendors are config, not content, and at least one real vendor is known to ship a CLI whose name would collide with this command's own name: before pointing this command at a real reviewer for the first time, check that reviewer's `cli.binary` and any skill its own install docs mention against `bot-review` and against the `/bot-review` slash command specifically, and rename this file (and its registration in the global `CLAUDE.md`) if either collides. Checked once per newly-added reviewer, not on every invocation, which is why this section sits here rather than at the top.

## Maintenance

After completing the workflow, check whether anything here has drifted from real vendor behavior: the two-endpoint fetch shape, the GraphQL `reviewThreads` schema, the REST reply endpoint, the freshness/dedupe assumptions in Steps 3-6 (most now confirmed against a real bot; the description-level fallback in step 4 and the unchanged-HEAD re-review question in the nested loop remain stated as unverified where they are), the poll cadence in the nested loop, and each configured reviewer's actual CLI flags. Flag drift and offer a ready-to-use prompt to update this command.

$ARGUMENTS
