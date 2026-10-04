---
name: peer-review
description: Review and address unresolved peer review threads on the current PR.
disable-model-invocation: true
---

Review and address unresolved peer review threads on the current PR.

This is a human reviewer, so take extra care with response quality and tone.
Nothing is posted to them without my approval of the exact text: every reply
waits for a yes.

## Steps

### 1. Resolve the doctrine and get PR and repo info

Resolve planwright's review doctrine per
[doctrine.md](../review-shared/doctrine.md), then:

```bash
gh pr view --json number -q '.number'
gh repo view --json owner,name -q '.owner.login + " " + .name'
```

### 2. (Optional) Jira context

Extract a Jira ticket key from the branch name or PR title. If one is found and
Jira tools are available, fetch it and note the description and acceptance
criteria for use while validating (a concern might be out of scope, or a check
might be required by the AC). Otherwise skip this step.

### 3. Fetch unresolved review threads

Take the same-PR lock, keyed `peer-review`, and fetch the threads per
[github.md](../review-shared/github.md). Refresh the lock before the walk in
step 6 and again after it, before the first push, reply or resolve; release
it at the end of the run. Keep threads where `isResolved` is false and the
first comment's author is not a `Bot`:

```bash
jq '[.[].data.repository.pullRequest.reviewThreads.nodes[]
     | select(.isResolved == false and .comments.nodes[0].author.__typename != "Bot")]'
```

Bot threads belong to `/copilot-review` or `/bot-review`; human tone is wrong
for a bot. A bot that neither handles (CodeQL, a dependency bot) is left to be
handled by hand, which beats applying the wrong workflow's tone.

### 4. Validate each thread

Read the whole thread, the source at the referenced location, and the
reviewer's likely intent. Then apply validation-rigor's three passes. Classify
each as **valid**, **false positive**, **preference**, or **low-confidence**
(passes did not converge; never guess). For a preference, surface the
trade-off rather than asserting correctness.

### 5. Present the validated threads

Record them in finding-categorization's four tables, in fixed order, in the
artifact; in the turn, an empty bucket is one line per
[workflow.md](../review-shared/workflow.md). Columns:

| # | Thread ID | File:Line | Reviewer's concern | What we found | Classification | Validation passes | Proposed action | Draft response |
|---|---|---|---|---|---|---|---|---|

- **Auto-applicable**: tool-grounded and mechanical; the draft is usually
  "Done in `<sha>`".
- **Agent-resolvable**: only with an active kickoff brief and a
  failing-then-passing test, per finding-categorization.
- **Needs sign-off**: one recommended action (fix, dismiss with reasons, or
  acknowledge a preference) and its draft reply.
- **Needs human judgment**: add `Why ambiguous` and `Options` (the actual
  branches).

No lens-coverage table: this skill validates existing threads and runs no
discovery pass (a full-diff sweep belongs in `/self-review`).

### 6. Address items

Walk the items per [workflow.md](../review-shared/workflow.md). Every reply,
including a terse "Done in `<sha>`" on a mechanical fix, is shown to me and
posts only on my yes.

**Response tone** (this goes to a person):
- Concise but not curt
- Acknowledge good points genuinely
- When disagreeing, explain the reasoning without being defensive
- "I" not "we" unless it is a team decision
- No corporate speak, no filler, no em-dashes
- Sound like me writing it

A thread that leads to a code change gets validation-rigor's solution
validation; for a non-testable change, say in the reply why no test was added.

### 7. Commit and push

Commit and push the changes before any reply describes them. On a hook
failure, follow the push-hook rule in [github.md](../review-shared/github.md).

### 8. Reply to and resolve each approved thread

Per [github.md](../review-shared/github.md): reply to each thread with the
approved text through the posted-body rule, rescue any pending review once
after the batch, then resolve each thread.

### 9. Tell each reviewer their comments are addressed

Optional and non-blocking, per [slack.md](../review-shared/slack.md). One
message per reviewer whose threads were replied to, sent after their replies
are posted and resolved; a reviewer with no threads in this run gets nothing.
There is deliberately no start-of-pass message: reviewers wait on the result,
not on the start.

**All threads handled**
```
addressed your comments on #<number> :white_check_mark:
<n> replied · <n> with fixes in <sha>

– clanky
```

**Some left open**
```
went through your comments on #<number> :warning:
<n> replied · <n> left open, they need a call from you

– clanky
```

Use the second whenever any thread of theirs is still open after step 8,
skipped or deferred items included: claiming done-ness while their thread
sits unanswered invites a re-review of something that is not ready. Drop the `<sha>` clause when no code
changed. Each message is confirmed separately, since each goes to a separate
person.

$ARGUMENTS
