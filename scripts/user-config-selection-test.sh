#!/usr/bin/env bash
# Suite for `scripts/playbook.sh --user-config`, the selection an unattended
# run applies: every cross-platform config role, no platform baseline, no
# privileged or upgrade task, and a refusal (not a password prompt) at any
# task in it that would still escalate.
#
#   Selection -- read from `--list-tasks`, so it needs no host and changes
#                nothing: both platform roles are out, every config role is
#                in, the services role's Debian lifecycle is out, and the full
#                run still lists the platform roles.
#   Probe     -- the claude role's 1Password probe is selected whenever a task
#                reading its result is, under every tag selection a mise task
#                or the docs name (it was once lost to `--skip-tags linux`).
#   Refusal   -- the become plugin playbook.sh selects fails a task that would
#                escalate with a message naming the way out, and leaves a
#                task whose `when:` is false, and unprivileged tasks, alone.
set -uo pipefail

here="$(cd -- "$(dirname "$0")" && pwd -P)"
repo="$(cd -- "$here/.." && pwd -P)"
work="$(mktemp -d)" || { echo "FAIL[harness]: mktemp failed"; exit 1; }
trap 'rm -rf "$work"' EXIT
trap 'exit 130' INT TERM HUP
fails=0

ok()   { printf 'ok[%s]: %s\n' "$1" "$2"; }
fail() { printf 'FAIL[%s]: %s\n' "$1" "$2"; fails=$((fails + 1)); }

user_config_roles="kitty fish services environments tmux ssh git claude"

# list <ansible-playbook selection args...>: one `role : task` line per task.
list() {
    (cd "$repo" && ansible-playbook main.yml --list-tasks -l server "$@") >"$work/list" 2>&1 \
        || { echo "FAIL[harness]: --list-tasks $* failed"; sed 's/^/    /' "$work/list" | tail -20; exit 1; }
    awk -F'\t' '$1 ~ /^ +[a-z_-]+ : / && $2 ~ /^TAGS: \[/ {
        sub(/^ +/, "", $1); t = $2; sub(/^TAGS: \[/, "", t); sub(/\]$/, "", t); print $1 "|" t
    }' "$work/list" >"$work/tasks"
    [ -s "$work/tasks" ] || { echo "FAIL[harness]: --list-tasks $* listed no tasks"; exit 1; }
}
has_task() { grep -qF -- "$1" "$work/tasks"; }
has_role() { grep -q "^$1 : " "$work/tasks"; }

list --tags user-config --skip-tags privileged,upgrade
for r in osx linux; do
    if has_role "$r"; then fail "selection-excludes-$r" "$(grep "^$r : " "$work/tasks" | head -3 | tr '\n' ';')"
    else ok "selection-excludes-$r" "no $r task is selected"; fi
done
for r in $user_config_roles; do
    if has_role "$r"; then ok "selection-includes-$r" "$r is selected"
    else fail "selection-includes-$r" "no $r task is selected"; fi
done
if has_task "services : Install the declared dev-service packages"; then
    fail selection-excludes-services-lifecycle "the Debian services lifecycle (apt, systemd) is selected"
else
    ok selection-excludes-services-lifecycle "the Debian services lifecycle is left out"
fi
if has_task "services : Apply the client defaults to my.cnf"; then
    ok selection-keeps-services-darwin "the unprivileged macOS services content stays in"
else
    fail selection-keeps-services-darwin "the macOS services content is not selected"
fi
untagged="$(grep -v 'user-config' "$work/tasks" | head -3 | tr '\n' ';')"
if [ -z "$untagged" ]; then ok selection-tagged "every selected task carries user-config"
else fail selection-tagged "selected without the tag: $untagged"; fi

list
for r in osx linux $user_config_roles; do
    if has_role "$r"; then ok "full-run-includes-$r" "the full run still lists $r"
    else fail "full-run-includes-$r" "the full run lost $r"; fi
done

probe="claude : Detect the 1Password CLI"
for sel in "--tags user-config --skip-tags privileged,upgrade" "--skip-tags linux" "--skip-tags osx" \
    "--tags claude" "--tags osx" "--tags linux" "--skip-tags shell,upgrade"; do
    # shellcheck disable=SC2086  # word-split on purpose: $sel is several arguments
    list $sel
    consumers="$(grep -c -e 'claude : Render ' -e 'claude : Sync Gemini' "$work/tasks")"
    if [ "$consumers" -eq 0 ] || has_task "$probe"; then
        ok "probe[$sel]" "the 1Password probe is selected wherever its result is read"
    else
        fail "probe[$sel]" "$consumers task(s) read claude_op_probe but the probe is not selected"
    fi
done

# The plugin is found the way main.yml finds it: beside the playbook.
ln -s "$repo/become_plugins" "$work/become_plugins" || { echo "FAIL[harness]: cannot link become_plugins"; exit 1; }
cat >"$work/play.yml" <<'YAML' || { echo "FAIL[harness]: cannot write the play"; exit 1; }
- name: Exercise the privilege refusal
  hosts: localhost
  connection: local
  gather_facts: false
  tasks:
    - name: Unprivileged task
      ansible.builtin.command: "true"
      changed_when: false
    - name: Privileged task whose condition is false
      ansible.builtin.command: "true"
      become: true
      changed_when: false
      when: false
    - name: Privileged task that would run
      ansible.builtin.command: "true"
      become: true
      become_user: postgres
      changed_when: false
YAML
(cd "$work" && ansible-playbook -i localhost, play.yml -e ansible_become_method=refuse_privilege) >"$work/out" 2>&1
rc=$?
grep -q 'PLAY RECAP' "$work/out" || { echo "FAIL[harness]: no recap"; sed 's/^/    /' "$work/out" | tail -20; exit 1; }
if [ "$rc" -ne 0 ] && grep -qE 'ok=1 .*failed=1 .*skipped=1 ' "$work/out"; then
    ok refusal-scope "only the task that would escalate fails"
else
    fail refusal-scope "rc $rc; $(grep -A1 'PLAY RECAP' "$work/out" | tail -1)"
fi
if grep -qF 'needs privilege escalation' "$work/out" && grep -qF 'playbook.sh -K' "$work/out"; then
    ok refusal-message "the failure says why and names the full run as the way out"
else
    fail refusal-message "$(grep -m1 'fatal:' "$work/out")"
fi

if [ "$fails" -eq 0 ]; then
    echo "user-config-selection-test: all assertions hold"
else
    echo "user-config-selection-test: $fails assertion(s) failed"
    exit 1
fi
