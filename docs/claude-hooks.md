# Claude hooks this repo installs, and the ones it does not

Rationale behind the hook rules in the repo-root `CLAUDE.md`.

## Worktree bootstrap

`roles/claude/files/scripts/worktree-bootstrap.sh` runs on `SessionStart`. Its
header is the reference for what it does (mise trust, a background dependency
install keyed on lockfile and project-file pairs, the per-repo
`.claude/worktree-bootstrap` extension), the marker state machine, the log
path, and how to force a re-run. A failed run removes the marker so the next
session retries. In a primary checkout it is a silent no-op by design.

The per-repo script runs with no sandboxing, so opening Claude in an
untrusted checkout executes whatever it contains. Same trust model as
`mise trust`: inspect the script before opening a repo you did not author.

## planwright's hooks

planwright wires its own hooks through the plugin's `hooks/hooks.json`,
resolved against `CLAUDE_PLUGIN_ROOT` (among them `tool-discovery` on
SessionStart and `tasks-pr-sync` on PostToolUse). Wiring any of them again in
the tracked `settings.json` would double-fire them. `tool-discovery` is a
silent no-op when nothing is detected, outside a git work tree, or without
`jq`, so a missing summary does not necessarily mean "no tooling found".

## Worker guard gate

`roles/claude/files/scripts/worker-guard-gate.sh` runs on `PreToolUse(Bash)`
and delegates to planwright's `worker-command-guard.sh`, which auto-approves
the routine commands a dispatched fleet worker runs. Its header covers the env
gate and the exec-time plugin resolution.

It is user-scope on purpose: the script exits 0 immediately unless
`PLANWRIGHT_WORKER_HANDLE` is set, so an interactive or tower session gets no
widened permissions. It used to sit in a per-project, gitignored
`.claude/settings.local.json`, so every freshly created worktree started
without it and escalated every routine worker command to the operator. The
SessionStart bootstrap cannot fix that from its side: settings are read at
process startup, so anything it writes lands too late for the session that
just started.

`scripts/claude-settings-merge.sh` rebuilds the entries this repo owns from
the tracked file on every run, so dropping the `Read|Edit|Write` entry there
silently unwires `path-guard`. Hooks other tools install on the same event are
preserved. On an event the tracked file declares, ours exist only as long as
it lists them; an event key it drops is left as it was, ours included.
