#!/usr/bin/env bash
# Test for the corrected declarations (specs/dev-services Task 5, REQ-B1.5).
# The `services` role now provisions a declared dev-services layer on Linux, so
# the tracked statements written when it did not are false. This makes Task 5's
# Done-when checkable rather than reviewed:
#
#   Scope claims -- no tracked configuration comment or documentation file
#                   still states that database services are out of scope, and
#                   the scanner that decides this is itself exercised against a
#                   fixture, in both directions, on every run.
#   Corrected    -- the two files Task 5's Deliverables name still carry the
#   descriptions  corrected description, not merely the absence of the old
#                 one: the Linux role's defaults point at the declaration, and
#                 the repo guide describes a platform-dispatched role. REQ-B1.5
#                 is positive ("corrected to describe the declared layer"), so
#                 checking only the negative half would let a later tidy-up
#                 delete the correction and still report green.
#   Entry points -- the playbook's roles comment and the `mise run services`
#                   blurb, the other two places the role describes itself.
#
# Why a repo-wide scan and not a fixed list of files: the risk here is not
# breakage but incompleteness -- a stale claim left in a file nobody thought to
# reread. A scan finds the straggler; a list only re-checks what was already
# known. The per-file cases above are the complement, not a substitute: they
# cover what the scan structurally cannot, which is that something correct is
# still *there*.
#
# `specs/` is excluded, deliberately and in both directions. Spec bundles carry
# `## Out of scope` sections as format vocabulary, and `specs/linux-migration`'s
# clause on long-running services is the historical record the comments below
# were citing -- a record that is frozen by the format's stable-ID rules rather
# than rewritten when a successor bundle takes the scope over. Correcting the
# config that cites it is this task; editing the citation's target is not.
#
# This file is excluded too: it carries both halves of the pattern it looks for,
# in the regexes below, and a detector cannot also be its own subject. The
# exclusion is by resolved path rather than by a hardcoded string, so a copy of
# this script left in the worktree is not mistaken for it.
#
# Not wired into CI or lefthook. Four scripts here are manual in the same way
# (services-declaration-test.sh, gitleaks-rules-test.sh,
# ssh-lan-config-sync-test.sh, postgresql-access-test.sh); run manually:
# `scripts/stale-declarations-test.sh`. Exit 0 = all assertions pass.
#
# The others have an independent CI signal behind them -- CI runs the role, or
# the scanner, itself. This one does not: its subject is prose anyone can edit,
# so manual means it runs once, on the branch that wrote it. test-spec.md pins
# REQ-B1.5 as `[test]`, which means "runs in the repo's CI", so a step in the
# `lint` job is the wiring this wants. That step edits CI configuration, a
# hard-disqualifier zone, so it is recorded as a recommendation in
# specs/dev-services/tasks.md rather than applied here.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
self_path=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")
guide="$repo_root/CLAUDE.md"
playbook="$repo_root/main.yml"
mise_toml="$repo_root/mise.toml"
declaration="$repo_root/roles/services/defaults/main.yml"
linux_defaults="$repo_root/roles/linux/defaults/main.yml"

fails=0
note_failure() { fails=$((fails + 1)); }

# Preconditions front-loaded, so a missing tool is a named refusal rather than
# a bare `set -e` abort that looks like an assertion failure and names nothing.
for tool in python3 git; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "FAIL: $tool is not on PATH; the cases below need it" >&2
        exit 1
    fi
done
if ! python3 -c 'import yaml' 2>/dev/null; then
    echo "FAIL: PyYAML is unavailable; the scan derives its service vocabulary" \
        "from the declaration and cannot fall back to a hardcoded list" >&2
    exit 1
fi

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

# ---------------------------------------------------------------------------
# The scanner, written to a file rather than inlined, because it runs twice:
# once over the repository, and once over a fixture that proves it can still
# detect what it is looking for. An assertion script whose detector has quietly
# stopped detecting is worse than no test, since the green log asserts the
# opposite -- the same reasoning REQ-D1.4 applies to the identifier generator.
# ---------------------------------------------------------------------------

cat >"$workdir/scan.py" <<'PY'
import pathlib
import re
import sys

import yaml

root, listing, self_path, declaration = (
    pathlib.Path(sys.argv[1]),
    pathlib.Path(sys.argv[2]),
    pathlib.Path(sys.argv[3]),
    pathlib.Path(sys.argv[4]),
)

