# Media Server — Kickoff Brief

## Header

- **Spec:** `specs/media-server`
- **Spec commit at walkthrough start:** `e543ea6`
- **Walkthrough date:** 2026-11-26
- **Mode:** first activation
- **Validator (pre-flight):** `spec-validate.sh specs/media-server` — 0 errors, 0 warnings (Draft).
- **Config:** planwright defaults for `commit_on_kickoff`, `mark_spec_pr_ready_on_kickoff` and `kickoff_ready_ci_wait`.
- **Working location:** flight branch `planwright/flight/mc-dotfiles-ad-hoc-292ea704` in its flight worktree (the bundle was drafted there, not on a `planwright/media-server/spec` branch).
- **Process:** every walkthrough question went to the operator through mission control and the hub; each answer below quotes the operator's chosen option. No decision/transcript log path was provided, so the mirror is skipped.

## Goal & glossary

**Restatement.** The spec rebuilds the media server that `specs/media-server-cleanup/` removed: native Jellyfin 12.x run by the fleet account on the shared Mac under launchd, with VideoToolbox transcoding. A Gelato plugin backed by a self-hosted AIOStreams imports the operator's Stremio catalogs into ordinary Jellyfin libraries so Infuse can browse them, and every stream resolves through Real-Debrid or AllDebrid. Tokens exist only as 0600 files rendered from the personal agents vault. The Mac is shared, so the media service outranks CI and offload work.

**Rules out:** Docker or colima, Homebrew or anything in the Mac owner's account, sudo, internet exposure, hosting or acquiring media, a resident `op` or service-account credential, and any non-debrid (P2P) stream.

**Assumes:** the fleet account can run launchd user agents and a Node runtime; Infuse and Tailscale (standard app, installed by the operator) are available on the operator's devices; the pinned picks support Jellyfin 12.x, which Task 1 verifies and may replace.

**Glossary resolutions.**

- **Bridge** — Gelato plus AIOStreams together (D-2); "catalog" and "catalogue" are the same thing.
- **Fleet account** — the Mac's non-owner account the CI runners already use (mission-control rule r-3).
- **Debrid-only** — no magnet, info-hash-only or peer result is offered or played (REQ-B1.5, D-6).
- **Vetted** — a version Task 1 records in `docs/media-server.md` with its license, last release and token storage.

Signed off: 2026-11-26 ("Yes, matches (Recommended)")

## Requirements walkthrough

**Per-group outcomes.** REQ-A (server and player), REQ-B (providers, secrets, debrid-only), REQ-C (shared Mac) and REQ-D (catalog and plugins) read as written. The operator's settled answers (Jellyfin 12.x, Stremio-plus-Infuse fallback, all three stream sources, RemuxDB telemetry off, Bazarr+, Trakt, scheduled operator steps, debrid-only) are in the bundle and were not re-asked.

**Decisions taken.**

- Task 4's no-BitTorrent playback check needs a stream, so Task 4 depends on Task 3: "Yes, reorder (Recommended)".
- Backup of Jellyfin settings and library, and upgrade rollback, are not decided here; accepted as risks R-1 and R-2: "Accept for now (Recommended)".

**Consolidated spec edits** (all landed in the bundle, recorded in the `requirements.md` changelog):

- `tasks.md`: Task 4 dependencies; Task 2 VideoToolbox check uses a synthetic test clip ("Yes, test clip (Recommended)"); Task 4 remote-bitrate cap is a role variable with a conservative default, tuned in Task 5 ("Yes, safe default (Recommended)"); Task 4 verifies loopback and LAN, Task 5 re-runs the check after Tailscale ("Yes, re-run later (Recommended)").
- `requirements.md`: the out-of-scope runner line names the launchd `ProcessType` Background setting ("Yes, widen (Recommended)").
- `test-spec.md`: REQ-C1.3 follows the same two-stage listener check.

Signed off: 2026-11-26 ("Yes, matches (Recommended)")

## Design walkthrough

**Ledger.** D-1 confirmed. D-2 confirmed; its open items are Task 1's gate and its failure branch is the operator's decision. D-3 confirmed; ordering of stream sources is Task 1's to re-check. D-4 confirmed. D-5 confirmed, amended in effect by the edits above (remote cap as a variable, two-stage listener check). D-6 confirmed. No D-ID superseded, and no design decision contradicts a requirement.

Signed off: 2026-11-26 ("Yes, matches (Recommended)")

## Verification approach

The Mac and the operator's players are unreachable from CI, so behaviour REQs are `[manual]`; role hygiene is `[test]` through the repository's lint CI. Ownership: CI runs the lint entries; the operator, through the Task 1 and Task 5 checks, sweeps the manual ones. Dead-path check: every REQ has a runnable verification once the order is Tasks 1, 2, 3, 4, 5 (the VideoToolbox and listener findings were the two dead paths and are fixed above). Coverage figures live in `test-spec.md`.

