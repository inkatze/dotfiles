# Review Skills — Test Spec

**Status:** Ready
**Last reviewed:** 2026-10-08
**Format-version:** 2
**Execution:** derived — see the status render

Coverage mix: `[test]` wherever a fixture suite or the contract checker can
pin the behaviour deterministically, run by the CI workflow job able to run
it (the shell-only job for pure fixtures, the job that installs Ansible for
role fixtures) on every pull request and push to `main`, and by lefthook
before each commit; `[manual]` for everything that needs a real PR,
a real reviewer, a second session or a host with 1Password signed in,
recorded in Task 10's verification table; `[design-level]` where the
artifact's existence and content is the verification. A requirement that
cannot be verified on a given host is recorded as unverified with its
reason, never marked passed by inference. Two ownership rules: every
fixture suite a task creates is wired into the CI workflow's job list and
into `lefthook.yml` by that same task, since both name each suite
explicitly; and a
`[test]` entry that names a command rather than a fixture (a `grep`, a
`git check-ignore`, a `git status`) is the owning task's branch Done-when, run
from the worktree by the executor and recorded in the task PR. The
identifier check is never CI: it runs by hand on the host that holds the
identifier file.

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

### REQ-A1.3 — Default reviewer and no vendor mechanics in tracked files [test + manual + design-level]

The contract checker's retired-name sweeps report zero hits for the retired
skill and backend names over the skills tree and the templates, and the
template's vendor-specific values are all `op://` references (a fixture
plants a literal and fails); manual: the identifier check, run on the host
that holds the identifier file, reports zero hits for reviewer logins,
marker syntax, comment commands and check names over the same surfaces and
this bundle; the rendered config's `default` names the cubic.dev entry
(design-level: the template declares it).

### REQ-A1.4 — Draft policy stated, never waited on [manual]

`/bot-review` against a draft PR under a reviewer whose policy skips drafts
prints the policy and the repository-side setting and exits its wait without
polling.

### REQ-A1.5 — Incremental re-request after a push [manual]

