# MCP server registration

Rationale behind the MCP rules in the repo-root `CLAUDE.md`.

## GitHub, through a sync script

User-scope MCP servers live in `~/.claude.json` under `.mcpServers.<name>`.
`scripts/claude-mcp-sync-github.sh` registers the GitHub server from a PAT
held in 1Password, so the secret never lands in this repo. Its header is the
reference for the idempotency vocabulary (`OK`, `CHANGED`, `FAILED:`), the
env-scoped PAT handling, the atomic write, and the rollback; the item it reads
and the field order are defined in the script.

It runs from `roles/osx/tasks/homebrew.yml` (reached by `mise run install` and
`mise run osx`) and `roles/osx/tasks/upgrade.yml` (reached by
`mise run upgrade`). Both tasks skip under `CI`, and Ansible gates
`changed_when` on `CHANGED` so a PAT rotation surfaces as one changed step.

Both assume an authenticated `op` session on non-CI machines. The strict
failure on a locked vault is deliberate: a silent skip would let a stale PAT
land unnoticed.

## Slack, by hand

`/code-review` and `/peer-review` DM the person on the other end of a PR
through a Slack MCP server, and nothing in this repo provisions it. That is a
choice: the notification is a courtesy the skills are built to do without
(a missing server means "say so once and carry on"), and automating a
registration used by two skills on one machine would add another 1Password
item and CI-guarded task pair to maintain. If more than one machine ever wants
it, mirror the GitHub layout above rather than copying the registration
around.
