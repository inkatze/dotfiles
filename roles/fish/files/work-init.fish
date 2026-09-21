# Sources a machine-local shell init that a second config manager wires only
# into bash/zsh, since roles/fish makes fish the login shell. The path comes
# from a machine-local pointer: this repo is public. The pointer's own
# contract is an absolute path; a relative one would resolve against
# whatever directory the shell happens to be in, since conf.d loads on every
# fish shell, not just logins.

set -l _pointer $HOME/.config/dotfiles/work-shell-init
if test -f $_pointer
    set -l _init (string trim <$_pointer | head -n1)
    if test -n "$_init"; and test -f "$_init"; and string match -q '/*' -- "$_init"
        # A .fish target is sourced natively; anything else is treated as a
        # POSIX/bash init and replayed through bass, since fish's own
        # `source` cannot parse bash syntax (bass exists for exactly this;
        # it can't parse fish syntax either, so dispatch matters both ways).
        if string match -q '*.fish' -- "$_init"
            source "$_init"
        else if functions -q bass
            bass source "$_init"
        else if status --is-interactive
            echo "work-init: bass not installed; can't load non-fish init $_init" >&2
        end
    else if status --is-interactive
        echo "work-init: $_pointer names no absolute, readable file; work shell init not loaded" >&2
    end
end

# After the source and outside the guard: the sourced init sets this true, and
# ~/.gitconfig resolves into this public repo, so git-duet would publish
# colleagues' names and emails. Setting it before the source is overwritten;
# setting it inside the guard makes the protection depend on an unrelated file.
set -gx GIT_DUET_GLOBAL false
