#!/usr/bin/env bash
# Runs /panel-review's reviewer:<name> backend snippet, extracted from
# reviewer-backend.md, against a sandbox: a throwaway HOME, repository, fake
# mise and fake reviewer CLI. The CLI records the PATH, environment and argv it
# was started with, so each case asserts what the snippet handed it.
#
# The fake mise answers `bin-paths` with a directory inside the repository
# when asked from there (a repo-steered config) and with HOME's tool
# directories otherwise. Every key here is an obvious placeholder.
set -uo pipefail

# A git hook exports these for the repository being committed to; inherited,
# they would point every sandbox `git -C` below at that repository instead
# (case 10 proves they cannot).
unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR \
  GIT_PREFIX GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_NAMESPACE GIT_CEILING_DIRECTORIES

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
[ -f "$ROOT/lefthook.yml" ] || {
  echo "reviewer-backend-test: must run from the dotfiles checkout (ROOT resolved to $ROOT)"
  exit 1
}
DOC="$ROOT/roles/claude/files/skills/panel-review/reviewer-backend.md"
TPL="$ROOT/roles/claude/files/skills/bot-review/bot-review.json.tpl"

pass=0
fail=0
ok() { echo "  ok: $1"; pass=$((pass + 1)); }
ko() { echo "  FAIL: $1"; fail=$((fail + 1)); }

work="$(cd -- "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$work"' EXIT

# The first ```bash block, de-indented: the snippet the agent transcribes.
snippet_src="$work/snippet.src"
awk '/^  ```bash$/ && !s {s=1; next} s && /^  ```$/ {exit} s {sub(/^  /, ""); print}' "$DOC" >"$snippet_src"
[ -s "$snippet_src" ] || { echo "reviewer-backend-test: no bash block in $DOC"; exit 1; }

