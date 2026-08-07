#!/usr/bin/env bash
# Test for the corrected declarations (specs/dev-services Task 5, REQ-B1.5).
# The `services` role now provisions a declared dev-services layer on Linux, so
# the tracked statements written when it did not are false. This makes Task 5's
# Done-when checkable rather than reviewed:
#
#   Scope claims -- no tracked configuration comment or documentation file
#                   still states that database services are out of scope
#                   (REQ-B1.5, and the verification test-spec.md pins to it).
#   Repo guide   -- the repo guide describes the `services` role as what it now
#                   is, a platform-dispatched provisioning role reading a
#                   declaration, rather than lumping it in with the roles that
#                   are cross-platform config.
#   Task blurb   -- the `mise run services` description does not describe the
#                   role as installing databases; it provisions a database and
#                   a cache on Linux and applies macOS-only configuration
#                   elsewhere.
#
# Why a repo-wide scan and not a fixed list of files: the risk here is not
# breakage but incompleteness -- a stale claim left in a file nobody thought to
# reread. A scan finds the straggler; a list only re-checks what was already
# known.
#
# `specs/` is excluded, deliberately and in both directions. Spec bundles carry
# `## Out of scope` sections as format vocabulary, and `specs/linux-migration`'s
# clause on long-running services is the historical record the comments below
# were citing -- a record that is frozen by the format's stable-ID rules rather
# than rewritten when a successor bundle takes the scope over. Correcting the
# config that cites it is this task; editing the citation's target is not.
#
# This file is excluded too: it carries both halves of the pattern it looks for,
# in the regexes below, and a detector cannot also be its own subject.
#
# Not wired into CI or lefthook, matching its two siblings
# (services-declaration-test.sh, gitleaks-rules-test.sh); run manually:
# `scripts/stale-declarations-test.sh`. Exit 0 = all assertions pass.
#
# test-spec.md pins REQ-B1.5 as `[test]`, which means "runs in the repo's CI",
# so a step in the `lint` job is the wiring this wants. That step edits CI
# configuration, a hard-disqualifier zone, so it is recorded as a
# recommendation in specs/dev-services/tasks.md rather than applied here.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
self_rel="scripts/$(basename "${BASH_SOURCE[0]}")"
guide="$repo_root/CLAUDE.md"
mise_toml="$repo_root/mise.toml"

fails=0
pass() { echo "ok[$1]: $2"; }
fail() {
    echo "FAIL[$1]: $2" >&2
    fails=$((fails + 1))
}

if ! python3 --version >/dev/null 2>&1; then
    echo "FAIL: python3 is not on PATH; every case below needs it" >&2
    exit 1
fi

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

# ---------------------------------------------------------------------------
# The scope claims (REQ-B1.5). Repository-wide, over tracked files plus
# untracked-but-not-ignored ones -- the same scope
# scripts/services-declaration-test.sh uses, and for the same reason: a claim
# in a file that is about to be committed is a claim this repo is about to
# make.
# ---------------------------------------------------------------------------

(cd "$repo_root" && git ls-files --cached --others --exclude-standard) \
    >"$workdir/listing.txt"

scan_rc=0
python3 - "$repo_root" "$workdir/listing.txt" "$self_rel" <<'PY' || scan_rc=$?
import pathlib
import re
import sys

root, listing, self_rel = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3]

# The two halves of the claim. A file states database services are out of scope
# by naming one and asserting the other; neither half alone says anything.
# `long-running service` is in the first half because that is the wording the
# clause these comments cite is written in -- the phrase the config comments
# actually use, rather than the word a later reader would search for.
subject = re.compile(
    r"\b(databases?|postgres\w*|mariadb|mysql|valkey|redis|long-running services?)\b",
    re.I,
)
claim = re.compile(r"out[- ]of[- ]scope", re.I)

# Two lines either side, not the whole paragraph. The halves have to be near
# each other to read as one statement, and a paragraph window is too coarse for
# the comment blocks this repo writes: a list of deliberate omissions puts an
# out-of-scope rationale for one entry within the same paragraph as an
# unrelated entry naming a database, which is two statements, not one.
WINDOW = 2

hits = []
for rel in filter(None, listing.read_text().splitlines()):
    if rel.startswith("specs/") or rel == self_rel:
        continue
    path = root / rel
    if not path.is_file():
        continue
    try:
        lines = path.read_text().splitlines()
    except (OSError, UnicodeDecodeError):
        continue
    for i, line in enumerate(lines):
        if not subject.search(line):
            continue
        window = range(max(0, i - WINDOW), min(len(lines), i + WINDOW + 1))
        paired = next((j for j in window if claim.search(lines[j])), None)
        if paired is not None:
            hits.append(f"{rel}:{i + 1}: {line.strip()}\n        pairs with :{paired + 1}: {lines[paired].strip()}")

if hits:
    print(
        "FAIL[no-out-of-scope-service-claim]: tracked files still place services out of scope:\n"
        + "\n".join(f"    {h}" for h in hits),
        file=sys.stderr,
    )
    sys.exit(1)
print("ok[no-out-of-scope-service-claim]: no tracked config or doc places database services out of scope")
PY
if [[ "$scan_rc" -ne 0 ]]; then
    fails=$((fails + 1))
