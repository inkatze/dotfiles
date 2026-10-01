function tower --description 'Launch the planwright tower under its tower permission profile'
    # Newest installed version, resolved at launch like worker-guard-gate.sh
    # does, so a planwright upgrade needs nothing regenerated here.
    # `set` is the one place an unmatched glob is silently empty rather than
    # an error.
    set -l roots $HOME/.claude/plugins/cache/planwright/planwright/*/
    set -l root (string trim --right --chars=/ -- (printf '%s\n' $roots | sort -V | tail -n 1))
    if test -z "$root"
        printf 'tower: no planwright install under %s; refusing to launch without the tower profile\n' \
            "$HOME/.claude/plugins/cache/planwright/planwright" >&2
        return 1
    end

    # Fail closed: the profile's deny block is the tower's security floor, and
    # a tower started without it runs with nothing looking wrong.
    set -l settings "$root/config/tower-settings.json"
    if not test -f "$settings"
        printf 'tower: %s is missing; refusing to launch without the tower profile\n' "$settings" >&2
        return 1
    end

    # The profile's hook command names ${CLAUDE_PLUGIN_ROOT}, which Claude Code
    # injects for plugin-declared hooks but not for a --settings file.
    set -lx CLAUDE_PLUGIN_ROOT "$root"
    claude --settings "$settings" /planwright:tower $argv
end
