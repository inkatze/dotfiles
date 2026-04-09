# Baseline Snapshot Schema

This document defines the fields every `baseline-YYYY-MM.md(.age)` snapshot
must contain. Every field is required unless marked *optional*. Missing data
is recorded as `0` or an empty list, never omitted, so diffs across snapshots
stay structurally comparable.

## Dimensions

Every volume and friction metric below is broken down along **all three**
of these dimensions (not only as a global aggregate):

- `project` — per-project key (e.g. `tecpan`, `paycalc-services`, `dotfiles`).
- `machine` — `personal` | `work`.
- `thread` — `main` | `subagent`. Subagent JSONL under
  `<session-id>/subagents/` counts as `subagent`, never folded into `main`.

A metric shown with ✅ in a column below must be emitted split along that
dimension. Global aggregates may be included *in addition to*, never
*instead of*, the required breakdowns.

## 1. Corpus scope

| Field | Definition |
|---|---|
| `date_range` | Inclusive start/end dates of the window walked. |
| `machines` | List of machines included (`personal`, `work`). |
| `dominant_model` | Most-used model ID across the window. |
| `directories_walked` | Absolute paths walked, explicitly including `<session-id>/subagents/`. |
| `conversation_counts.total` | Total conversation count in window. |
| `conversation_counts.per_project` | Map of project → count. |
| `conversation_counts.per_machine` | Map of machine → count. |
| `conversation_counts.per_thread` | Map of `main`/`subagent` → count. |
| `conversation_counts.daily` | Map of date → count (one entry per day in window). |

Dimensions: project ✅, machine ✅, thread ✅.

## 2. Tool-call volumes

| Field | Definition |
|---|---|
| `tool_calls.total` | Total tool invocations in window. |
| `tool_calls.by_project` | Map of project → count. |
| `tool_calls.by_machine` | Map of machine → count. |
| `tool_calls.by_thread` | Map of `main`/`subagent` → count. |

Dimensions: project ✅, machine ✅, thread ✅.

## 3. Top tools

| Field | Definition |
|---|---|
| `top_tools.main_thread` | Top 10 tools by call count on main thread, as `[{tool, calls}]`. |
| `top_tools.subagent` | Top 10 tools by call count within subagent threads. |

## 4. Per-tool error rate

| Field | Definition |
|---|---|
| `tool_error_rates` | Map of tool → `{calls, errors, error_rate}`. `error_rate = errors / calls`. Normalized so a drop in errors can't be confused with a drop in usage. |

Dimensions: thread ✅ (reported separately for main vs subagent).

## 5. Friction tallies (wasted calls)

| Field | Definition |
|---|---|
| `friction.edit_old_string_mismatch` | Count of Edit calls that failed because `old_string` did not match. Reported as its own line, never folded into a generic "Edit mismatches". |
| `friction.precommit_hook_failures` | Map of hook name → failure count. |
| `friction.push_hook_failures` | Map of hook name → failure count. |
| `friction.file_path_mistakes` | Count of tool calls that failed due to wrong/nonexistent paths. |
| `friction.user_rejections` | Count of tool calls rejected by the user at the permission prompt. |
| `friction.gh_graphql_errors` | Count of `gh api graphql` errors. |
| `friction.other` | Map of category → count for any additional wasted-call categories surfaced. |
| `friction.total_wasted_calls` | Sum of all wasted-call categories. |
| `friction.wasted_share` | `total_wasted_calls / tool_calls.total`. |

Dimensions: project ✅, machine ✅, thread ✅.

## 6. Permission prompts

| Field | Definition |
|---|---|
| `permission_prompts.total` | Total permission prompts shown. |
| `permission_prompts.approved` | Count approved. |
| `permission_prompts.denied` | Count denied. |
| `permission_prompts.by_tool` | Map of tool → `{approved, denied}`. |

Measurement target for improvement-plan items #3 (deny rules) and #4
(permission pruning).

Dimensions: project ✅, machine ✅, thread ✅.

## 7. Stuck-loop sessions

