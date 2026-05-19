# Route panel-* skills (and any other Ollama HTTP client) to the work host's
# Ollama daemon when running on a non-work box. The work host serves Ollama on
# the LAN (OLLAMA_HOST=0.0.0.0:11434 in its LaunchAgent plist, see
# roles/osx/tasks/homebrew.yml). Hostname patterns mirror scripts/playbook.sh.
#
# On the work host this snippet does nothing; OLLAMA_BASE_URL stays unset and
# panel-review.md falls back to http://localhost:11434.
#
# To override (e.g., when on a different network and the work host is not
# reachable), unset OLLAMA_BASE_URL or set it explicitly:
#   set -gx OLLAMA_BASE_URL http://localhost:11434

set -l _ollama_host (hostname)
if string match -q '*crojtini*' -- $_ollama_host
    or string match -q '*panela*' -- $_ollama_host
    set -gx OLLAMA_BASE_URL http://192.168.1.20:11434
end
