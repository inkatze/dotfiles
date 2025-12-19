function tnotify -d "Terminal notification that works in tmux + SSH"
    # Check if we're in tmux locally OR on a remote connected via kitten ssh from tmux
    if set -q TMUX; or set -q KITTY_TMUX_PASSTHROUGH
        # Wrap for tmux passthrough: double all ESC chars and wrap in DCS
        set -l esc (printf '\e')
        set -l code (kitten notify --only-print-escape-code $argv | sed "s/$esc/$esc$esc/g")
        printf '\ePtmux;%s\e\\' "$code"
    else
        kitten notify $argv
    end
end
