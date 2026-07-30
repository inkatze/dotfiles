# Export GH_TOKEN from a machine-local file, so the gh CLI works on a host with
# no unlocked keyring.
#
# THE PROBLEM. gh stores its OAuth token in the system keyring, which an
# interactive login unlocks and a headless boot does not. After an unattended
# reboot `gh auth token` returns EMPTY, and gh reports "the token in default is
# invalid" -- which reads like a revoked credential and is not. Everything built
# on the API stops: gh pr view, gh api graphql, the review commands, and pushes
# over HTTPS through the gh credential helper.
#
# An SSH auth key (roles/git) fixes pushing. It cannot fix this: the REST and
# GraphQL APIs authenticate with a token, not with an SSH key.
#
# WHY A FILE AND NOT 1PASSWORD. The service-account token does authenticate
# non-interactively, and reaching for it here was considered and rejected for the
# same reason roles/git/defaults/main.yml rejects it for signing: it trades a
# narrow credential for a broad one. A fine-grained PAT scoped to the repos this
# host pushes can do that and nothing else; the service-account token is a bearer
# credential granting READ over a whole vault. Fetching the narrow one by
# presenting the broad one, on every shell start, is worse in both exposure and
# latency.
#
# GH_TOKEN takes priority over the keyring in gh's resolution order, so setting
# it sidesteps the locked keyring rather than trying to unlock it.
#
# The file is machine-local and untracked, like the other entries in
# ~/.config/dotfiles: it holds a live bearer credential and belongs nowhere near
# a public repo. Create it by hand with a fine-grained PAT:
#
#   umask 077; printf '%s' '<token>' > ~/.config/dotfiles/gh-token
#
# Absent, this is a silent no-op and gh falls back to the keyring, which is
# correct on a machine with a human at it.
set -l __gh_token_file "$HOME/.config/dotfiles/gh-token"

if test -r "$__gh_token_file"
    # Refuse a world- or group-readable token rather than exporting it anyway,
    # the same posture scripts/ssh-lan-config-sync.sh takes with the
    # service-account token. A secret this process is about to put in the
    # environment of every child should not be sitting at 0644.
    set -l __gh_mode (stat -c '%a' "$__gh_token_file" 2>/dev/null; or stat -f '%Lp' "$__gh_token_file" 2>/dev/null)
    if contains -- "$__gh_mode" 600 400
        # `string trim` because a token written with a trailing newline is a
        # token GitHub rejects, and the resulting 401 says nothing about why.
        set -l __gh_token (string trim < "$__gh_token_file")
        if test -n "$__gh_token"
            set -gx GH_TOKEN "$__gh_token"
        end
        set -e __gh_token
    else
        echo "github-token.fish: refusing $__gh_token_file (mode $__gh_mode, want 600)" >&2
    end
    set -e __gh_mode
end

set -e __gh_token_file
