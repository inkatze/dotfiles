#!/usr/bin/env bash
# Fixture suite for the planwright overlay render in
# roles/claude/tasks/op-render.yml: which item each inventory host renders its
# overlay from, and from which 1Password account. A work host reads its own
# item from the work account and never the personal one; every other host
# renders exactly what it did before the work host had an item of its own.
#
# Driven through ansible-playbook as each inventory alias, against scratch
# HOMEs and a fake `op`, from a scratch directory whose roles/ links into this
# repo. Its scripts/ holds stand-ins that pass the overlay render to the real
# scripts/op-render.sh and answer every other render and key sync with OK, so
# the cases see only the overlay.
set -uo pipefail
unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE
unset DOTFILES_OP_WORK_ACCOUNT DOTFILES_OP_WORK_VAULT DOTFILES_OP_WORK_ITEM
unset OP_SERVICE_ACCOUNT_TOKEN DOTFILES_OP_TOKEN_FILE DOTFILES_OP_VAULT

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

tpl="$repo/roles/claude/files/planwright/planwright.yml.tpl"
ln -s "$repo/roles" "$work/roles" || { echo "FAIL[harness]: cannot link roles"; exit 1; }
mkdir -p "$work/scripts" "$work/bin" "$work/items"

cat >"$work/scripts/op-render.sh" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"\$RENDER_ARGV"
case " \$* " in
  *"/planwright.yml.tpl "*) exec "$repo/scripts/op-render.sh" "\$@" ;;
esac
echo "OK: stand-in"
STUB
printf '#!/usr/bin/env bash\necho "OK: stand-in"\n' >"$work/scripts/op-key-sync.sh"

# The fake op serves the personal item from the service-account vault (no
# --account) and the work host's item from the work account and vault alone.
cat >"$work/bin/op" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$OP_ARGV"
[ "$1 $2" = "item get" ] || exit 2
case " $* " in
  *" --account work.example.com "*)
    [ "$3" = dotfiles-planwright-overlay-work ] && [[ " $* " == *" --vault Work Vault "* ]] \
      && exec cat "$OP_ITEMS/work.json" ;;
  *" --account "*) ;;
  *)
    [ "$3" = dotfiles-planwright-overlay ] && [[ " $* " == *" --vault Dotfiles Service Account "* ]] \
      && exec cat "$OP_ITEMS/personal.json" ;;
esac
echo "[ERROR] \"$3\" isn't an item in this account and vault" >&2
exit 1
FAKE
chmod +x "$work/scripts/op-render.sh" "$work/scripts/op-key-sync.sh" "$work/bin/op"

# to_item <file> <label=value>...: an item in op's JSON shape.
to_item() {
  local dest="$1"
  shift
  printf '%s\n' "$@" | jq -R -s '
    split("\n") | map(select(length > 0) | capture("^(?<label>[^=]+)=(?<value>.*)$"))
    | {id: "stub", title: "stub", fields: map({id: .label, type: "STRING", label, value})}' >"$dest"
}
to_item "$work/items/personal.json" 'flight_pr_hosts=[github.com/personal-org]' \
  'mission_control=mission_control_programs: [personal-program]'
to_item "$work/items/work.json" 'flight_pr_hosts=[github.com/work-org]' \
  'mission_control=mission_control_programs: [work-program]'

play="$work/play.yml"
cat >"$play" <<'YAML' || { echo "FAIL[harness]: cannot write the play"; exit 1; }
- name: Exercise the 1Password render tasks
  hosts: all
  connection: local
  gather_facts: true
  # Only the env subset op-render reads: the default set and `min` each cost
  # about 72s a play on GitHub's macOS runners.
  gather_subset: ['!all', '!min', 'env']
  tasks:
    - name: Run only the 1Password render tasks
      ansible.builtin.include_role:
        name: claude
        tasks_from: op-render
YAML

work_source=(DOTFILES_OP_WORK_ACCOUNT=work.example.com "DOTFILES_OP_WORK_VAULT=Work Vault" DOTFILES_OP_WORK_ITEM=work-item)