fi

# ---------------------------------------------------------------------------
# The repo guide's description of the role (Task 5's second Done-when clause).
# The guide's `Ansible role layout` section is where a reader learns what each
# role does, and it described `services` as one of the roles that are plain
# cross-platform config -- true when the role's whole content was a `~/.my.cnf`
# symlink, and no longer a description of a role that reads a declaration and
# provisions from it on one platform only.
# ---------------------------------------------------------------------------

guide_rc=0
python3 - "$guide" <<'PY' || guide_rc=$?
import pathlib
import re
import sys

guide = pathlib.Path(sys.argv[1])
failed = []


def ok(name, msg):
    print(f"ok[{name}]: {msg}")


def bad(name, msg):
    print(f"FAIL[{name}]: {msg}", file=sys.stderr)
    failed.append(name)


if not guide.is_file():
    bad("guide-present", f"{guide} does not exist")
    sys.exit(1)

text = guide.read_text()
sections = re.split(r"^## ", text, flags=re.M)
layout = next((s for s in sections if s.startswith("Ansible role layout")), None)
if layout is None:
    bad("guide-present", "the repo guide has no `## Ansible role layout` section")
    sys.exit(1)

# services-not-cross-platform-config -- the enumeration of roles that are
# cross-platform config must no longer carry `services`. Scoped to the
# paragraph making that claim rather than to the section, so the role's own
# description below it is free to say what it does on each platform.
paragraphs = [p for p in layout.split("\n\n") if "cross-platform config" in p]
if not paragraphs:
    bad(
        "services-not-cross-platform-config",
        "no paragraph in the section enumerates the cross-platform config roles;"
        " the check cannot tell whether `services` is still in it",
    )
elif [p for p in paragraphs if "`services`" in p]:
    bad(
        "services-not-cross-platform-config",
        "the cross-platform-config enumeration still lists `services`, which now"
        " provisions the declared dev services on Linux and nothing on macOS",
    )
else:
    ok("services-not-cross-platform-config", "`services` is no longer described as plain cross-platform config")

# services-role-described -- and it is described somewhere in the section
# instead. Asserted by the three things a reader needs and cannot infer: where
# the declaration lives, and what the role does on each of the two platforms.
# Not a prose match: any wording satisfies it as long as it names them. Scoped
# to the paragraphs describing the role rather than to the section, which names
# both platforms anyway in the baseline table at the top of it.
role_paragraphs = [p for p in layout.split("\n\n") if "roles/services/" in p]
if not role_paragraphs:
    bad("services-role-described", "the section never describes `roles/services/`")
else:
    body = "\n\n".join(role_paragraphs)
    described = {
        "the declaration it reads": "roles/services/defaults/main.yml" in body,
        "what it does on Linux": re.search(r"\b(Debian|Linux)\b", body) is not None,
        "what it does on macOS": re.search(r"\b(Darwin|macOS)\b", body) is not None,
    }
    absent = [what for what, present in described.items() if not present]
    if absent:
        bad("services-role-described", f"the role's description does not name: {absent}")
    else:
        ok("services-role-described", "the description names the declaration and both platform behaviours")

sys.exit(1 if failed else 0)
PY
if [[ "$guide_rc" -ne 0 ]]; then
    fails=$((fails + 1))
fi

# ---------------------------------------------------------------------------
# The task blurb. `mise tasks` is the other place the role describes itself,
# and "Install database services" is now wrong twice over: half of what it
# provisions is a cache rather than a database, and installing is one of four
# lifecycle steps it drives.
# ---------------------------------------------------------------------------

mise_rc=0
python3 - "$mise_toml" <<'PY' || mise_rc=$?
import pathlib
import re
import sys

toml = pathlib.Path(sys.argv[1])
if not toml.is_file():
    print(f"FAIL[services-task-described]: {toml} does not exist", file=sys.stderr)
    sys.exit(1)

# Hand-parsed rather than via tomllib: the description is one key in one table,
# and reading it as text keeps the case runnable on a Python without tomllib.
block = re.search(r"^\[tasks\.services\]$(.*?)(?=^\[|\Z)", toml.read_text(), re.M | re.S)
if block is None:
    print("FAIL[services-task-described]: mise.toml declares no [tasks.services]", file=sys.stderr)
    sys.exit(1)

description = re.search(r'^description\s*=\s*"(.*)"$', block.group(1), re.M)
if description is None:
    print("FAIL[services-task-described]: [tasks.services] has no description", file=sys.stderr)
    sys.exit(1)

value = description.group(1)
if re.search(r"\bdatabases?\b", value, re.I):
    print(
        f"FAIL[services-task-described]: the task still calls itself {value!r};"
        " the role provisions a cache as well as a database, and does more than install",
        file=sys.stderr,
    )
    sys.exit(1)
print(f"ok[services-task-described]: `mise run services` describes itself as {value!r}")
PY
if [[ "$mise_rc" -ne 0 ]]; then
    fails=$((fails + 1))
fi

if [[ "$fails" -ne 0 ]]; then
    echo "stale-declarations-test: $fails assertion group(s) failed" >&2
    exit 1
fi
echo "stale-declarations-test: all assertions passed"