# The subject half. The generic terms are unioned with the identifiers the
# declaration actually carries, so a service declared later brings its own
# vocabulary with it -- the sibling harness derives its per-service tokens the
# same way rather than snapshotting them (services-declaration-test.sh's
# no-per-service-branching case). A hand-listed vocabulary would quietly lose
# the find-the-straggler property this scan exists for the moment the declared
# set changed.
declared = (yaml.safe_load(declaration.read_text()) or {}).get("services_dev_services") or []
tokens = {
    str(entry[field])
    for entry in declared
    for field in ("name", "package", "unit")
    if entry.get(field)
}
tokens |= {"database", "databases", "cache", "caches", "long-running service", "long-running services"}
# `postgres\w*` rather than a literal, so postgres/postgresql/postgresql@18 all
# match; the declared tokens are escaped, since a package name is data.
subject = re.compile(
    r"\b(" + "|".join([r"postgres\w*", r"mariadb", r"mysql", r"redis", r"valkey\w*"]
                      + sorted(re.escape(t) for t in tokens)) + r")\b",
    re.I,
)

# The claim half. More than the one literal phrase: a re-introduced claim in
# other words is the failure this scan would otherwise be blind to. "Deferred"
# is deliberately absent -- this repo uses it constantly and legitimately (the
# spec format has a whole Deferred section), so including it would trade a rare
# miss for a steady stream of false hits.
claim = re.compile(r"out[- ]of[- ]scope|not in scope|outside (?:the )?scope", re.I)

# A negated claim is not a claim. Without this, the single most honest sentence
# anyone could write about this task -- "databases are no longer out of scope"
# -- fails the test, which pressures documentation away from naming the history
# it is correcting. The lookback is short and immediately before the phrase, so
# a negation elsewhere in a long sentence does not launder a live claim; when
# in doubt this flags rather than misses.
negated = re.compile(r"\b(?:no longer|not|never|nor|isn't|aren't)\b[\s\w,]{0,24}$", re.I)

# The two halves count as one claim only inside one **statement unit**, not
# within N lines of each other. A line window was the obvious first shape and
# the wrong one: too narrow and a bullet reflowed to a different column becomes
# a silent miss, too wide and an unrelated out-of-scope sentence one paragraph
# away pairs with a service name. Both failures are artifacts of measuring
# distance instead of structure.
#
# A unit is a blank-line-separated block, split further at list markers, which
# is what makes it work on the two shapes this repo writes. A prose paragraph
# is one unit, so a review-scope sentence in a neighbouring paragraph never
# pairs with a service name. A comment block listing deliberate omissions is
# one unit per bullet, so one entry's out-of-scope rationale does not attach to
# a different entry that happens to name a database. Reflowing a bullet cannot
# hide anything, because the whole bullet is the unit however it wraps.
MARKER = re.compile(r"^(?:[-*+]|\d+[.)])\s")
COMMENT = re.compile(r"^\s*(?:#+|//|;)\s?")


def units(lines):
    """Yield (start_line_number, [(line_number, text), ...]) statement units."""
    unit = []
    for number, text in enumerate(lines, start=1):
        bare = COMMENT.sub("", text).strip()
        if not bare:
            if unit:
                yield unit
                unit = []
            continue
        if MARKER.match(bare) and unit:
            yield unit
            unit = []
        unit.append((number, text))
    if unit:
        yield unit


hits = []
skipped = []
examined = []
for rel in filter(None, listing.read_text().splitlines()):
    if rel.startswith("specs/"):
        continue
    path = root / rel
    if not path.is_file():
        continue
    if path.resolve() == self_path.resolve():
        continue
    try:
        lines = path.read_text().splitlines()
    except (OSError, UnicodeDecodeError) as exc:
        # Counted and reported, never waved through: a doc saved in a
        # non-UTF-8 encoding would otherwise vanish from the scan and take any
        # claim in it along.
        skipped.append(f"{rel} ({type(exc).__name__})")
        continue
    examined.append(rel)
    for unit in units(lines):
        subject_line = next(((n, t) for n, t in unit if subject.search(t)), None)
        if subject_line is None:
            continue
        for number, text in unit:
            found = claim.search(text)
            if found and not negated.search(text[: found.start()]):
                hits.append(
                    f"{rel}:{subject_line[0]}: {subject_line[1].strip()}"
                    f"\n        pairs with :{number}: {text.strip()}"
                )
                break

print(f"examined {len(examined)}")
for rel in skipped:
    print(f"skipped {rel}")
for hit in hits:
    print(f"hit {hit}")
