#!/usr/bin/env bash
# Fixture suite for the credential-path guard in roles/environments (~/.npmrc)
# and roles/services (~/.my.cnf).
#
# The property under test is a security one: both paths hold credentials
# (registry _authToken lines, a MySQL client password) and both roles write to
# them with blockinfile, which has no `follow` option and therefore writes
# THROUGH a symlink. So a symlink this repo does not own must be skipped
# outright -- otherwise the block, and anything a later writer appends beside
# it, lands in whatever file another tool points that path at. A symlink an
# earlier version of the role left behind must instead be replaced, because it
# points into a public checkout.
#
# Driven through ansible-playbook against a scratch HOME rather than by reading
# the tasks, since the guard is a `when:` expression and a reordering that
# breaks it would still read correctly.
set -uo pipefail

here="$(cd -- "$(dirname "$0")" && pwd -P)"
repo="$(cd -- "$here/.." && pwd -P)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
trap 'exit 130' INT TERM HUP
fails=0

ok()   { printf 'ok[%s]: %s\n' "$1" "$2"; }
fail() { printf 'FAIL[%s]: %s\n' "$1" "$2"; fails=$((fails + 1)); }

# ansible-playbook makes the PLAYBOOK's directory the process working
# directory, and these roles build symlink targets from ansible_facts.env.PWD.
# A playbook in the scratch directory therefore resolves every src path under
# the scratch directory -- hence the symlinked roles tree beside it, which is
# what points those paths back at the real files. Keeping the playbook out of
# the repo matters: lefthook runs `yamllint .` and `ansible-lint` over the whole
# tree, so a transient file there trips the repo's own linters.
ln -s "$repo/roles" "$work/roles"

# tasks_from rather than the whole role: the role also symlinks a machine-local
# mise.toml, and running the role entire pulls in work unrelated to the paths
# under test.
play="$work/play.yml"
cat >"$play" <<'YAML'
- name: Exercise the tasks that own the credential paths
  hosts: localhost
  connection: local
  gather_facts: true
  tasks:
    - name: Run only the nodejs tasks, which own ~/.npmrc
      ansible.builtin.include_role:
        name: environments
        tasks_from: nodejs
YAML

# Runs the tasks with HOME pointed at a fresh scratch directory. Each case seeds
# ~/.npmrc itself, so the run only has to report what it did with it. The guards
# are here because a run that does nothing leaves every fixture untouched, which
# several assertions below would otherwise read as success.
run_role() {
    home="$1"
    # No -t filter: the include_role wrapper carries no tag of its own, so a tag
    # filter excludes it and the play runs nothing but Gathering Facts.
    HOME="$home" ansible-playbook "$play" >"$work/out" 2>&1
    if ! grep -q 'PLAY RECAP' "$work/out"; then
        printf 'FAIL[harness]: the playbook did not run; no PLAY RECAP\n'
        sed 's/^/    /' "$work/out" | head -12
        exit 1
    fi
    if grep -qE '^fatal' "$work/out"; then
        printf 'FAIL[harness]: the playbook reported a fatal\n'
        grep -A4 '^fatal' "$work/out" | head -12 | sed 's/^/    /'
        exit 1
    fi
    if ! grep -q 'Apply the npm defaults to npmrc' "$work/out"; then
        printf 'FAIL[harness]: the npmrc tasks never appeared in the run\n'
        grep -E '^TASK|localhost *:' "$work/out" | head -8 | sed 's/^/    /'
        exit 1
    fi
}

fresh_home() {
    h="$work/h$RANDOM"
    mkdir -p "$h"
    printf '%s\n' "$h"
}

# 1. A foreign symlink is left alone: not removed, not written through.
h="$(fresh_home)"
foreign="$h/other-tool-npmrc"
printf '//registry.example.test/:_authToken=SECRET\n' >"$foreign"
ln -s "$foreign" "$h/.npmrc"
run_role "$h"
if [ -L "$h/.npmrc" ] &&
   [ "$(readlink "$h/.npmrc")" = "$foreign" ] &&
   ! grep -q 'ANSIBLE MANAGED BLOCK' "$foreign" &&
   grep -q 'SECRET' "$foreign"; then
    ok foreign-symlink-untouched "left the link in place and wrote nothing through it"
else
    fail foreign-symlink-untouched "link=$( [ -L "$h/.npmrc" ] && readlink "$h/.npmrc" || echo '<gone>') target_written=$(grep -c 'ANSIBLE MANAGED BLOCK' "$foreign" 2>/dev/null)"
fi

# 2. The skip is reported rather than silent, or the missing defaults look like
#    a bug in npm rather than a deliberate refusal.
if grep -q 'does not own' "$work/out"; then
    ok foreign-symlink-reported "the run said why the defaults were not applied"
else
    fail foreign-symlink-reported "no report of the skipped foreign symlink"
fi

# 3. A symlink this repo owns is replaced with a real file, because npm writes
#    through it and the target is a public checkout.
h="$(fresh_home)"
ln -s "$repo/roles/environments/files/npmrc" "$h/.npmrc"
before="$(sha256sum "$repo/roles/environments/files/npmrc" 2>/dev/null || shasum -a 256 "$repo/roles/environments/files/npmrc")"
run_role "$h"
after="$(sha256sum "$repo/roles/environments/files/npmrc" 2>/dev/null || shasum -a 256 "$repo/roles/environments/files/npmrc")"
if [ ! -L "$h/.npmrc" ] && [ -f "$h/.npmrc" ] && grep -q 'ANSIBLE MANAGED BLOCK' "$h/.npmrc"; then
    ok owned-symlink-replaced "replaced with a real file carrying the block"
else
    fail owned-symlink-replaced "still a symlink, or the block is missing"
fi
if [ "$before" = "$after" ]; then
    ok tracked-file-untouched "the tracked npmrc in the repo was not written to"
else
    fail tracked-file-untouched "THE TRACKED FILE CHANGED — a write went through the symlink"
fi

# 4. A pre-existing real file keeps its own content and only gains the block.
h="$(fresh_home)"
printf '//registry.example.test/:_authToken=KEEPME\n' >"$h/.npmrc"
run_role "$h"
if grep -q 'KEEPME' "$h/.npmrc" && grep -q 'ANSIBLE MANAGED BLOCK' "$h/.npmrc"; then
    ok real-file-preserved "existing content kept, block appended"
else
    fail real-file-preserved "existing content lost or block missing"
fi

# 5. The file holds credentials, so the mode is asserted rather than inherited.
#    GNU stat first: its -f is --file-system and would "succeed" on a format
#    string, never falling through to BSD's -f.
mode="$(stat -c '%a' "$h/.npmrc" 2>/dev/null || stat -f '%Lp' "$h/.npmrc")"
if [ "$mode" = 600 ]; then
    ok mode-asserted "left at 0600"
else
    fail mode-asserted "mode is $mode"
fi

# 6. Running twice adds one block, not two.
run_role "$h"
count="$(grep -c 'BEGIN ANSIBLE MANAGED BLOCK' "$h/.npmrc")"
if [ "$count" = 1 ]; then
    ok idempotent "one block after a second run"
else
    fail idempotent "$count blocks after a second run"
fi

if [ "$fails" -eq 0 ]; then
    echo "credential-path-guard-test: all assertions hold"
else
    echo "credential-path-guard-test: $fails assertion(s) failed"
    exit 1
fi
