function claude --wraps claude --description 'Claude Code with on-demand keychain unlock'
    # Unlock the macOS keychain if needed (locked when accessing via SSH).
    # Claude Code stores auth tokens in the keychain, so it must be unlocked.
    #
    # Darwin-guarded because `security` is a macOS binary and this function is
    # cross-platform (roles/fish deploys it on every host). On Linux, Claude
    # Code keeps its token in ~/.claude/.credentials.json with no keychain
    # involved, so the block has nothing to do there. Without the guard every
    # SSH'd `claude` invocation opened with `fish: Unknown command: security`
    # -- harmless, since the wrapper still exec'd claude, but it looked like an
    # auth failure at exactly the moment you were checking auth.
    if set -q SSH_CONNECTION; and test (uname) = Darwin
        if not security show-keychain-info ~/Library/Keychains/login.keychain-db 2>/dev/null
            security unlock-keychain ~/Library/Keychains/login.keychain-db
        end
    end

    command claude $argv
end