sys.exit(1 if hits else 0)
PY

# ---------------------------------------------------------------------------
# The positive control, first: prove the scanner detects before trusting it to
# report clean. Five fixture files cover the directions that matter: a plain
# claim, a claim reflowed across four lines of one bullet, a negated claim,
# prose naming a service with no claim in its unit, and an out-of-scope
# sentence in the paragraph next to one that names a service.
#
# The last two are the pair a line window could not separate, and they are here
# because the fixture is the only thing that keeps the unit rule honest: adjust
# the splitting and one of them breaks.
# ---------------------------------------------------------------------------

fixture="$workdir/fixture"
mkdir -p "$fixture"
cat >"$fixture/plain.md" <<'EOF'
Databases are out of scope for this repository.
EOF
cat >"$fixture/reflowed.yml" <<'EOF'
# - Databases (postgresql): long-running services that this baseline
#   deliberately does not carry, for the same reason the
#   containers entry above gives, which is that they are
#   out of scope until a later bundle claims them.
EOF
cat >"$fixture/negated.md" <<'EOF'
Databases are no longer out of scope: roles/services declares them.
EOF
cat >"$fixture/clean.md" <<'EOF'
PostgreSQL and Valkey are provisioned from the declaration.
Adding one is an entry in that list rather than a task edit.
EOF
cat >"$fixture/unrelated.md" <<'EOF'
PostgreSQL and Valkey are provisioned from the declaration.

Pre-existing mess unrelated to the diff is out of scope, and
especially so on someone else's pull request. That is a review
rule, and it has nothing to do with the paragraph above it.
EOF
printf '%s\n' plain.md reflowed.yml negated.md clean.md unrelated.md >"$fixture/listing.txt"

fixture_out="$workdir/fixture.out"
if python3 "$workdir/scan.py" "$fixture" "$fixture/listing.txt" "$self_path" "$declaration" \
    >"$fixture_out" 2>&1; then
    echo "FAIL[scanner-detects]: the scanner reported clean against a fixture" \
        "containing a stale claim; it can no longer detect what it looks for" >&2
    note_failure
else
    flagged=$(grep -c '^hit ' "$fixture_out" || true)
    missing=""
    grep -q '^hit plain\.md' "$fixture_out" || missing="$missing plain"
    grep -q '^hit reflowed\.yml' "$fixture_out" || missing="$missing reflowed(reflow)"
    spurious=""
    grep -q '^hit negated\.md' "$fixture_out" && spurious="$spurious negated"
    grep -q '^hit clean\.md' "$fixture_out" && spurious="$spurious clean"
    grep -q '^hit unrelated\.md' "$fixture_out" && spurious="$spurious unrelated(unit-split)"
    if [[ -n "$missing" || -n "$spurious" ]]; then
        echo "FAIL[scanner-detects]: fixture mismatch; missed:${missing:- none}," \
            "wrongly flagged:${spurious:- none} ($flagged hit(s))" >&2
        note_failure
    else
        echo "ok[scanner-detects]: the scanner flags a plain and a reflowed claim," \
            "and leaves a negated one and unrelated prose alone"
    fi
fi

# ---------------------------------------------------------------------------
# The scope claims themselves (REQ-B1.5). Repository-wide, over tracked files
# plus untracked-but-not-ignored ones -- the same scope
# scripts/services-declaration-test.sh uses, and for the same reason: a claim
# in a file that is about to be committed is a claim this repo is about to
# make.
# ---------------------------------------------------------------------------

(cd "$repo_root" && git ls-files --cached --others --exclude-standard) \
    >"$workdir/listing.txt"

scan_out="$workdir/scan.out"
scan_rc=0
python3 "$workdir/scan.py" "$repo_root" "$workdir/listing.txt" "$self_path" "$declaration" \
    >"$scan_out" 2>&1 || scan_rc=$?

# An empty or truncated corpus is the way this case passes while proving
# nothing: git exits 0 with no output from a tarball export, a mismatched
# GIT_WORK_TREE, or an over-broad ignore rule, and the scan then certifies a
# repository it never read. Asserted against the files Task 5 actually names,
# not against a bare count.
corpus_missing=""
for required in CLAUDE.md main.yml mise.toml roles/linux/defaults/main.yml; do
    grep -qx "$required" "$workdir/listing.txt" || corpus_missing="$corpus_missing $required"
