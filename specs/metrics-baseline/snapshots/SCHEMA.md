# Baseline Snapshot Schema

This document defines the fields every `baseline-YYYY-MM.md(.age)` snapshot
must contain. Every field is required unless marked *optional*. Required
(non-optional) fields are never omitted; if required data is missing, record
it as `0` or an empty list so diffs across snapshots stay structurally
comparable.

## Dimensions

Every volume and friction metric in this schema must be emitted split along
all three dimensions:

- `project` — per-project key (e.g. `tecpan`, `paycalc-services`, `dotfiles`).
- `machine` — `personal` | `work`.
- `thread` — `main` | `subagent`. Subagent JSONL under
  `<session-id>/subagents/` counts as `subagent`, never folded into `main`.

Section-level `Dimensions:` lines and corresponding `by_*` fields document
the required breakdown representations for each metric. Global
aggregates may be included *in addition to* these required breakdowns, but
never as a substitute for them. A volume or friction metric reported only as
a global aggregate is incomplete.

## 1. Corpus scope

| Field | Definition |
|---|---|
| `date_range` | Inclusive start/end dates of the window walked. |
| `machines` | List of machines included (`personal`, `work`). |
| `dominant_model` | Most-used model ID across the window. |
| `directories_walked` | Absolute paths walked, explicitly including `<session-id>/subagents/`. |
| `conversation_counts.total` | Total conversation count in window. |
| `conversation_counts.by_project` | Map of project → count. |
| `conversation_counts.by_machine` | Map of machine → count. |
| `conversation_counts.by_thread` | Map of `main`/`subagent` → count. |
| `conversation_counts.daily` | Map of date → count (one entry per day in window). |
| `conversation_counts.daily.by_project` | Map of project → map of date → count (one entry per day in window per bucket; use `0` for zero-days). |
| `conversation_counts.daily.by_machine` | Map of machine → map of date → count (one entry per day in window per bucket; use `0` for zero-days). |
| `conversation_counts.daily.by_thread` | Map of `main`/`subagent` → map of date → count (one entry per day in window per bucket; use `0` for zero-days). |

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
| `top_tools.by_thread.main` | Top 10 tools by call count on main thread, as `[{tool, calls}]`. |
| `top_tools.by_thread.subagent` | Top 10 tools by call count within subagent threads, same shape. |
| `top_tools.by_project` | Map of project → top 10 `[{tool, calls}]` for that project. |
| `top_tools.by_machine` | Map of machine → top 10 `[{tool, calls}]` for that machine. |

Dimensions: project ✅, machine ✅, thread ✅.

## 4. Per-tool error rate

The entry shape everywhere in this section is `{calls, errors, error_rate}`
where `error_rate = errors / calls` when `calls > 0`; when `calls = 0`, emit
`{calls: 0, errors: 0, error_rate: 0}` to avoid `NaN`/`Infinity` while
keeping snapshots structurally comparable. Normalized so a drop in errors
can't be confused with a drop in usage.

| Field | Definition |
|---|---|
| `tool_error_rates.by_thread.main` | Map of tool → entry, for main-thread calls. |
| `tool_error_rates.by_thread.subagent` | Map of tool → entry, for subagent-thread calls. |
| `tool_error_rates.by_project` | Map of project → map of tool → entry. |
| `tool_error_rates.by_machine` | Map of machine → map of tool → entry. |

Dimensions: project ✅, machine ✅, thread ✅.

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
| `friction.wasted_share` | `total_wasted_calls / tool_calls.total`; emit `0` when `tool_calls.total = 0`. |
| `friction.by_project` | Map of project → `{<same category fields as above>, total_wasted_calls, wasted_share}`. `wasted_share` uses that project's `tool_calls.by_project` denominator; emit `0` when the denominator is `0`. |
| `friction.by_machine` | Map of machine → same shape as `friction.by_project`, using the corresponding `tool_calls.by_machine` denominator. |
| `friction.by_thread` | Map of `main`/`subagent` → same shape, using the corresponding `tool_calls.by_thread` denominator. Subagent friction is never folded into main. |

Dimensions: project ✅, machine ✅, thread ✅.

## 6. Permission prompts