# Tool directories the snippet itself needs, from this host, minus anything
# mise-managed so the planted shims stay the only ones.
host_dirs=""
for tool in git jq realpath printenv timeout gtimeout mktemp cksum xargs; do
  p="$(command -v "$tool" 2>/dev/null)" || continue
  d="${p%/*}"
  case "$d" in */mise/*) continue ;; esac
  case ":$host_dirs:" in *":$d:"*) ;; *) host_dirs="${host_dirs:+$host_dirs:}$d" ;; esac
done

new_case() {
  S="$(mktemp -d "$work/case.XXXXXX")"
  H="$S/home"
  R="$S/repo"
  mkdir -p "$H/.config/dotfiles" "$H/.local/share/mise/shims" "$S/mise-bin" \
    "$S/tools/node/bin" "$S/tools/cli/bin" "$R/steered"
  printf '%s' 'placeholder-cubic-key' >"$H/.config/dotfiles/test-key"
  chmod 600 "$H/.config/dotfiles/test-key"
  echo issues >"$S/mode"

  cat >"$S/mise-bin/mise" <<EOF
#!/bin/sh
case "\$1" in
  bin-paths)
    case "\$(pwd -P)" in "$R"|"$R"/*) echo "$R/steered" ;; *) echo "$S/tools/node/bin"; echo "$S/tools/cli/bin" ;; esac ;;
  *) exit 3 ;;
esac
EOF
  ln -s "$S/mise-bin/mise" "$H/.local/share/mise/shims/fakecli"
  ln -s "$S/mise-bin/mise" "$H/.local/share/mise/shims/node"

  # The CLI's own interpreter, which must come from HOME's tool directories.
  cat >"$S/tools/node/bin/node" <<EOF
#!/bin/sh
echo "$S/tools/node/bin/node" >"$S/seen-node"
env >"$S/seen-env"
printf '%s\n' "\$@" >"$S/seen-argv"
case "\$(cat "$S/mode")" in
  issues) printf '{"issues":[{"file":"a.sh","line":3,"priority":"P1","title":"t","description":"d"}]}\n'; exit 1 ;;
  error) printf '{"issues":[],"error":"stubbed failure"}\n'; exit 1 ;;
  empty-exit1) printf '{"issues":[]}\n'; exit 1 ;;
  clean) printf '{"issues":[]}\n'; exit 0 ;;
  exit2) printf '{"issues":[]}\n'; exit 2 ;;
esac
EOF
  printf '#!/bin/sh\nexec node "$0" "$@"\n' >"$S/tools/cli/bin/fakecli"
  # Steered copies that must never run.
  printf '#!/bin/sh\necho steered >"%s/steered-ran"\nexit 0\n' "$S" >"$R/steered/fakecli"
  printf '#!/bin/sh\necho steered >"%s/steered-ran"\nexit 0\n' "$S" >"$R/steered/node"
  chmod +x "$S/mise-bin/mise" "$S/tools/node/bin/node" "$S/tools/cli/bin/fakecli" \
    "$R/steered/fakecli" "$R/steered/node"

  git -C "$R" init -q -b main
  printf '[tools]\nnode = "path:./steered"\n' >"$R/mise.toml"
  printf 'steered/\nmise.toml\n' >"$R/.gitignore"
  echo one >"$R/a.sh"
  git -C "$R" add a.sh .gitignore
  git -C "$R" -c user.name=t -c user.email=t@example.invalid commit -q -m one
  git -C "$R" checkout -q -b feature
  echo two >>"$R/a.sh"
  git -C "$R" -c user.name=t -c user.email=t@example.invalid commit -q -am two

  # The cubic entry's own cli block from the tracked template, pointed at the
  # fake binary and the placeholder key file, in the literal ~/ form the
  # snippet expands.
  # shellcheck disable=SC2088
  jq --arg key "~/.config/dotfiles/test-key" '
    {version: 1, default: "cubic", reviewers: {cubic: {cli: (.reviewers.cubic.cli
      | .binary = "fakecli"
      | .local_invocation |= sub("^[^ ]+"; "fakecli")
      | .env_files = {CUBIC_API_KEY: $key})}}}' "$TPL" >"$H/.config/dotfiles/bot-review.json"
  approved="$(cd "$S/tools/cli/bin" && pwd -P)/fakecli"
}

edit_cfg() { # edit_cfg <jq filter>
  jq "$1" "$H/.config/dotfiles/bot-review.json" >"$S/cfg.tmp" && mv "$S/cfg.tmp" "$H/.config/dotfiles/bot-review.json"
}

run_snippet() { # sets rc, out, err
  sed -e "s|'<name>'|'cubic'|" -e "s|'<base>'|'main'|" -e "s|'<effort>'|''|" \
    -e "s|'<approved-binary-path>'|'$approved'|" "$snippet_src" >"$S/snippet.sh"
  local session_path="$H/.local/share/mise/shims:$R/steered:$S/mise-bin:$host_dirs"
  (cd "$R" && env -i HOME="$H" PATH="$session_path" MISE_ENV=steered \
    SESSION_SECRET=session-only CUBIC_API_KEY=from-the-session \
    bash "$S/snippet.sh" >"$S/out" 2>"$S/err")
  rc=$?
  out="$(cat "$S/out")"
  err="$(cat "$S/err")"
}

seen() { grep -E "^$1=" "$S/seen-env" 2>/dev/null | head -n 1 | cut -d= -f2-; }

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
  *":$R/"*) ko "the CLI's PATH kept a directory inside the repo ($cli_path)" ;;
  *) ok "the CLI's PATH carries no repo-steered directory" ;;
esac
case "$cli_path" in
  "$S/tools/node/bin:$S/tools/cli/bin:"*) ok "HOME's tool directories come first" ;;
  *) ko "HOME's tool directories come first ($cli_path)" ;;
esac
[ -e "$S/seen-node" ] && ok "the CLI's interpreter resolved from HOME" || ko "the CLI's interpreter resolved from HOME"
[ -e "$S/steered-ran" ] && ko "a repo-steered binary ran" || ok "no repo-steered binary ran"
[ "$(seen CUBIC_API_KEY)" = placeholder-cubic-key ] && ok "the key comes from its file, not the session" || ko "the key comes from its file ($(seen CUBIC_API_KEY))"
for v in CUBIC_DISABLE_AUTOUPDATE CUBIC_DISABLE_GIT_AI; do
  [ -n "$(seen "$v")" ] && ok "$v is set" || ko "$v is set"
done
for v in SESSION_SECRET MISE_ENV MISE_OVERRIDE_CONFIG_FILENAMES; do
  grep -q "^$v=" "$S/seen-env" && ko "$v reached the CLI" || ok "$v kept from the CLI"
done
if [ "$(tr '\n' ' ' <"$S/seen-argv")" = "$S/tools/cli/bin/fakecli review --base main --json " ]; then
  ok "argv carries the base ref"
else
  ko "argv carries the base ref ($(tr '\n' ' ' <"$S/seen-argv"))"
fi

echo "2. a clean run exits 0 with no rows"
new_case
echo clean >"$S/mode"
run_snippet
[ "$rc" -eq 0 ] && [ "$out" = "[]" ] && ok "clean run" || ko "clean run (rc=$rc, out=$out, err=$err)"

echo "3. the vendor's error document is a backend failure"
new_case
echo error >"$S/mode"
run_snippet
[ "$rc" -ne 0 ] && [ -z "$out" ] && ok "error document stops the run" || ko "error document stops the run (rc=$rc, out=$out)"

echo "4. a findings exit code with no findings is a backend failure"
new_case
echo empty-exit1 >"$S/mode"
run_snippet
if [ "$rc" -ne 0 ] && grep -q "no rows" <<<"$err"; then ok "empty findings exit stops the run"; else ko "empty findings exit stops the run (rc=$rc, err=$err)"; fi

echo "5. an exit code the entry does not list is a backend failure"
new_case
echo exit2 >"$S/mode"
run_snippet
if [ "$rc" -ne 0 ] && grep -q "exited 2" <<<"$err"; then ok "unlisted exit stops the run"; else ko "unlisted exit stops the run (rc=$rc, err=$err)"; fi

echo "6. the key file is read only at a private mode"
new_case
chmod 644 "$H/.config/dotfiles/test-key"
run_snippet
if [ "$rc" -ne 0 ] && grep -q "mode 644" <<<"$err" && [ ! -e "$S/seen-env" ]; then ok "loose key file refused before the run"; else ko "loose key file refused (rc=$rc, err=$err)"; fi
new_case
: >"$H/.config/dotfiles/test-key"
run_snippet
if [ "$rc" -ne 0 ] && [ ! -e "$S/seen-env" ]; then ok "empty key file refused"; else ko "empty key file refused (rc=$rc, err=$err)"; fi
new_case
rm "$H/.config/dotfiles/test-key"
run_snippet
if [ "$rc" -ne 0 ] && [ ! -e "$S/seen-env" ]; then ok "missing key file refused"; else ko "missing key file refused (rc=$rc, err=$err)"; fi

echo "7. env_files reaches the CLI only through env_allow"
new_case
edit_cfg '.reviewers.cubic.cli.env_allow = []'
run_snippet
if [ "$rc" -ne 0 ] && grep -q "env_allow" <<<"$err" && [ ! -e "$S/seen-env" ]; then ok "unlisted key file refused"; else ko "unlisted key file refused (rc=$rc, err=$err)"; fi

echo "8. a fixed value cannot replace PATH or HOME"
new_case
edit_cfg '.reviewers.cubic.cli.env.PATH = "/tmp"'
run_snippet
if [ "$rc" -ne 0 ] && [ ! -e "$S/seen-env" ]; then ok "cli.env PATH refused"; else ko "cli.env PATH refused (rc=$rc, err=$err)"; fi

echo "9. a binary that still resolves to mise is refused"
new_case
mkdir -p "$S/odd"
ln -s "$S/mise-bin/mise" "$S/odd/fakecli"
rm "$S/tools/cli/bin/fakecli"
approved="$S/mise-bin/mise"
sed -e "s|'<name>'|'cubic'|" -e "s|'<base>'|'main'|" -e "s|'<effort>'|''|" \
  -e "s|'<approved-binary-path>'|'$approved'|" "$snippet_src" >"$S/snippet.sh"
(cd "$R" && env -i HOME="$H" PATH="$S/odd:$S/mise-bin:$host_dirs" bash "$S/snippet.sh" >"$S/out" 2>"$S/err")
rc=$?
if [ "$rc" -ne 0 ] && grep -q "mise" "$S/err" && [ ! -e "$S/seen-env" ]; then ok "unstripped shim refused"; else ko "unstripped shim refused (rc=$rc, err=$(cat "$S/err"))"; fi

if [ -z "${REVIEWER_BACKEND_TEST_INNER:-}" ]; then
  echo "10. run under a git hook's environment, the suite leaves that repository alone"
  D="$work/decoy"
  git init -q -b main "$D"
  echo decoy >"$D/f"
  git -C "$D" add f
  git -C "$D" -c user.name=t -c user.email=t@example.invalid commit -q -m decoy
  decoy_state() {
    (cd "$D" && git for-each-ref --format='%(refname) %(objectname)' && git symbolic-ref HEAD \
      && cksum .git/config .git/index && git config --list --local)
  }
  before="$(decoy_state)"
  REVIEWER_BACKEND_TEST_INNER=1 GIT_DIR="$D/.git" GIT_INDEX_FILE="$D/.git/index" GIT_WORK_TREE="$D" \
    "$0" >"$work/inner.log" 2>&1
  inner_rc=$?
  after="$(decoy_state)"
  [ "$before" = "$after" ] && ok "decoy refs, HEAD, index and config unchanged" || ko "the decoy repository changed: $(diff <(echo "$before") <(echo "$after"))"
  [ "$inner_rc" -eq 0 ] && ok "the suite still passes under the hook's environment" || ko "inner run failed: $(tail -n 5 "$work/inner.log")"
fi

echo
echo "reviewer-backend-test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
