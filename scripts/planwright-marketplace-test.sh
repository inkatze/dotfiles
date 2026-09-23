#!/usr/bin/env bash
# Fixture suite for the planwright marketplace migration in roles/claude.
#
# A host that recorded the marketplace under a different source (the full
# HTTPS URL the role used to add) rejects the shorthand add outright, so the
# role has to remove the stale record first. It must remove ONLY a stale one:
# removing a matching record on every run would re-clone the marketplace each
# time and report a change forever.
#
# Driven through ansible-playbook against a scratch HOME with a stub `claude`
# that logs its arguments, since the decision is a Jinja expression over two
# JSON files and a wrong key path still reads plausibly.
set -uo pipefail

here="$(cd -- "$(dirname "$0")" && pwd -P)"
repo="$(cd -- "$here/.." && pwd -P)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
trap 'exit 130' INT TERM HUP
fails=0

ok()   { printf 'ok[%s]: %s\n' "$1" "$2"; }
fail() { printf 'FAIL[%s]: %s\n' "$1" "$2"; fails=$((fails + 1)); }

# Playbook outside the repo so lefthook's repo-wide linters never see it; see
# credential-path-guard-test.sh for why the roles tree is symlinked beside it.
ln -s "$repo/roles" "$work/roles"
play="$work/play.yml"
cat >"$play" <<'YAML'
- name: Exercise the planwright marketplace tasks
  hosts: localhost
  connection: local
  gather_facts: true
  tasks:
    - name: Run only the planwright tasks
      ansible.builtin.include_role:
        name: claude
        tasks_from: planwright
YAML

legacy='{"source":"git","url":"https://github.com/inkatze/planwright.git"}'
current='{"source":"github","repo":"inkatze/planwright"}'

fresh_home() {
    h="$work/h$RANDOM"
    mkdir -p "$h/.local/bin" "$h/.claude/plugins"
    cat >"$h/.local/bin/claude" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >>"$HOME/calls"
echo "stub ok"
SH
    chmod +x "$h/.local/bin/claude"
    printf '%s\n' "$h"
}

# $1: home, $2: marketplace source for settings.json, $3: for known_marketplaces.json.
# An empty source leaves that file absent.
seed() {
    [ -n "$2" ] && printf '{"extraKnownMarketplaces":{"planwright":{"source":%s}}}\n' "$2" >"$1/.claude/settings.json"
    [ -n "$3" ] && printf '{"planwright":{"source":%s}}\n' "$3" >"$1/.claude/plugins/known_marketplaces.json"
    return 0
}

# CI is unset for the run: the tasks are CI-guarded, and a runner exports it,
# which would skip every task and pass each "no removal" case vacuously.
run_role() {
    HOME="$1" env -u CI ansible-playbook "$play" >"$work/out" 2>&1
    if ! grep -q 'PLAY RECAP' "$work/out" || grep -qE '^fatal' "$work/out"; then
        printf 'FAIL[harness]: the playbook did not complete\n'
        grep -A4 -E '^fatal|ERROR' "$work/out" | head -12 | sed 's/^/    /'
        exit 1
    fi
    if ! grep -q 'marketplace add inkatze/planwright' "$1/calls" 2>/dev/null; then
        printf 'FAIL[harness]: the add never ran\n'
        exit 1
    fi
}

removed() { grep -q 'marketplace remove planwright' "$1/calls"; }

# 1. The legacy URL source in settings.json, the record the add is checked
#    against, is removed before the add.
h="$(fresh_home)"; seed "$h" "$legacy" "$legacy"; run_role "$h"
if [ "$(sed -n 1p "$h/calls")" = "plugin marketplace remove planwright" ] &&
   [ "$(sed -n 2p "$h/calls")" = "plugin marketplace add inkatze/planwright" ]; then
    ok legacy-removed-first "removed, then re-added by shorthand"
else
    fail legacy-removed-first "calls: $(tr '\n' ';' <"$h/calls")"
fi

# 2. A stale record in only one of the two files is still acted on.
h="$(fresh_home)"; seed "$h" "" "$legacy"; run_role "$h"
if removed "$h"; then
    ok legacy-known-only "stale known_marketplaces.json record removed"
else
    fail legacy-known-only "no removal with a stale known_marketplaces.json record"
fi
h="$(fresh_home)"; seed "$h" "$legacy" ""; run_role "$h"
if removed "$h"; then
    ok legacy-settings-only "stale settings.json record removed"
else
    fail legacy-settings-only "no removal with a stale settings.json record"
fi

# 3. A matching record is left alone, or every run re-clones and reports a change.
h="$(fresh_home)"; seed "$h" "$current" "$current"; run_role "$h"
if ! removed "$h"; then
    ok current-kept "matching source not removed"
else
    fail current-kept "a matching source was removed"
fi

# 4. A fresh host with neither file just adds.
h="$(fresh_home)"; run_role "$h"
if ! removed "$h"; then
    ok fresh-host "no removal without a recorded source"
else
    fail fresh-host "removed on a host with nothing recorded"
fi

# 5. Other marketplaces do not trigger it.
h="$(fresh_home)"
printf '{"extraKnownMarketplaces":{"other":{"source":%s}}}\n' "$legacy" >"$h/.claude/settings.json"
run_role "$h"
if ! removed "$h"; then
    ok other-marketplace "an unrelated marketplace left alone"
else
    fail other-marketplace "removed planwright because of another marketplace"
fi

if [ "$fails" -eq 0 ]; then
    echo "planwright-marketplace-test: all assertions hold"
else
    echo "planwright-marketplace-test: $fails assertion(s) failed"
    exit 1
fi
