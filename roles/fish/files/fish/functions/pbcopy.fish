function pbcopy -d "Copy stdin to the clipboard (native tool where there is one, OSC 52 otherwise)"
    # macOS has the real thing; `command` bypasses this function so there is no
    # recursion. Linux gets whichever display-server tool matches the session.
    if command -q pbcopy
        command pbcopy $argv
    else if set -q WAYLAND_DISPLAY; and command -q wl-copy
        wl-copy $argv
    else if set -q DISPLAY; and command -q xclip
        xclip -selection clipboard $argv
    else
        # No display server at all — the headless server reached over SSH. Hand
        # the bytes to the attached terminal via OSC 52 so they land in the
        # *local* machine's clipboard. `base64 | tr -d '\n'` rather than GNU
        # `base64 -w0`, which BSD base64 does not accept.
        printf '\033]52;c;%s\a' (base64 | tr -d '\n')
    end
end
