function tnotify-watch -d "Watch for notifications and send via tnotify"
    set -l fifo "$HOME/.cache/tnotify.fifo"

    # Clean up old FIFO if it exists
    test -e "$fifo"; and rm -f "$fifo"

    # Create the FIFO
    mkfifo "$fifo"

    echo "tnotify-watch: listening on $fifo"

    # Read from FIFO in a loop
    while true
        # Read blocks until something is written
        if read -l line < "$fifo"
            set -l parts (string split \t "$line")
            if test (count $parts) -ge 2
                tnotify "$parts[1]" "$parts[2]"
            end
        end
    end
end
