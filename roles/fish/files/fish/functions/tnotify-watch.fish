function tnotify-watch -d "Watch for notifications and send via tnotify"
    set -l queue "$HOME/.cache/tnotify.queue"
    set -l pidfile "$HOME/.cache/tnotify.pid"

    # Write PID for detection
    echo %self > "$pidfile"

    # Clean up on exit
    function _tnotify_cleanup --on-signal INT --on-signal TERM --on-process-exit %self
        rm -f "$HOME/.cache/tnotify.pid"
        functions -e _tnotify_cleanup
    end

    echo "tnotify-watch: polling $queue"

    # Poll the queue file
    while true
        if test -s "$queue"
            # Read and process all lines
            while read -l line
                set -l parts (string split \t "$line")
                if test (count $parts) -ge 2
                    tnotify "$parts[1]" "$parts[2]"
                end
            end < "$queue"
            # Clear the queue
            : > "$queue"
        end
        sleep 0.5
    end
end
