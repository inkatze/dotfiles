# Scoping note: decouple review/pairing tooling from pair-flow

- Recorded: 2026-06-04
- Status: **The config-mis-homing problem this note exists for is resolved (2026-07-13).** `pair-flow-config.sh` and `pair-flow.yml` were deleted outright (repo-class was found not to gate anything real; `panel-backends` is now a hardcoded profile-table default in `panel-review.md`/`panel-pairing.md`, no config file at all). More complete than the relocation this note proposed ("Why it matters" #1 / "Scope" #1 below, and the "Open decision" section, are all moot as a result — left in place below as the historical record of the note's original proposal). Two things this note also raised remain open and are NOT resolved by the above: the broader org-name scrub ("Separate, optional" section below) and the `CLAUDE.md` "convergence layer" doc-framing point ("Why it matters" #3 / "Scope" #3 below). Still a seed for `/spec-draft` if pursued.
- Suggested branch: off `main`, e.g. `refactor/decouple-review-config`

## Problem

The review/pairing commands (`panel-review`, `panel-pairing`, `copilot-review`,
`copilot-pairing`, `peer-review`, `self-review`, `polish`, `code-review`) are
standalone review tooling. Pair-flow *uses* some of them (e.g. `/polish` as a
convergence step) but does not *own* them. Today they are over-coupled to
pair-flow in three ways, and one of those couplings leaks an employer signal
into this public repo.

## Why it matters

1. **Config is mis-homed. Resolved 2026-07-13 (see Status above).** `panel-backends` used to live in `pair-flow.yml`
   (`roles/osx/files/claude/pair-flow.yml:8`, now deleted) and was governed by D-6 / D-19 in
   the pair-flow spec. A non-pair-flow command's backend default should not have been
   coupled to pair-flow's config file or its design decisions — it now isn't, because the config file is gone.
2. **Public leak (resolved in PR #28).** `panel-review.md` previously hardcoded a
   work-org allowlist to detect the "work" profile, baking an employer signal
   into a tracked, public file. Profile detection now reads the untracked
   `PANEL_REVIEW_PROFILE` env var. The same scrub still needs to reach the files
   under "broader org-name scrub" below.
3. **Doc framing.** `roles/osx/files/CLAUDE.md` describes the review workflows
   as "the convergence layer of the pair-flow pipeline," reinforcing the
   coupling.

## Scope

1. **Resolved 2026-07-13, more completely than proposed** (see Status above): rather than moving `panel-backends` + the work/personal signal
   **out of** `pair-flow.yml` into a separate review-tooling config surface, the tracked file was deleted outright and the setting became a hardcoded profile-table default (no config file, no indirection at all). `pair-flow.local.yml` (untracked, never Ansible-managed) is unaffected by this — orphaned wherever it existed, not deleted.
2. Done in PR #28: the work-org allowlist was removed from `panel-review.md`;
   the profile now resolves from the untracked `PANEL_REVIEW_PROFILE` env var.
3. Re-frame `CLAUDE.md` so the review workflows are described as standalone
   tooling that pair-flow optionally invokes, not part of the pipeline.

## Open decision: work-detection mechanism (moot, resolved by deletion — see Status above)

This decision was about how `panel-backends` should pick codex vs. gemini without leaking org/host names into a tracked file. It's moot now: `panel-backends` deletion left `PANEL_REVIEW_PROFILE` (the existing untracked env var already used for the personal/work profile split) as the only signal, which happens to match the "per-machine" option below. Left in place as the historical record of the original proposal.

Pick the leak-free shape (no org/host names in tracked files):

- **Per-machine (simplest):** the work machine's untracked
  `~/.claude/<review>.local.yml` (or env var) sets `panel-backends: [codex]`;
  tracked default is `[gemini]`. Downside: a personal repo opened on the work
  machine still gets codex.
- **Per-repo-org (via untracked list):** untracked local config holds
  `work-orgs: [...]`; tracked `panel-review` reads that list and picks codex for
  matching repos, gemini otherwise. Preserves per-repo switching, names stay out
  of git.

Recommended: neutral tracked default `[gemini]`; work signal in the untracked
local file. Mirrors the repo's existing leak-free patterns
(`scripts/playbook.sh` reads `$PERSONALHOST`/`$ALTHOST` from env;
`pair-flow.local.yml` used to be "per-host, agent-maintained, never tracked", read by
`roles/osx/files/claude/scripts/pair-flow-config.sh` (deleted 2026-07-13) — the file itself is untouched by that deletion, just orphaned).

## Separate, optional: broader org-name scrub

Out of scope for the decoupling itself, but the same org names also appear in:

- `roles/fish/files/fish/functions/tm.fish` (many work-org clone URLs; these are
  functional, so the scrub needs a config indirection, not deletion).
- War-story notes referencing a work repo's PR in `copilot-review.md` and
  `copilot-pairing.md` (`peer-review.md` scrubbed in PR #28).
- MCP server names embedding the employer org in `copilot-pairing.md`.

Note: `tm.fish`, `copilot-review.md`, and `copilot-pairing.md` are already in
`main` history, so scrubbing the working tree does not remove them from the
public record; handle that out of band (history rewrite / making the repo
private / accepting the exposure).

Decide whether to fold these into the same change or a dedicated hygiene pass.

## Pointers

- `roles/osx/files/claude/pair-flow.yml:8` (deleted 2026-07-13) — used to hold `panel-backends: [codex]`
- `roles/osx/files/claude/commands/panel-review.md` (pre-flight step 3-4) —
  profile detection (via `PANEL_REVIEW_PROFILE`) + backend resolution (now a hardcoded profile table, no config file)
- `roles/osx/files/claude/commands/panel-pairing.md` — defers to panel-review's
  backend resolution
- `roles/osx/files/claude/scripts/pair-flow-config.sh` (deleted 2026-07-13) — used to read
  `~/.claude/pair-flow.local.yml`
- `scripts/playbook.sh:7-11` — env-var host detection (leak-free precedent)
