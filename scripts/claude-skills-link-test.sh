#!/usr/bin/env bash
# Fixture suite for roles/claude/tasks/skills.yml: each tracked skill is
# linked into ~/.claude/skills without touching entries this repo does not own,
# its own dangling links are pruned, and the retired commands link is removed
# only when it is this repo's.
#
# Driven through ansible-playbook against a scratch HOME, run from a scratch
# directory whose roles/ links into this repo, so the tasks' PWD-relative
# paths resolve here.
set -uo pipefail

here="$(cd -- "$(dirname "$0")" && pwd -P)"
repo="$(cd -- "$here/.." && pwd -P)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
trap 'exit 130' INT TERM HUP
fails=0

ok()   { printf 'ok[%s]: %s\n' "$1" "$2"; }
fail() { printf 'FAIL[%s]: %s\n' "$1" "$2"; fails=$((fails + 1)); }

ln -s "$repo/roles" "$work/roles"
play="$work/play.yml"
cat >"$play" <<'YAML'
- name: Exercise the Claude skill link tasks
  hosts: localhost
  connection: local
  gather_facts: true
  tasks:
    - name: Run only the skill link tasks
      ansible.builtin.include_role:
        name: claude
        tasks_from: skills
YAML

skills=()
for d in "$repo"/roles/claude/files/skills/*/; do skills+=("$(basename "$d")"); done
[ "${#skills[@]}" -gt 0 ] || { echo "FAIL[harness]: no tracked skills found"; exit 1; }

fresh_home() {
    h="$work/h$RANDOM$RANDOM"
    mkdir -p "$h/.claude/skills"
    printf '%s\n' "$h"
}

# run_role <home>: 0 when the play completed, 1 when a task failed.
run_role() {
    (cd "$work" && HOME="$1" ansible-playbook "$play" >"$work/out" 2>&1)
    grep -q 'PLAY RECAP' "$work/out" || { printf 'FAIL[harness]: no recap\n'; sed 's/^/    /' "$work/out" | tail -20; exit 1; }
    grep -qE 'failed=0 ' "$work/out"
}

linked_all() {
    local s
    for s in "${skills[@]}"; do
        [ -L "$1/.claude/skills/$s" ] || return 1
        [ "$s" = review-shared ] || [ -f "$1/.claude/skills/$s/SKILL.md" ] || return 1
    done
}

h="$(fresh_home)"
mkdir -p "$h/.claude/skills/synced"; echo keep >"$h/.claude/skills/synced/file"
if run_role "$h" && linked_all "$h" && [ -f "$h/.claude/skills/synced/file" ] && [ ! -L "$h/.claude/skills/synced" ]; then
    ok fresh "every tracked skill linked, the foreign entry untouched"
else
    fail fresh "links or the foreign entry wrong: $(ls -l "$h/.claude/skills" | tr '\n' ';')"
fi

h="$(fresh_home)"; mkdir "$h/.claude/skills/${skills[0]}"
if ! run_role "$h" && [ -d "$h/.claude/skills/${skills[0]}" ] && [ ! -L "$h/.claude/skills/${skills[0]}" ]; then
    ok foreign-dir-refused "a real directory under a tracked name fails the play and survives"
else
    fail foreign-dir-refused "the play replaced or ignored a directory it does not own"
fi

h="$(fresh_home)"; ln -s /elsewhere/"${skills[0]}" "$h/.claude/skills/${skills[0]}"
if ! run_role "$h" && [ "$(readlink "$h/.claude/skills/${skills[0]}")" = "/elsewhere/${skills[0]}" ]; then
    ok foreign-link-refused "a link someone else made under a tracked name fails the play and survives"
else
    fail foreign-link-refused "the play replaced a link it does not own"
fi

h="$(fresh_home)"; ln -s "/other/clone/roles/claude/files/skills/${skills[0]}" "$h/.claude/skills/${skills[0]}"
if run_role "$h" && [ "$(readlink "$h/.claude/skills/${skills[0]}")" = "$work/roles/claude/files/skills/${skills[0]}" ]; then
    ok other-clone-relinked "a link from another clone of this repo is repointed"
else
    fail other-clone-relinked "target: $(readlink "$h/.claude/skills/${skills[0]}")"
fi

h="$(fresh_home)"
ln -s "/gone/roles/claude/files/skills/retired-skill" "$h/.claude/skills/retired-skill"
ln -s "/gone/somewhere/else" "$h/.claude/skills/foreign-dangling"
if run_role "$h" && [ ! -L "$h/.claude/skills/retired-skill" ] && [ -L "$h/.claude/skills/foreign-dangling" ]; then
    ok prune-own-dangling "this repo's dangling link pruned, a foreign one kept"
else
    fail prune-own-dangling "$(ls -l "$h/.claude/skills" | tr '\n' ';')"
fi

h="$(fresh_home)"; ln -s "/some/clone/roles/claude/files/commands" "$h/.claude/commands"
if run_role "$h" && [ ! -e "$h/.claude/commands" ] && [ ! -L "$h/.claude/commands" ]; then
    ok commands-link-removed "the retired commands link into this repo is removed"
else
    fail commands-link-removed "still present: $(ls -ld "$h/.claude/commands" 2>&1)"
fi

h="$(fresh_home)"; mkdir "$h/.claude/commands"; echo keep >"$h/.claude/commands/mine.md"
if run_role "$h" && [ -f "$h/.claude/commands/mine.md" ]; then
    ok commands-dir-kept "a real commands directory is left alone"
else
    fail commands-dir-kept "a commands directory this repo does not own was removed"
fi

h="$(fresh_home)"; run_role "$h" >/dev/null; run_role "$h"
if grep -qE 'changed=0 ' "$work/out"; then
    ok idempotent "a second run changes nothing"
else
    fail idempotent "$(grep -E 'ok=|changed=' "$work/out" | tail -1)"
fi

if [ "$fails" -eq 0 ]; then
    echo "claude-skills-link-test: all assertions hold"
else
    echo "claude-skills-link-test: $fails assertion(s) failed"
    exit 1
fi
