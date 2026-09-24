#!/usr/bin/env bash
# Fixture suite for how scripts/playbook.sh picks the inventory host it passes
# to `ansible-playbook -l`, and the OP_ACCOUNT it exports.
#
# The property that matters most is the empty case: `-l ""` is read by Ansible
# as no limit at all, so an alias file that exists but names nothing would run
# every inventory host's configuration against this machine. An empty or
# whitespace-only file has to behave like an absent one.
#
# Driven end to end with stubs for ansible-playbook and hostname first on PATH,
# so nothing is provisioned and the hostname branch is deterministic.
set -uo pipefail

here="$(cd -- "$(dirname "$0")" && pwd -P)"
playbook="$here/playbook.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
trap 'exit 130' INT TERM HUP
fails=0

ok()   { printf 'ok[%s]: %s\n' "$1" "$2"; }
fail() { printf 'FAIL[%s]: %s\n' "$1" "$2"; fails=$((fails + 1)); }

mkdir -p "$work/bin"
cat >"$work/bin/ansible-playbook" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$STUB_ARGV"
printf '%s' "${OP_ACCOUNT-<unset>}" >"$STUB_OP_ACCOUNT"
SH
cat >"$work/bin/hostname" <<'SH'
#!/usr/bin/env bash
echo "${STUB_HOSTNAME:-ci-runner}"
SH
chmod +x "$work/bin/ansible-playbook" "$work/bin/hostname"

# Runs playbook.sh with a clean environment apart from what the case sets, then
# prints the value passed to -l. A missing argv file means the stub never ran,
# which is reported as such rather than as an empty limit.
limit_for() {
    rm -f "$work/argv" "$work/op"
    env -i PATH="$work/bin:$PATH" HOME="$work/home" \
        STUB_ARGV="$work/argv" STUB_OP_ACCOUNT="$work/op" \
        DOTFILES_HOST_FILE="$work/host" DOTFILES_OP_ACCOUNT_FILE="$work/op-account" \
        "$@" bash "$playbook" >/dev/null 2>"$work/stderr"
    if [ ! -f "$work/argv" ]; then
        echo "<not run>"
        return
    fi
    awk 'prev == "-l" { print; found = 1; exit } { prev = $0 } END { if (!found) print "<no -l>" }' "$work/argv"
}

expect_limit() {
    name="$1" want="$2"
    shift 2
    got="$(limit_for "$@")"
    if [ "$got" = "$want" ]; then
        ok "$name" "-l '$got'"
    else
        fail "$name" "expected -l '$want', got '$got'"
    fi
}

reset_files() { rm -f "$work/host" "$work/op-account"; }

# 1. The regression: an empty file must not produce an empty limit.
reset_files
: >"$work/host"
expect_limit empty-file work
if grep -q 'defaulting to' "$work/stderr"; then
    ok empty-file-warns "fallback warning printed"
else
    fail empty-file-warns "no fallback warning on stderr"
fi

# 2. Same for whitespace only, which `tr -d '[:space:]'` also trims to nothing.
reset_files
printf ' \n\t\n' >"$work/host"
expect_limit whitespace-file work

# 3. An empty file still falls through to the alt hostname match, not straight
#    to work.
reset_files
: >"$work/host"
expect_limit empty-file-alt-hostname alt STUB_HOSTNAME=panela-mini

# 4. A file naming a host is used, trimmed.
reset_files
printf 'server\n' >"$work/host"
expect_limit file-names-host server

# 5. DOTFILES_HOST wins over the file.
reset_files
printf 'server\n' >"$work/host"
expect_limit env-override personal DOTFILES_HOST=personal

# 6. No file and no hostname match falls back to work.
reset_files
expect_limit absent-file work

# 7. DOTFILES_HOST is the escape hatch for a broken file, so the file is not
#    read at all when it is set. Root reads a mode-000 file regardless.
if [ "$(id -u)" -eq 0 ]; then
    ok env-skips-unreadable-file "skipped: running as root"
else
    reset_files
    : >"$work/host"
    chmod 000 "$work/host"
    expect_limit env-skips-unreadable-file personal DOTFILES_HOST=personal
    chmod 600 "$work/host"
fi

# 8. OP_ACCOUNT: an empty or whitespace-only file exports nothing, a populated
#    one exports its trimmed value, and an already-exported value wins.
op_for() {
    limit_for "$@" >/dev/null
    cat "$work/op" 2>/dev/null || echo "<not run>"
}
expect_op() {
    name="$1" want="$2"
    shift 2
    got="$(op_for "$@")"
    if [ "$got" = "$want" ]; then
        ok "$name" "OP_ACCOUNT=$got"
    else
        fail "$name" "expected OP_ACCOUNT=$want, got $got"
    fi
}

reset_files
: >"$work/op-account"
expect_op op-empty-file '<unset>'

reset_files
printf '  \n' >"$work/op-account"
expect_op op-whitespace-file '<unset>'

reset_files
printf 'my.1password.com\n' >"$work/op-account"
expect_op op-file my.1password.com

reset_files
printf 'my.1password.com\n' >"$work/op-account"
expect_op op-env-wins other.1password.com OP_ACCOUNT=other.1password.com

reset_files
expect_op op-absent-file '<unset>'

if [ "$fails" -eq 0 ]; then
    echo "playbook-alias-test: all assertions hold"
else
    echo "playbook-alias-test: $fails assertion(s) failed"
    exit 1
fi
