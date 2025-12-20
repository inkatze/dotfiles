function tnotify-send -d "Queue a notification for tnotify-watch to send"
    set -l fifo "$HOME/.cache/tnotify.fifo"

    if test ! -p "$fifo"
        echo "tnotify-watch is not running. Start it with: tnotify-watch &" >&2
        return 1
    end

    # Write title and message as tab-separated line
    echo -e "$argv[1]\t$argv[2]" > "$fifo"
end
