#!/usr/bin/env bash
# Fixture suite for the sshCommand roles/git writes into ~/.gitconfig.local.
#
# A host on git_unattended_auth_hosts must get an sshCommand that offers its
# on-disk key and nothing from an agent (IdentitiesOnly), and a host off the
# list must get no sshCommand at all, since that would change how a host with a
# working agent authenticates.
#
# Driven through ansible-playbook against a scratch HOME rather than by reading
# the template, because the result depends on the inventory alias resolving
# through two defaults and a Jinja conditional, and a broken chain still reads
# correctly.
set -uo pipefail

here="$(cd -- "$(dirname "$0")" && pwd -P)"
repo="$(cd -- "$here/.." && pwd -P)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
trap 'exit 130' INT TERM HUP
fails=0

ok()   { printf 'ok[%s]: %s\n' "$1" "$2"; }
fail() { printf 'FAIL[%s]: %s\n' "$1" "$2"; fails=$((fails + 1)); }

# Outside the repo so lefthook's repo-wide linters never see it. The roles
# symlink is what lets include_role find the real role from here.
ln -s "$repo/roles" "$work/roles"
play="$work/play.yml"
cat >"$play" <<'YAML'
- name: Exercise the git role
  hosts: all
  connection: local
  gather_facts: true
  tasks:
    - name: Run the git role
      ansible.builtin.include_role:
        name: git
YAML

# Inventory aliases the role keys on, all local. The real inventory also sets
# become options for `server`, which this role never uses.
inv="$work/hosts"
cat >"$inv" <<INI
server ansible_connection=local ansible_python_interpreter=$(command -v python3)
personal ansible_connection=local ansible_python_interpreter=$(command -v python3)
INI

# Placeholder key files, so the role's `creates` guards skip key generation:
# the property under test is the rendered config, not ssh-keygen.
fresh_home() {
    h="$work/h$RANDOM"
    mkdir -p "$h/.ssh"
    for k in id_signing id_github_auth; do
        : >"$h/.ssh/$k"
        : >"$h/.ssh/$k.pub"
    done
    printf '%s\n' "$h"
}

# $1: home, $2: inventory alias. Run from the scratch directory because the
# role builds a symlink source from the working directory.
run_role() {
    (cd "$work" && HOME="$1" ansible-playbook -i "$inv" -l "$2" "$play") >"$work/out" 2>&1
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
    if [ ! -f "$1/.gitconfig.local" ]; then
        printf 'FAIL[harness]: the run wrote no .gitconfig.local\n'
        grep -E '^TASK|: ok=' "$work/out" | head -8 | sed 's/^/    /'
        exit 1
    fi
}

# 1. A listed host offers only its on-disk key.
h="$(fresh_home)"
run_role "$h" server
cmd="$(git config --file "$h/.gitconfig.local" --get core.sshCommand)"
case "$cmd" in
    *"-i $h/.ssh/id_github_auth"*) ok listed-key "sshCommand names the on-disk key" ;;
    *) fail listed-key "sshCommand is '$cmd'" ;;
esac
case "$cmd" in
    *"IdentitiesOnly=yes"*) ok listed-identities-only "agent identities are not offered" ;;
    *) fail listed-identities-only "sshCommand is '$cmd'" ;;
esac

# 2. A host off the list gets no sshCommand, so its agent keeps working as is.
h="$(fresh_home)"
run_role "$h" personal
if cmd="$(git config --file "$h/.gitconfig.local" --get core.sshCommand)"; then
    fail unlisted-untouched "sshCommand is '$cmd'"
else
    ok unlisted-untouched "no sshCommand written"
fi

if [ "$fails" -eq 0 ]; then
    echo "git-unattended-auth-test: all assertions hold"
else
    echo "git-unattended-auth-test: $fails assertion(s) failed"
    exit 1
fi
