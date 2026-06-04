# Scoping note: decouple review/pairing tooling from pair-flow

- Recorded: 2026-06-04
- Status: seed for a future `/spec-draft` (do NOT implement on `spec/pair-flow`)
- Suggested branch: off `main`, e.g. `refactor/decouple-review-config`

## Problem

The review/pairing commands (`panel-review`, `panel-pairing`, `copilot-review`,
`copilot-pairing`, `peer-review`, `self-review`, `polish`, `code-review`) are
standalone review tooling. Pair-flow *uses* some of them (e.g. `/polish` as a
convergence step) but does not *own* them. Today they are over-coupled to
pair-flow in three ways, and one of those couplings leaks an employer signal
into this public repo.

## Why it matters

1. **Config is mis-homed.** `panel-backends` lives in `pair-flow.yml`
   (`roles/osx/files/claude/pair-flow.yml:8`) and is governed by D-6 / D-19 in
   the pair-flow spec. A non-pair-flow command's backend default should not be
   coupled to pair-flow's config file or its design decisions.
2. **Public leak (resolved in PR #28).** `panel-review.md` previously hardcoded a
   work-org allowlist to detect the "work" profile, baking an employer signal
   into a tracked, public file. Profile detection now reads the untracked
   `PANEL_REVIEW_PROFILE` env var. The same scrub still needs to reach the files
   under "broader org-name scrub" below.
3. **Doc framing.** `roles/osx/files/CLAUDE.md` describes the review workflows
   as "the convergence layer of the pair-flow pipeline," reinforcing the
   coupling.

## Scope

1. Move `panel-backends` + the work/personal signal **out of** `pair-flow.yml` /
   `pair-flow.local.yml` into a review-tooling config surface that is not
   pair-flow-coupled (its own file, or an env var).
2. Done in PR #28: the work-org allowlist was removed from `panel-review.md`;
   the profile now resolves from the untracked `PANEL_REVIEW_PROFILE` env var.
3. Re-frame `CLAUDE.md` so the review workflows are described as standalone
   tooling that pair-flow optionally invokes, not part of the pipeline.

## Open decision: work-detection mechanism

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
`pair-flow.local.yml` is "per-host, agent-maintained, never tracked", read by
`roles/osx/files/claude/scripts/pair-flow-config.sh`).

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

- `roles/osx/files/claude/pair-flow.yml:8` — `panel-backends: [codex]`
- `roles/osx/files/claude/commands/panel-review.md` (pre-flight step 3-4) —
  profile detection (now via `PANEL_REVIEW_PROFILE`) + backend resolution
- `roles/osx/files/claude/commands/panel-pairing.md` — defers to panel-review's
  backend resolution
- `roles/osx/files/claude/scripts/pair-flow-config.sh` — reads
  `~/.claude/pair-flow.local.yml`
- `scripts/playbook.sh:7-11` — env-var host detection (leak-free precedent)
