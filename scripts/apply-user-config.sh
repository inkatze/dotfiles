#!/usr/bin/env bash
# Applies merged user config unattended: `playbook.sh --user-config` from a
# clean `main` checkout brought level with origin, and nothing else. Built so a
# host-chore session can run this one narrowly named entry (`mise run apply`)
# instead of the playbook with its open argument surface.
#
# Refuses, naming the reason and exiting non-zero, unless this is the main
# checkout (not a linked worktree), on `main`, with no tracked or untracked
# changes, and `main` fast-forwards to origin's. Takes no arguments, never
# prompts, never needs sudo, and holds a lock so runs never overlap. Output
# goes to the terminal and to a fixed log.
#
#   Log:  ${XDG_STATE_HOME:-~/.local/state}/dotfiles/apply-user-config.log
#   Lock: the same directory, apply-user-config.lock (a directory, as macOS has
#         no flock; a dead holder's lock is taken over)
set -euo pipefail

if [[ $# -gt 0 ]]; then
    echo "apply-user-config.sh: takes no arguments." >&2
    exit 2
fi

repo="$(cd -- "$(dirname -- "$0")/.." && pwd -P)"
state="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
log="$state/apply-user-config.log"
lock="$state/apply-user-config.lock"

mkdir -p -- "$state"
exec </dev/null

say() { printf 'apply-user-config: %s\n' "$*"; }
die() {
    say "FAILED: $*"
    exit 1
}

main() {
    say "start $(date -u +%Y-%m-%dT%H:%M:%SZ) in $repo"

    [[ "$(id -u)" != 0 ]] || die "refusing to run as root"

    # Never wait on a credential prompt.
    export GIT_TERMINAL_PROMPT=0
    # Only when nothing else picks the ssh command: GIT_SSH_COMMAND would
    # override a configured core.sshCommand.
    if [[ -z "${GIT_SSH_COMMAND:-}" && -z "$(git -C "$repo" config --get core.sshCommand || true)" ]]; then
        export GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=30"
    fi
    git_() { git -C "$repo" "$@"; }

    if ! mkdir -- "$lock" 2>/dev/null; then
        holder="$(cat -- "$lock/pid" 2>/dev/null || true)"
        if [[ "$holder" =~ ^[1-9][0-9]*$ ]] && kill -0 "$holder" 2>/dev/null; then
            die "another run holds the lock (pid $holder)"
        fi
        # No pid yet means the holder is between mkdir and its pid write: only
        # a lock older than that window is stale.
        if [[ -z "$holder" && -n "$(find "$lock" -maxdepth 0 -mmin -1 2>/dev/null)" ]]; then
            die "another run is taking the lock"
        fi
        # Renaming is atomic, so of several runs finding it stale only one wins.
        mv -- "$lock" "$lock.stale.$$" 2>/dev/null || die "another run is taking the lock"
        rm -rf -- "$lock.stale.$$"
        mkdir -- "$lock" 2>/dev/null || die "another run is taking the lock"
    fi
    trap 'rm -rf -- "$lock"' EXIT
    trap 'exit 130' INT TERM HUP
    echo "${BASHPID:-$$}" >"$lock/pid"

    # Assigned apart from the test, so a failing git cannot read as an empty
    # (passing) answer.
    git_dir="$(git_ rev-parse --git-dir)" || die "git cannot read $repo"
    common_dir="$(git_ rev-parse --git-common-dir)" || die "git cannot read $repo"
    [[ "$git_dir" == "$common_dir" ]] \
        || die "$repo is a linked worktree; run it from the main checkout"
    branch="$(git_ symbolic-ref --short -q HEAD || true)"
    [[ "$branch" == main ]] || die "checked out branch is '${branch:-detached HEAD}', not main"
    changes="$(git_ status --porcelain --untracked-files=all)" || die "git status failed in $repo"
    [[ -z "$changes" ]] \
        || die "the checkout has uncommitted or untracked changes"

    # A hung fetch would hold the lock for good, so bound it where timeout exists.
    fetch=(git_ fetch --quiet origin main)
    if command -v timeout >/dev/null 2>&1; then fetch=(timeout 120 git -C "$repo" fetch --quiet origin main); fi
    "${fetch[@]}" || die "could not fetch origin main"
    git_ merge --ff-only --quiet origin/main || die "local main does not fast-forward to origin/main"
    [[ "$(git_ rev-parse HEAD)" == "$(git_ rev-parse origin/main)" ]] \
        || die "main is not level with origin/main after the fast-forward"
    say "applying $(git_ rev-parse --short HEAD)"

    # The playbook's own guards (alias, ANSIBLE_* refusal, selection) apply as ever.
    # mise-managed tools need fish's activation, so fall back to it when
    # ansible-playbook is not already on PATH.
    cd -- "$repo"
    if command -v ansible-playbook >/dev/null 2>&1 || ! command -v fish >/dev/null 2>&1; then
        ./scripts/playbook.sh --user-config || die "playbook.sh --user-config failed; tasks before the failure stay applied"
    else
        fish -c 'exec ./scripts/playbook.sh --user-config' || die "playbook.sh --user-config failed; tasks before the failure stay applied"
    fi
    say "done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

# Every line to the terminal and the log, the exit status kept.
main 2>&1 | tee -a "$log"
exit "${PIPESTATUS[0]}"