| Field | Definition |
|---|---|
| `permission_prompts.total` | Total permission prompts shown. |
| `permission_prompts.approved` | Count approved. |
| `permission_prompts.denied` | Count denied. |
| `permission_prompts.by_tool` | Map of tool → `{approved, denied}`. |
| `permission_prompts.by_project` | Map of project → `{total, approved, denied, by_tool}`. |
| `permission_prompts.by_machine` | Map of machine → `{total, approved, denied, by_tool}`. |
| `permission_prompts.by_thread` | Map of `main`/`subagent` → `{total, approved, denied, by_tool}`. |

Measurement target for improvement-plan items #3 (deny rules) and #4
(permission pruning).

Dimensions: project ✅, machine ✅, thread ✅.

## 7. Stuck-loop sessions

| Field | Definition |
|---|---|
| `stuck_loops.sessions` | Count of sessions containing ≥3 consecutive same-tool calls where each errored. |
| `stuck_loops.by_tool` | Map of tool → session count. A session increments every tool bucket for which it contains at least one qualifying stuck-loop run; multiple runs of the same tool in one session count once. Therefore `sum(by_tool.values())` may exceed `stuck_loops.sessions`. |
| `stuck_loops.by_project` | Map of project → `{sessions, by_tool}`. |
| `stuck_loops.by_machine` | Map of machine → `{sessions, by_tool}`. |
| `stuck_loops.by_thread` | Map of `main`/`subagent` → `{sessions, by_tool}`. |

Dimensions: project ✅, machine ✅, thread ✅.

## 8. Underused features

| Field | Definition |
|---|---|
| `features.agent_share` | `Agent tool calls / tool_calls.total`; emit `0` when `tool_calls.total = 0`. |
| `features.plan_mode_invocations` | Count of Plan mode / ExitPlanMode invocations. |
| `features.subagent_invocations_by_type` | Map of subagent type (`Explore`, `Plan`, `general-purpose`, custom names) → count. |
| `features.memory_inventory` | List of memory files present at snapshot time, with size in bytes. |
| `features.by_project` | Map of project → `{agent_share, plan_mode_invocations, subagent_invocations_by_type}`. |
| `features.by_machine` | Map of machine → same shape as `features.by_project`. |
| `features.by_thread` | Map of `main`/`subagent` → same shape as `features.by_project`. Emit `0`, `{}`, or `[]` for fields that are not applicable on a given thread so snapshots remain structurally comparable. |

Dimensions: project ✅, machine ✅, thread ✅.

## 9. Slash command usage

| Field | Definition |
|---|---|
| `slash_commands.top` | Top 10 slash commands as `[{command, invocations, successes, success_rate}]`. "Success" = the invocation reached its terminal action (commit landed, PR created, threads resolved) rather than bailing mid-flow. |
| `slash_commands.by_project` | Map of project → top 10 `[{command, invocations, successes, success_rate}]`. |
| `slash_commands.by_machine` | Map of machine → top 10, same shape. |
| `slash_commands.by_thread` | Map of thread (`main`, `subagent`) → top 10, same shape. If slash commands cannot be invoked from subagents, emit `subagent` as an explicit empty list so snapshots remain structurally comparable. |

Dimensions: project ✅, machine ✅, thread ✅.

## 10. MCP tool usage

| Field | Definition |
|---|---|
| `mcp_usage` | Map of MCP server name (`Gmail`, `GCal`, …) → `{tools: {tool_name: calls}, total_calls}`. |
| `mcp_usage.by_project` | Map of project → same shape as `mcp_usage`. |
| `mcp_usage.by_machine` | Map of machine → same shape as `mcp_usage`. |
| `mcp_usage.by_thread` | Map of thread (`main` \| `subagent`) → same shape as `mcp_usage`. Emit both keys; if no subagent MCP calls occurred, `subagent` is still present with zero-valued counts / empty maps. |

Dimensions: project ✅, machine ✅, thread ✅.

## 11. Hot-file re-reads

| Field | Definition |
|---|---|
| `hot_files` | Map of project → list of top 20 `{path, session_id, reads}` entries, ranked by re-read count within a single session. |
| `hot_files.by_machine` | Map of machine → map of project → top 20, same entry shape. |
| `hot_files.by_thread` | Map of thread (`main` \| `subagent`) → map of project → top 20, same entry shape. Include subagent-session re-reads under `subagent`; never fold them into `main`. |

