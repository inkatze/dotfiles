#!/usr/bin/env bash
# Runs /panel-review's reviewer:<name> backend snippet, extracted from
# reviewer-backend.md, against a sandbox: a throwaway HOME, repository, fake
# mise and fake reviewer CLI. The CLI records the PATH, environment and argv it
# was started with, and the fake mise the environment it was asked from, so
# each case asserts what the snippet handed them.
#
# The fake mise answers `bin-paths` with a directory inside the repository
# when asked from there (a repo-steered config) and with HOME's tool
# directories otherwise. Every key here is an obvious placeholder.
set -uo pipefail

# A git hook exports these for the repository being committed to; inherited,
# they would point every sandbox git call below at that repository instead
# (the git-hook-environment case at the end proves they cannot). Global and
# system config stay out too, so a signing or hooks setting never reaches a
# sandbox commit.
unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR \
  GIT_PREFIX GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_NAMESPACE GIT_CEILING_DIRECTORIES \
  GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
inner=""
[ "${1:-}" != --inner ] || inner=1

root="$(cd "$(dirname "$0")/../../../.." && pwd)"
[ -f "$root/lefthook.yml" ] || {
  echo "reviewer-backend-test: must run from the dotfiles checkout (root resolved to $root)"
  exit 1
}
doc="$root/roles/claude/files/skills/panel-review/reviewer-backend.md"
tpl="$root/roles/claude/files/skills/bot-review/bot-review.json.tpl"

pass=0
fail=0
ok() { echo "  ok: $1"; pass=$((pass + 1)); }
ko() { echo "  FAIL: $1"; fail=$((fail + 1)); }

