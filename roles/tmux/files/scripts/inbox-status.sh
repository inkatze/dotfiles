#!/usr/bin/env bash
# inbox-status.sh — dracula `custom:` slot wrapper for the pair-flow inbox.
#
# The real implementation lives at ~/.claude/scripts/inbox-status.sh
# (tracked at roles/osx/files/claude/scripts/inbox-status.sh, materialized
# via the Symlink Claude hook scripts task in roles/osx/tasks/osx.yml).
# This wrapper exists only so the dracula plugin path stays consistent
# with the existing custom plugin convention (`custom:../../../scripts/...`).
target="$HOME/.claude/scripts/inbox-status.sh"
if [ -x "$target" ]; then
    exec "$target"
fi
# Claude scripts not materialized yet (tmux role applied before the osx role,
# or the symlink temporarily missing): degrade to a placeholder so the dracula
# status slot renders cleanly instead of erroring.
printf 'inbox?'