Signal for whether project-scoped CLAUDE.md files reduce re-reads
(improvement-plan item #11).

Dimensions: project ✅ (inherent), machine ✅, thread ✅.

## 12. Conversation outcomes

| Field | Definition |
|---|---|
| `outcomes.by_session` | Map of session → one of `commit` \| `push` \| `pr` \| `none`. |
| `outcomes.counts` | Map of outcome → count. |
| `outcomes.counts.by_project` | Map of project → map of outcome → count. |
| `outcomes.counts.by_machine` | Map of machine → map of outcome → count. |
| `outcomes.tool_calls_per_shipped_commit` | Map of project → ratio (`total tool calls / commits landed`); if `commits landed = 0` for a project in the window, emit `0` for that project rather than omission, `Infinity`, or `NaN`. |
| `outcomes.counts.by_thread` | Map of `main`/`subagent` → map of outcome → count. Shipped outcomes (`commit`, `push`, `pr`) are attributed to `main`; `subagent` rows are still emitted and will typically be all zeros except `none`, because subagent JSONL does not independently ship commits, pushes, or PRs. |
| `outcomes.tool_calls_per_shipped_commit.by_machine` | Map of machine → map of project → ratio, same zero-denominator rule. |
| `outcomes.tool_calls_per_shipped_commit.by_thread` | Map of `main`/`subagent` → map of project → ratio, same zero-denominator rule. Subagent-thread rows cover tool calls made inside `<session-id>/subagents/` JSONL; emit `0` when no shipped commits are attributable. |

Dimensions: project ✅, machine ✅, thread ✅.

## 13. Interaction style indicators

| Field | Definition |
|---|---|
| `interaction.median_user_turns_per_conversation` | Median user turns per conversation. |
| `interaction.median_tool_calls_per_conversation` | Median tool calls per conversation. |
| `interaction.interrupt_rate` | Fraction of conversations containing a user interrupt. |
| `interaction.tool_rejection_rate` | Fraction of tool calls rejected at permission prompt. |
| `interaction.by_project` | Map of project → `{median_user_turns_per_conversation, median_tool_calls_per_conversation, interrupt_rate, tool_rejection_rate}`. |
| `interaction.by_machine` | Map of machine → same shape as `interaction.by_project`. |
| `interaction.by_thread` | Map of `main`/`subagent` → same shape. Subagent-thread rows cover tool calls made inside `<session-id>/subagents/` JSONL. |

Dimensions: project ✅, machine ✅, thread ✅.

## 14. Token and cost per session

| Field | Definition |
|---|---|
| `tokens_cost.input_tokens_per_session` | Per-session input token count. |
| `tokens_cost.output_tokens_per_session` | Per-session output token count. |
| `tokens_cost.cost_per_session` | Per-session dollar cost. If the JSONL corpus does not expose per-session cost directly, record a duration-based proxy and note the proxy in the methodology section. |
| `tokens_cost.by_project` | Map of project → `{input_tokens_per_session, output_tokens_per_session, cost_per_session}`. |
| `tokens_cost.by_machine` | Map of machine → same shape. |
| `tokens_cost.by_thread` | Map of `main`/`subagent` → same shape. |

Dimensions: project ✅, machine ✅, thread ✅.

## 15. Optional secondary signals

These are cheap to include and useful as secondary signals, but do not block
a snapshot. Omit the field entirely if not computed.

| Field | Definition |
|---|---|
| `optional.time_of_day_distribution` | Tool-call volume by hour-of-day and day-of-week. |
| `optional.edit_write_file_types` | Map of file extension → Edit/Write call count. |
| `optional.todowrite_task_usage` | Frequency of TodoWrite / Task tool invocations. |
| `optional.top_user_opener_verbs` | Top 20 first-word frequencies from user messages (e.g. `lets: 372`). |
| `optional.top_bash_patterns` | Top N bash invocation patterns, normalized to leading command + notable flags. **Only permitted while snapshots are encrypted at rest.** If encryption is ever disabled, this field must be removed from the schema rather than emitted in plaintext. |

## 16. Methodology (required narrative section)

Every snapshot ends with a "How this was measured" section recording:

- Directories walked (with absolute paths), explicitly noting inclusion of
  `<session-id>/subagents/` JSONL files.
- Exact date window (inclusive start/end).
- Known caveats or undercounts (e.g. remote history root unreachable,
  truncated sessions).
- Enough detail that a future re-run can reproduce the same numbers given
  the same corpus.