| Field | Definition |
|---|---|
| `stuck_loops.sessions` | Count of sessions containing ≥3 consecutive same-tool calls where each errored. |
| `stuck_loops.by_tool` | Map of tool → session count. |

Dimensions: project ✅, machine ✅, thread ✅.

## 8. Underused features

| Field | Definition |
|---|---|
| `features.agent_share` | `Agent tool calls / tool_calls.total`. |
| `features.plan_mode_invocations` | Count of Plan mode / ExitPlanMode invocations. |
| `features.subagent_invocations_by_type` | Map of subagent type (`Explore`, `Plan`, `general-purpose`, custom names) → count. |
| `features.memory_inventory` | List of memory files present at snapshot time, with size in bytes. |

Dimensions: project ✅, machine ✅ (thread is implicit — Agent calls are main-thread only).

## 9. Slash command usage

| Field | Definition |
|---|---|
| `slash_commands.top` | Top 10 slash commands as `[{command, invocations, successes, success_rate}]`. "Success" = the invocation reached its terminal action (commit landed, PR created, threads resolved) rather than bailing mid-flow. |

Dimensions: project ✅, machine ✅.

## 10. MCP tool usage

| Field | Definition |
|---|---|
| `mcp_usage` | Map of MCP server name (`Gmail`, `GCal`, …) → `{tools: {tool_name: calls}, total_calls}`. |

Dimensions: project ✅, machine ✅.

## 11. Hot-file re-reads

| Field | Definition |
|---|---|
| `hot_files` | Map of project → list of top 20 `{path, session_id, reads}` entries, ranked by re-read count within a single session. |

Signal for whether project-scoped CLAUDE.md files reduce re-reads
(improvement-plan item #11).

Dimensions: project ✅ (inherent), machine ✅.

## 12. Conversation outcomes

| Field | Definition |
|---|---|
| `outcomes.by_session` | Map of session → one of `commit` \| `push` \| `pr` \| `none`. |
| `outcomes.counts` | Map of outcome → count. |
| `outcomes.tool_calls_per_shipped_commit` | Map of project → ratio (`total tool calls / commits landed`). |

Dimensions: project ✅, machine ✅.

## 13. Interaction style indicators

| Field | Definition |
|---|---|
| `interaction.median_user_turns_per_conversation` | Median user turns per conversation. |
| `interaction.median_tool_calls_per_conversation` | Median tool calls per conversation. |
| `interaction.interrupt_rate` | Fraction of conversations containing a user interrupt. |
| `interaction.tool_rejection_rate` | Fraction of tool calls rejected at permission prompt. |

Dimensions: project ✅, machine ✅, thread ✅.

## 14. Optional secondary signals

These are cheap to include and useful as secondary signals, but do not block
a snapshot. Omit the field entirely if not computed.

| Field | Definition |
|---|---|
| `optional.time_of_day_distribution` | Tool-call volume by hour-of-day and day-of-week. |
| `optional.edit_write_file_types` | Map of file extension → Edit/Write call count. |
| `optional.todowrite_task_usage` | Frequency of TodoWrite / Task tool invocations. |
| `optional.tokens_per_session` | Per-session token / cost totals, if JSONL exposes it. |
| `optional.top_user_opener_verbs` | Top 20 first-word frequencies from user messages (e.g. `lets: 372`). |
| `optional.top_bash_patterns` | Top N bash invocation patterns, normalized to leading command + notable flags. **Only permitted while snapshots are encrypted at rest.** If encryption is ever disabled, this field must be removed from the schema rather than emitted in plaintext. |

## 15. Methodology (required narrative section)

Every snapshot ends with a "How this was measured" section recording:

- Directories walked (with absolute paths), explicitly noting inclusion of
  `<session-id>/subagents/` JSONL files.
- Exact date window (inclusive start/end).
- Known caveats or undercounts (e.g. remote history root unreachable,
  truncated sessions).
- Enough detail that a future re-run can reproduce the same numbers given
  the same corpus.
