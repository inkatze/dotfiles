# planwright's adopter overlay and cross-spec fleet home, for every shell and
# every worker it spawns. Claude Code injects CLAUDE_PLUGIN_DATA only into the
# plugin's own hooks, so a planwright script run as an ordinary tool command
# cannot derive either path and fails to find its fleet state.
#
# Both sit under the plugin-data dir, which is stable across planwright
# upgrades, unlike the versioned install root `tower` resolves at launch.
#
# A value the caller already set wins: planwright reads both as an explicit
# override, and a test or harness pointing them at a scratch dir would
# otherwise be sent back to the real fleet state by every `fish -c` it runs.
set -l __pw_data "$HOME/.claude/plugins/data/planwright-planwright"
test -n "$PLANWRIGHT_ADOPTER_OVERLAY"; or set -gx PLANWRIGHT_ADOPTER_OVERLAY "$__pw_data/overlay"
test -n "$PLANWRIGHT_FLEET_STATE_DIR"; or set -gx PLANWRIGHT_FLEET_STATE_DIR "$__pw_data/fleet"
