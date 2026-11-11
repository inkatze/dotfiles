#!/usr/bin/env bash
# Fixture suite for scripts/ci-role-matrix.sh: which role jobs a pull
# request's changed paths start, and that the trigger table still names every
# script a role's tasks run. Needs bash, grep and sed.
set -uo pipefail

repo_root=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
matrix="$repo_root/scripts/ci-role-matrix.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fails=0

pass() { echo "ok[$1]: $2"; }
fail() {
    echo "FAIL[$1]: $2" >&2
    fails=$((fails + 1))
}

roles_of() {
    grep -oE '"role":"[^"]*"' | sed 's/^"role":"//; s/"$//' | tr '\n' ' ' | sed 's/ $//'
}

all_roles=$("$matrix" --all | roles_of)

# expect <name> <expected roles, space-separated, "ALL" or ""> <path>...
expect() {
    local name=$1 want=$2 got
    shift 2
    printf '%s\n' "$@" >"$work/changed"
    [[ "$want" == ALL ]] && want=$all_roles
    got=$("$matrix" --changed "$work/changed" | roles_of)
    if [[ "$got" == "$want" ]]; then
        pass "$name" "${got:-no role job}"
    else
        fail "$name" "want '${want}', got '${got}'"
    fi
}

if [[ "$all_roles" == "ssh git kitty tmux fish osx environments services upgrade" ]]; then
    pass all "--all lists every role job"
else
    fail all "--all lists '$all_roles'"
fi

if "$matrix" --all | grep -q '{"role":"services","runner":"macos-latest","brew_deps":"","strict_idempotency":true}'; then
    pass services-strict "services runs at strict idempotency"
else
    fail services-strict "the services entry lost strict idempotency"
fi

# Homebrew and macOS-only roles must not drift onto an Ubuntu runner: a role
# installing brew dependencies, and the roles whose tasks branch on macOS,
# stay on macos-latest.
runner_of() { "$matrix" --all | grep -oE "\"role\":\"$1\",\"runner\":\"[^\"]*\"" | sed 's/.*"runner":"//; s/"$//'; }
for role in ssh tmux fish osx environments services upgrade; do
    if [[ "$(runner_of "$role")" == macos-latest ]]; then
        pass "runner:$role" "stays on macos-latest"
    else
        fail "runner:$role" "left macos-latest"
    fi
done
for role in git kitty; do
    if [[ "$(runner_of "$role")" == ubuntu-latest ]]; then
        pass "runner:$role" "runs on ubuntu-latest"
    else
        fail "runner:$role" "is not on ubuntu-latest"
    fi
done
if "$matrix" --all | grep -E '"runner":"ubuntu-latest","brew_deps":"[^"]+"' >/dev/null; then
    fail ubuntu-brew "a role that installs brew dependencies is on Ubuntu"
else
    pass ubuntu-brew "no Ubuntu role installs brew dependencies"
fi

