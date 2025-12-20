function tnotify -d "Terminal notification that works in tmux + SSH"
    if set -q TMUX
        # Wrap for tmux passthrough: double all ESC chars and wrap in DCS
        set -l esc (printf '\e')
        set -l code (kitten notify --only-print-escape-code $argv | sed "s/$esc/$esc$esc/g")
        printf '\ePtmux;%s\e\\' "$code" > /dev/tty
    else
        kitten notify $argv
    end
end
