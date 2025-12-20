function tnotify-send -d "Queue a notification for tnotify-watch to send"
    set -l queue "$HOME/.cache/tnotify.queue"

    # Append notification to queue file (non-blocking)
    echo -e "$argv[1]\t$argv[2]" >> "$queue"
end