scratch="$(mktemp -d)" || exit 1
work="$(cd -- "$scratch" && pwd -P)" || exit 1
case "$work" in / | "$root" | "$root"/*) echo "reviewer-backend-test: refusing scratch directory $work"; exit 1 ;; esac
trap 'rm -rf "$work"' EXIT

# The first ```bash block, de-indented: the snippet the agent transcribes.
snippet_src="$work/snippet.src"
awk '/^  ```bash$/ && !s {s=1; next} s && /^  ```$/ {exit} s {sub(/^  /, ""); print}' "$doc" >"$snippet_src"
[ -s "$snippet_src" ] || { echo "reviewer-backend-test: no bash block in $doc"; exit 1; }

# Tool directories the snippet itself needs, from this host, minus anything
# mise-managed so the planted shims stay the only ones.
host_dirs=""
for tool in git jq realpath printenv timeout gtimeout mktemp cksum xargs; do
  p="$(command -v "$tool" 2>/dev/null)" || continue
  d="${p%/*}"
  case "$d" in */mise/*) continue ;; esac
  case ":$host_dirs:" in *":$d:"*) ;; *) host_dirs="${host_dirs:+$host_dirs:}$d" ;; esac
done

sandbox_git() { git -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false "$@"; }

new_case() {
  sandbox="$(mktemp -d "$work/case.XXXXXX")"
  home="$sandbox/home"
  repo="$sandbox/repo"
  mkdir -p "$home/.config/dotfiles" "$home/.config/cubic" "$home/.local/share/mise/shims" "$sandbox/mise-bin" \
    "$sandbox/tools/node/bin" "$sandbox/tools/cli/bin" "$sandbox/cli-real" "$repo/steered"
  printf '%s' 'placeholder-cubic-key' >"$home/.config/dotfiles/test-key"
  chmod 600 "$home/.config/dotfiles/test-key"
  : >"$home/.config/cubic/AGENTS.md"
  echo issues >"$sandbox/mode"

  cat >"$sandbox/mise-bin/mise" <<EOF
#!/bin/sh
env >"$sandbox/seen-mise-env"
case "\$1" in
  bin-paths)
    case "\$(pwd -P)" in "$repo"|"$repo"/*) echo "$repo/steered" ;; *) echo "$sandbox/tools/node/bin"; echo "$sandbox/tools/cli/bin" ;; esac ;;
  *) exit 3 ;;
esac
EOF
  ln -s "$sandbox/mise-bin/mise" "$home/.local/share/mise/shims/fakecli"
  ln -s "$sandbox/mise-bin/mise" "$home/.local/share/mise/shims/node"

  # The CLI's own interpreter, which must come from HOME's tool directories.
  cat >"$sandbox/tools/node/bin/node" <<EOF
#!/bin/sh
echo "$sandbox/tools/node/bin/node" >"$sandbox/seen-node"
env >"$sandbox/seen-env"
printf '%s\n' "\$@" >"$sandbox/seen-argv"
if { true >&3; } 2>/dev/null; then echo open >"$sandbox/seen-fd3"; fi
case "\$(cat "$sandbox/mode")" in
  issues) printf '{"issues":[{"file":"a.sh","line":3,"priority":"P1","title":"t","description":"d"}]}\n'; exit 1 ;;
  error) printf '{"issues":[{"file":"a.sh","line":1,"priority":"P2","title":"t"}],"error":"stubbed failure"}\n'; echo "stubbed vendor reason" >&2; exit 1 ;;
  empty-exit1) printf '{"issues":[]}\n'; echo "stubbed vendor reason" >&2; exit 1 ;;
  clean) printf '{"issues":[]}\n'; exit 0 ;;
  exit2) printf '{"issues":[]}\n'; exit 2 ;;
esac
EOF
  # The configured name is a link, so the unresolved path is what must run.
  printf '#!/bin/sh\nexec node "$0" "$@"\n' >"$sandbox/cli-real/fakecli"
  ln -s "$sandbox/cli-real/fakecli" "$sandbox/tools/cli/bin/fakecli"
  # Steered copies that must never run.
  printf '#!/bin/sh\necho steered >"%s/steered-ran"\nexit 0\n' "$sandbox" >"$repo/steered/fakecli"
  printf '#!/bin/sh\necho steered >"%s/steered-ran"\nexit 0\n' "$sandbox" >"$repo/steered/node"
  chmod +x "$sandbox/mise-bin/mise" "$sandbox/tools/node/bin/node" "$sandbox/cli-real/fakecli" \
    "$repo/steered/fakecli" "$repo/steered/node"

  printf '[tools]\nnode = "path:./steered"\n' >"$repo/mise.toml"
  printf 'steered/\nmise.toml\n' >"$repo/.gitignore"
  echo one >"$repo/a.sh"
  { sandbox_git -C "$repo" init -q -b main \
    && sandbox_git -C "$repo" add a.sh .gitignore \
    && sandbox_git -C "$repo" commit -q -m one \
    && sandbox_git -C "$repo" checkout -q -b feature \
    && echo two >>"$repo/a.sh" \
    && sandbox_git -C "$repo" commit -q -am two; } \
    || { echo "reviewer-backend-test: could not build the sandbox repository"; exit 1; }

  # The cubic entry's own cli block from the tracked template, pointed at the
  # fake binary and the placeholder key file, in the literal ~/ form the
  # snippet expands.
  # shellcheck disable=SC2088
  jq --arg key "~/.config/dotfiles/test-key" '
    {version: 1, default: "cubic", reviewers: {cubic: {cli: (.reviewers.cubic.cli
      | .binary = "fakecli"
      | .local_invocation |= sub("^[^ ]+"; "fakecli")
      | .env_files = {CUBIC_API_KEY: $key})}}}' "$tpl" >"$home/.config/dotfiles/bot-review.json"
  approved="$sandbox/cli-real/fakecli"
  approved="$(cd "${approved%/*}" && pwd -P)/fakecli"
  session_path="$home/.local/share/mise/shims:$repo/steered:$sandbox/mise-bin:$host_dirs"
  session_env=()
}

edit_cfg() { # edit_cfg <jq filter>
  jq "$1" "$home/.config/dotfiles/bot-review.json" >"$sandbox/cfg.tmp" \
    && mv "$sandbox/cfg.tmp" "$home/.config/dotfiles/bot-review.json"
}

# Runs the snippet from the sandbox repository under session_path and any
# extra session_env assignments; sets rc, out and err.
run_snippet() {
  sed -e "s|'<name>'|'cubic'|" -e "s|'<base>'|'main'|" -e "s|'<effort>'|''|" \
    -e "s|'<approved-binary-path>'|'$approved'|" "$snippet_src" >"$sandbox/snippet.sh"
  (cd "$repo" && env -i HOME="$home" PATH="$session_path" MISE_ENV=steered \
    SESSION_SECRET=session-only CUBIC_API_KEY=from-the-session ${session_env[@]+"${session_env[@]}"} \
    bash "$sandbox/snippet.sh" >"$sandbox/out" 2>"$sandbox/err")
  rc=$?
  out="$(cat "$sandbox/out")"
  err="$(cat "$sandbox/err")"
}

seen() { grep -E "^$1=" "$sandbox/seen-env" 2>/dev/null | head -n 1 | cut -d= -f2-; }

# expect_refused <label> <message fragment>: the snippet stopped, said why,
# and never started the CLI.
expect_refused() {
  if [ "$rc" -ne 0 ] && grep -qF -- "$2" <<<"$err" && [ ! -e "$sandbox/seen-node" ]; then
    ok "$1"
  else
    ko "$1 (rc=$rc, err=$err)"
  fi
}

echo "1. findings: the CLI runs from HOME's tools with only the allowed environment"
new_case
run_snippet
if [ "$rc" -eq 0 ] && [ "$(jq -r 'length' <<<"$out" 2>/dev/null)" = 1 ]; then
  ok "a findings exit with one issue yields one row"
else
  ko "a findings exit with one issue yields one row (rc=$rc, out=$out, err=$err)"
fi
[ "$(jq -r '.[0].severity' <<<"$out" 2>/dev/null)" = P1 ] && ok "row carries the vendor's priority" || ko "row carries the vendor's priority ($out)"
cli_path="$(seen PATH)"
case ":$cli_path:" in
  *"/mise/shims:"*) ko "the CLI's PATH kept the mise shims directory ($cli_path)" ;;
  *) ok "the CLI's PATH carries no mise shims directory" ;;
esac
case ":$cli_path:" in
  *":$repo/"*) ko "the CLI's PATH kept a directory inside the repo ($cli_path)" ;;
  *) ok "the CLI's PATH carries no repo-steered directory" ;;
esac
case "$cli_path" in
  "$sandbox/tools/node/bin:$sandbox/tools/cli/bin:"*) ok "HOME's tool directories come first" ;;
  *) ko "HOME's tool directories come first ($cli_path)" ;;
esac
[ -e "$sandbox/seen-node" ] && ok "the CLI's interpreter resolved from HOME" || ko "the CLI's interpreter resolved from HOME"
[ -e "$sandbox/steered-ran" ] && ko "a repo-steered binary ran" || ok "no repo-steered binary ran"
[ "$(seen CUBIC_API_KEY)" = placeholder-cubic-key ] && ok "the key comes from its file, not the session" || ko "the key comes from its file ($(seen CUBIC_API_KEY))"
for v in $(jq -r '.reviewers.cubic.cli.env | keys[]' "$tpl"); do
  want="$(jq -r --arg v "$v" '.reviewers.cubic.cli.env[$v]' "$tpl")"
  [ "$(seen "$v")" = "$want" ] && ok "$v=$want reaches the CLI" || ko "$v reaches the CLI as $want ($(seen "$v"))"
done
for v in SESSION_SECRET MISE_ENV MISE_OVERRIDE_CONFIG_FILENAMES; do
  grep -q "^$v=" "$sandbox/seen-env" && ko "$v reached the CLI" || ok "$v kept from the CLI"
done
for v in CUBIC_API_KEY SESSION_SECRET MISE_ENV; do
  grep -q "^$v=" "$sandbox/seen-mise-env" && ko "$v reached mise" || ok "$v kept from mise"
done
if [ "$(tr '\n' ' ' <"$sandbox/seen-argv")" = "$sandbox/tools/cli/bin/fakecli review --base main --json " ]; then
  ok "the configured link runs, with the base ref in argv"
else
  ko "the configured link runs, with the base ref in argv ($(tr '\n' ' ' <"$sandbox/seen-argv"))"
fi

[ ! -e "$sandbox/seen-fd3" ] && ok "the key pipe is closed before the CLI starts" || ko "the CLI inherited the key pipe on fd 3"

if [ -n "$inner" ]; then
  echo
  echo "reviewer-backend-test: $pass passed, $fail failed"
  [ "$fail" -eq 0 ]
  exit
fi

echo "2. a clean run exits 0 with no rows"
new_case
echo clean >"$sandbox/mode"
run_snippet
[ "$rc" -eq 0 ] && [ "$out" = "[]" ] && ok "clean run" || ko "clean run (rc=$rc, out=$out, err=$err)"

echo "3. the vendor's error document is a backend failure, with its reason shown"
new_case
echo error >"$sandbox/mode"
run_snippet
if [ "$rc" -ne 0 ] && [ -z "$out" ] && grep -q "does not fit" <<<"$err" && grep -q "stubbed vendor reason" <<<"$err"; then
  ok "error document stops the run"
else
  ko "error document stops the run (rc=$rc, out=$out, err=$err)"
fi

echo "4. a findings exit code with no findings is a backend failure"
new_case
echo empty-exit1 >"$sandbox/mode"
run_snippet
if [ "$rc" -ne 0 ] && grep -q "no rows" <<<"$err" && grep -q "stubbed vendor reason" <<<"$err"; then
  ok "empty findings exit stops the run"
else
  ko "empty findings exit stops the run (rc=$rc, err=$err)"
fi
new_case
echo empty-exit1 >"$sandbox/mode"
edit_cfg '.reviewers.cubic.cli.findings_exit_codes = [1.0]'
run_snippet
if [ "$rc" -ne 0 ] && grep -q "no rows" <<<"$err"; then ok "a code written 1.0 still means 1"; else ko "a code written 1.0 still means 1 (rc=$rc, err=$err)"; fi

echo "5. an exit code the entry does not list is a backend failure"
new_case
echo exit2 >"$sandbox/mode"
run_snippet
if [ "$rc" -ne 0 ] && grep -q "exited 2" <<<"$err"; then ok "unlisted exit stops the run"; else ko "unlisted exit stops the run (rc=$rc, err=$err)"; fi

echo "6. the key file is read only at a private mode"
new_case
chmod 644 "$home/.config/dotfiles/test-key"
run_snippet
expect_refused "loose key file refused" "mode 644"
new_case
: >"$home/.config/dotfiles/test-key"
run_snippet
expect_refused "empty key file refused" "unreadable or empty"
new_case
printf 'placeholder\nsecond' >"$home/.config/dotfiles/test-key"
run_snippet
expect_refused "multi-line key file refused" "holds whitespace"
new_case
rm "$home/.config/dotfiles/test-key"
run_snippet
expect_refused "missing key file refused" "is missing"
new_case
chmod 400 "$home/.config/dotfiles/test-key"
run_snippet
[ "$rc" -eq 0 ] && [ "$(seen CUBIC_API_KEY)" = placeholder-cubic-key ] && ok "0400 key file accepted" || ko "0400 key file accepted (rc=$rc, err=$err)"

echo "7. env_files and env stay inside their rules"
new_case
edit_cfg '.reviewers.cubic.cli.env_allow = []'
run_snippet
expect_refused "a key file not listed in env_allow" "must be in cli.env_allow"
for bad in '.env.PATH = "/tmp"' '.env.HOME = "/tmp"' '.env.CUBIC_API_KEY = "x"' \
  '.env_files.PATH = "~/x" | .env_allow += ["PATH"]' '.env.GIT_DIR = "/tmp"' \
  '.env_allow += ["GIT_INDEX_FILE"]' '.env.X = "a\nb"' '.env.SHELLOPTS = "xtrace"'; do
  new_case
  edit_cfg ".reviewers.cubic.cli |= ($bad)"
  run_snippet
  expect_refused "refused: $bad" "cli.env_files and cli.env must map"
done

new_case
edit_cfg '.reviewers.cubic.cli.env_allow += ["FOO\n"]'
run_snippet
expect_refused "a variable name with a trailing newline" "cli.env_allow must be a list of variable names"

echo "8. no mise shim runs"
new_case
mkdir -p "$sandbox/odd"
ln -s "$sandbox/mise-bin/mise" "$sandbox/odd/fakecli"
rm "$sandbox/tools/cli/bin/fakecli"
approved="$sandbox/mise-bin/mise"
session_path="$sandbox/odd:$sandbox/mise-bin:$host_dirs"
run_snippet
expect_refused "a binary linked to mise from an unrecognised directory" "not recognised as mise's shims"
new_case
mkdir -p "$home/md/shims"
ln -s "$sandbox/mise-bin/mise" "$home/md/shims/node"
session_env=(MISE_DATA_DIR="$home/md")
session_path="$home/md/shims:$sandbox/mise-bin:$host_dirs"
run_snippet
case ":$(seen PATH):" in
  *":$home/md/shims:"*) ko "a relocated MISE_DATA_DIR's shims stayed on the CLI's PATH" ;;
  *) [ "$rc" -eq 0 ] && ok "a relocated MISE_DATA_DIR's shims are stripped" || ko "relocated MISE_DATA_DIR run (rc=$rc, err=$err)" ;;
esac

new_case
mkdir -p "$sandbox/odd"
ln -s "$sandbox/mise-bin/mise" "$sandbox/odd/git"
session_path="$sandbox/odd:$session_path"
run_snippet
if [ "$rc" -ne 0 ] && grep -qF "git ($sandbox/odd/git) is a mise shim outside mise's shims directory" <<<"$err" \
  && [ ! -e "$sandbox/seen-mise-env" ]; then
  ok "a git linked to mise is refused before it runs"
else
  ko "a git linked to mise is refused before it runs (rc=$rc, err=$err)"
fi
new_case
session_path="$home::$session_path"
printf '#!/bin/sh\necho steered >"%s/steered-ran"\nexit 1\n' "$sandbox" >"$repo/git"
chmod +x "$repo/git"
run_snippet
[ "$rc" -eq 0 ] && [ ! -e "$sandbox/steered-ran" ] && ok "an empty PATH entry never finds a git in the repo" || ko "empty PATH entry (rc=$rc, err=$err)"

echo "8b. without env_files, nothing is piped and the CLI still runs"
new_case
edit_cfg '.reviewers.cubic.cli |= (del(.env_files) | .env_allow = [])'
run_snippet
[ "$rc" -eq 0 ] && [ -z "$(seen CUBIC_API_KEY)" ] && ok "no key, no pipe, CLI ran" || ko "no env_files (rc=$rc, err=$err)"

echo "8c. a tree carrying a path the CLI would load is refused before mise or the CLI runs"
for planted in cubic.json cubic.jsonc .cubic .cubic-link .cubic-dangling; do
  new_case
  case "$planted" in
    .cubic) mkdir -p "$repo/.cubic/plugin" && echo 'export default {}' >"$repo/.cubic/plugin/x.js" ;;
    .cubic-link) mkdir -p "$sandbox/elsewhere" && ln -s "$sandbox/elsewhere" "$repo/.cubic" ;;
    .cubic-dangling) ln -s "$sandbox/nowhere" "$repo/.cubic" ;;
    *) echo '{}' >"$repo/$planted" ;;
  esac
  run_snippet
  want="${planted%%-*}"
  if [ "$rc" -ne 0 ] && grep -qF "$want exists at its root" <<<"$err" && grep -qF "hosted bot still reviews" <<<"$err" \
    && [ ! -e "$sandbox/seen-mise-env" ] && [ ! -e "$sandbox/seen-node" ]; then
    ok "$planted refused before mise or the CLI ran"
  else
    ko "$planted refused before mise or the CLI ran (rc=$rc, err=$err)"
  fi
done
for bad in '"../outside"' '"."' '"cubic.json/"' '""'; do
  new_case
  edit_cfg ".reviewers.cubic.cli.refuse_paths = [$bad]"
  run_snippet
  expect_refused "refuse_paths entry $bad refused as malformed" "cli.refuse_paths must be a list"
done
new_case
# The fake CLI plants a listed path while it runs.
sed -i.bak "s|^env >\"$sandbox/seen-env\"|mkdir -p \"$repo/.cubic\"; env >\"$sandbox/seen-env\"|" "$sandbox/tools/node/bin/node"
run_snippet
if [ "$rc" -ne 0 ] && grep -qF "appeared at the repo root while the reviewer CLI ran" <<<"$err"; then
  ok "a listed path created during the run is named"
else
  ko "a listed path created during the run is named (rc=$rc, err=$err)"
fi

echo "8d. the CLI's global instruction file must exist and be empty"
new_case
rm "$home/.config/cubic/AGENTS.md"
run_snippet
if [ "$rc" -ne 0 ] && grep -qF "needs $home/.config/cubic/AGENTS.md to exist, be yours and be empty" <<<"$err" \
  && [ ! -e "$sandbox/seen-mise-env" ] && [ ! -e "$sandbox/seen-node" ]; then
  ok "a missing instruction file stops the run before mise or the CLI"
else
  ko "a missing instruction file stops the run (rc=$rc, err=$err)"
fi
new_case
echo "personal rules" >"$home/.config/cubic/AGENTS.md"
run_snippet
expect_refused "a non-empty instruction file stops the run" "to exist, be yours and be empty"
new_case
rm "$home/.config/cubic/AGENTS.md"
ln -s /dev/null "$home/.config/cubic/AGENTS.md"
run_snippet
expect_refused "a symlinked instruction file stops the run" "to exist, be yours and be empty"
for bad in '"relative/x"' '"~/a/../b"'; do
  new_case
  edit_cfg ".reviewers.cubic.cli.require_empty = [$bad]"
  run_snippet
  expect_refused "require_empty entry $bad refused as malformed" "cli.require_empty must be a list"
done

echo "9. under a git hook's environment, the suite leaves that repository alone"
decoy="$work/decoy"
sandbox_git init -q -b main "$decoy"
echo decoy >"$decoy/f"
sandbox_git -C "$decoy" add f
sandbox_git -C "$decoy" commit -q -m decoy
decoy_state() {
  (cd "$decoy" && git for-each-ref --format='%(refname) %(objectname)' && git symbolic-ref HEAD \
    && cksum .git/config .git/index && git config --list --local)
}
before="$(decoy_state)"
GIT_DIR="$decoy/.git" GIT_INDEX_FILE="$decoy/.git/index" GIT_WORK_TREE="$decoy" \
  "$0" --inner >"$work/inner.log" 2>&1
inner_rc=$?
after="$(decoy_state)"
[ "$before" = "$after" ] && ok "decoy refs, HEAD, index and config unchanged" || ko "the decoy repository changed: $(diff <(echo "$before") <(echo "$after"))"
[ "$inner_rc" -eq 0 ] && ok "the suite still passes under the hook's environment" || ko "inner run failed: $(tail -n 5 "$work/inner.log")"

echo
echo "reviewer-backend-test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
