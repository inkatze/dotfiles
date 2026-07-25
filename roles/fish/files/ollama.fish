# Route Ollama clients (the `ollama` CLI via OLLAMA_HOST, and panel-* skills
# / other HTTP consumers via OLLAMA_BASE_URL) to the work host's Ollama daemon
# when running on a non-work box. The work host serves Ollama on the LAN
# (OLLAMA_HOST=0.0.0.0:11434 in its LaunchAgent plist, see
# roles/osx/tasks/homebrew.yml).
#
# Which box this is comes from the same inventory alias scripts/playbook.sh
# resolves: the DOTFILES_HOST env var, else the untracked
# ~/.config/dotfiles/host file. Keying on the alias rather than on a hostname
# keeps a real hostname out of this public repo (linux-migration REQ-F1.1) and
# makes the `server` host a client by declaration instead of by the accident
# of reusing the old Mac's hostname.
#
# Any alias other than `work` is a client. An unresolved alias sets nothing,
# so the work host (which has no alias file) and any unconfigured machine fall
# back to localhost:11434 — the safe direction: a client that has not been
# told its alias fails to reach a local daemon rather than silently talking to
# a LAN address.
#
# OLLAMA_HOST is host:port (no scheme); OLLAMA_BASE_URL is a full URL.
#
# To override (e.g., when on a different network and the work host is not
# reachable), unset both or set them explicitly:
#   set -gx OLLAMA_HOST localhost:11434
#   set -gx OLLAMA_BASE_URL http://localhost:11434

set -l _ollama_host_file $HOME/.config/dotfiles/host
set -l _ollama_alias $DOTFILES_HOST
if test -z "$_ollama_alias"; and test -f $_ollama_host_file
    set _ollama_alias (tr -d '[:space:]' <$_ollama_host_file)
end
# Same residual hostname fallback scripts/playbook.sh still carries for `alt`.
if test -z "$_ollama_alias"; and string match -q '*panela*' -- (hostname)
    set _ollama_alias alt
end

if test -n "$_ollama_alias"; and test "$_ollama_alias" != work
    set -gx OLLAMA_HOST 192.168.1.20:11434
    set -gx OLLAMA_BASE_URL http://192.168.1.20:11434
end
