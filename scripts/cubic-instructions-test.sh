#!/usr/bin/env bash
# Fixture suite for the claude role's cubic instruction-file and provider
# tasks, driven through ansible-playbook against scratch HOMEs, as
# mise-global-config-test.sh drives the environments role.
set -uo pipefail

here="$(cd -- "$(dirname "$0")" && pwd -P)"
repo="$(cd -- "$here/.." && pwd -P)"
work="$(cd -- "$(mktemp -d)" && pwd -P)" || exit 1
# A hung play's workers must not outlive the suite; they get a moment to exit
# before their scratch files go.
trap 'pkill -f "$work" 2>/dev/null && sleep 1; rm -rf "$work"' EXIT
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
  gather_subset: [min]
  tasks:
    - name: Run only the tasks that own the cubic CLI's files
      ansible.builtin.include_role:
        name: claude
        tasks_from: cubic-instructions
YAML

# run_role <home> [ansible-playbook flags...]: a run that fails the play is a
# failure of the role, which must report and carry on.
run_role() {
  local home="$1"
  shift
  HOME="$home" ansible-playbook "$play" "$@" >"$work/out" 2>&1
  if ! grep -q 'PLAY RECAP' "$work/out" || grep -qE '^fatal|failed=[1-9]' "$work/out"; then
    fail play "the play failed"
    sed 's/^/    /' "$work/out" | tail -12
    return 1
  fi
}
changed() { grep -oE 'changed=[0-9]+' "$work/out" | head -1 | cut -d= -f2; }
reported() { grep -qF -- "$1" "$work/out"; }
# Sets h; a subshell would let a failed mktemp leave h empty and the suite
# writing under /.
fresh_home() { h="$(mktemp -d "$work/h.XXXXXX")" || { echo "cubic-instructions-test: mktemp failed"; exit 1; }; }
mode_of() { stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"; }

fresh_home
run_role "$h" --check && [ ! -e "$h/.config/cubic" ] && ok check "a --check run on a fresh host writes nothing" \
  || fail check "a --check run wrote files or failed"
run_role "$h"
f="$h/.config/cubic/AGENTS.md"
p="$h/.local/share/cubic/preferences.json"
if [ -f "$f" ] && [ ! -s "$f" ] && [ "$(mode_of "$f")" = 600 ]; then ok created "an empty 0600 AGENTS.md"; else fail created "no empty 0600 AGENTS.md"; fi
if [ "$(jq -r .preferredProvider "$p" 2>/dev/null)" = cubic ] && [ "$(mode_of "$p")" = 600 ]; then
  ok prefs "a 0600 preferences.json preferring cubic"
else
  fail prefs "no 0600 preferences.json preferring cubic"
fi
[ "$(mode_of "$h/.config/cubic")" = 700 ] && ok dirmode "the cubic config directory is 0700" || fail dirmode "the cubic config directory is not 0700"
reported "is not an empty regular file" && fail quiet "a fresh host was reported" || ok quiet "a fresh host is not reported"
run_role "$h"
[ "$(changed)" = 0 ] && ok idempotent "a second run changes nothing" || fail idempotent "a second run reported changed=$(changed)"
if reported "is not an empty regular file" || reported "whose preferredProvider is" || reported "/cubic holds" \
  || reported "not yours"; then
  fail quiet-again "a converged host was reported"
else
  ok quiet-again "a converged host reports nothing"
fi

fresh_home
mkdir -p "$h/.config/cubic" "$h/.local/share/cubic"
printf 'my own rules\n' >"$h/.config/cubic/AGENTS.md"
printf '{"preferredProvider":"claude-code"}\n' >"$h/.local/share/cubic/preferences.json"
echo '{}' >"$h/.config/cubic/cubic.json"
run_role "$h"
[ "$(cat "$h/.config/cubic/AGENTS.md")" = "my own rules" ] && ok kept "an AGENTS.md with content is left as it is" || fail kept "AGENTS.md was changed"
[ "$(jq -r .preferredProvider "$h/.local/share/cubic/preferences.json")" = claude-code ] \
  && ok kept-prefs "another preferred provider is left as it is" || fail kept-prefs "preferences.json was changed"
reported "is not an empty regular file" && ok reported "AGENTS.md with content is reported" || fail reported "no report for AGENTS.md"
reported "whose preferredProvider is" && ok reported-prefs "the other provider is reported" || fail reported-prefs "no report for the provider"
reported "holds cubic.json" && ok reported-extra "an extra config entry is reported" || fail reported-extra "no report for cubic.json"

fresh_home
mkdir -p "$h/.config/cubic/AGENTS.md" "$h/.local/share/cubic"
printf 'not json\n' >"$h/.local/share/cubic/preferences.json"
run_role "$h" && ok dir "a directory at AGENTS.md is reported, not fatal"
reported "is not an empty regular file" || fail dir-report "no report for a directory at AGENTS.md"
reported "whose preferredProvider is" && ok not-json "a preferences.json that is not JSON is reported, not fatal" \
  || fail not-json "no report for unparseable preferences"

fresh_home
mkdir -p "$h/.config/cubic"
: >"$h/elsewhere"
ln -s "$h/elsewhere" "$h/.config/cubic/AGENTS.md"
run_role "$h"
[ -L "$h/.config/cubic/AGENTS.md" ] && ok link "a symlinked AGENTS.md is left alone" || fail link "the symlink was replaced"
reported "is not an empty regular file" && ok link-report "a symlinked AGENTS.md is reported" || fail link-report "no report for the symlink"

fresh_home
mkdir -p "$h/.local/share/cubic" "$h/real-config" "$h/.config"
ln -s "$h/real-config" "$h/.config/cubic"
printf '{"x":{"preferredProvider":"cubic"}}\n' >"$h/.local/share/cubic/preferences.json"
run_role "$h"
[ ! -e "$h/real-config/AGENTS.md" ] && ok link-dir "nothing is written through a symlinked config directory" \
  || fail link-dir "AGENTS.md was written through the symlink"
reported "not yours" && ok link-dir-report "a symlinked config directory is reported" || fail link-dir-report "no report for the symlinked directory"
reported "whose preferredProvider is" && ok nested "a nested preferredProvider is reported, as the backend refuses it" \
  || fail nested "no report for a nested preferredProvider"

fresh_home
mkdir -p "$h/.config/cubic" "$h/.local/share/cubic"
if (unset USER; run_role "$h"); then ok no-user "an unset USER does not fail the play"; else fail no-user "an unset USER failed the play"; fi
[ -f "$h/.config/cubic/AGENTS.md" ] && ok no-user-created "the user's own directories are still used" \
  || fail no-user-created "nothing was created with USER unset"

fresh_home
mkdir -p "$h/.local/share/cubic"
mkfifo "$h/.local/share/cubic/preferences.json"
tbin="$(command -v timeout || command -v gtimeout)" || tbin=""
if [ -z "$tbin" ]; then
  echo "SKIP[fifo]: no timeout or gtimeout to bound a hung play"
elif "$tbin" 120 bash -c 'source /dev/stdin' <<<"$(declare -f run_role fail); play='$play' work='$work' fails=0; run_role '$h'"; then
  ok fifo "a FIFO at preferences.json neither hangs nor fails the play"
  reported "whose preferredProvider is" && ok fifo-report "the FIFO is reported" || fail fifo-report "no report for the FIFO"
else
  fail fifo "a FIFO at preferences.json hung or failed the play"
fi

fresh_home
mkdir -p "$h/.local/share/cubic"
printf '{"https://example.invalid":{"type":"wellknown","key":"PLACEHOLDER","token":"placeholder-secret-value"}}\n' \
  >"$h/.local/share/cubic/auth.json"
run_role "$h"
reported "holds a wellknown login" && ok wellknown "a wellknown login is reported" || fail wellknown "no report for a wellknown login"
reported "placeholder-secret-value" && fail wellknown-leak "auth.json contents reached the output" \
  || ok wellknown-leak "auth.json contents never reach the output"

fresh_home
mkdir -p "$h/.local/share/cubic" "$work/nojq"
printf '{"preferredProvider":"cubic"}\n' >"$h/.local/share/cubic/preferences.json"
printf '#!/bin/sh\nexit 127\n' >"$work/nojq/jq"
chmod +x "$work/nojq/jq"
PATH="$work/nojq:$PATH" run_role "$h"
reported "could not run jq" && ok no-jq "a missing jq is reported as such" || fail no-jq "no report for a missing jq"
reported "whose preferredProvider is" && fail no-jq-blame "a missing jq was blamed on preferences.json" \
  || ok no-jq-blame "a missing jq is not blamed on the files"
fresh_home
mkdir -p "$h/.local/share/cubic"
ln -s /dev/null "$h/.local/share/cubic/preferences.json"
printf '{"cubic":{"type":"api","key":"placeholder"}}\n' >"$h/.local/share/cubic/auth.json"
PATH="$work/nojq:$PATH" run_role "$h"
reported "could not run jq" && reported "whose preferredProvider is" && ok no-jq-link "without jq, a symlinked preferences.json is still reported" \
  || fail no-jq-link "without jq, the symlinked preferences.json went unreported"
reported "holds a wellknown login" && fail no-jq-auth "without jq, auth.json was blamed" || ok no-jq-auth "without jq, auth.json is not blamed"

[ "$fails" -eq 0 ] && echo "cubic-instructions-test: all assertions hold" || { echo "cubic-instructions-test: $fails failed"; exit 1; }
