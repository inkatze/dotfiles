#!/usr/bin/env bash
# Fixture suite for the Copilot CLI retirement: no host declaration installs the
# CLI any more, and roles/claude/tasks/copilot-credential.yml removes the stale
# GitHub Copilot credential directory, reporting changed only when it removed
# something and leaving every other credential directory alone.
#
# The role cases drive ansible-playbook against a scratch HOME, run from a
# scratch directory whose roles/ links into this repo, so the tasks'
# PWD-relative paths resolve here.
set -uo pipefail

here="$(cd -- "$(dirname "$0")" && pwd -P)"
repo="$(cd -- "$here/.." && pwd -P)"
work="$(mktemp -d)" || { echo "FAIL[harness]: mktemp failed"; exit 1; }
trap 'rm -rf "$work"' EXIT
trap 'exit 130' INT TERM HUP
fails=0

ok()   { printf 'ok[%s]: %s\n' "$1" "$2"; }
fail() { printf 'FAIL[%s]: %s\n' "$1" "$2"; fails=$((fails + 1)); }

# Every Brewfile, mise file and package list a host installs from. A file in
# this list that has gone missing is a failure, not a pass: the grep below
# would otherwise report nothing found in nothing read.
# The Brewfile glob expands in $repo, never the caller's directory, so a run
# from elsewhere scans this checkout's variants.
declarations=("$repo"/Brewfile "$repo"/Brewfile.* "$repo"/mise.toml
  "$repo"/roles/environments/files/{mise.toml,default-npm-packages,default-python-packages}
  "$repo"/roles/linux/files/mise/linux.toml "$repo"/roles/linux/defaults/main.yml)
missing=""
for f in "${declarations[@]}"; do
    [ -f "$f" ] || missing="$missing ${f#"$repo"/}"
done
if [ -n "$missing" ]; then
    fail declarations "declaration file(s) not found:$missing"
else
    # Any non-comment line naming copilot, whatever the declaration form (a
    # cask, a mise key under any backend, a list entry quoted or versioned).
    all="$(grep -niH copilot -- "${declarations[@]}")"
    rc=$?
    hits="$(grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' <<< "$all")"
    if [ "$rc" -gt 1 ]; then
        fail declarations "grep failed (exit $rc)"
    elif [ -z "$hits" ]; then
        ok declarations "no Brewfile, mise file or package list declares the Copilot CLI"
    else
        fail declarations "still declared: $(tr '\n' ';' <<< "${hits//"$repo"\//}")"
    fi
fi

# The fixture below runs the task file directly, so this is what proves the
# role still imports it.
if (cd "$repo" && ansible-playbook main.yml --list-tasks --tags claude 2>/dev/null) \
    | grep -qF 'claude : Remove the stale GitHub Copilot credential directory'; then
    ok wired "the claude role imports the removal task"
else
    fail wired "\`ansible-playbook main.yml --list-tasks --tags claude\` does not list the removal task"
fi

ln -s "$repo/roles" "$work/roles" || { echo "FAIL[harness]: cannot link roles"; exit 1; }
play="$work/play.yml"
cat >"$play" <<'YAML' || { echo "FAIL[harness]: cannot write the play"; exit 1; }
- name: Exercise the Copilot credential removal
  hosts: localhost
  connection: local
  gather_facts: true
  gather_subset: ['!all', '!min', 'env']
  tasks:
    - name: Run only the credential removal tasks
      ansible.builtin.include_role:
        name: claude
        tasks_from: copilot-credential
YAML

fresh_home() {
    h="$(mktemp -d "$work/h.XXXXXX")" || { echo "FAIL[harness]: mktemp failed" >&2; exit 1; }
    mkdir -p "$h/.config/gh" "$h/.copilot"
    echo token >"$h/.config/gh/hosts.yml"
    echo state >"$h/.copilot/config.json"
    printf '%s\n' "$h"
}

with_credential() {
    mkdir -p "$1/.config/github-copilot"
    echo secret >"$1/.config/github-copilot/auth.db"
    chmod 644 "$1/.config/github-copilot/auth.db"
}

# run_role <home>: 0 when the play completed, 1 when a task failed.
run_role() {
    # Become off, whatever the caller's environment says: sudo would reset HOME
    # and aim the removal at a real home. Fact injection off, as the repo's
    # ansible.cfg (unread from $work) has it, so a bare ansible_env fails here too.
    (cd "$work" && HOME="$1" ANSIBLE_BECOME=false ANSIBLE_INJECT_FACT_VARS=false \
        ansible-playbook "$play" >"$work/out" 2>&1)
    grep -q 'PLAY RECAP' "$work/out" || { printf 'FAIL[harness]: no recap\n'; sed 's/^/    /' "$work/out" | tail -20; exit 1; }
    grep -qE 'failed=0 ' "$work/out"
}

changed_count() { sed -n 's/.*changed=\([0-9][0-9]*\).*/\1/p' "$work/out" | tail -1; }

siblings_intact() {
    [ "$(cat "$1/.config/gh/hosts.yml" 2>/dev/null)" = token ] \
        && [ "$(cat "$1/.copilot/config.json" 2>/dev/null)" = state ]
}

h="$(fresh_home)"; with_credential "$h"
if run_role "$h" && [ "$(changed_count)" = 1 ] && [ ! -e "$h/.config/github-copilot" ] && siblings_intact "$h"; then
    ok removes "the credential directory is removed, reported changed, siblings untouched"
else
    fail removes "changed=$(changed_count); $(ls -la "$h/.config" | tr '\n' ';')"
fi

if run_role "$h" && [ "$(changed_count)" = 0 ] && siblings_intact "$h"; then
    ok idempotent "a second run reports no change"
else
    fail idempotent "changed=$(changed_count) on the second run"
fi

h="$(fresh_home)"
if run_role "$h" && [ "$(changed_count)" = 0 ] && siblings_intact "$h"; then
    ok absent "a home without the directory reports no change"
else
    fail absent "changed=$(changed_count) with nothing to remove"
fi

# A link at the path is removed as a link: its target is someone else's.
h="$(fresh_home)"; mkdir -p "$h/elsewhere"; echo keep >"$h/elsewhere/auth.db"
ln -s "$h/elsewhere" "$h/.config/github-copilot"
if run_role "$h" && [ "$(changed_count)" = 1 ] && [ ! -L "$h/.config/github-copilot" ] \
    && [ "$(cat "$h/elsewhere/auth.db")" = keep ] && siblings_intact "$h"; then
    ok link-target-kept "a link at the path is removed without touching its target"
else
    fail link-target-kept "$(ls -la "$h/.config" "$h/elsewhere" 2>&1 | tr '\n' ';')"
fi

if [ "$fails" -eq 0 ]; then
    echo "copilot-retirement-test: all assertions hold"
else
    echo "copilot-retirement-test: $fails assertion(s) failed"
    exit 1
fi
