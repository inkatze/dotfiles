#!/usr/bin/env bash
# The macOS role matrix .github/workflows/test.yml runs, and which of its
# entries a set of changed paths selects.
#
#   ci-role-matrix.sh --all              every entry
#   ci-role-matrix.sh --changed <file>   entries whose triggers match a path
#                                        listed in <file>, one per line
#
# Prints a JSON array of {role, brew_deps, strict_idempotency} for the test
# job's `matrix.include`. Plain bash (3.2 included) and printf, so it runs on
# the Ubuntu runner and in lint's macOS suites alike.
#
# A job selects on its own role's paths plus the shared paths below, which
# every role job reads whatever its tag. Parse-only exposure (another role's
# task file failing to load) is lint's syntax check, which gates the matrix.
set -euo pipefail

# role|brew_deps|strict_idempotency|trigger patterns, space-separated. A `*`
# matches across `/`. Scripts are the ones the role's tasks run through
# `{{ ansible_facts.env.PWD }}/scripts/`, plus what those source;
# scripts/ci-role-matrix-test.sh fails when a task references one missing here.
#
# `services` proves the negative: a macOS host provisions none of the declared
# Linux services, so a missing or wrong os_family guard surfaces as an attempt
# to install apt packages on a Mac (specs/dev-services REQ-B1.4). Strict, so
# the role is held to the same convergence bar as everything else (REQ-C1.1).
#
# `osx` also runs the claude role's osx-tagged Gemini tasks, hence their sync
# script. `upgrade` runs every role's upgrade-tagged tasks: osx, environments,
# fish and tmux.
matrix_table='
ssh||true|roles/ssh/* scripts/ssh-lan-config-sync.sh scripts/op-token.sh
git||true|roles/git/* scripts/op-render.sh scripts/op-token.sh
kitty||true|roles/kitty/*
tmux|tmux|false|roles/tmux/*
fish|fish|false|roles/fish/*
osx|mas|false|roles/osx/* Brewfile Brewfile.* scripts/claude-mcp-sync-github.sh scripts/op-render.sh scripts/op-token.sh scripts/claude-gemini-auth-sync.sh
environments|fish gpg|false|roles/environments/*
services||true|roles/services/*
upgrade|mas fish tmux|false|roles/osx/* roles/environments/* roles/fish/* roles/tmux/* Brewfile Brewfile.* scripts/claude-mcp-sync-github.sh scripts/op-render.sh scripts/op-token.sh
'

# Read by every role job: the workflow and this selector, the playbook's
# entry points, and the four task files holding `tags: [always]` tasks, which
# run under any tag.
shared_patterns='
.github/workflows/test.yml
scripts/ci-role-matrix.sh
main.yml
hosts
ansible.cfg
group_vars/*
become_plugins/*
mise.toml
scripts/playbook.sh
roles/osx/tasks/main.yml
roles/claude/tasks/main.yml
roles/environments/tasks/main.yml
roles/fish/tasks/main.yml
'

# Role defaults, vars, meta and handlers load into every run's play scope,
# whichever role they belong to.
is_play_scoped() {
    local rest sub
    case "$1" in roles/*/*) ;; *) return 1 ;; esac
    rest=${1#roles/}
    rest=${rest#*/}
    sub=${rest%%/*}
    case "$sub" in defaults | vars | meta | handlers) [[ "$rest" == */* ]] ;; *) return 1 ;; esac
}

matches_any() {
    local path=$1 pattern
    shift
    for pattern in "$@"; do
        # shellcheck disable=SC2053 # the pattern is meant to glob
        [[ "$path" == $pattern ]] && return 0
    done
    return 1
}

emit() {
    local first=1 role deps strict
    printf '['
    while IFS='|' read -r role deps strict _; do
        [[ -n "$role" ]] || continue
        [[ $first -eq 1 ]] || printf ','
        first=0
        printf '{"role":"%s","brew_deps":"%s","strict_idempotency":%s}' "$role" "$deps" "$strict"
    done
    printf ']\n'
}

usage() {
    echo "usage: ci-role-matrix.sh --all | --changed <file>" >&2
    exit 2
}

[[ $# -ge 1 ]] || usage
case "$1" in
    --all)
        printf '%s\n' "$matrix_table" | emit
        ;;
    --changed)
        [[ $# -eq 2 && -r "$2" ]] || usage
        set -f
        # shellcheck disable=SC2086 # word splitting into patterns is the point
        set -- "$2" $shared_patterns
        changed_file=$1
        shift
        shared=("$@")
        all=0
        while IFS= read -r path || [[ -n "$path" ]]; do
            [[ -n "$path" ]] || continue
            if matches_any "$path" "${shared[@]}" || is_play_scoped "$path"; then
                all=1
                break
            fi
        done <"$changed_file"
        if [[ $all -eq 1 ]]; then
            printf '%s\n' "$matrix_table" | emit
            exit 0
        fi
        selected=''
        while IFS='|' read -r role deps strict triggers; do
            [[ -n "$role" ]] || continue
            # shellcheck disable=SC2086
            set -- $triggers
            while IFS= read -r path || [[ -n "$path" ]]; do
                [[ -n "$path" ]] || continue
                if matches_any "$path" "$@"; then
                    selected+="$role|$deps|$strict"$'\n'
                    break
                fi
            done <"$changed_file"
        done <<<"$matrix_table"
        printf '%s' "$selected" | emit
        ;;
    *) usage ;;
esac
