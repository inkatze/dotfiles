function tower --description 'Launch the planwright tower under its tower permission profile'
    # claude keeps the last --settings it is given, so passing one through
    # would replace the profile rather than add to it; the others switch the
    # permission layer or its hooks off outright.
    for arg in $argv
        if string match -qr -- '^--(settings|permission-|bare|dangerously-|allow-dangerously-)' $arg
            printf 'tower: refusing %s, which would replace or disable the tower profile\n' $arg >&2
            return 1
        end
    end

    # Newest installed version, resolved at launch so a planwright upgrade
    # needs nothing regenerated here.
    # Only version-named directories count, and not one Claude Code has marked
    # orphaned: it keeps superseded versions on disk, so the newest name there
    # is not necessarily the version it loads.
    set -l cache $HOME/.claude/plugins/cache/planwright/planwright
    set -l versions
    # `for` is one of the places an unmatched glob is silently empty rather
    # than an error.
    for dir in $cache/*/
        set -l v (string replace -r '.*/([^/]+)/$' '$1' -- $dir)
        string match -qr '^[0-9]+(\.[0-9]+)*$' -- $v; or continue
        test -e "$cache/$v/.orphaned_at"; and continue
        set -a versions $v
    end
    # Sorted on the bare name: a trailing slash changes what -V compares.
    set -l newest (printf '%s\n' $versions | sort -V | tail -n 1)
    if test -z "$newest"
        printf 'tower: no live planwright install under %s; refusing to launch without the tower profile\n' \
            "$cache" >&2
        return 1
    end
    set -l root "$cache/$newest"

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
