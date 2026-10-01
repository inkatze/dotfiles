# planwright's adopter overlay and cross-spec fleet home, for every shell and
# every worker it spawns. Claude Code injects CLAUDE_PLUGIN_DATA only into the
# plugin's own hooks, so a planwright script run as an ordinary tool command
# cannot derive either path and fails to find its fleet state.
#
# Both sit under the plugin-data dir, which is stable across planwright
# upgrades, unlike the versioned install root `tower` resolves at launch.
set -l __pw_data "$HOME/.claude/plugins/data/planwright-planwright"
set -gx PLANWRIGHT_ADOPTER_OVERLAY "$__pw_data/overlay"
set -gx PLANWRIGHT_FLEET_STATE_DIR "$__pw_data/fleet"
