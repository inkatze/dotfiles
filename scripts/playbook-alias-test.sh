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
work="$(mktemp -d)" || exit 1
trap 'rm -rf "$work"' EXIT
trap 'exit 130' INT TERM HUP
fails=0

ok()   { printf 'ok[%s]: %s\n' "$1" "$2"; }
skip() { printf 'skip[%s]: %s\n' "$1" "$2"; }
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
# Without both stubs in place, PATH would resolve to the real ansible-playbook
# and the first case would provision this machine.
[ -x "$work/bin/ansible-playbook" ] && [ -x "$work/bin/hostname" ] || {
    echo "playbook-alias-test: stubs under $work/bin are not executable; refusing to run" >&2
    exit 1
}

# Runs playbook.sh with a clean environment apart from what the case sets, then
# prints the value passed to -l. A missing argv file means the stub never ran,
# which is reported as such rather than as an empty limit. The exit status
# lands in a file, since the caller reads this through a substitution.
limit_for() {
    rm -f "$work/argv" "$work/op"
    env -i PATH="$work/bin:$PATH" HOME="$work/home" \
        STUB_ARGV="$work/argv" STUB_OP_ACCOUNT="$work/op" \
        DOTFILES_HOST_FILE="$work/host" DOTFILES_OP_ACCOUNT_FILE="$work/op-account" \
        "$@" bash "$playbook" >/dev/null 2>"$work/stderr"
    echo $? >"$work/rc"
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
if grep -q 'exists but names no alias' "$work/stderr"; then
    ok empty-file-named "the empty file is named on stderr"
else
    fail empty-file-named "stderr does not say the file was found empty"
fi

# 2. Same for whitespace only, which `tr -d '[:space:]'` also trims to nothing.
reset_files
printf ' \n\t\n' >"$work/host"
expect_limit whitespace-file work

# 3. An empty file still falls through to the alt hostname match, not straight
#    to work.
reset_files
: >"$work/host"
expect_limit empty-file-alt-hostname alt STUB_HOSTNAME=ci-panela-stub
if grep -q 'exists but names no alias' "$work/stderr"; then
    ok empty-file-alt-hostname-named "the empty file is named even when alt resolves"
else
    fail empty-file-alt-hostname-named "alt fallback ignored the empty file silently"
fi

# 4. A file naming a host is used, trimmed, with or without a trailing
#    newline, and without the fallback warning.
reset_files
printf 'server\n' >"$work/host"
expect_limit file-names-host server
if grep -q 'defaulting to' "$work/stderr"; then
    fail file-names-host-quiet "fallback warning printed although the file resolved"
else
    ok file-names-host-quiet "no fallback warning"
fi
reset_files
printf 'server' >"$work/host"
expect_limit file-no-newline server

# 5. DOTFILES_HOST wins over the file, but an empty one falls through to it.
reset_files
printf 'server\n' >"$work/host"
expect_limit env-override personal DOTFILES_HOST=personal
reset_files
printf 'server\n' >"$work/host"
expect_limit env-empty-falls-through server DOTFILES_HOST=

# 6. No file and no hostname match falls back to work.
reset_files
expect_limit absent-file work

# 7. DOTFILES_HOST is the escape hatch for a broken file, so the file is not
#    read at all when it is set; without the override, an unreadable file is a
#    misconfiguration and the run stops there rather than falling through to
#    another host. The read guard itself needs no unreadable file: an empty one
#    would print its notice if it were read.
reset_files
: >"$work/host"
expect_limit env-skips-file-read personal DOTFILES_HOST=personal
if grep -q 'names no alias' "$work/stderr"; then
    fail env-skips-file-read-quiet "the file was read although DOTFILES_HOST is set"
else
    ok env-skips-file-read-quiet "the file was not read"
fi

# The stub never starting is the expected outcome here, so the exit status and
# stderr have to say why, or any earlier abort would pass.
expect_abort() {
    name="$1" file="$2"
    shift 2
    got="$(limit_for "$@")"
    if [ "$got" = "<not run>" ] && [ "$(cat "$work/rc")" -ne 0 ] && grep -qF "$file" "$work/stderr"; then
        ok "$name" "aborted on $file with status $(cat "$work/rc")"
    else
        fail "$name" "expected an abort naming $file, got -l '$got' with status $(cat "$work/rc")"
    fi
}

# Root reads a mode-000 file regardless, so these two cannot run there.
if [ "$(id -u)" -eq 0 ]; then
    skip env-skips-unreadable-file "running as root"
    skip unreadable-file-aborts "running as root"
else
    reset_files
    : >"$work/host"
    chmod 000 "$work/host"
    expect_limit env-skips-unreadable-file personal DOTFILES_HOST=personal
    expect_abort unreadable-file-aborts "$work/host"
    chmod 600 "$work/host"
fi

# 8. Anything that is not a plain name, or not a host the inventory lists, is
#    refused outright with a non-zero status, whichever source it came from;
#    that includes values Ansible would split into nothing. `<not run>` means
#    the stub never started, which is the only acceptable outcome here.
expect_refused() {
    name="$1"
    shift
    got="$(limit_for "$@")"
    if [ "$got" = "<not run>" ] && [ "$(cat "$work/rc")" -ne 0 ] && grep -q 'refusing to run' "$work/stderr"; then
        ok "$name" "refused before ansible-playbook ran"
    else
        fail "$name" "expected a refusal, got -l '$got' with status $(cat "$work/rc")"
    fi
}

reset_files
printf ',\n' >"$work/host"
expect_refused separator-only-file

# Under a UTF-8 locale, so the escaping of the echoed value is exercised where
# it would otherwise print raw.
reset_files
printf '\302\240\n' >"$work/host"
expect_refused nbsp-only-file LC_ALL=C.UTF-8
if LC_ALL=C grep -q "$(printf '\302\240')" "$work/stderr"; then
    fail nbsp-escaped "the refused value reached stderr as raw bytes"
else
    ok nbsp-escaped "the refused value is escaped on stderr"
fi

reset_files
printf 'server\n' >"$work/host"
expect_refused whitespace-env DOTFILES_HOST=' '

reset_files
expect_refused separator-env DOTFILES_HOST=work,

# A bad leading character: `-v` would reach ansible-playbook's option parser,
# and `!work` is every host except work.
reset_files
expect_refused leading-hyphen-env DOTFILES_HOST=-v

reset_files
expect_refused negation-env DOTFILES_HOST='!work'

# A group name is a plain name that still means several hosts.
reset_files
printf 'all\n' >"$work/host"
expect_refused all-file

reset_files
expect_refused group-env DOTFILES_HOST=secrets

reset_files
expect_refused ungrouped-env DOTFILES_HOST=ungrouped

# The accepted set must not widen under a UTF-8 locale.
reset_files
expect_refused non-ascii-utf8-env DOTFILES_HOST="$(printf 'caf\303\251')" LC_ALL=C.UTF-8

# An escape sequence is the refused value that could actually drive the terminal.
reset_files
expect_refused esc-env DOTFILES_HOST="$(printf 'a\033[2Jb')"
if LC_ALL=C grep -q "$(printf '\033')" "$work/stderr"; then
    fail esc-escaped "a raw ESC reached stderr"
else
    ok esc-escaped "the ESC is escaped on stderr"
fi

# 9. OP_ACCOUNT: an empty or whitespace-only file exports nothing, a populated
#    one exports its trimmed value unless that isn't an account name, in which
#    case the run is refused, a non-empty already-exported value wins and
#    an empty one falls through to the file. An unreadable file is skipped
#    when OP_ACCOUNT is set and fatal otherwise, as for the host alias.
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
printf 'my.1password.com\n' >"$work/op-account"
expect_op op-empty-env-uses-file my.1password.com OP_ACCOUNT=

reset_files
expect_op op-absent-file '<unset>'

# A populated file that isn't an account is refused, not exported, under a
# UTF-8 locale too, where macOS tr would otherwise strip the NBSP.
reset_files
printf '\302\240\n' >"$work/op-account"
expect_refused op-nbsp-only-file LC_ALL=C.UTF-8
if LC_ALL=C grep -q "$(printf '\302\240')" "$work/stderr"; then
    fail op-nbsp-escaped "the refused value reached stderr as raw bytes"
else
    ok op-nbsp-escaped "the refused value is escaped on stderr"
fi

reset_files
printf ',\n' >"$work/op-account"
expect_refused op-separator-only-file

if [ "$(id -u)" -eq 0 ]; then
    skip op-env-skips-unreadable-file "running as root"
    skip op-unreadable-file-aborts "running as root"
else
    reset_files
    : >"$work/op-account"
    chmod 000 "$work/op-account"
    expect_op op-env-skips-unreadable-file other.1password.com OP_ACCOUNT=other.1password.com
    expect_abort op-unreadable-file-aborts "$work/op-account"
    chmod 600 "$work/op-account"
fi

if [ "$fails" -eq 0 ]; then
    echo "playbook-alias-test: all assertions hold"
else
    echo "playbook-alias-test: $fails assertion(s) failed"
    exit 1
fi
