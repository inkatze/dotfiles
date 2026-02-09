function claude --wraps claude --description 'Claude Code with on-demand keychain unlock'
    # Unlock the macOS keychain if needed (locked when accessing via SSH).
    # Claude Code stores auth tokens in the keychain, so it must be unlocked.
    if set -q SSH_CONNECTION
        if not security show-keychain-info ~/Library/Keychains/login.keychain-db 2>/dev/null
            security unlock-keychain ~/Library/Keychains/login.keychain-db
        end
    end

    command claude $argv
end
