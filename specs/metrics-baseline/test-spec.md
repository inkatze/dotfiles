# Claude Code Usage Metrics Baseline Test Specification

## What to verify

There is no automated test surface. Verification is by structural checks
against the schema and a sanity pass against the existing memory numbers.

### Schema conformance

- The decrypted contents of `snapshots/baseline-2026-04.md.age` (for
  example, decrypted to stdout or a temporary location outside
  `snapshots/`) contain every section defined in `snapshots/SCHEMA.md`.
  Missing sections are a failure even if the underlying number is zero.
- Every volume and friction metric is reported along all three required
  dimensions: per-project, per-machine (personal vs work), and main-thread
  vs subagent. A metric reported only as a global aggregate is a failure.
- All required metrics from `requirements.md` are present, including
  per-tool error rate, permission prompts (approve/deny per tool),
  hook failures broken down by hook name, Edit `old_string` mismatch rate,
  slash command success rate, hot-file re-reads, conversation outcomes,
  stuck-loop sessions, subagent type breakdown, and MCP usage.
- The methodology section names every directory walked, including
  `<session-id>/subagents/`, and the exact date window.

### Encryption hygiene

- Only `baseline-*.md.age` files exist under `snapshots/`. No plaintext
  `baseline-*.md` is committed, staged, or present on disk in the
  snapshots directory after the snapshot task completes.
- The pre-commit guard rejects a deliberate test commit attempting to
  stage a plaintext `baseline-*.md` file.
- `recipients.txt` exists in plaintext, contains at least one valid SSH
  public key, and is committed.
- The encrypted snapshot decrypts successfully with the user's SSH private
  key (`age -i ~/.ssh/<key> -d`) on at least one of the user's machines,
  and the decrypted contents pass the schema conformance checks above.
- `SCHEMA.md`, the four spec files, `recipients.txt`, `README.md`, and any
  helper script remain plaintext and reviewable.

### Sanity against memory

The first snapshot's headline numbers must be in the same ballpark as
`project_usage_analysis` and `project_subagent_volume` memory entries:

- Total conversations ≈ 463 for Mar 3 – Apr 2, 2026.
- Subagent share of tool calls ≈ 52%.
- Wasted-call total ≈ 650, ≈ 4% of all tool usage.
- Top subagent tools roughly match: Read, Bash, Grep, Glob.

Order-of-magnitude divergences require investigation before the snapshot is
committed; small drift is expected because the memory numbers were rounded.

### Pre-baseline acknowledgement present

The snapshot's methodology section explicitly lists improvements that
shipped before the baseline window closed (AGENTS.md → CLAUDE.md rename,
terraform bump, any others). Listing zero is acceptable only if zero is true.

### Diff hygiene

The implementation commit touches only files under `specs/metrics-baseline/`,
plus the single cross-link line in the `project_improvement_plan` memory
entry, plus any minimal repo-level hook or ignore configuration needed
solely to enforce the plaintext `baseline-*.md` guard. No other stray
edits to unrelated config, roles, or other specs.

### Re-measurement readiness

A reader who has never seen the source corpus can, from `SCHEMA.md` and the
first snapshot's methodology section alone, reproduce the same numbers given
the same JSONL files. If reproduction requires asking the original author for
context, the methodology section is incomplete.

## Out of scope

- Building or testing an automated metrics pipeline. The first snapshot may
  be produced by a throwaway script.
- Validating the *correctness* of any specific friction category's
  classification logic. The schema defines categories; classification quality
  is a separate, later concern.
- Measuring the effect of improvements. That is what future snapshots are
  for, not this one.
