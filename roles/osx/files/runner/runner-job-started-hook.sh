#!/bin/sh
# Runner job-started hook: refuse any job whose code is not this runner's own
# repository's. The runner runs it before every job (ACTIONS_RUNNER_HOOK_JOB_STARTED
# in the runner's .env), and a non-zero exit fails the job before its first step.
#
# The play installs one copy per runner as runner-hook-<slug>.sh with the
# repository it serves, as owner/repo, in the sibling runner-hook-<slug>.repo.
# Fails closed: an unreadable repository file, an unreadable or missing payload,
# or any event but push and pull_request refuses.
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
