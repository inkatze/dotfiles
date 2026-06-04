# Export GEMINI_API_KEY from ~/.gemini/.api-key if present so the gemini
# CLI (panel-* skill backend on personal/alt hosts per D-6) can run
# non-interactively. The key file is written by
# scripts/claude-gemini-auth-sync.sh from a 1Password item; this snippet
# is the read side. The file is gitignored and mode 0600.
#
# Skip silently if the file does not exist (sync script not run yet, or
# host without the 1Password item provisioned). The gemini CLI will then
# halt with its own auth-missing error the next time a panel-* skill
# invokes it, which surfaces the gap at the right moment.

set -l _gemini_key_file "$HOME/.gemini/.api-key"
if test -f "$_gemini_key_file"
    set -gx GEMINI_API_KEY (cat "$_gemini_key_file")
end
