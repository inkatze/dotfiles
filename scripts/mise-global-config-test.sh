#!/usr/bin/env bash
# Fixture suite for the environments role's move of the mise pins from
# ~/.config/mise.toml to mise's global config, ~/.config/mise/config.toml.
#
# Driven through ansible-playbook against a scratch HOME, for the reason
# credential-path-guard-test.sh gives: the migration is a set of `when:`
# expressions, and a reordering that breaks them would still read correctly.
set -uo pipefail

here="$(cd -- "$(dirname "$0")" && pwd -P)"
repo="$(cd -- "$here/.." && pwd -P)"
work="$(cd -- "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$work"' EXIT
trap 'exit 130' INT TERM HUP
fails=0

ok()   { printf 'ok[%s]: %s\n' "$1" "$2"; }
fail() { printf 'FAIL[%s]: %s\n' "$1" "$2"; fails=$((fails + 1)); }

# The roles build link targets from ansible_facts.env.PWD, which is the
# playbook's directory, so the scratch directory carries a link to the real
# roles tree. See credential-path-guard-test.sh.
ln -s "$repo/roles" "$work/roles"
pins="$work/roles/environments/files/mise.toml"
idiomatic="$work/roles/environments/files/mise-idiomatic.toml"

play="$work/play.yml"
cat >"$play" <<'YAML'
- name: Exercise the mise global config tasks
  hosts: localhost
  connection: local
  gather_facts: true
  tasks:
    - name: Run only the tasks that own the mise config paths
      ansible.builtin.include_role:
        name: environments
        tasks_from: mise_config
YAML

run_role() {
    h_="$1"; shift
    HOME="$h_" ansible-playbook "$play" "$@" >"$work/out" 2>&1
    if ! grep -q 'PLAY RECAP' "$work/out" || grep -qE '^fatal' "$work/out"; then
        printf 'FAIL[harness]: the playbook did not complete\n'
        sed 's/^/    /' "$work/out" | tail -12
        exit 1
    fi
    if ! grep -q 'Inspect the mise global config' "$work/out"; then
        printf 'FAIL[harness]: the mise config tasks never appeared in the run\n'
        exit 1
    fi
}

changed() { grep -oE 'changed=[0-9]+' "$work/out" | head -1 | cut -d= -f2; }

fresh_home() {
    h="$(mktemp -d "$work/h.XXXXXX")" || exit 1
    mkdir -p "$h/.config"
    printf '%s\n' "$h"
}

idiomatic_path() { printf '%s/.config/mise/conf.d/dotfiles-idiomatic.toml' "$1"; }
idiomatic_is_ours() { [ -L "$(idiomatic_path "$1")" ] && [ "$(readlink "$(idiomatic_path "$1")")" = "$idiomatic" ]; }
work_host=(-e environments_mise_idiomatic_enabled=false)

global_is_ours() { [ -L "$1/.config/mise/config.toml" ] && [ "$(readlink "$1/.config/mise/config.toml")" = "$pins" ]; }

# 1. A fresh host gets the global link, and a second run changes nothing.
h="$(fresh_home)"
run_role "$h"
if global_is_ours "$h"; then
    ok fresh-linked "global config linked at the pins"
else
    fail fresh-linked "global config is $(ls -l "$h/.config/mise/config.toml" 2>&1)"
fi
run_role "$h"
if [ "$(changed)" = 0 ]; then
    ok idempotent "second run reported changed=0"
else
    fail idempotent "second run reported changed=$(changed)"
fi

# 2. The old role's link is removed once the global link is in place, including
#    one naming a different clone.
h="$(fresh_home)"
ln -s /elsewhere/clone/roles/environments/files/mise.toml "$h/.config/mise.toml"
run_role "$h"
if global_is_ours "$h" && [ ! -e "$h/.config/mise.toml" ] && [ ! -L "$h/.config/mise.toml" ]; then
    ok legacy-link-migrated "old link removed, global link in place"
else
    fail legacy-link-migrated "legacy=$(readlink "$h/.config/mise.toml" 2>/dev/null || echo '<gone>')"
fi

# 3. A global link from before the asdf interlude, to files/config.toml, is
#    this repo's and is repointed.
h="$(fresh_home)"
mkdir -p "$h/.config/mise"
ln -s /elsewhere/clone/roles/environments/files/config.toml "$h/.config/mise/config.toml"
run_role "$h"
if global_is_ours "$h"; then
    ok old-global-link-repointed "config.toml link repointed at the pins"
else
    fail old-global-link-repointed "global=$(readlink "$h/.config/mise/config.toml" 2>/dev/null)"
fi

# 4. A real global config is never clobbered, and the old link stays so the
#    host keeps its pins.
h="$(fresh_home)"
mkdir -p "$h/.config/mise"
printf '[tools]\nfoo = "1"\n' >"$h/.config/mise/config.toml"
ln -s "$pins" "$h/.config/mise.toml"
run_role "$h"
if [ ! -L "$h/.config/mise/config.toml" ] && grep -q 'foo' "$h/.config/mise/config.toml" &&
   [ -L "$h/.config/mise.toml" ] && grep -q 'was left alone' "$work/out"; then
    ok real-global-kept "real config.toml untouched, old link kept, skip reported"
