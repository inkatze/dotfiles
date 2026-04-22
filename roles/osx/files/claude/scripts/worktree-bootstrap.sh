#!/usr/bin/env bash
# Bootstrap a fresh git worktree when Claude Code starts in one.
# Wired from ~/.claude/settings.json as a SessionStart hook.
#
# Behavior (runs once per worktree; marker at .git/claude-bootstrap-done):
#   1. Exit quietly if not a git worktree or already bootstrapped.
#   2. Synchronously: `mise trust` the worktree so .mise.toml / .tool-versions
#      are accepted. This is fast and fixes the first-use friction.
#   3. In the background: run a best-effort dependency install based on
#      detected lockfiles (npm/yarn/pnpm, bundler, mix, cargo, go mod, uv,
#      poetry). Logs go to ~/.claude/cache/worktree-bootstrap.log.
#      A desktop notification fires when the install finishes.
#   4. If the repo ships an executable .claude/worktree-bootstrap script,
#      invoke it after the language installers so projects can layer on
#      additional steps (codegen, DB setup, etc.).
#
# To force a re-run: rm .git/claude-bootstrap-done in the worktree.

set -u

cwd="${CLAUDE_PROJECT_DIR:-$PWD}"

# Only interested in git worktrees. In a worktree, .git is a *file* pointing
# at the per-worktree gitdir; in the primary checkout it's a directory.
[ -f "$cwd/.git" ] || exit 0

# Resolve the real per-worktree gitdir (the .git file is a pointer).
gitdir=$(git -C "$cwd" rev-parse --git-dir 2>/dev/null)
[ -n "$gitdir" ] || exit 0
# Make absolute so a later `cd` in the background subshell doesn't break it.
case "$gitdir" in
    /*) ;;
    *) gitdir="$cwd/$gitdir" ;;
esac

marker="$gitdir/claude-bootstrap-done"
[ -f "$marker" ] && exit 0

# Claim the marker up-front so concurrent SessionStart hooks short-circuit
# before they get to the (heavy) background installers below.
touch "$marker"

log_dir="$HOME/.claude/cache"
log_file="$log_dir/worktree-bootstrap.log"
mkdir -p "$log_dir"

ts() { date '+%Y-%m-%dT%H:%M:%S'; }
log() { printf '[%s] %s\n' "$(ts)" "$*" >>"$log_file"; }

log "bootstrap start: $cwd"

# Step 1: trust mise synchronously so subsequent tool invocations work.
if [ -f "$cwd/.mise.toml" ] || [ -f "$cwd/mise.toml" ] || [ -f "$cwd/.tool-versions" ]; then
    if command -v mise >/dev/null 2>&1; then
        if mise trust "$cwd" >>"$log_file" 2>&1; then
            log "mise trusted"
        else
            log "mise trust failed (continuing)"
        fi
    fi
fi

# Step 2: background dependency install.
(
    cd "$cwd" || exit 0
    ran_any=0
    succeeded=1

    run() {
        ran_any=1
        log "run: $*"
        if fish -c "cd '$cwd'; and $*" >>"$log_file" 2>&1; then
            log "ok: $*"
        else
            log "fail: $*"
            succeeded=0
        fi
    }

    [ -f package-lock.json ] && run "npm ci"
    [ -f yarn.lock ] && [ ! -f package-lock.json ] && run "yarn install --frozen-lockfile"
    [ -f pnpm-lock.yaml ] && run "pnpm install --frozen-lockfile"
    [ -f Gemfile.lock ] && run "bundle install"
    [ -f mix.exs ] && run "mix deps.get"
    [ -f go.mod ] && run "go mod download"
    [ -f Cargo.lock ] && run "cargo fetch"
    [ -f uv.lock ] && run "uv sync"
    [ -f poetry.lock ] && run "poetry install --no-root"

    # Per-repo hook: runs after language installers.
    if [ -x ".claude/worktree-bootstrap" ]; then
        ran_any=1
        log "run: .claude/worktree-bootstrap"
        if fish -c "cd '$cwd'; and ./.claude/worktree-bootstrap" >>"$log_file" 2>&1; then
            log "ok: .claude/worktree-bootstrap"
        else
            log "fail: .claude/worktree-bootstrap"
            succeeded=0
        fi
    fi

    if [ $ran_any -eq 1 ]; then
        if [ $succeeded -eq 1 ]; then
            fish -c "tnotify-send 'Claude worktree' 'Bootstrap complete'" >/dev/null 2>&1 || true
        else
            fish -c "tnotify-send 'Claude worktree' 'Bootstrap had failures (see log)'" >/dev/null 2>&1 || true
        fi
    fi
    log "bootstrap end (ran_any=$ran_any succeeded=$succeeded)"
) >/dev/null 2>&1 &
disown

# Emit additionalContext so Claude knows this happened.
detected=()
[ -f "$cwd/package-lock.json" ] && detected+=("npm")
[ -f "$cwd/yarn.lock" ] && [ ! -f "$cwd/package-lock.json" ] && detected+=("yarn")
[ -f "$cwd/pnpm-lock.yaml" ] && detected+=("pnpm")
[ -f "$cwd/Gemfile.lock" ] && detected+=("bundler")
[ -f "$cwd/mix.exs" ] && detected+=("mix")
[ -f "$cwd/go.mod" ] && detected+=("go")
[ -f "$cwd/Cargo.lock" ] && detected+=("cargo")
[ -f "$cwd/uv.lock" ] && detected+=("uv")
[ -f "$cwd/poetry.lock" ] && detected+=("poetry")
[ -x "$cwd/.claude/worktree-bootstrap" ] && detected+=("repo-bootstrap")

if [ ${#detected[@]} -eq 0 ]; then
    summary="Fresh git worktree detected. Trusted mise config if present. No package lockfiles or repo bootstrap script found."
else
    joined=$(IFS=, ; echo "${detected[*]}")
    summary="Fresh git worktree detected. Trusted mise config; running installs in background: ${joined}. Log: ~/.claude/cache/worktree-bootstrap.log. Marker: .git/claude-bootstrap-done (delete to force re-run)."
fi

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":%s}}\n' \
    "$(printf '%s' "$summary" | jq -Rs .)"

exit 0
