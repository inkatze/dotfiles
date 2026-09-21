# Sources a machine-local shell init that only bash/zsh get wired for, since
# roles/fish makes fish the login shell. The path comes from a machine-local
# pointer: this repo is public.

set -l _pointer $HOME/.config/dotfiles/work-shell-init
if test -f $_pointer
    set -l _init (string trim <$_pointer | head -n1)
    if test -n "$_init"; and test -f "$_init"
        source "$_init"
    else if status --is-interactive
        echo "work-init: $_pointer names no readable file; work shell init not loaded" >&2
    end
end

# After the source and outside the guard: the sourced init sets this true, and
# ~/.gitconfig resolves into this public repo, so git-duet would publish
# colleagues' names and emails. Setting it before the source is overwritten;
# setting it inside the guard makes the protection depend on an unrelated file.
set -gx GIT_DUET_GLOBAL false
