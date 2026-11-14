#!/bin/sh
# Runner job-started hook: refuse any job whose code is not this runner's own
# repository's. The runner runs it before every job (ACTIONS_RUNNER_HOOK_JOB_STARTED
# in the runner's .env), and a non-zero exit fails the job before its first step.
#
# The play installs one copy per runner as runner-hook-<slug>.sh with the
# repository it serves, as owner/repo, in the sibling runner-hook-<slug>.repo.
# Fails closed: an unreadable repository file, an unreadable or missing payload,
# or any event but push and pull_request refuses.
#
# A job that passes also keeps the Mac out of system sleep: caffeinate -s (held
# only on AC power) waits on the runner's worker process, so it ends with the
# job and never outlives it. Idle sleep alone is blocked by the gate's own
# caffeinate -i; the maintenance sleep that froze a running job is not.
set -eu

refuse() {
    echo "offload-mac-ci: refusing this job: $*" >&2
    exit 1
}

repo_file="${RUNNER_HOOK_REPO_FILE:-${0%.sh}.repo}"
repo="$(cat "$repo_file" 2>/dev/null)" || refuse "cannot read $repo_file"
[ -n "$repo" ] || refuse "$repo_file is empty"

[ "${GITHUB_REPOSITORY:-}" = "$repo" ] ||
    refuse "repository '${GITHUB_REPOSITORY:-}' is not $repo"

case "${GITHUB_EVENT_NAME:-}" in
push) ;;
pull_request)
    head="$("${RUNNER_HOOK_JQ:-/usr/bin/jq}" -r '.pull_request.head.repo.full_name // empty' \
        "${GITHUB_EVENT_PATH:?}")" || refuse "cannot read the event payload"
    [ "$head" = "$repo" ] || refuse "pull request head '$head' is not $repo"
    ;;
*) refuse "event '${GITHUB_EVENT_NAME:-}' is not push or pull_request" ;;
esac

# Hold on the nearest ancestor that is the worker, which outlives the hook and
# the shell it may run through. With no worker above the hook (run by hand) there
# is nothing to tie the hold to, and a hold on a short-lived parent would end at
# once, so say so and hold nothing. A Mac without caffeinate still runs the job.
# ps and tr are the system's by absolute path, as caffeinate and jq are: the
# job's PATH can put Homebrew's copies first.
caffeinate="${RUNNER_HOOK_CAFFEINATE:-/usr/bin/caffeinate}"
if [ -x "$caffeinate" ]; then
    holder=""
    p=$PPID
    for _ in 1 2 3 4 5 6 7 8; do
        # comm is the program alone, one line and never split or globbed, so a
        # runner directory with a space in it still matches and an argument that
        # merely names the worker does not (macOS prints the full path, Linux the
        # bare name).
        prog="$(/bin/ps -ww -p "$p" -o comm= 2>/dev/null)" || prog=""
        case "$prog" in
        Runner.Worker | */Runner.Worker)
            holder=$p
            break
            ;;
        esac
        p="$(/bin/ps -ww -p "$p" -o ppid= 2>/dev/null | /usr/bin/tr -d ' ')"
        [ -n "$p" ] && [ "$p" -gt 1 ] 2>/dev/null || break
    done
    if [ -n "$holder" ]; then
        "$caffeinate" -s -w "$holder" </dev/null >/dev/null 2>&1 &
    else
        echo "offload-mac-ci: no Runner.Worker above this hook; not holding the Mac awake" >&2
    fi
fi