else
    fail real-global-kept "global=$(ls -l "$h/.config/mise/config.toml") legacy=$(readlink "$h/.config/mise.toml" 2>/dev/null || echo '<gone>')"
fi

# 5. A foreign symlink at the global path is left alone.
h="$(fresh_home)"
mkdir -p "$h/.config/mise"
ln -s /elsewhere/other-tool.toml "$h/.config/mise/config.toml"
run_role "$h"
if [ "$(readlink "$h/.config/mise/config.toml")" = /elsewhere/other-tool.toml ]; then
    ok foreign-global-kept "foreign global link untouched"
else
    fail foreign-global-kept "global=$(readlink "$h/.config/mise/config.toml")"
fi

# 6. Anything at the old path that is not this repo's link is left and reported.
h="$(fresh_home)"
ln -s /elsewhere/mise.toml "$h/.config/mise.toml"
run_role "$h"
foreign_ok=0
[ "$(readlink "$h/.config/mise.toml")" = /elsewhere/mise.toml ] && grep -q 'was left alone' "$work/out" && foreign_ok=1
h="$(fresh_home)"
printf '[tools]\n' >"$h/.config/mise.toml"
run_role "$h"
if [ "$foreign_ok" = 1 ] && [ -f "$h/.config/mise.toml" ] && [ ! -L "$h/.config/mise.toml" ] &&
   grep -q 'was left alone' "$work/out" && global_is_ours "$h"; then
    ok foreign-legacy-kept "foreign link and real file at the old path untouched and reported"
else
    fail foreign-legacy-kept "foreign_ok=$foreign_ok real=$(ls -l "$h/.config/mise.toml" 2>&1)"
fi

# 7. The idiomatic-version setting lives in its own conf.d link, never in the
#    global pins, and a personal host gets that link.
h="$(fresh_home)"
run_role "$h"
if idiomatic_is_ours "$h" && ! grep -q 'idiomatic_version_file_enable_tools' "$pins"; then
    ok idiomatic-linked "conf.d link in place, pins free of the setting"
else
    fail idiomatic-linked "idiomatic=$(ls -l "$(idiomatic_path "$h")" 2>&1)"
fi

# 8. A work host gets no link, an earlier run's link is removed, and a second
#    run changes nothing.
h="$(fresh_home)"
run_role "$h" "${work_host[@]}"
none_ok=0
[ ! -e "$(idiomatic_path "$h")" ] && [ ! -L "$(idiomatic_path "$h")" ] && global_is_ours "$h" && none_ok=1
mkdir -p "$(dirname "$(idiomatic_path "$h")")"
ln -s /elsewhere/clone/roles/environments/files/mise-idiomatic.toml "$(idiomatic_path "$h")"
run_role "$h" "${work_host[@]}"
removed_ok=0
[ ! -e "$(idiomatic_path "$h")" ] && [ ! -L "$(idiomatic_path "$h")" ] && removed_ok=1
run_role "$h" "${work_host[@]}"
if [ "$none_ok" = 1 ] && [ "$removed_ok" = 1 ] && [ "$(changed)" = 0 ]; then
    ok idiomatic-work-host "no link created, earlier link removed, rerun changed=0"
else
    fail idiomatic-work-host "none_ok=$none_ok removed_ok=$removed_ok changed=$(changed)"
fi

# 9. A foreign file at the conf.d path is left alone on either kind of host.
h="$(fresh_home)"
mkdir -p "$(dirname "$(idiomatic_path "$h")")"
printf '[settings]\nfoo = "seeded"\n' >"$(idiomatic_path "$h")"
cp "$(idiomatic_path "$h")" "$work/idiomatic-seed"
run_role "$h"
personal_kept=0
[ -f "$(idiomatic_path "$h")" ] && [ ! -L "$(idiomatic_path "$h")" ] &&
    cmp -s "$work/idiomatic-seed" "$(idiomatic_path "$h")" && personal_kept=1
run_role "$h" "${work_host[@]}"
if [ "$personal_kept" = 1 ] && [ -f "$(idiomatic_path "$h")" ] && [ ! -L "$(idiomatic_path "$h")" ] &&
   cmp -s "$work/idiomatic-seed" "$(idiomatic_path "$h")" && grep -q 'was left alone' "$work/out"; then
    ok idiomatic-foreign-kept "real conf.d file untouched and reported"
else
    fail idiomatic-foreign-kept "personal_kept=$personal_kept idiomatic=$(ls -l "$(idiomatic_path "$h")" 2>&1)"
fi

if [ "$fails" -gt 0 ]; then
    printf 'mise-global-config-test: %d assertion(s) failed\n' "$fails"
    exit 1
fi
printf 'mise-global-config-test: all assertions hold\n'
