#!/usr/bin/env bash
# Runs the runner's job-started hook against event payloads in a scratch
# directory: only a push from, or a pull request from a branch of, the
# runner's own repository passes; everything else, and any unreadable input,
# is refused.
set -eu

repo="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

hook="$scratch/runner-hook-o-r.sh"
cp "$repo/roles/osx/files/runner/runner-job-started-hook.sh" "$hook"
echo "o/r" >"$scratch/runner-hook-o-r.repo"
# The hook calls /usr/bin/jq (macOS); elsewhere point it at the host's jq.
jq_bin=/usr/bin/jq
[ -x "$jq_bin" ] || jq_bin="$(command -v jq)"
export RUNNER_HOOK_JQ="$jq_bin"

echo '{"pull_request":{"head":{"repo":{"full_name":"o/r"}}}}' >"$scratch/same.json"
echo '{"pull_request":{"head":{"repo":{"full_name":"evil/r"}}}}' >"$scratch/fork.json"
echo '{"pull_request":{"head":{"repo":null}}}' >"$scratch/deleted-fork.json"
echo 'not json' >"$scratch/garbage.json"

passed=0 failed=0
# run_hook <repository> <event> <payload path or empty> [hook]
run_hook() {
    env -u GITHUB_EVENT_PATH GITHUB_REPOSITORY="$1" GITHUB_EVENT_NAME="$2" \
        ${3:+GITHUB_EVENT_PATH="$3"} "${4:-$hook}" >/dev/null 2>&1
}
passes() { run_hook "$@"; }
refuses() { ! run_hook "$@"; }
check() {
    local label="$1"
    shift
    if "$@"; then
        passed=$((passed + 1)); echo "  ok: $label"
    else
        failed=$((failed + 1)); echo "  FAIL: $label"
    fi
}

check "a push from the repository passes" passes o/r push ""
check "a same-repository pull request passes" passes o/r pull_request "$scratch/same.json"
check "a fork pull request is refused" refuses o/r pull_request "$scratch/fork.json"
check "a pull request with no head repository is refused" refuses o/r pull_request "$scratch/deleted-fork.json"
check "another event is refused" refuses o/r workflow_dispatch ""
check "pull_request_target is refused" refuses o/r pull_request_target "$scratch/same.json"
check "no event is refused" refuses o/r "" ""
check "another repository is refused" refuses x/y push ""
check "no repository is refused" refuses "" push ""
check "a pull request with no payload path is refused" refuses o/r pull_request ""
check "a missing payload is refused" refuses o/r pull_request "$scratch/none.json"
check "an unparseable payload is refused" refuses o/r pull_request "$scratch/garbage.json"
mkdir "$scratch/lone"
cp "$hook" "$scratch/lone/runner-hook-q-s.sh"
check "a missing repository file is refused" refuses q/s push "" "$scratch/lone/runner-hook-q-s.sh"
: >"$scratch/lone/runner-hook-q-s.repo"
check "an empty repository file is refused" refuses q/s push "" "$scratch/lone/runner-hook-q-s.sh"

# An accepted job holds caffeinate -s on the worker, which ends with the job;
# a refused job holds nothing.
cat >"$scratch/caffeinate" <<'STUB'
#!/bin/sh
d="$(dirname "$0")"
echo "$*" >>"$d/awake"
echo $$ >>"$d/awake.pid"
while [ "$1" != -w ]; do shift; done
while kill -0 "$2" 2>/dev/null; do sleep 0.1; done
STUB
chmod +x "$scratch/caffeinate"
cat >"$scratch/Runner.Worker" <<'STUB'
#!/bin/sh
"$1"
sleep 1
STUB
chmod +x "$scratch/Runner.Worker"
GITHUB_REPOSITORY=o/r GITHUB_EVENT_NAME=push RUNNER_HOOK_CAFFEINATE="$scratch/caffeinate" \
    "$scratch/Runner.Worker" "$hook" &
worker=$!
for _ in $(seq 50); do [ -s "$scratch/awake.pid" ] && break; sleep 0.1; done
check "an accepted job holds caffeinate -s on the runner's worker" \
    grep -qx -- "-s -w $worker" "$scratch/awake"
wait "$worker"
for _ in $(seq 50); do kill -0 "$(tail -n 1 "$scratch/awake.pid")" 2>/dev/null || break; sleep 0.1; done
check "the hold ends with the job and leaves no caffeinate behind" \
    sh -c '! kill -0 "$(tail -n 1 "$1")" 2>/dev/null' _ "$scratch/awake.pid"
rm -f "$scratch/awake" "$scratch/awake.pid"
GITHUB_REPOSITORY=x/y GITHUB_EVENT_NAME=push RUNNER_HOOK_CAFFEINATE="$scratch/caffeinate" \
    "$hook" >/dev/null 2>&1 || true
check "a refused job holds nothing" test ! -e "$scratch/awake"
check "a missing caffeinate does not fail an accepted job" \
    env GITHUB_REPOSITORY=o/r GITHUB_EVENT_NAME=push RUNNER_HOOK_CAFFEINATE="$scratch/none" "$hook"
check "the hook takes the assertion with -s via /usr/bin/caffeinate" \
    grep -q -- '/usr/bin/caffeinate' "$repo/roles/osx/files/runner/runner-job-started-hook.sh"

echo "runner-hook: $passed passed, $failed failed"
[ "$failed" -eq 0 ]
