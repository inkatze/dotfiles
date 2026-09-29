# Workflow choice and handoff

How a review skill walks the operator through what is left to decide.

## Artifact first, projection in the turn

The full record (lens-coverage table, bucket or tier tables, declined log,
pending-sign-off checklist) belongs to the artifact: the PR body, or the audit
file a local-only run writes. In the turn, an empty bucket or lens is one line,
`none: <reason>`; the full tables, `none` rows included, stay in the artifact.

## Choosing how to walk the items

Ask once which way to take the remaining items, unless the handoff rule below
applies:

- **(a) All at once**: the whole list, to re-prioritize, group or bulk-dismiss.
- **(b) One by one**: present an item, discuss, wait for the decision, move on.
- **(c) Batched**: `AskUserQuestion`, up to four items per call, one
  single-select question each.
- **(d) Clustered**: items grouped by a shared decision axis (same fix
  template, same lens, same module), one question per cluster whose answer
  applies to every member. List each cluster's members (file:line and one
  line) before its question. "Pick individually" drops that cluster into (c).

Suggest (c) or (d) when there are about ten items or more. Show a progress
tracker in (b) and (c) (`[2/7]`) and the cluster index in (d)
(`cluster [2/4]: 5 findings`).

## Option sets

- **Needs sign-off**: `Apply / Skip / Modify`; clustered, `Apply all / Skip all
  / Pick individually`. `Skip` covers both leaving it and deferring it.
- **Needs human judgment**: bespoke options per item, the actual decision
  branches. Timing options (now / later / dismiss) are forbidden here; an item
  whose only honest options are timing belongs in Needs sign-off.
- A skill that does not categorize states its own option set.

The auto-added "Other" is the escape hatch, not the default. Acknowledge the
decisions before acting on them.

## Handoff after an autonomous loop

A nested loop hands off a small residue, so skip the "how do you want to walk
these" question and pick the mode from the shape: clusters of three or more
first in (d), the rest in (c), with the progress tracker throughout.