# A usage error must exit non-zero, so the workflow's selection step fails
# visibly rather than handing the test job an empty matrix.
for args in "" "--bogus" "--changed" "--changed $work/absent"; do
    label=${args//$work/<tmp>}
    # shellcheck disable=SC2086 # split into argv on purpose
    if "$matrix" $args >/dev/null 2>&1; then
        fail "usage:${label:-none}" "exited 0"
    else
        pass "usage:${label:-none}" "refused"
    fi
done

expect specs-only "" specs/README.md specs/dev-services/tasks.md docs/editor.md
expect claude-only "" roles/claude/files/skills/polish/SKILL.md roles/claude/tasks/skills.yml
expect git-only "git" roles/git/files/gitconfig roles/git/tasks/main.yml
expect fish-files "fish upgrade" roles/fish/files/fish/config.fish
expect tmux-upgrade "tmux upgrade" roles/tmux/tasks/upgrade.yml
expect brewfile "osx upgrade" Brewfile.work
expect op-render "git osx upgrade" scripts/op-render.sh
expect op-token "ssh git osx upgrade" scripts/op-token.sh
expect two-roles "kitty services" roles/kitty/files/kitty/kitty.conf roles/services/tasks/darwin.yml
expect workflow ALL .github/workflows/test.yml
expect selector ALL scripts/ci-role-matrix.sh
expect playbook ALL scripts/playbook.sh
expect mise ALL mise.toml
expect group-vars ALL group_vars/all.yml
expect always-tasks ALL roles/claude/tasks/main.yml
expect role-defaults ALL roles/git/defaults/main.yml
expect role-handlers ALL roles/linux/handlers/main.yml
expect nested-defaults-name "" roles/claude/files/skills/defaults/x.md
expect unrelated-script "" scripts/stale-declarations-test.sh
expect empty ""
expect quoted-path ALL '"roles/fish/files/\303\261.fish"'

# Every script a role's tasks run, and every script that one sources, must
# start that role's job; otherwise an edit to it reaches the role untested.
set -f
table=$(sed -n "/^matrix_table='/,/^'/p" "$matrix" | sed '1d;$d')
while IFS='|' read -r role _ _ _ triggers; do
    [[ -n "$role" ]] || continue
    # shellcheck disable=SC2086 # split into patterns, globbing off above
    for dir in $(printf '%s\n' $triggers | sed -n 's#^roles/\([^/*]*\)/\*$#\1#p'); do
        scripts=$(grep -rhoE 'env\.PWD \}\}/scripts/[A-Za-z0-9._-]+' "$repo_root/roles/$dir/tasks" |
            sed 's#.*}}/##' | sort -u)
        for s in $scripts; do
            # shellcheck disable=SC2016 # a literal $script_dir in the source
            sourced=$(sed -nE 's#^[[:space:]]*(\.|source)[[:space:]]+"?\$\{?script_dir\}?/([^" ]+)"?.*#scripts/\2#p' "$repo_root/$s")
            for need in $s $sourced; do
                printf '%s\n' "$need" >"$work/changed"
                if "$matrix" --changed "$work/changed" | grep -q "\"role\":\"$role\""; then
                    pass "reads:$role:$need" "triggers $role"
                else
                    fail "reads:$role:$need" "roles/$dir runs $need, which does not trigger $role"
                fi
            done
        done
    done
    if ! grep -q "^\[tasks\.$role\]" "$repo_root/mise.toml"; then
        fail "mise-task:$role" "mise.toml has no [tasks.$role] for the job to run"
    fi
done <<<"$table"

# A task file carrying a job's tag runs in that job, and one carrying
# `always` runs in every job, so editing it must start them. roles/linux is
# exempt: main.yml runs it on Debian only, never on a macOS runner, and no Ubuntu job selects a tag it carries.
selects() {
    printf '%s\n' "$1" >"$work/changed"
    "$matrix" --changed "$work/changed" | grep -q "\"role\":\"$2\""
}
tagged_files() {
    grep -rlE "^[[:space:]]*tags:[[:space:]]*\[([^]]*[ ,])?$1([ ,][^]]*)?\]" "$repo_root/roles" --include='*.yml' |
        grep '/tasks/' |
        sed "s#^$repo_root/##" | grep -v '^roles/linux/'
}
# The checks below read inline lists only, so any other spelling fails here
# rather than passing unread.
other_forms=$(grep -rnE '^[[:space:]]*tags:' "$repo_root/roles" --include='*.yml' |
    grep '/tasks/' | grep -vE ':[[:space:]]*tags:[[:space:]]*\[[^]]*\]' | sed "s#^$repo_root/##")
if [[ -n "$other_forms" ]]; then
    fail tag-form "write task tags as an inline list (tags: [a, b]) so this suite can read them:
$other_forms"
fi
for f in $(tagged_files always); do
    for role in $all_roles; do
        selects "$f" "$role" || fail "always:$f" "runs in every job but does not start $role"
    done
done
for role in $all_roles; do
    for f in $(tagged_files "$role"); do
        if selects "$f" "$role"; then
            pass "tag:$role:$f" "starts $role"
        else
            fail "tag:$role:$f" "carries the $role tag but does not start $role"
        fi
    done
done

if [[ $fails -ne 0 ]]; then
    echo "ci-role-matrix-test: $fails assertion(s) failed" >&2
    exit 1
fi
echo "ci-role-matrix-test: all assertions passed"
