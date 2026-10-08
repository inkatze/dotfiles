#!/usr/bin/env bash
# Fixture suite for roles/claude/tasks/steps-catalog.yml: the tracked planwright
# steps catalog is installed as a marker-guarded copy in the adopter overlay,
# a foreign destination fails the run with nothing written through it, and the
# role's own copy goes when its source does. Also holds this repository's
# repo-tracked step lists to their rules.
#
# Driven through ansible-playbook against scratch HOMEs, run from a scratch
# directory whose roles/ links into this repo, so the tasks' PWD-relative
# paths resolve here.
set -uo pipefail
unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE

here="$(cd -- "$(dirname "$0")" && pwd -P)"
repo="$(cd -- "$here/.." && pwd -P)"
work="$(cd -- "$(mktemp -d)" && pwd -P)" || { echo "FAIL[harness]: mktemp failed"; exit 1; }
# Remove the link into this repo before anything else: a recursive delete must
# never reach the checkout through it.
trap 'rm -f "$work/roles"; rm -rf "$work"' EXIT
trap 'exit 130' INT TERM HUP
fails=0

ok()   { printf 'ok[%s]: %s\n' "$1" "$2"; }
fail() { printf 'FAIL[%s]: %s\n' "$1" "$2"; fails=$((fails + 1)); }

tracked="$repo/roles/claude/files/planwright/steps.yaml"
defaults="$repo/roles/claude/defaults/main.yml"
marker="$(sed -n 's/^claude_steps_catalog_marker: "\(.*\)"$/\1/p' "$defaults")"
[ -n "$marker" ] || { echo "FAIL[harness]: no claude_steps_catalog_marker in $defaults"; exit 1; }

ln -s "$repo/roles" "$work/roles" || { echo "FAIL[harness]: cannot link roles"; exit 1; }
play="$work/play.yml"
cat >"$play" <<'YAML' || { echo "FAIL[harness]: cannot write the play"; exit 1; }
- name: Exercise the planwright steps catalog tasks
  hosts: localhost
  connection: local
  gather_facts: true
  gather_subset: [min]
  tasks:
    - name: Run only the steps catalog tasks
      ansible.builtin.include_role:
        name: claude
        tasks_from: steps-catalog
YAML