Signed off: 2026-11-26 ("Yes, matches (Recommended)")

## Task graph

Derived from the `Dependencies:` lines in `tasks.md` (authoritative). Task 1 is the gate and root; Tasks 2, 3 and 4 follow in a line after the edit above; Task 5 closes. The critical path is the whole chain; there is no parallelism after Task 1, deliberately.

**Deliberate non-edges.** Task 4 does not wait on Task 5 even though its Tailscale check is completed there (Task 5 re-runs it). Task 3 does not depend on Task 4: provider setup needs the role, not the priority rules.

Signed off: 2026-11-26 ("Yes, matches (Recommended)")

## Risk register

| ID | Risk | Mitigation / early signal |
| --- | --- | --- |
| R-1 | No backup of Jellyfin's settings or library database (decision-domains gap: data-storage). | Accepted ("Accept for now (Recommended)"): rebuild from the role and pinned versions; a backup spec comes later. |
| R-2 | No rollback for a bad Jellyfin or plugin upgrade (gap: deploy-migration). | Accepted: versions are pinned and changed only through the role; rollback spec comes later. |
| R-3 | Infuse cannot browse a full Gelato-imported catalog. | Task 1 gate; fallback is Stremio for browsing with Infuse as external player (REQ-A1.4). Accepted ("Accept all (Recommended)"). |
| R-4 | Gelato, AIOStreams, Trakt or Bazarr+ do not support Jellyfin 12.x. | Task 1 verifies each and swaps a failed pick for its alternative. Accepted. |
| R-5 | Torrentio's maintenance is the least verified of the three sources. | Listed last; Task 1 re-checks and may reorder. Accepted. |
| R-6 | The stream sources may return copyrighted material. | The operator's own legal and terms-of-service responsibility, stated in the runbook (D-3). Accepted. |
| R-7 | The no-BitTorrent check sees only the fleet account's processes, not machine-wide traffic. | Packet capture needs sudo (REQ-C1.1); the limit is stated in the runbook and the sources are debrid-only by configuration and filter. Accepted. |
| R-8 | Logs and plugin settings could hold tokens or other sensitive data (gap: observability). | Task 3's scripted scan covers logs, plists, `ps` output and the tracked tree; log retention is plain configuration, not decided here. |

Signed off: 2026-11-26 ("Accept all (Recommended)", "Yes, matches (Recommended)")

## Sign-off

**Lens review (spec class; first activation, full bundle).** Path: walked inline by the kickoff agent over all four files (no sub-agent fan-out, declared). The performance, concurrency / state and error-handling lenses are n/a for a prose artifact.

| Lens (spec set) | Findings | Notes |
| --- | --- | --- |
| Contract correctness / internal consistency | 1 | Runner scope line omitted the `ProcessType` setting D-5 and Task 4 use; applied. |
| Ambiguity / interpretation forks | 1 | Remote bitrate cap value unstated; applied (role variable, default, runbook tuning). |
| Citation and coverage integrity | none | Every REQ and D-ID is cited by a task; every REQ has a test-spec entry. |
| Dead verification paths | 2 | Task 2 VideoToolbox check had no media; Task 4 listener check could not see Tailscale yet; both applied. |
| Decision-domain gaps | 2 | Backup (data-storage) and rollback (deploy-migration) undecided; recorded as risks R-1 and R-2, accepted. Observability recorded as R-8. |
| Testability of Done-when | none | Every Done-when is evaluable by the Task 1 to 5 checks after the fixes above. |
| Cross-file consistency | 1 | Task 4 lacked its dependency on Task 3 (playback needs a stream); applied. |
| Documentation / glossary drift | none | Catalog/catalogue spelling is a preference, not a defect. |
| Rendered-content safety | n/a | Prose is not rendered into an executing context. |

Altitude check (REQ-H1.3): no altitude trigger in the Sources, so not applicable. Ship-gate check (REQ-L1.4): the bundle names no out-of-band fix, none to record. Qualified cross-spec citations: the only cross-spec reference is to `specs/media-server-cleanup/`, as a source, not a decision citation. Decision-domains gap check: run against the merged catalog; findings above. Every finding is dispositioned (all applied or accepted by the operator).

Validator at sign-off: 0 errors, 0 warnings, run after the Draft to Ready flip.

Sign-off: operator, 2026-11-26, relayed by the hub: "Sign off (Recommended)", reconfirmed after the four lens-pass edits ("The final sign-off you already hold ... stands with these applied").

Class: meaning
Lens-pass: the lens review table above (full bundle, spec set, all findings dispositioned)
Anchor: `538453282f895799da959ab4b3006d9058e7596a` — computed as
`spec-anchor.sh specs/media-server`

## Amendment log

(none yet)
