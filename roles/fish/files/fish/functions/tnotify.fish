function tnotify -d "Terminal notification that works in tmux + SSH"
    if set -q TMUX
        # Write raw OSC 99 directly to the tmux client TTY, bypassing
        # per-pane passthrough routing so the watcher isn't tied to
        # whichever pane originally spawned it.
        set -l client_tty (tmux list-clients -F '#{client_tty}' 2>/dev/null | head -1)
        if test -n "$client_tty"
            kitten notify --only-print-escape-code $argv > "$client_tty"
        end
    else
        kitten notify $argv
    end
end
