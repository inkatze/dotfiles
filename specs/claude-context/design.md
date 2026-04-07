# Dotfiles Repo-Root CLAUDE.md Design Decisions

Decisions specific to introducing a tracked `CLAUDE.md` at the root of the dotfiles repo
so that Claude Code sessions launched with `cwd = ~/dev/dotfiles` have the minimum
non-obvious context they need to act correctly in this repo.

## Template adaptation note

This spec follows a four-file convention borrowed from another project of mine:
`design.md` (decisions and rationale), `requirements.md` ("shall" language, no
implementation details), `tasks.md` (implementation status), `test-spec.md` (test
coverage by behavior). The dotfiles repo does not have a pre-existing `specs/` tree;
this spec establishes one under `specs/claude-context/`. The convention is
borrowed wholesale with no structural changes. If more specs land in this repo later,
a `specs/README.md` index can be added then.

## Status

- **Wave:** C (plan-only). Nothing in Wave C has been implemented yet, including
  this item. This spec captures the resolved plan; the actual repo-root `CLAUDE.md`
  has not been written.
- **Decisions resolved:** 2026-04-07.
- **Source plan:** improvement-plan item #11 in
  `~/.claude/plans/zippy-pondering-planet.md` (section `[11/18]`). This spec is the
  durable form of that plan section for #11's own substance. The one external
  dependency is #8's three-layer permissions reasoning (see "Soft dependency on
  #8" below): once #8 has its own spec, the plan doc can be deleted without
  losing context. Until then, the plan doc remains the only durable record of
  #8's full rationale.

## Context

Source: improvement-plan item #11, originally framed as "dotfiles project memory"
(an entry under `~/.claude/projects/-Users-inkatze-dev-dotfiles/memory/`). Wave B of
the analysis surfaced no evidence for the original framing — hot-file re-reads were
project source in tecpan/paycalc, not dotfiles config — and the global
`~/.claude/CLAUDE.md` "What NOT to save in memory" rules forbid what-memory about
file paths, project structure, and architecture. A naive project memory would have
violated policy.

The reframe: write a tracked `CLAUDE.md` at the dotfiles repo root instead. CLAUDE.md
is the purpose-built, auto-loaded mechanism for repo-scoped ambient context, and does
not run afoul of memory rules.

## Mechanism: repo-root CLAUDE.md, not memory

The file lives at `/Users/inkatze/dev/dotfiles/CLAUDE.md`, tracked in git, and is
**not** symlinked into `~/.claude/`. It is about *this repo*, not about the global
Claude config. Claude Code auto-loads it whenever a session is started with cwd inside
this repo, which is the only mechanism needed — no Ansible task, no symlink, no
memory entry.

## Scope gate (three-part test)

A fact qualifies for inclusion only if it satisfies **all three** of:

1. Non-obvious from a quick `ls` or `cat .mise.toml` in the repo root.
2. Not already covered by global `~/.claude/CLAUDE.md`.
3. Would change how Claude acts when working in this repo.

Anything that fails any leg of the test is excluded. The point is restraint: every
section must earn its keep, and the file must stay short enough to remain useful
context rather than become noise.

## Explicit excludes

- Fish shell usage notes — already in global CLAUDE.md.
- mise usage notes — already in global CLAUDE.md.
- Conventional-commit / no-Claude-footer / explicit-remote-on-push rules — already
  in global CLAUDE.md.
- Ansible tutorial content. Claude can read Ansible docs on demand.
- Full file-tree dumps or role inventories. Claude can `ls` on demand.

## Content ordering: decision-oriented, not inventory-oriented

Each section answers "when you're about to do X, know Y" rather than "here is what
the repo contains." Inventory belongs in the filesystem; CLAUDE.md is for the
non-derivable rules and gotchas that shape behavior.

## Soft dependency on #8 (three-layer permissions model)

Improvement-plan item #8 resolves the three-layer permissions model
(global tracked, per-repo tracked, per-repo local). One of CLAUDE.md's key sections
is a compact restatement of that model so Claude knows where new permissions belong.

This spec **consumes** #8's decisions; it does not duplicate or restate them in
detail. If #8's model changes during implementation, the corresponding CLAUDE.md
section is updated to match. The dependency is soft because #8 is already planned
in Wave A — drafting the section here can proceed against the planned model even
if #8 has not yet shipped.

Reference: see improvement-plan item #8 in
`~/.claude/plans/zippy-pondering-planet.md` for the full three-layer reasoning.

## No memory file is created

The existing entry at `project_improvement_plan.md` in memory remains untouched.
No new `project_dotfiles_structure.md` or similar is created as part of this work.
If a future decision or incident genuinely fits a memory type (project / feedback /
reference), it can be added then on its own merit, not bundled with this item.

## Decision log

- **Reframed from project memory to repo-root CLAUDE.md.** Original framing
  ("dotfiles project memory") would have violated the global memory policy's
  prohibition on what-memory about file paths, project structure, and architecture.
  CLAUDE.md is the purpose-built mechanism for the same job and carries no such
  policy conflict.
- **Repo-root, tracked in git, not symlinked into `~/.claude/`.** It is about
  *this repo*, not about global Claude config. Auto-load handles the rest; no
  Ansible task needed.
- **Scope gated by the three-part test.** Non-obvious AND not in global CLAUDE.md
  AND behavior-changing. All three legs required, no exceptions.
- **Consumes #8's three-layer permissions model; does not duplicate it.** The
  CLAUDE.md section for permissions is a compact restatement, not a re-derivation.
  If #8's model changes, this file follows.
- **Soft dependency on #8 (planned, not necessarily shipped).** Already satisfied:
  #8 is in Wave A.
- **No new memory file created.** Existing `project_improvement_plan.md` memory
  entry is untouched. Future memory entries, if any, must earn their place on
  their own merit, not as part of this item.
- **Effort estimate: XS–S, ~30 minutes.** Most of the effort is restraint —
  resisting the urge to dump structure that Claude can derive from a quick `ls`.