# run_role <home> [ansible-playbook flags...]: 0 when the play completed, 1 when
# a task failed; a play that never reached its recap aborts the suite.
run_role() {
  local home="$1"
  shift
  # Become off, whatever the caller's environment says: sudo would reset HOME
  # and aim the role at a real home. Fact injection off, as the repo's
  # ansible.cfg (unread from $work) has it, so a bare ansible_env fails here too.
  # The output format pinned, since the cases match one-line refusal messages.
  (cd "$work" && env -u ANSIBLE_CONFIG HOME="$home" ANSIBLE_BECOME=false ANSIBLE_INJECT_FACT_VARS=false \
    ANSIBLE_STDOUT_CALLBACK=ansible.builtin.default ANSIBLE_CALLBACK_RESULT_FORMAT=json \
    ansible-playbook "$play" "$@" >"$work/out" 2>&1)
  grep -q 'PLAY RECAP' "$work/out" || { echo "FAIL[harness]: no recap"; sed 's/^/    /' "$work/out" | tail -20; exit 1; }
  grep -qE 'failed=0 ' "$work/out"
}
changed() { grep -oE 'changed=[0-9]+' "$work/out" | head -1 | cut -d= -f2; }
reported() { grep -qF -- "$1" "$work/out"; }
show() { sed 's/^/    /' "$work/out" | tail -12; }
fresh_home() { h="$(mktemp -d "$work/h.XXXXXX")" || { echo "FAIL[harness]: mktemp failed"; exit 1; }; }
overlay() { printf '%s/.claude/plugins/data/planwright-planwright/overlay' "$1"; }
mode_of() { stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"; }
# seed <home> <file>: an installed copy, laid down without a play.
seed() { mkdir -p "$(overlay "$1")/catalogs" && cp "$2" "$(overlay "$1")/catalogs/steps.yaml"; }

# A scratch source stands in for the tracked catalog wherever a case changes
# or removes it.
src_dir="$work/src/planwright"
mkdir -p "$src_dir"
src="$src_dir/steps.yaml"
with_src=(-e "claude_steps_catalog_src=$src")

# --- The tracked catalog (REQ-F1.5) ---
[ "$(head -n 1 "$tracked")" = "$marker" ] && ok tracked-marker "the tracked catalog's first line is the role's marker" \
  || fail tracked-marker "the tracked catalog's first line is not the marker the role checks"
for step in panel-review bot-review; do
  if awk -v id="$step" '
      /^  - id: / { cur = $3; next }
      cur == id && $1 == "kind:" && $2 == "skill" { k = 1 }
      cur == id && $1 == "target:" && $2 == id { t = 1 }
      cur == id && $1 == "args:" && $2 == "--nested" && NF == 2 { a = 1 }
      END { exit !(k && t && a) }' "$tracked"; then
    ok "tracked-$step" "the tracked catalog declares $step as a --nested skill step"
  else
    fail "tracked-$step" "the tracked catalog does not declare $step as a --nested skill step"
  fi
done

# --- Fresh host ---
fresh_home
if run_role "$h" --check && [ ! -e "$(overlay "$h")/catalogs" ] && [ "$(changed)" != 0 ]; then
  ok check-fresh "a --check run on a fresh host reports the install and writes nothing"
else
  fail check-fresh "a --check run on a fresh host failed, wrote the catalog, or reported no change"; show
fi
if run_role "$h" && cmp -s "$tracked" "$(overlay "$h")/catalogs/steps.yaml"; then
  ok fresh "a fresh host gets a byte-for-byte copy of the tracked catalog"
else
  fail fresh "a fresh host got no copy, or a different one"; show
fi
[ "$(mode_of "$(overlay "$h")/catalogs")" = 755 ] && ok catalogs-mode "a created catalogs directory is 0755" \
  || fail catalogs-mode "the created catalogs directory is $(mode_of "$(overlay "$h")/catalogs")"
if run_role "$h" --check && [ "$(changed)" = 0 ]; then
  ok check-idempotent "a --check run over an identical marked copy reports no change"
else
  fail check-idempotent "a --check run over an identical copy failed or reported changed=$(changed)"; show
fi
if run_role "$h" && [ "$(changed)" = 0 ]; then
  ok idempotent "an identical marked copy reports no change"
else
  fail idempotent "a second run failed or reported changed=$(changed)"; show
fi

# --- A marked copy whose source changed ---
fresh_home
cp "$tracked" "$src"
seed "$h" "$src"
printf '  - id: extra\n    kind: skill\n    target: extra\n' >>"$src"
dest="$(overlay "$h")/catalogs/steps.yaml"
cp "$dest" "$work/before"
if run_role "$h" "${with_src[@]}" --check && cmp -s "$work/before" "$dest" && [ "$(changed)" != 0 ]; then
  ok check-update "a --check run reports the rewrite without writing it"
else
  fail check-update "a --check run wrote the copy or reported no change"; show
fi
if run_role "$h" "${with_src[@]}" && cmp -s "$src" "$dest"; then
  ok update "a marked copy is rewritten when its source changes"
else
  fail update "a marked copy was not rewritten to its changed source"; show
fi

# --- Foreign destinations fail the run, nothing written through them ---
cp "$tracked" "$src"
remedy="merge its entries into"

fresh_home
mkdir -p "$(overlay "$h")/catalogs"
printf 'steps:\n  - id: mine\n    kind: skill\n    target: mine\n' >"$(overlay "$h")/catalogs/steps.yaml"
cp "$(overlay "$h")/catalogs/steps.yaml" "$work/foreign"
for mode in --check ""; do
  label="unmarked${mode:+-check}"
  if run_role "$h" ${mode:+"$mode"}; then
    fail "$label" "an unmarked catalog did not fail the run"
  elif reported "$(overlay "$h")/catalogs/steps.yaml is not the dotfiles" && reported "$remedy"; then
    ok "$label" "an unmarked catalog fails the run naming its path and the remedy"
  else
    fail "$label" "the failure did not name the path and the remedy"; show
  fi
  cmp -s "$work/foreign" "$(overlay "$h")/catalogs/steps.yaml" && ok "$label-kept" "the unmarked catalog is left as it was" \
    || fail "$label-kept" "the unmarked catalog was changed"
done

for mode in --check ""; do
  sfx="${mode:+-check}"

  fresh_home
  mkdir -p "$(overlay "$h")/catalogs" "$h/elsewhere"
  cp "$tracked" "$h/elsewhere/steps.yaml"
  printf '  - id: drift\n    kind: skill\n    target: drift\n' >>"$h/elsewhere/steps.yaml"
  cp "$h/elsewhere/steps.yaml" "$work/linked"
  ln -s "$h/elsewhere/steps.yaml" "$(overlay "$h")/catalogs/steps.yaml"
  if run_role "$h" ${mode:+"$mode"}; then
    fail "symlink$sfx" "a symlink to a marked catalog did not fail the run"
  elif reported "$(overlay "$h")/catalogs/steps.yaml is not the dotfiles" && reported "$remedy"; then
    ok "symlink$sfx" "a symlink to a marked catalog fails the run naming its path and the remedy"
  else
    fail "symlink$sfx" "the failure did not come from the foreign-catalog refusal"; show
  fi
  [ -L "$(overlay "$h")/catalogs/steps.yaml" ] && cmp -s "$work/linked" "$h/elsewhere/steps.yaml" \
    && ok "symlink-kept$sfx" "nothing is written through the symlink" || fail "symlink-kept$sfx" "the symlink or its target was changed"

  fresh_home
  mkdir -p "$(overlay "$h")" "$h/elsewhere"
  ln -s "$h/elsewhere" "$(overlay "$h")/catalogs"
  if run_role "$h" ${mode:+"$mode"}; then
    fail "catalogs-link$sfx" "a symlinked catalogs directory did not fail the run"
  elif reported "$(overlay "$h")/catalogs is not a plain directory" && reported "remove it, then"; then
    ok "catalogs-link$sfx" "a symlinked catalogs directory fails the run naming its path and the remedy"
  else
    fail "catalogs-link$sfx" "the failure did not come from the catalogs-directory refusal"; show
  fi
  [ -L "$(overlay "$h")/catalogs" ] && [ -z "$(ls -A "$h/elsewhere")" ] \
    && ok "catalogs-link-kept$sfx" "nothing is written through the symlinked directory" \
    || fail "catalogs-link-kept$sfx" "something was written through the symlinked directory"

  fresh_home
  mkdir -p "$(overlay "$h")"
  printf 'not a directory\n' >"$(overlay "$h")/catalogs"
  if run_role "$h" ${mode:+"$mode"}; then
    fail "catalogs-file$sfx" "a regular file at catalogs did not fail the run"
  elif reported "$(overlay "$h")/catalogs is not a plain directory"; then
    ok "catalogs-file$sfx" "a regular file at catalogs fails the run naming its path"
  else
    fail "catalogs-file$sfx" "the failure did not come from the catalogs-directory refusal"; show
  fi
  [ "$(cat "$(overlay "$h")/catalogs")" = "not a directory" ] && ok "catalogs-file-kept$sfx" "the file at catalogs is left as it was" \
    || fail "catalogs-file-kept$sfx" "the file at catalogs was changed"
done

# --- The source is gone ---
fresh_home
seed "$h" "$tracked"
printf 'kept\n' >"$(overlay "$h")/catalogs/other.yaml"
printf 'kept\n' >"$(overlay "$h")/planwright.yml"
rm -f "$src"
dest="$(overlay "$h")/catalogs/steps.yaml"
if run_role "$h" "${with_src[@]}" --check && [ -f "$dest" ] && [ "$(changed)" != 0 ]; then
  ok check-retire "a --check run reports the removal and keeps the copy"
else
  fail check-retire "a --check run failed, removed the copy, or reported no change"; show
fi
if run_role "$h" "${with_src[@]}" && [ ! -e "$dest" ]; then
  ok retire "the role's own copy is removed when its source is gone"
else
  fail retire "the role's own copy survived its source, or the run failed"; show
fi
[ -f "$(overlay "$h")/catalogs/other.yaml" ] && [ -f "$(overlay "$h")/planwright.yml" ] \
  && ok retire-scoped "removal touches nothing but the role's copy" || fail retire-scoped "removal reached another overlay file"

fresh_home
mkdir -p "$(overlay "$h")/catalogs"
cp "$work/foreign" "$(overlay "$h")/catalogs/steps.yaml"
for mode in --check ""; do
  label="retire-foreign${mode:+-check}"
  if run_role "$h" "${with_src[@]}" ${mode:+"$mode"} && cmp -s "$work/foreign" "$(overlay "$h")/catalogs/steps.yaml" \
    && [ "$(changed)" = 0 ]; then
    ok "$label" "an unmarked catalog is left in place when the source is gone"
  else
    fail "$label" "an unmarked catalog was changed or planned for change, or the run failed, with the source gone"; show
  fi
done

# A run from outside a checkout would read every source as gone.
fresh_home
seed "$h" "$tracked"
if run_role "$h" -e "claude_steps_catalog_src=$work/nowhere/planwright/steps.yaml"; then
  fail no-checkout "a missing source directory did not fail the run"
else
  [ -f "$(overlay "$h")/catalogs/steps.yaml" ] && reported "is not a directory; run the" && ok no-checkout "a missing source directory fails the run and keeps the copy" \
    || { fail no-checkout "a missing source directory removed the copy, or another failure fired"; show; }
fi

fresh_home
printf 'steps:\n  - id: unmarked\n    kind: skill\n    target: unmarked\n' >"$src"
if run_role "$h" "${with_src[@]}"; then
  fail src-unmarked "a source without the marker did not fail the run"
else
  [ ! -e "$(overlay "$h")/catalogs/steps.yaml" ] && reported "must begin with the line" && ok src-unmarked "a source without the marker fails the run and installs nothing" \
    || { fail src-unmarked "a source without the marker was installed, or another failure fired"; show; }
fi

# --- This repository's step lists (REQ-F1.2, REQ-F1.3) ---
lists="$repo/.claude/planwright.yml"
if git -C "$repo" ls-files --error-unmatch .claude/planwright.yml >/dev/null 2>&1; then
  ok lists-tracked ".claude/planwright.yml is tracked"
else
  fail lists-tracked ".claude/planwright.yml is not tracked"
fi
# ignored_rc <path>: git check-ignore's status, 0 ignored and 1 not; anything
# else is an error that must not read as either.
ignored_rc() { git -C "$repo" check-ignore -q --no-index "$1"; echo $?; }
[ "$(ignored_rc .claude/planwright.yml)" = 1 ] && ok lists-ignored "the ignore rules leave .claude/planwright.yml out" \
  || fail lists-ignored "the ignore rules still match .claude/planwright.yml, or git failed"
[ "$(ignored_rc .claude/worktrees)" = 0 ] && ok worktrees-ignored ".claude/worktrees stays ignored" \
  || fail worktrees-ignored ".claude/worktrees is no longer ignored, or git failed"
[ "$(ignored_rc roles/claude/.claude/settings.local.json)" = 0 ] && ok nested-ignored "a nested .claude/ entry stays ignored" \
  || fail nested-ignored "a nested .claude/ entry is no longer ignored, or git failed"
[ "$(ignored_rc roles/claude/.claude/planwright.yml)" = 0 ] && ok nested-lists-ignored "only the root .claude/planwright.yml is re-included" \
  || fail nested-lists-ignored "a nested .claude/planwright.yml is no longer ignored, or git failed"
list_of() { sed -n "s/^$1: *\[\(.*\)\] *$/\1/p" "$lists" | tr -d ' '; }
[ "$(list_of steps_convergence)" = polish,panel-review ] && ok convergence "steps_convergence is [polish, panel-review]" \
  || fail convergence "steps_convergence is not [polish, panel-review]"
[ "$(list_of steps_post_pr)" = bot-review ] && ok post-pr "bot-review is named at post-pr" \
  || fail post-pr "steps_post_pr is not [bot-review]"
if grep -E '^steps_' "$lists" | grep -v '^steps_post_pr:' | grep -q 'bot-review'; then
  fail bot-review-only "bot-review is named at a point other than post-pr"
else
  ok bot-review-only "bot-review is named only at post-pr"
fi

# --- Wiring and vocabulary (REQ-F1.5, REQ-F1.4) ---
grep -qxF -- '  ansible.builtin.import_tasks: steps-catalog.yml' "$repo/roles/claude/tasks/main.yml" \
  && ok wired "the role's main tasks import the steps catalog tasks" \
  || fail wired "roles/claude/tasks/main.yml no longer imports steps-catalog.yml"
stale="$(cd "$repo" && grep -rn review_sequence roles/ CLAUDE.md | grep -v retired)"
[ -z "$stale" ] && ok retired-knob "every review_sequence mention records the knob's retirement" \
  || { fail retired-knob "review_sequence named without its retirement:"; printf '    %s\n' "$stale"; }

[ "$fails" -eq 0 ] && echo "claude-steps-catalog-test: all assertions hold" || { echo "claude-steps-catalog-test: $fails failed"; exit 1; }
