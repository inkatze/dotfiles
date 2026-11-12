#!/usr/bin/env bash
# Suite for scripts/apply-user-config.sh, the unattended apply entry. Each case
# builds a throwaway origin and main checkout with the script copied in and a
# stub scripts/playbook.sh, so nothing is provisioned and the script's own
# refusals (arguments, worktree, branch, dirty tree, divergence, lock, failed
# playbook) and its log are what is under test.
set -uo pipefail

here="$(cd -- "$(dirname "$0")" && pwd -P)"
work="$(mktemp -d)" || exit 1
trap 'rm -rf "$work"' EXIT
trap 'exit 130' INT TERM HUP
fails=0

ok()   { printf 'ok[%s]: %s\n' "$1" "$2"; }
fail() { printf 'FAIL[%s]: %s\n' "$1" "$2"; fails=$((fails + 1)); }

export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid
export GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export XDG_STATE_HOME="$work/state"
log="$XDG_STATE_HOME/dotfiles/apply-user-config.log"

# fixture <name>: $work/<name>/{origin.git,checkout}; the stub playbook records
# its argv and cwd into $work/<name>/ran.
fixture() {
    local d="$work/$1"
    mkdir -p "$d" && git init -q --bare -b main "$d/origin.git"
    git clone -q "$d/origin.git" "$d/checkout" 2>/dev/null
    (
        cd "$d/checkout" && git checkout -q -b main 2>/dev/null
        mkdir scripts
        cp "$here/apply-user-config.sh" scripts/
        cat >scripts/playbook.sh <<SH
#!/usr/bin/env bash
printf '%s\n' "\$@" >"$d/ran"
pwd -P >>"$d/ran"
exit \${STUB_EXIT:-0}
SH
        chmod +x scripts/*.sh
        git add -A && git commit -q -m init && git push -q origin main
    )
    echo "$d"
}
run() { (cd "$1/checkout" && shift && env "$@" scripts/apply-user-config.sh 2>&1); }

d="$(fixture happy)"
out="$(run "$d" STUB_EXIT=0)"; rc=$?
if [ $rc -eq 0 ] && [ "$(sed -n 1p "$d/ran")" = --user-config ] && [ -s "$log" ] && grep -q 'done' <<<"$out"; then
    ok happy-path "runs playbook.sh --user-config and logs"
else fail happy-path "rc=$rc out=$out"; fi

# Picks up a merge on origin by fast-forwarding.
(cd "$d" && git clone -q origin.git other 2>/dev/null && cd other && git checkout -q main && echo x >f && git add f && git commit -q -m merged && git push -q origin main)
rm -f "$d/ran"; out="$(run "$d")"; rc=$?
if [ $rc -eq 0 ] && [ -e "$d/checkout/f" ] && [ -e "$d/ran" ]; then ok fast-forwards "pulls origin main before applying"
else fail fast-forwards "rc=$rc out=$out"; fi

refused() { # name dir expected-text
    local rc out
    out="$(run "$2")"; rc=$?
    if [ $rc -ne 0 ] && [ ! -e "$2/ran" ] && grep -q -- "$3" <<<"$out"; then ok "$1" "refused: $3"
    else fail "$1" "rc=$rc ran=$([ -e "$2/ran" ] && echo yes || echo no) out=$out"; fi
}

d="$(fixture dirty)"; echo y >"$d/checkout/scratch"
refused dirty-untracked "$d" 'uncommitted or untracked'
if [ ! -e "$XDG_STATE_HOME/dotfiles/apply-user-config.lock" ]; then ok lock-released-on-refusal "a refusal releases the lock"
else fail lock-released-on-refusal "lock left behind"; fi
rm -f "$d/checkout/scratch"; echo z >>"$d/checkout/scripts/playbook.sh"
refused dirty-tracked "$d" 'uncommitted or untracked'

d="$(fixture branch)"; git -C "$d/checkout" checkout -q -b feature
refused off-main "$d" "not main"
git -C "$d/checkout" checkout -q --detach
refused detached "$d" "detached HEAD"

d="$(fixture diverged)"
(cd "$d" && git clone -q origin.git other 2>/dev/null && cd other && git checkout -q main && echo x >f && git add f && git commit -q -m up && git push -q origin main)
(cd "$d/checkout" && echo l >g && git add g && git commit -q -m local)
refused diverged "$d" 'does not fast-forward'

d="$(fixture ahead)"; (cd "$d/checkout" && echo l >g && git add g && git commit -q -m local)
refused ahead "$d" 'not level with origin/main'

d="$(fixture fresh-lock)"; mkdir -p "$XDG_STATE_HOME/dotfiles/apply-user-config.lock"
refused lock-being-taken "$d" 'taking the lock'
touch -t 200001010000 "$XDG_STATE_HOME/dotfiles/apply-user-config.lock"
out="$(run "$d")"; rc=$?
if [ $rc -eq 0 ] && [ -e "$d/ran" ]; then ok old-pidless-lock "an old lock with no pid is taken over"
else fail old-pidless-lock "rc=$rc out=$out"; fi
rm -rf "$XDG_STATE_HOME/dotfiles/apply-user-config.lock"

d="$(fixture worktree)"; git -C "$d/checkout" worktree add -q -b wt "$d/wt" 2>/dev/null
out="$(cd "$d/wt" && scripts/apply-user-config.sh 2>&1)"; rc=$?
if [ $rc -ne 0 ] && grep -q 'linked worktree' <<<"$out" && [ ! -e "$d/ran" ]; then ok linked-worktree "refused in a linked worktree"
else fail linked-worktree "rc=$rc out=$out"; fi

d="$(fixture args)"
out="$(cd "$d/checkout" && scripts/apply-user-config.sh --check 2>&1)"; rc=$?
if [ $rc -ne 0 ] && grep -q 'takes no arguments' <<<"$out" && [ ! -e "$d/ran" ]; then ok no-arguments "refuses any argument"
else fail no-arguments "rc=$rc out=$out"; fi

d="$(fixture lock)"; mkdir -p "$XDG_STATE_HOME/dotfiles/apply-user-config.lock"
sleep 30 & holder=$!
trap 'kill "$holder" 2>/dev/null; rm -rf "$work"' EXIT
echo "$holder" >"$XDG_STATE_HOME/dotfiles/apply-user-config.lock/pid"
refused lock-held "$d" 'holds the lock'
kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null
out="$(run "$d")"; rc=$?
if [ $rc -eq 0 ] && [ -e "$d/ran" ] && [ ! -e "$XDG_STATE_HOME/dotfiles/apply-user-config.lock" ]; then ok stale-lock "dead holder's lock is taken over and released"
else fail stale-lock "rc=$rc out=$out"; fi

d="$(fixture root)"; mkdir -p "$work/rootbin"
printf '#!/usr/bin/env bash\necho 0\n' >"$work/rootbin/id"; chmod +x "$work/rootbin/id"
out="$(cd "$d/checkout" && PATH="$work/rootbin:$PATH" scripts/apply-user-config.sh 2>&1)"; rc=$?
if [ $rc -ne 0 ] && grep -q 'as root' <<<"$out" && [ ! -e "$d/ran" ]; then ok root-refused "refuses to run as root"
else fail root-refused "rc=$rc out=$out"; fi

d="$(fixture failing)"; rm -f "$log"
out="$(run "$d" STUB_EXIT=3)"; rc=$?
if [ $rc -ne 0 ] && grep -q 'FAILED' <<<"$out" && grep -q 'FAILED' "$log"; then ok playbook-failure "non-zero exit, FAILED on terminal and in log"
else fail playbook-failure "rc=$rc out=$out"; fi

[ "$fails" -eq 0 ] || { echo "$fails failed"; exit 1; }
echo "all passed"
