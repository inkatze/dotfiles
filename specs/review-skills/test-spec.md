# Review Skills — Test Spec

**Status:** Draft
**Last reviewed:** 2026-10-02
**Format-version:** 2
**Execution:** derived — see the status render

Coverage mix: `[test]` wherever a fixture suite or the contract checker can
pin the behaviour deterministically, run by the contract-checker job of the
repository's CI workflow on every pull request and push to `main`, and by
lefthook before each commit; `[manual]` for everything that needs a real PR,
a real reviewer, a second session or a host with 1Password signed in,
recorded in Task 10's verification table; `[design-level]` where the
artifact's existence and content is the verification. A requirement that
cannot be verified on a given host is recorded as unverified with its
reason, never marked passed by inference.

## REQ-A — Reviewer configuration

### REQ-A1.1 — One generic reviewer schema [test + manual]

The renderer's fixture rejects a rendered config missing each required field
in turn, naming the field. Manual: `/bot-review --dry-run` against the
rendered config names the reviewer's login, re-request method and reviewed
head in its pre-flight output.

### REQ-A1.2 — Template and schema checked mechanically [test]

The contract checker accepts the committed template and fails a fixture
missing a required key; the renderer suite fails a template with an
unsubstituted expression and a rendered config failing the schema rule.

### REQ-A1.3 — Default reviewer and no vendor mechanics in tracked files [test + design-level]

The identifier check and the contract checker's retired-name sweep report
zero hits for reviewer logins, marker syntax, comment commands and check
names over the skills tree, the templates and this bundle; the rendered
config's `default` names the cubic.dev entry (design-level: the template
declares it).

### REQ-A1.4 — Draft policy stated, never waited on [manual]

`/bot-review` against a draft PR under a reviewer whose policy skips drafts
prints the policy and the repository-side setting and exits its wait without
polling.

### REQ-A1.5 — Incremental re-request after a push [manual]

