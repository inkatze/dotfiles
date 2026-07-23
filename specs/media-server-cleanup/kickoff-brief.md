# Media Server Cleanup — Kickoff Brief

## 1. Header

- **Spec path:** `specs/media-server-cleanup/`
- **Spec commit at walkthrough start:** `4074170149c43d2f94f10bfb8618de23f3765d7d`
- **Walkthrough date:** 2026-07-22
- **Mode:** first activation (Status Draft, no prior brief)
- **Validator outcome (pre-flight):** `spec-validate: 0 error(s), 0 warning(s)`
- **Config:** `commit_on_kickoff: true`, `mark_spec_pr_ready_on_kickoff: true`,
  `kickoff_ready_ci_wait: 10m` (all plugin defaults; no local overlay)
- **Format-version:** 2 (stored status set Draft/Ready/Retired/Superseded;
  Active/Done derived via the status render)

## 2. Goal & glossary

**Restatement (agent's own words).** A total, deliberate teardown in two
coupled moves: the repo stops knowing about the media stack (the stremio
block in `roles/services/`, the `[tasks.stremio]` mise task, the three Plex
casks in `Brewfile.personal`), then the personal machine is physically
cleaned (containers and volumes, watchdog agent and logs,
`~/.config/stremio-server/` including the rendered Real-Debrid token, Plex
and Stremio apps zapped with their data, the keychain entry), ending with
the human revoking the 1Password service account. Repo-first ordering (D-2)
closes the resurrection window: once the repo no longer tracks the stack,
no playbook or mise run can re-create what the teardown removes.

**Rules out.** Any archival fallback (git history is the only reference the
future re-add spec gets); touching Transmission, VLC, Infuse, `my.cnf`, the
colima/docker runtime (retagged, retained), or deleting the Real-Debrid
vault item (its token value is regenerated per REQ-C1.3 — a sign-off
lens-pass addition reconciled here by the stale-reference sweep);
designing the replacement stack.

**Assumes.** (a) Machine-side tasks run on the personal host; (b) the
1Password service account has no consumer besides this stack; (c) the
Firebird dev container is the canary proving non-media Docker survived;
(d) after Task 1 the machine-side symlinks dangle, so the teardown script
never paths into the repo (D-2 consequence).

**Glossary (implicit terms surfaced).**
- *zurg* — the Real-Debrid mount service the stack streams from.
- *autoheal* — container-level restart supervisor.
- *the watchdog* — `com.inkatze.stremio-watchdog`, host-level launchd agent
  restarting the stack and colima every 5 minutes; the reason D-1 disables
  supervisors before services.
- *close-out* — Task 5's PR: teardown script deleted, final sweep, dated
  Changelog entry.

No ambiguities exposed by the restatement remained open.

Signed off: 2026-07-22

## 3. Requirements walkthrough

**REQ-A (repo untracking).** Intent: the repo forgets the stack completely;
colima's lifecycle survives under `[services, colima]` with Ansible as sole
owner (resolving obs:552c0512); a sweep proves nothing else references it.
Inventory verified against the working tree (role block, `mise.toml:56`,
`Brewfile.personal:12-14`). Outcome: confirmed, with edit E1 below.

**REQ-B (machine teardown).** Intent: supervisors first, then services,
config, apps, data, credential last. Every named target verified present on
the host this session (four casks, three healthy containers, watchdog
agent, config dir, ~589 MB Plex library, keychain entry; Firebird canary
`nifty_wing` = `jacobalberty/firebird:3` present). Outcome: confirmed, with
edits E2 and E3 below.

**REQ-C (credentials).** Intent: machine loses its copy (Task 3), then the
credential dies at the source (Task 4, manual, after teardown so an aborted
run can still re-render config). Outcome: confirmed, with edit E4 below
(the no-secrets claim's verification is review, not tooling — lefthook has
no general secret scanner).

**REQ-D (verification).** Intent: repo health by lint + full playbook,
destructiveness bounded by the idempotent double-run, completion = the
REQ-B checklist in one pass. Outcome: confirmed; one environmental
precondition (authenticated `op` session for the Task 3 playbook run)
parked as a risk-register row (§7) by operator decision — no spec edit.

**Consolidated spec-edit list (applied in place, Draft bundle; changelog
entry dated 2026-07-22 in `requirements.md`):**

- **E1** — test-spec REQ-A1.5: sweep pattern word-bounded
  (`git grep -iE` → `git grep -iwE`); the substring form false-matched
  "multiplexer"/"complex" in unrelated files (6 at the sign-off
  re-derivation; verified both ways against
  the working tree).
- **E2** — REQ-B1.1, Task 2, test-spec REQ-B1.1: Docker volume names
  corrected to the compose-project-prefixed forms
  `stremio-server_stremio-data` / `stremio-server_zurg-data` (verified via
  `docker volume inspect`; bare names would have made the script's guarded
  `docker volume rm` a silent miss).
- **E3** — D-1, Task 2, test-spec REQ-B1.4: Plex helper launchd label
  pinned as `tv.plex.player-helper` (plist verified in
  `~/Library/LaunchAgents/`).
- **E4** — test-spec REQ-C1.2: lefthook clause scoped to lint; review at
  Tasks 2/5 named as the verification (grounded in `lefthook.yml`).

**Mid-walk delta lens (E1–E4):** precision/gap-fill edits consistent with
accepted decisions (no REQ meaning altered, no decision contradicted).
Post-edit checks: no stale bare volume names remain in the bundle; new
names and the helper label present in all affected files; validator re-run
clean (0 errors, 0 warnings). Disposition: applied, operator-approved.

Signed off: 2026-07-22

## 4. Design walkthrough

Reconciled ledger — every D-ID accounted for:

| D-ID | Disposition | Notes |
| --- | --- | --- |
| D-1 | Confirmed, amended for precision (E3) | Supervisor-first ordering; watchdog's 5-minute launchd restart loop and live autoheal verified on host. Helper label pinned `tv.plex.player-helper`. |
| D-2 | Confirmed | Consequence clause verified: config-dir symlinks point into the repo and dangle after Task 1; the script's no-repo-paths constraint is what keeps Task 3 executable. |
| D-3 | Confirmed | colima tasks sit mid-flow tagged `[services, stremio]`; mountInotify fix comment confirms it is colima-generic. Retag = obs:552c0512's resolution (Ansible sole owner). |
| D-4 | Confirmed | All four target casks verified installed. |
| D-5 | Confirmed | Script committed → executed/verified → deleted at close-out; history is the reference for the re-add spec. |

No decision contradicts a walked requirement.

Signed off: 2026-07-22

## 5. Verification approach

**Coverage mix:** per the test-spec intro — predominantly `[manual]`
(no CI runner reaches the host's launchd, Docker, or keychain state);
`[test + manual]` on the repo-health REQs (A1.1, D1.1); `[design-level]`
on C1.2, backed by review per E4.

**Ownership:** `[test]` halves run in GitHub Actions (`test.yml`,
yamllint/ansible-lint) on the Task 1 PR. `[manual]` entries are swept by
the operator on the personal host: repo checks at Task 1, the REQ-B
checklist plus the D1.2 idempotency double-run at Task 3 (recorded in the
task PR), the C1.1 revocation confirmation at Task 4, the final sweep at
Task 5. C1.2 is reviewed at Tasks 2 and 5.

**Dead paths:** one found and fixed this session (E1 — the A1.5 sweep
pattern could never pass as written). All remaining paths verified
runnable: `scripts/playbook.sh` present and executable, the CI workflow
carries the lint suite, and every checklist command was exercised
read-only against live host state during the walk.

Signed off: 2026-07-22

## 6. Task graph

Reconstructed from the `Dependencies:` lines of `tasks.md` (cross-checked
against the `spec-graph.sh` render; the lines are authoritative):

- **Shape:** Tasks 1 and 2 are independent roots; both feed Task 3; then
  4; then 5 (which also takes a direct edge from 3).
- **Parallelism:** 1 ∥ 2 only; everything after 3 is serial.
- **Critical path** (effort-weighted; per-task efforts in `tasks.md`):
  1 → 3 → 4 → 5, four half-days elapsed with 1 ∥ 2 overlapped.
- **Deliberate non-edges:**
  1. Task 2 does not depend on Task 1 — the script is authored against
     machine reality (no repo paths, D-2 consequence); D-2's ordering
     binds execution (Task 3), not authoring.
  2. The direct 3→5 edge stays alongside 3→4→5 — close-out needs the
     teardown evidence itself, not merely the revocation.
  3. Task 4 strictly after Task 3 — revocation-last is D-1's abortability
     rationale at the credential level.

Signed off: 2026-07-22

## 7. Risk register

Decision-domains gap check (merged catalog via
`scripts/resolve-catalog.sh decision-domains`, 11 seed domains, no overlay
additions): the spec touches five domains — Data storage (full teardown,
escalated and decided at drafting), Secrets & configuration (Tasks 3/4,
REQ-C1.2), Concurrency (supervisor race, decided by D-1), Deploy &
migration (D-2 ordering, D-5 script, human-directed execution), and the
mise-task edge of API surface (REQ-A1.2) — and decides every one. No
touched-but-undecided domain; no gap rows. Confirms and extends the
drafting-session walk in `design.md`'s cross-cutting section.

| # | Risk | Mitigation / early signal |
| --- | --- | --- |
| 1 | Task 3's full playbook run silently requires an authenticated 1Password CLI session (the MCP sync scripts fail closed without one) | Mitigation: `op signin` before the run. Early signal: `FAILED: could not read GitHub PAT …` |
| 2 | Supervisor race: the watchdog (5-minute launchd loop) or autoheal restarts containers mid-teardown if D-1's order is violated | Mitigation: D-1 ordering (supervisors first). Early signal: a removed container reappears in `docker ps` |
| 3 | Accepted risk: the Plex library (~589 MB at kickoff) and the Docker volumes are deleted with no backup | Deliberate full-teardown decision; git history is the only reference. No mitigation intended |
| 4 | Cask zap stanzas miss data paths | Mitigation: post-zap `~/Library` sweep (D-4) plus checklist REQ-B1.4/B1.5. Early signal: leftovers found in the sweep |
| 5 | Post-sign-off review edits (the operator-requested `/panel-review --nested`) stale the content anchor before the ready-flip | Mitigation: re-validate and take the sanctioned re-anchor/delta path before `gh pr ready`. Early signal: `spec-anchor.sh` output differs from the recorded anchor |

Open questions: none carried; all resolved into decisions or the accepted
risk above.

Signed off: 2026-07-22

## 8. Sign-off

**Mode/scope:** first activation, full-bundle lens review (fan-out: one
read-only sub-agent per canonical lens, 9 agents).

**Lens-coverage table** (findings shown post-validation, deduplicated
across lenses):

| Lens | Findings | Notes |
| --- | --- | --- |
| Correctness, logic, edge cases | 3 | autoheal ordering; Stremio cask unplaced in D-1; colima-task enumeration risk (addressed by the A1.4 guard/tag check) |
| Security | 1 | Real-Debrid token rotation (operator: rotate in Task 4 → REQ-C1.3); 2 further claims refuted/declined |
| Error handling and failure modes | 3 | daemon-unreachable guard semantics; Plex-stop verify; stale D-1 abort rationale |
| Performance | none | half-day is the format's effort floor; full-playbook check deliberate; colima wait bounded (retries 30 × delay 2, refuted) |
| Concurrency / state | 3 | watchdog drain; idempotency guard specificity; Task 3 host-sync precondition |
| Naming, readability, structure | 3 | test-spec intro tag accounting; REQ-B1.4 helper attribution; domain-list contradiction (design.md vs §7) |
| Documentation | none | archived-observation staleness declined (point-in-time records with `Consumed-by:` marker); side catch: `specs/README.md` index row added |
| Tests / verification | 8 | sweep term extension; my.cnf-unchanged; B1.5 residue; A1.4 guard; B1.7 running; C1.2 Task-3 checkpoint; Task-2 Done-when timing; D1.1 absence-clause conflation |
| Cross-file consistency | 3 | out-of-scope list sync; Task 2 "D-1 order" attribution; Task 2 missing REQ-B1.7 citation |

**Altitude check (REQ-H1.3):** not applicable — no seed claim in
`## Sources` asserts an altitude; mechanism-only task decomposition
matches the work's nature.

**Dispositions:** 21 findings applied as spec edits (operator-approved as
a cluster) plus the operator-decided REQ-C1.3 rotation (new REQ, Task 4
step, test-spec entry). Declined with rationale: token-copies-outside-
keychain (speculative, no evidence), revocation-gate gap (refuted — Task 5
depends on Task 4), keychain `-a` attribute (refuted — entry verified with
that attribute on-host this session), effort-estimate flatness (format
floor), full-playbook cost (deliberate repo-health check), colima wait
bound (refuted — bounded), playbook partial-run / wrong-account / keychain
multi-match depth (proportionality; single-consumer assumption
operator-attested in §2), terminology variance and A1.5 referent nits
(style; no confusion risk), archived-observation staleness (accumulator
convention), bootout-by-label (already mandated by D-2's consequence).
No finding left undispositioned.

**Post-lens stale-reference sweep (REQ-C1.3 minted):** reconciled the §2
rules-out line, `requirements.md` In-scope/Out-of-scope entries, and
`tasks.md` Out of scope; no other stale references found (mechanical grep
for C1.3/Real-Debrid/rotation across bundle and brief).

**Pre-flip verification:** repo lint (lefthook pre-commit) ran clean — no
configured rule matches markdown spec surfaces, surfaced as such, no
errors. Recorded-claim re-derivation: word-bounded sweep derives to zero
non-carve-out matches post-removal; REQ↔test-spec coverage 18↔18
(validator-confirmed); Plex library figure re-derived (589M); one
mismatch found and corrected before the flip (the E1 "unrelated files"
count: recorded 9, derived 6 — brief corrected to the derived value).

**Validator:** 0 errors, 0 warnings at Draft (pre-flight), after the
walkthrough edits, and re-run after the Draft→Ready flip.

**Status flip:** Draft→Ready on all four spec files, 2026-07-22
(format-version 2: Ready is the stored resting state; Active/Done derive).

**Operator instructions recorded mid-run:** after this sign-off's
commit/push/draft-PR, run `/panel-review --nested`, re-validate the
bundle (re-anchor via the sanctioned path if spec files change), then
mark the spec PR ready gated on green head-SHA CI; push notification when
attention is needed and when the PR is ready.

Class: meaning
Lens-pass: the lens review recorded in this section (coverage table and
dispositions above), full-bundle scope, 2026-07-22
Anchor: `4c20daf294453eb99997fe2ba85a4dd696cc034e` — computed as
`scripts/spec-anchor.sh specs/media-server-cleanup`

## 9. Amendment log

(none yet)
