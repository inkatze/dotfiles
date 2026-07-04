# Point SSH_AUTH_SOCK at the 1Password SSH agent.
#
# git is configured to sign commits with an SSH key via 1Password's
# op-ssh-sign (gpg.format=ssh). op-ssh-sign reaches the key through the SSH
# agent named by $SSH_AUTH_SOCK, and it does NOT read ~/.ssh/config's
# IdentityAgent. macOS's default launchd agent
# (/var/run/com.apple.launchd.*/Listeners) does not hold the 1Password key,
# so leaving SSH_AUTH_SOCK at that default lets `git push` work (the ssh
# client reads IdentityAgent) while `git commit -S` fails to sign. Exporting
# the 1Password socket here fixes both for every shell and tmux pane.
set -l __op_ssh_sock "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
if test -S "$__op_ssh_sock"
    set -gx SSH_AUTH_SOCK "$__op_ssh_sock"
end
