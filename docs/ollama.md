# Ollama is no longer provisioned

Nothing in this repo installs, serves or routes Ollama. The `work` host used
to run the daemon bound to `0.0.0.0:11434` for `personal` and `alt` to reach
over the LAN; that was dropped rather than moved, so there is no daemon host.
Removed together: the daemon and model tasks in `roles/osx/tasks/homebrew.yml`,
`brew "ollama"`, and the fish drop-in, whose symlink task is now an `absent`
task in `roles/fish/tasks/main.yml` (`conf.d` is a symlink farm, so a retired
drop-in would otherwise dangle).

The `qwen-coder` and `gpt-oss` backends `/panel-review` routed to that daemon
went with it, since without a daemon they could only fail with
connection-refused.

Restoring any of it means digging up the git history of this note's subject
and of the panel-review skill, and re-reading the LAN-exposure caveat: Ollama
has no auth, so binding `0.0.0.0` exposes it to the whole network. The
contract checker refuses those two backend names (and `OLLAMA_BASE_URL`) in
the skills tree and the tracked global `CLAUDE.md`, so a restore also updates
its retired-backend sweep in the same change.
