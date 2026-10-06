#!/usr/bin/env bash
# Fixture suite for the claude role's cubic instruction-file tasks, driven
# through ansible-playbook against scratch HOMEs, as
# mise-global-config-test.sh drives the environments role.
set -uo pipefail

here="$(cd -- "$(dirname "$0")" && pwd -P)"
repo="$(cd -- "$here/.." && pwd -P)"
work="$(cd -- "$(mktemp -d)" && pwd -P)" || exit 1
trap 'rm -rf "$work"' EXIT
fails=0

ok()   { printf 'ok[%s]: %s\n' "$1" "$2"; }
fail() { printf 'FAIL[%s]: %s\n' "$1" "$2"; fails=$((fails + 1)); }

ln -s "$repo/roles" "$work/roles"
play="$work/play.yml"
cat >"$play" <<'YAML'
- name: Exercise the cubic instruction-file tasks
  hosts: localhost
  connection: local
  gather_facts: true
  tasks:
    - name: Run only the tasks that own the cubic instruction file
      ansible.builtin.include_role:
        name: claude
        tasks_from: cubic-instructions
YAML

run_role() {
  HOME="$1" ansible-playbook "$play" >"$work/out" 2>&1
  if ! grep -q 'PLAY RECAP' "$work/out" || grep -qE '^fatal' "$work/out"; then
    printf 'FAIL[harness]: the playbook did not complete\n'
    sed 's/^/    /' "$work/out" | tail -12
    exit 1
  fi
}
changed() { grep -oE 'changed=[0-9]+' "$work/out" | head -1 | cut -d= -f2; }
fresh_home() { h="$(mktemp -d "$work/h.XXXXXX")" || exit 1; printf '%s\n' "$h"; }
mode_of() { stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"; }

h="$(fresh_home)"
run_role "$h"
f="$h/.config/cubic/AGENTS.md"
if [ -f "$f" ] && [ ! -s "$f" ] && [ "$(mode_of "$f")" = 600 ]; then
  ok created "an empty 0600 file on a fresh host"
else
  fail created "no empty 0600 file at $f"
fi
run_role "$h"
[ "$(changed)" = 0 ] && ok idempotent "a second run changes nothing" || fail idempotent "a second run reported changed=$(changed)"

h="$(fresh_home)"
mkdir -p "$h/.config/cubic"
printf 'my own rules\n' >"$h/.config/cubic/AGENTS.md"
run_role "$h"
if [ "$(cat "$h/.config/cubic/AGENTS.md")" = "my own rules" ]; then
  ok kept "a file with content is left as it is"
else
  fail kept "a file with content was changed"
fi
grep -q 'is not an empty' "$work/out" && ok reported "the file with content is reported" || fail reported "no report for a file with content"

h="$(fresh_home)"
run_role "$h"
grep -q 'is not an empty' "$work/out" && fail quiet "an empty file was reported" || ok quiet "an empty file is not reported"

[ "$fails" -eq 0 ] && echo "cubic-instructions-test: all assertions hold" || { echo "cubic-instructions-test: $fails failed"; exit 1; }