done
if [[ -n "$corpus_missing" ]]; then
    echo "FAIL[scan-corpus-complete]: the file listing is missing:$corpus_missing;" \
        "the scan below covered less than the repository" >&2
    note_failure
else
    echo "ok[scan-corpus-complete]: $(grep -c . "$workdir/listing.txt") file(s) listed," \
        "$(grep '^examined ' "$scan_out" | cut -d' ' -f2) read"
fi

if grep -q '^skipped ' "$scan_out"; then
    echo "FAIL[no-out-of-scope-service-claim]: file(s) could not be read and were not scanned:" >&2
    sed -n 's/^skipped /    /p' "$scan_out" >&2
    note_failure
elif [[ "$scan_rc" -ne 0 ]]; then
    echo "FAIL[no-out-of-scope-service-claim]: files still place services out of scope" \
        "(tracked, or untracked and not ignored):" >&2
    sed -n 's/^hit /    /p' "$scan_out" >&2
    note_failure
else
    echo "ok[no-out-of-scope-service-claim]: nothing in the checkout places database" \
        "or cache services out of scope"
fi

# ---------------------------------------------------------------------------
# The corrected descriptions. Four files describe the `services` role: the two
# Task 5's Deliverables name (the Linux role's defaults, the repo guide) and
# the two entry points a reader meets first (the playbook's roles list, the
# mise task blurb).
# ---------------------------------------------------------------------------

described_rc=0
python3 - "$repo_root" "$linux_defaults" "$guide" "$playbook" "$mise_toml" <<'PY' || described_rc=$?
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
linux_defaults, guide, playbook, mise_toml = (pathlib.Path(p) for p in sys.argv[2:6])
failed = []


def ok(name, msg):
    print(f"ok[{name}]: {msg}")


def bad(name, msg):
    print(f"FAIL[{name}]: {msg}", file=sys.stderr)
    failed.append(name)


DECLARATION = "roles/services/defaults/main.yml"

# linux-defaults-describes-layer -- the positive half of REQ-B1.5 on the file
# the Deliverables name. Without it, deleting the omission block outright
# passes every other case here while removing the correction this task is.
if not linux_defaults.is_file():
    bad("linux-defaults-describes-layer", f"{linux_defaults} does not exist")
else:
    text = linux_defaults.read_text()
    if DECLARATION not in text:
        bad(
            "linux-defaults-describes-layer",
            f"the Linux role's defaults no longer point at {DECLARATION};"
            " the databases-and-caches note says where they are provisioned"
            " instead of that they are out of scope, and that pointer is the"
            " correction REQ-B1.5 asks for",
        )
    else:
        ok("linux-defaults-describes-layer", f"the apt baseline points at {DECLARATION}")

# The guide cases below read the role-layout section.
if not guide.is_file():
    bad("guide-present", f"{guide} does not exist")
    sys.exit(1)

sections = re.split(r"^## ", guide.read_text(), flags=re.M)
layout = next((s for s in sections if s.startswith("Ansible role layout")), None)
if layout is None:
    bad(
        "guide-present",
        "the repo guide has no `## Ansible role layout` section, so neither"
        " services-not-cross-platform-config nor services-role-described could run",
    )
    sys.exit(1)

# services-not-cross-platform-config -- the enumeration of roles that are
# cross-platform config must no longer carry `services`. Scoped to an actual
# enumeration (a parenthesised, comma-separated list of role names) rather than
# to any paragraph mentioning the phrase, so a sentence *contrasting* the role
# with those roles reads as the accurate sentence it is instead of failing.
enumerations = [
    [token.strip().strip("`") for token in group.split(",")]
    for paragraph in layout.split("\n\n")
    if "cross-platform config" in paragraph
    for group in re.findall(r"\(([^)]*)\)", paragraph, re.S)
]
if not enumerations:
    ok(
        "services-not-cross-platform-config",
        "the section enumerates no cross-platform config roles, so `services` is not among them",
    )
elif any("services" in names for names in enumerations):
    bad(
        "services-not-cross-platform-config",
        "the cross-platform-config enumeration still lists `services`, which now"
        " provisions the declared dev services on Linux and nothing on macOS",
    )
else:
    ok("services-not-cross-platform-config", "`services` is not in the cross-platform-config enumeration")

# services-role-described -- and it is described somewhere in the section
# instead. The declaration check resolves the path the guide names and asserts
# it exists, rather than matching a literal: a guide pointing at a file that
# has since moved is exactly the failure a literal match cannot see, and it
# would also fail a guide correctly updated to the new location.
role_paragraphs = [p for p in layout.split("\n\n") if "roles/services/" in p]
if not role_paragraphs:
    bad("services-role-described", "the section never describes `roles/services/`")
