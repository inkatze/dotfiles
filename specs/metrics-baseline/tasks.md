# Claude Code Usage Metrics Baseline Implementation Status

## Task order

Tasks are ordered by dependency.

### 1. Define the snapshot schema

Write `specs/metrics-baseline/snapshots/SCHEMA.md` describing the required
sections, field names, and definitions for any baseline snapshot. Pulls from
`requirements.md` "Required dimensions" and "Required metrics." The schema
must specify, for every metric, which dimensions it is broken down along
(per-project, per-machine, main-thread vs subagent) so that future
re-measurements diff cleanly.

The schema file is plaintext and committed.

### 2. Set up encryption surface

Create the snapshots directory with the encryption support files:

- `specs/metrics-baseline/snapshots/recipients.txt` — one or more SSH
  public keys (the user's existing keys on the personal and work machines).
  Plaintext, committed.
- `specs/metrics-baseline/snapshots/README.md` — short, plaintext.
  Documents the encrypt and decrypt commands:
  `age -R recipients.txt baseline-YYYY-MM.md > baseline-YYYY-MM.md.age`
  and `age -i ~/.ssh/<key> -d baseline-YYYY-MM.md.age`.
- A pre-commit guard rejecting any staged plaintext `baseline-*.md` file
  under `snapshots/`. A gitignore entry is not sufficient: the guard must
  fail loudly rather than silently drop the file.

### 3. Produce the first snapshot (encrypted)

Walk both `~/.claude/projects/` and any remote history root, including
`<session-id>/subagents/` JSONL files. Compute every metric defined in the
schema, broken down along every required dimension, for the same date
window already covered by `project_usage_analysis` memory
(Mar 3 – Apr 2, 2026), so the first snapshot anchors to numbers the user
has already seen.

Write the plaintext result to a temporary location, encrypt it with
`age -R recipients.txt` to
`specs/metrics-baseline/snapshots/baseline-2026-04.md.age`, then delete
the plaintext intermediate. Include the methodology section inline in the
plaintext before encryption. Acknowledge pre-baseline shipped improvements
(AGENTS.md → CLAUDE.md rename, terraform bump, etc.) under a "Pre-baseline
state" subsection.

A throwaway script is fine; it does not need to be committed. If it is
committed, it lives under `specs/metrics-baseline/scripts/` and is marked
as non-load-bearing. The script must not write the plaintext snapshot to
the snapshots directory at any point; it may write only to a temp location
outside the repo or to stdout piped directly into `age`.

### 4. Verify

Confirm the encrypted file decrypts cleanly with the user's SSH key on at
least one machine, and that the decrypted contents conform to the schema.
Confirm `git status` shows only the `.age` file under `snapshots/`, never
a plaintext `baseline-*.md`.

### 5. Cross-link from the improvement plan

Update the `project_improvement_plan` memory entry with a single line
pointing at `specs/metrics-baseline/snapshots/baseline-2026-04.md.age` as
the reference point for measuring future improvements. This is the only
memory edit this spec performs.

### 6. Commit on a feature branch

Conventional commit, no Claude footer, no co-author, GPG signed.
Example: `docs(spec): add metrics baseline spec and 2026-04 snapshot`. Push
and PR happen as part of the implementation workflow, not this task.

## Dependencies

- **Blocks:** any improvement-plan item whose effect should be measured against
  the baseline. Specifically, the claude-context implementation should not
  ship until the first snapshot exists, otherwise its effect cannot be
  attributed.
- **Blocked by:** nothing.

## Effort

**S** — most of the work is the one-off script to walk the JSONL corpus and
tally the schema fields. The schema and snapshot prose are short.

## Rollback

`git rm -r specs/metrics-baseline/` and revert the memory cross-link line.
No other surfaces are touched.