A `--nested` iteration that pushes a fix issues the incremental form of the
re-request (observed in the PR's comment or reviewer-request timeline), and
the first request of the run issues the full form.

### REQ-A1.6 — Version key on every machine-local file [test]

The renderer suite, the helper's fixture and the ledger fixture each feed a
file carrying an unknown version and assert the refusal names the file and
the version; a file with no version key is refused the same way.

## REQ-B — Retire `/copilot-review`

### REQ-B1.1 — Skill removed, generic mechanics kept [test + manual]

`grep -rn copilot-review roles/ CLAUDE.md` returns only lines recording the
retirement, and the contract checker pins the generic baseline,
errored-review, suppression-disposition and diminishing-returns sentences in
`/bot-review`. Manual: a `--nested` run on a PR with an errored review skips
it and pins its baseline to the reviewed head.

### REQ-B1.2 — Never mark ready [test]

The contract checker pins `/bot-review`'s never-mark-ready sentence, with a
fixture planting its removal; no file under the skills tree carries a
mark-ready offer.

### REQ-B1.3 — Peer-review routes bot threads [test]

The contract checker pins the routing sentence in `/peer-review` and
asserts that file names no entry of the committed template.

### REQ-B1.4 — References removed, budgets re-derived [test]

The contract checker and budget guard pass on the branch; the budget suite's
formula check matches every touched row.

### REQ-B1.5 — Copilot CLI backend removed [test]

The retired-backend sweep fails a fixture planting the backend name in a
skill file; no Brewfile, mise file or package list names the cask, pin or
package; the contract checker pins the stop-and-name-the-replacement
sentence for the retired backend and skill names.

## REQ-C — The cubic.dev CLI as a reviewer backend

### REQ-C1.1 — Runs through `reviewer:<name>` [test + manual]

The contract checker's backend-set pin lists no new backend kind. Manual:
`/panel-review --backends reviewer:cubic` resolves the entry's `cli` block
and produces findings rows.

### REQ-C1.2 — mise pin and opt-outs [test + manual]

The cross-platform tracked mise file names the CLI with a version, and the
contract checker pins the opt-out variables in the invocation template.
Manual: after a run, `git notes list` in the reviewed repository is unchanged
from before it and the binary's version is unchanged.

### REQ-C1.3 — Key synced and passed at invocation only [test + manual]

The key sync's fixture refuses a key file at a loose mode and a blank value;
`grep -rn CUBIC roles/fish` returns nothing. Manual: the key variable is
listed in `env_allow`, its value reaches the CLI on the backend's pipe, and it
appears on no process's argv, the `env -i` line included; a shell started
after the sync does not export it. *(Amended at execute-task review
(Task 5) 2026-10-05: the key arrives on a pipe, never an argv.)*

### REQ-C1.4 — mise shims stripped structurally [test]

A fixture places a mise shims directory and a repo-steered mise config on
the path and asserts the backend's resolved `PATH` carries neither and the
CLI resolves from `HOME`.

### REQ-C1.5 — No bare positional parameters [test]

The contract checker fails a fixture carrying a bare `$1` in a skill file,
including inside an awk program, and passes the rewritten backend snippet;
helper scripts under the scripts directory are outside the sweep.

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
untracked file is added, a miss after a staged change, a stable key across
a no-op, and that CI evidence is recorded under the repository's declared
test-task key so the local full-suite lookup hits it.

### REQ-D1.3 — Green CI counts as evidence [test + manual]

The fixture records a check-run source from a stubbed check-run list and
asserts the lookup hits for that head's tree; a list with a skipped run
beside a success still hits, and a list with a failed run, a run not yet
concluded, a cancelled run, or only skipped runs, misses. Manual: a nested
iteration on a pushed green head reports the full suite as reused from CI.

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

The contract checker pins the lock-taking sentence at the apply, commit,
push, review-submission, reply, resolve and ledger-write steps of every
skill (`/peer-review` and `/code-review` included), its absence at
discovery, and the branch-to-PR handover sentence. Manual: the two-session
drill shows one commit stream and one reply per thread.

### REQ-E1.2 — Lock contents and reclaim [test]

The helper's fixture asserts the lock link's target is the owner token
naming the session process found by the ancestry walk from a child shell,
and holder, skill and worktree are recorded beside it; a second create
fails while held; a lock whose owner process is gone is reclaimed with a
notice naming the previous holder and its inbox files, which are removed;
a live holder's lock is kept whatever its age; a repository, PR or branch
segment outside the plain-name charset is encoded before any path use.

### REQ-E1.3 — Inbox handoff with a bounded wait [test + manual]

The fixture asserts an inbox file lands under the holder's name, the sender
returns within the poll window, and the sender takes a lock that frees
within the window. Manual: the drill's second session ends with a handoff
naming the inbox path.

### REQ-E1.4 — Inbox read at iteration boundaries, data not instructions [test]

The contract checker pins the data-not-instructions sentence, the
boundary-read sentence in each loop and the read-before-release sentence in
each single-pass skill, with fixtures planting their removal; the helper's
fixture asserts a read inbox file is moved aside and not returned by the
next read.

### REQ-E1.8 — Socket nudge only from a sender that cannot send [test + manual]

The contract checker pins the shared state file's sentences that a "Not
sent" result naming the holder's inbound controls counts as a refusal and
that a refused or held message gets no socket nudge, with a fixture planting
the removal of each; the helper's fixture asserts the nudge posts only to a
socket the user owns. Manual, both sessions on Claude Code 2.1.224 or later
(`claude --version`, recorded in the drill row):

- *Socket-nudge drill.* A sender whose session lacks the SendMessage tool,
  confirmed before the handoff, nudges a holder that accepts messages; the
  holder's transcript shows the nudge naming the inbox file. A post the
  helper reports as failed is recorded as the drill's outcome and filed as
  an observation about the line format, not as a REQ-E1.8 failure.
- *Refused-messaging drill.* A sender that can send messages hands off to a
  holder whose `crossSessionInbound` is `refuse`; the sender's transcript
  shows the send's result and no nudge call after it, its handoff says no
  socket nudge was sent, and the holder's inbox file is read at its next
  boundary.

### REQ-E1.6 — Worktree-free `/code-review` [test + manual]

The contract checker pins the archive-export sentence and fails a fixture
carrying the retired isolated-session stop. Manual: a run from an isolated
worktree session completes through the tooling step with `git worktree list`
unchanged, and two sessions on two PRs run concurrently.

### REQ-E1.7 — Session registry [test]

The fixture asserts a registration carrying name, skill, PR or branch,
worktree, start time and the session process id exists during the run, is
removed on exit, is read as gone when its owner process is absent, and is
removed at the next reclaim.

## REQ-F — planwright steps

### REQ-F1.5 — Tracked catalog installed as a managed copy in the overlay [test + manual]

The copy fixture suite passes: a copy is written when the destination and
`catalogs/` are absent; an identical marked copy reports no change; a marked
copy is rewritten when its source changes; an unmarked file, a symlink to a
marked file, and a `catalogs/` that is a symlink or a regular file each fail
the run naming the path, with nothing written through them; check mode makes
the same decisions without writing; the role's own copy is removed when the
source is gone, and an unmarked file is left in place then. Manual:
planwright's step resolver, run unattended with its explain flag in this
repository, prints `run` for each named step with the adopter layer as its
catalog source.

### REQ-F1.2 — No adopter-wide list; repo-tracked list committed [test]

The renderer suite asserts the Claude role's overlay template sets no
`steps_<point>` key; `git check-ignore --no-index .claude/planwright.yml`
exits non-zero and the file is tracked; `git check-ignore .claude/worktrees`
exits zero.

### REQ-F1.3 — bot-review at post-pr only, panel-review never pushes at convergence [test]

The repo-tracked list names `bot-review` under `steps_post_pr` only; the
contract checker pins `/panel-review --nested`'s local-only sentence.

### REQ-F1.4 — Retired knob vocabulary replaced [test]

`grep -rn review_sequence roles/ CLAUDE.md` returns only lines recording
the knob's retirement.

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

### REQ-H1.2 — No vendor mechanics or private names [manual + design-level]

Manual: the identifier check run over the note on the host that holds the
identifier file reports zero hits. Design-level: a read of the note against
the schema's mechanics fields (login pattern, marker syntax, comment
command, check name) finds none quoted.

## REQ-I — Review-run discipline

### REQ-I1.1 — Decision ledger kept [test]

The ledger fixture writes an entry and asserts its fields (every
disposition kind, suppression included), its version key and the file mode;
the contract checker pins the never-pruned sentence.

### REQ-I1.2 — Re-raise rules [test]

The ledger fixture asserts a same-head re-raise returns the recorded reply,
a later-head re-raise of a rejected finding routes to Needs sign-off with
the rejection attached, and a re-raise of a fixed finding is returned as new.

### REQ-I1.3 — Follow-up-linked deferrals, CI cost rejected [test]

The ledger fixture asserts a deferral lacking a follow-up link halts and a
rejection lacking one does not, and the contract checker pins the CI-cost
sentence.

### REQ-I1.4 — Convergence as a fact, every other stop a handoff [test + manual]

The contract checker pins the never-declares-done sentence and the
convergence definition (no unresolved thread and reviewed head equal to
head). Manual: a `--nested` run that hits diminishing returns ends with a
handoff carrying the ledger, not a convergence claim.

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