else:
    body = "\n\n".join(role_paragraphs)
    named = re.findall(r"roles/services/[\w./-]+\.ya?ml", body)
    resolvable = [ref for ref in named if (root / ref).is_file()]
    described = {
        "a declaration file that exists": bool(resolvable),
        "what it does on Linux": re.search(r"\b(Debian|Linux)\b", body) is not None,
        "what it does on macOS": re.search(r"\b(Darwin|macOS)\b", body) is not None,
    }
    absent = [what for what, present in described.items() if not present]
    if named and not resolvable:
        bad(
            "services-role-described",
            f"the guide points at {named}, none of which exists; the declaration moved"
            " and the description was left behind",
        )
    elif absent:
        bad("services-role-described", f"the role's description does not name: {absent}")
    else:
        # Deliberately narrow wording: this asserts the description names the
        # declaration and both platforms, not that its prose is accurate. No
        # mechanical check can decide the latter, and claiming it here would
        # be the overclaim the case exists to avoid.
        ok(
            "services-role-described",
            f"the description names {resolvable[0]} and both platforms",
        )

# playbook-comment-describes-dispatch -- main.yml lists `- services` bare among
# roles introduced as cross-platform config, so without a comment saying why,
# the list itself is the stale claim. This is the one corrected statement that
# had no guard at all.
if not playbook.is_file():
    bad("playbook-comment-describes-dispatch", f"{playbook} does not exist")
else:
    comments = "\n".join(
        line for line in playbook.read_text().splitlines() if line.lstrip().startswith("#")
    )
    # Backticked, the way this file names every other role, and specifically
    # not a bare substring test: the comment also says "dev-services layer",
    # which contains the word and would satisfy a substring check even after
    # every mention of the role itself had been removed.
    if "`services`" not in comments:
        bad(
            "playbook-comment-describes-dispatch",
            "the playbook's roles comment does not name `services`, so the bare"
            " list entry reads as one more cross-platform config role",
        )
    elif not (re.search(r"\b(Debian|Linux)\b", comments) and re.search(r"\b(Darwin|macOS)\b", comments)):
        bad(
            "playbook-comment-describes-dispatch",
            "the playbook's roles comment mentions `services` without naming what it"
            " does on each platform",
        )
    else:
        ok("playbook-comment-describes-dispatch", "the playbook's roles comment names the platform dispatch")

# services-task-described -- `mise tasks` is the other place the role describes
# itself, and "Install database services" was wrong twice over: half of what it
# provisions is a cache rather than a database, and installing is one of four
# lifecycle steps it drives. Both halves are checked, so an empty or
# placeholder blurb fails rather than passing the negative test vacuously.
if not mise_toml.is_file():
    bad("services-task-described", f"{mise_toml} does not exist")
else:
    block = re.search(r"^\[tasks\.services\]$(.*?)(?=^\[|\Z)", mise_toml.read_text(), re.M | re.S)
    if block is None:
        bad("services-task-described", "mise.toml declares no [tasks.services]")
    else:
        # Non-greedy, and both TOML string quotings: a greedy match swallows a
        # trailing comment on the same line, and a literal string is as valid
        # as a basic one.
        found = re.search(r"""^description\s*=\s*(?:"([^"]*)"|'([^']*)')\s*(?:#.*)?$""",
                          block.group(1), re.M)
        if found is None:
            bad("services-task-described", "[tasks.services] has no parseable description")
        else:
            value = found.group(1) if found.group(1) is not None else found.group(2)
            if re.search(r"\bdatabases?\b", value, re.I):
                bad(
                    "services-task-described",
                    f"the task still calls itself {value!r}; the role provisions a cache"
                    " as well as a database",
                )
            elif not re.search(r"\bservices?\b", value, re.I):
                bad(
                    "services-task-described",
                    f"the task describes itself as {value!r}, which does not say it"
                    " provisions the declared services",
                )
            else:
                ok("services-task-described", f"`mise run services` describes itself as {value!r}")

sys.exit(1 if failed else 0)
PY
if [[ "$described_rc" -ne 0 ]]; then
    note_failure
fi

if [[ "$fails" -ne 0 ]]; then
    echo "stale-declarations-test: $fails assertion group(s) failed" >&2
    exit 1
fi
echo "stale-declarations-test: all assertions passed"