A `--nested` iteration that pushes a fix issues the incremental form of the
re-request (observed in the PR's comment or reviewer-request timeline), and
the first request of the run issues the full form.

## REQ-B — Retire `/copilot-review`

### REQ-B1.1 — Skill removed, generic mechanics kept [test + manual]

`grep -rn copilot-review roles/ CLAUDE.md` returns only changelog and spec
lines, and the contract checker pins the generic baseline, errored-review and
diminishing-returns sentences in `/bot-review`. Manual: a `--nested` run on a
PR with an errored review skips it and pins its baseline to the reviewed head.

### REQ-B1.2 — Never mark ready [test]

The contract checker pins `/bot-review`'s never-mark-ready sentence, with a
fixture planting its removal; no file under the skills tree carries a
mark-ready offer.

### REQ-B1.3 — Peer-review routes bot threads [test]

The contract checker pins the routing sentence in `/peer-review` and the
retired-name sweep reports no vendor name there.

### REQ-B1.4 — References removed, budgets re-derived [test]

The contract checker and budget guard pass on the branch; the budget suite's
formula check matches every touched row.

### REQ-B1.5 — Copilot CLI backend removed [test]

The retired-backend sweep fails a fixture planting the backend name in a
skill file; the Brewfile parse step and the mise config carry no entry for
it.

## REQ-C — The cubic.dev CLI as a reviewer backend

### REQ-C1.1 — Runs through `reviewer:<name>` [test + manual]

The contract checker's backend-set pin lists no new backend kind. Manual:
`/panel-review --backends reviewer:cubic` resolves the entry's `cli` block
and produces findings rows.

### REQ-C1.2 — mise pin and opt-outs [test + manual]

`mise ls --json` on the branch's config names the CLI with a version, and the
contract checker pins the opt-out variables in the invocation template.
Manual: after a run, `git notes list` in the reviewed repository is empty and
the binary's version is unchanged.

### REQ-C1.3 — Key synced and passed at invocation only [test + manual]

The key sync's fixture refuses a key file at a loose mode and a blank value;
`grep -rn CUBIC roles/fish` returns nothing. Manual: the backend's `env -i`
line carries the key variable from `env_allow` and a shell started after the
sync does not export it.

### REQ-C1.4 — mise shims stripped structurally [test]

A fixture places a mise shims directory and a repo-steered mise config on
the path and asserts the backend's resolved `PATH` carries neither and the
CLI resolves from `HOME`.

### REQ-C1.5 — No bare positional parameters [test]

The contract checker fails a fixture carrying a bare `$1` in a skill file and
passes the rewritten backend snippet.

### REQ-C1.6 — Egress consent unchanged [manual]

The first run asks consent once per repository and reviewer binary, the
second run does not, and the consent record carries the reviewer key.

## REQ-D — Shared evidence

### REQ-D1.1 — Record written with its fields [test]

The helper's fixture records a command and asserts the entry carries exit
status, start and end times, source and output under the tree-hash
directory.

### REQ-D1.2 — Exact-key reuse [test]

The fixture asserts a hit for the same tree and command, a miss after an
untracked file is added, a miss after a staged change, and a stable key
across a no-op.

### REQ-D1.3 — Green CI counts as evidence [test + manual]

The fixture records a check-run source from a stubbed check-run list and
asserts the lookup hits for that head's tree. Manual: a nested iteration on a
pushed green head reports the full suite as reused from CI.

### REQ-D1.4 — Suite once per iteration, diff-scoped per fix [manual]

The measurement table in Task 10 shows one full-suite entry per nested
iteration and one diff-scoped entry per fix; the baseline column shows more.

### REQ-D1.5 — Never committed or named in a PR body [test]

`git status --porcelain` after a recorded run shows nothing under
`.claude/`, and the contract checker pins the never-committed sentence.

### REQ-D1.6 — Redirect-free writes [test]

The contract checker fails a fixture carrying a `>` or `>>` into the evidence
or inbox paths in a skill or shared file.

### REQ-D1.7 — Layout matches the upstream handoff member [design-level]

The shared reference file names the upstream bundle member it mirrors and
lists each divergence; the seed note (REQ-H1.1) carries the same list.

## REQ-E — Concurrency and isolation

### REQ-E1.1 — Writer lock around writes only [test + manual]

The contract checker pins the lock-taking sentence at the apply, commit and
push steps of each loop and its absence at discovery. Manual: the two-session
drill shows one commit stream.

### REQ-E1.2 — Lock contents and reclaim [test]

The helper's fixture asserts the lock directory carries holder, skill,
worktree and epoch; a second create fails while held; a lock older than the
threshold is reclaimed with a notice naming the previous holder.

### REQ-E1.3 — Inbox handoff with a bounded wait [test + manual]

The fixture asserts an inbox file lands under the holder's name and the
sender returns within the poll window. Manual: the drill's second session
ends with a handoff naming the inbox path.

### REQ-E1.4 — Inbox read at iteration boundaries, data not instructions [test]

The contract checker pins the data-not-instructions sentence and the
boundary-read sentence in each loop, with fixtures planting their removal.

### REQ-E1.5 — Fallback without messaging [manual]

With inbound messages refused in the holder's settings, the sender's inbox
file is still read at the next boundary, and a nudge posted through the
session's inbox socket by the helper arrives.

### REQ-E1.6 — Worktree-free `/code-review` [test + manual]

The contract checker pins the archive-export sentence and fails a fixture
carrying the retired isolated-session stop. Manual: a run from an isolated
worktree session completes through the tooling step with `git worktree list`
unchanged, and two sessions on two PRs run concurrently.

### REQ-E1.7 — Session registry [test]

The fixture asserts a registration carrying name, skill, PR or branch,
worktree and start time exists during the run and is removed on exit.

## REQ-F — planwright steps

### REQ-F1.1 — Tracked catalog linked into the overlay [test + manual]

The link fixture suite passes. Manual: planwright's step resolver in this
repository prints `run` for each named step with the adopter layer as its
catalog source.

### REQ-F1.2 — No adopter-wide list; repo-tracked list committed [test]

The overlay config fixture asserts the tracked sources set no
`steps_<point>` key; `git check-ignore .claude/planwright.yml` exits
non-zero and the file is tracked.

### REQ-F1.3 — bot-review at post-pr only, panel-review never pushes at convergence [test]

The repo-tracked list names `bot-review` under `steps_post_pr` only; the
contract checker pins `/panel-review --nested`'s local-only sentence.

### REQ-F1.4 — Retired knob vocabulary replaced [test]

`grep -rn review_sequence roles/ CLAUDE.md` returns only changelog and spec
lines.

## REQ-G — Credential cleanup

### REQ-G1.1 — Credential directory removed, revoke documented [test + manual]

`ansible-playbook main.yml --list-tasks --tags claude` lists the removal
task and the repo-root `CLAUDE.md` names the revoke step. Manual: a host
holding the directory reports the task changed once and `OK` on the next run.

### REQ-G1.2 — Changed only on removal, nothing else touched [test]

A fixture runs the task against a scratch home with and without the
directory and a sibling credential directory, asserting changed only in the
first case and the sibling untouched.

## REQ-H — Seed for planwright

### REQ-H1.1 — The pending note exists with its items [design-level]

The note exists in the planwright repository's pending-notes directory and
names each required item with the dotfiles decision it came from.

### REQ-H1.2 — No vendor mechanics or private names [test]

The identifier check run over the note on the host that holds the identifier
file reports zero hits; the retired-name sweep finds no reviewer login or
marker syntax.

## REQ-I — Review-run discipline

### REQ-I1.1 — Decision ledger kept [test]

The ledger fixture writes an entry and asserts its fields and the file mode.

### REQ-I1.2 — Re-raise rules [test]

The ledger fixture asserts a same-head re-raise returns the recorded reply
and a later-head re-raise of a declined finding routes to Needs sign-off
with the decline attached.

### REQ-I1.3 — Tracker-linked deferrals, CI cost rejected [test]

The ledger fixture asserts a resolve-without-change lacking a tracker link
halts, and the contract checker pins the CI-cost sentence.

### REQ-I1.4 — Convergence as a fact, every other stop a handoff [test + manual]

The contract checker pins the never-declares-done sentence. Manual: a
`--nested` run that hits diminishing returns ends with a handoff carrying
the ledger, not a convergence claim.

### REQ-I1.5 — Per-push scoped discovery pass [manual]

A `--nested` iteration that pushes carries a lens table over the fix diff in
its loop artifact before the push entry.

### REQ-I1.6 — Staleness re-validation [manual]

A head rewrite mid-loop produces the re-validation notice and a screenshot
refresh flag in the loop artifact.

### REQ-I1.7 — Sibling map as validation context [test + manual]

The renderer suite renders the map template and the contract checker pins
the pass-2 attachment sentence in both skills. Manual: a PR consuming a
mapped producer's shape shows the producer file named in the validation
record.

### REQ-I1.8 — Replies state decision plus evidence [test]

The contract checker pins the one-paragraph decision-plus-evidence sentence
in `/bot-review`'s reply step.