# run_as <alias> [env assignments...]: a fresh HOME, the play run as that
# inventory host; 0 when it completed, 1 when a task failed.
run_as() {
  local alias="$1"
  shift
  h="$(mktemp -d "$work/h.XXXXXX")" || { echo "FAIL[harness]: mktemp failed"; exit 1; }
  ov="$h/.claude/plugins/data/planwright-planwright/overlay/planwright.yml"
  : >"$work/op-argv"
  : >"$work/render-argv"
  # CI unset, since the tasks skip under it; become off, so sudo cannot reset
  # HOME and aim the role at a real home; fact injection off, as the repo's
  # ansible.cfg (unread from $work) has it. No ANSIBLE_PIPELINING, unlike the
  # other ansible suites: with it the first play here never finishes.
  (cd "$work" && env -u CI -u ANSIBLE_CONFIG "$@" HOME="$h" PATH="$work/bin:$PATH" \
    OP_ARGV="$work/op-argv" OP_ITEMS="$work/items" RENDER_ARGV="$work/render-argv" \
    ANSIBLE_BECOME=false ANSIBLE_INJECT_FACT_VARS=false \
    ANSIBLE_STDOUT_CALLBACK=ansible.builtin.default ANSIBLE_CALLBACK_RESULT_FORMAT=json \
    ansible-playbook -i "$alias," "$play" -e '{"claude_op_probe": {"rc": 0}}' >"$work/out" 2>&1)
  grep -q 'PLAY RECAP' "$work/out" || { echo "FAIL[harness]: no recap"; sed 's/^/    /' "$work/out" | tail -20; exit 1; }
  grep -q 'Render the planwright adopter overlay config' "$work/out" \
    || { echo "FAIL[harness]: the overlay render never ran"; sed 's/^/    /' "$work/out" | tail -20; exit 1; }
  grep -qE 'failed=0 ' "$work/out"
}
overlay_argv() { grep -F '/planwright.yml.tpl ' "$work/render-argv"; }
show() { sed 's/^/    /' "$work/out" | tail -12; }

# What a host rendered before work hosts had their own item: the template and
# the shared item, through the real renderer directly.
ref_home="$(mktemp -d "$work/ref.XXXXXX")"
(env HOME="$ref_home" PATH="$work/bin:$PATH" OP_ARGV="$work/ref-argv" OP_ITEMS="$work/items" \
  "$repo/scripts/op-render.sh" "$tpl" dotfiles-planwright-overlay "$ref_home/planwright.yml" >/dev/null) \
  || { echo "FAIL[harness]: the reference render failed"; exit 1; }

# 1. Every host but work renders the shared item exactly as before, through
#    the same renderer call, and never reads the work account, even with the
#    work source exported.
for alias in personal alt server; do
  for exported in no yes; do
    extra=()
    [ "$exported" = no ] || extra=("${work_source[@]}")
    label="$alias-unchanged$([ "$exported" = no ] || echo -with-work-source)"
    if ! run_as "$alias" "${extra[@]}"; then
      fail "$label" "the play failed"; show; continue
    fi
    if [ "$(overlay_argv)" = "$work/roles/claude/files/planwright/planwright.yml.tpl dotfiles-planwright-overlay $ov" ] &&
       cmp -s "$ref_home/planwright.yml" "$ov" && ! grep -q -- '--account' "$work/op-argv"; then
      ok "$label" "shared item rendered byte-for-byte as before, no work-account read"
    else
      fail "$label" "argv=$(overlay_argv) op=$(cat "$work/op-argv")"
    fi
  done
done

# 2. The work host renders its own item from the work account, and nothing of
#    the shared item's programs.
if run_as work "${work_source[@]}"; then
  if [ "$(overlay_argv)" = "--work-account $work/roles/claude/files/planwright/planwright.yml.tpl dotfiles-planwright-overlay-work $ov" ] &&
     grep -qx 'mission_control_programs: \[work-program\]' "$ov" &&
     grep -qx 'flight_pr_hosts: \[github.com/work-org\]' "$ov" && ! grep -q personal "$ov" &&
     ! grep -v -- '--account' "$work/op-argv" | grep -q .; then
    ok work-own-item "work item rendered from the work account, no shared programs"
  else
    fail work-own-item "argv=$(overlay_argv) op=$(cat "$work/op-argv") overlay=$(cat "$ov" 2>/dev/null)"
  fi
else
  fail work-own-item "the play failed"; show
fi

# 3. A work host without the work source fails the play rather than fall back
#    to the shared item, and nothing is written.
if run_as work; then
  fail work-no-fallback "the play succeeded"; show
elif [ ! -e "$ov" ] && ! [ -s "$work/op-argv" ] && grep -qF -- '--work-account needs DOTFILES_OP_WORK_ACCOUNT' "$work/out"; then
  ok work-no-fallback "play failed naming the missing work source, no op read, no overlay written"
else
  fail work-no-fallback "op=$(cat "$work/op-argv") overlay=$(cat "$ov" 2>/dev/null)"; show
fi

if [ "$fails" -gt 0 ]; then
  printf 'claude-overlay-render-test: %d assertion(s) failed\n' "$fails"
  exit 1
fi
printf 'claude-overlay-render-test: all assertions hold\n'
