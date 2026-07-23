# Linux Migration — Kickoff Brief

## 1. Header

- **Spec:** `specs/linux-migration`
- **Spec commit at walkthrough start:** 7138fc6
- **Walkthrough dates:** 2026-07-22 – 2026-07-23
- **Mode:** First activation (Status Draft, no prior brief)
- **Format-version:** 2
- **Validator outcome (pre-flight):** `spec-validate: 0 error(s), 0 warning(s)` at Draft
- **Config:** `commit_on_kickoff: true` · `mark_spec_pr_ready_on_kickoff: true` · `kickoff_ready_ci_wait: 10m` (defaults; no local overrides)

## 2. Goal & glossary

**Restatement (agent's own words).** The spec turns the 2018 15" MacBook Pro
(T2, 6-core i9, 32 GB, Radeon Pro 560X dGPU, RX 580 eGPU) into a Linux
machine with macOS erased entirely, still managed by this repo's Ansible via
a new Linux platform baseline. End state: *server-ready but service-free* —
LUKS-encrypted whole disk unlockable remotely during early boot, hardened
key-only SSH, hybrid remote access (router VPN into the LAN + Tailscale mesh
on the host), unattended power-loss recovery, verified headless boot. The
eGPU does both display and Vulkan compute within this spec. The one
irreversible step (the wipe) is reached only through a staged safety
sequence: verified backup → latest firmware → power-loss auto-restart
set → Startup Security relaxed to No Security → boot-verified installer
USB → documented rollback (internet recovery), with firmware and backup
re-checked immediately before erasing.

**Rules out:** dual-boot or retained macOS partition; deploying any
long-running service; behavior changes on other Mac hosts; Mac Studio setup;
self-hosted VPN control plane (Headscale kept as a future exit).

**Assumes (accepted as-is at sign-off):** the t2linux T2-Ubuntu stream stays
active, release picked at execution time; the SMC autorestart setting
survives the OS change (verified post-install, Linux-native fallback
researched if not); a USB-C/Thunderbolt ethernet adapter drivable from the
initramfs; the home router can act as a VPN server; the network drive has
capacity; internet recovery works as rollback — explicitly untested by this
spec.

**Glossary resolutions:**

- *valuable local state* — judged at Task 1 execution by the human; the
  inventory artifact lives with the backup, never in the repo.
- *server-ready* — exactly the REQ-E set, nothing more.
- *network drive* — LAN-attached; identity intentionally untracked
  (REQ-F1.1).
- *the runbook* — **resolved: committed to this repo**, with REQ-F1.1
  hygiene applied (no serials, IPs, hostnames). Basis: test-spec REQ-A1.2
  already applies commit-hygiene language to it, and REQ-A1.5's
  design-level verification runs against a committed artifact. Spec edit
  collected (see §3 edit list). *(Lens pass 2026-07-23: pinned to the
  single artifact `specs/linux-migration/runbook.md`; every "documented
  in the repo" procedure — rollback, mid-install recovery, kernel-update
  + recovery, day-2 unlock routine, eGPU procedure, dGPU quirks,
  health-check home — is a section of it.)*

Signed off: 2026-07-22

## 3. Requirements walkthrough

**Per-group outcomes** (all groups walked 2026-07-22; validator clean
after every edit):

- **REQ-A — pre-migration safeguards:** the staged gate before the
  irreversible step. With the 1Password split (REQ-A1.1) and the
  runbook-in-repo resolution (REQ-A1.5) applied, every A-requirement has
  an unambiguous artifact home. No open gaps.
- **REQ-B — core OS on T2:** hardware coverage complete for the
  machine's own devices. Gap probed: external display via the built-in
  TB3 ports (dGPU) had no requirement; resolved by minting **REQ-B1.9**
  (operator chose "add a REQ" over recording a deliberate exclusion),
  homed in Task 6 with a test-spec entry that exercises one resolution
  change against the known T2 hybrid-graphics crash reports.
- **REQ-C — eGPU:** display + compute + documented procedure; Vulkan
  (not ROCm) settled by D-4. Confirmed as drafted.
- **REQ-D — dotfiles baseline:** converge / platform-split / stabilize
  to two consecutive clean runs / CI green. Matches repo conventions.
  Confirmed as drafted.
- **REQ-E — server readiness:** hybrid access paths cover each other's
  blind spots; E1.5's retirement of the WAN port-forward is explicitly
  ordered after verification. Confirmed as drafted.
- **REQ-F — hygiene + secrets:** F1.1 (no sensitive detail in committed
  artifacts) now pairs with minted **REQ-F1.2** (secrets live in and are
  retrieved from 1Password). Coherent pair.

**Mid-walk operator clarification (recorded decision):** all secrets
rely on **1Password**, and task sequencing accounts for it — vaulting
happens before the wipe (Task 1, with a second-device access check so
retrieval never depends on the wiped machine), and the `op` CLI enters
the Linux baseline (Task 4) before any post-wipe task consumes a secret.

**Consolidated spec-edit list (all applied in place; Draft bundle):**

1. `requirements.md` — REQ-A1.1 reworded (secrets → 1Password,
   non-secret data → network drive, second-device check).
2. `requirements.md` — REQ-A1.5 pins the runbook to this repo with
   REQ-F1.1 hygiene.
3. `requirements.md` — REQ-F1.2 minted (1Password as vault of record).
4. `requirements.md` — REQ-B1.9 minted (dGPU external display).
5. `requirements.md` — Changelog entry for the kickoff edits.
6. `design.md` — cross-cutting secrets note names 1Password;
   D-5 amended in place (baseline gains the `op` CLI).
7. `tasks.md` — Task 1 cargo split by class + second-device check;
   Task 4 gains `op` and cites REQ-F1.2; Task 6 gains the dGPU display
   deliverable and cites REQ-B1.9.
8. `test-spec.md` — REQ-A1.1 entry updated; REQ-F1.2 and REQ-B1.9
   entries added.
9. *(Added §7, 2026-07-23)* REQ-E1.6 minted (requirements + changelog),
   Task 10 deliverables/done-when/citations extended, test-spec
   REQ-E1.6 entry added.
10. *(Added at the sign-off lens pass, 2026-07-23)* The 41-finding
    edit set across all four files — see §8 for the lens record; the
    2026-07-23 changelog entry in `requirements.md` enumerates it.

**Mid-walk delta-scoped lens passes** (run inline at each point of
application — small, narrow deltas; per `kickoff-verification`):

- 1Password edit set: no blocking findings. Note recorded: Task 8 needs
  only the public key half on the host, so no Task 4 → Task 8 dependency
  edge is warranted (deliberate non-edge, see §6).
- REQ-B1.9 mint: no blocking findings; stale-reference sweep updated
  Task 6's "B1.3 through B1.6" done-when range to include B1.9; no other
  references to the old range exist in the bundle.

Signed off: 2026-07-22

## 4. Design walkthrough

Reconciled ledger, every D-ID accounted for (see `design.md` for the
decisions themselves):

- **Confirmed, rationale intact:** D-1, D-2, D-3, D-4, D-6, D-7, D-8,
  D-9. Notables checked during the walk: D-3's accepted consequence
  (every reboot waits at the unlock prompt for a human) restated and
  accepted; D-4's hotplug-vs-boot-attached posture deliberately left
  open for verification to decide; D-7's SMC-persistence assumption has
  its verification-plus-fallback task home (Task 10).
- **Amended in place:** D-5 — the Linux baseline package set gains the
  1Password CLI (`op`), clerical follow-through of the §3 secrets
  decision; annotation applied per the amendment-annotation format.
- **Superseded:** none.

No design decision contradicts a walked requirement; the one new
touchpoint (REQ-F1.2 secrets) is reconciled into D-5 and the
cross-cutting secrets note. No inconsistency halt was needed.

Signed off: 2026-07-22

## 5. Verification approach

**Coverage mix:** per `test-spec.md`'s intro and per-entry tags (cited,
not tallied here): predominantly `[manual]` (physical-machine checks),
`[test]` on the repo's existing lefthook + GitHub Actions automation for
the REQ-D repo work, `[design-level]` for the two documentation
artifacts (REQ-A1.5, REQ-C1.3). All three kickoff-minted REQs (B1.9,
F1.2, E1.6) are `[manual]`; F1.1 gained a `[test]` arm once the lens
pass added the lefthook secret scanner to Task 4.

**Ownership:** `[test]` entries run automatically in lefthook pre-commit
and CI on every commit — no human sweep. `[manual]` entries are owned by
the operator and are embedded in task *Done when* fields, so the sweep
happens as tasks complete rather than as a separate checklist.
`[design-level]` entries are verified at task-PR review by reading the
committed artifact against its coverage list.

**Dead-path check: clean.** Every named verification can run: pre-wipe
checks run while macOS exists; post-wipe checks use hardware the
operator has. Two notes carried to the risk register:

1. REQ-D1.2's "no unexpected changes compared to before" needs a
   baseline macOS playbook run captured before Task 4's split merges
   (ordering constraint, not a dead path).
2. REQ-F1.1/F1.2 hygiene is review-time only — no secret scanner in
   lefthook (noted in the test-spec).

Signed off: 2026-07-22

## 6. Task graph

Derived from the `Dependencies:` lines in `tasks.md` (authoritative;
render on demand via `scripts/spec-graph.sh specs/linux-migration`,
which confirmed this reconstruction). Efforts cited from the
`Estimated effort:` fields.

- **Immediately startable in parallel:** Tasks 1, 2, 4. Task 4 is the
  only agent-executable task pre-wipe; 1–3 are guided manual work on
  the machine, Task 5 is the human-directed irreversible step.
- **Critical path (effort-weighted):** T2 → T3 → T5 → T6 → T7 → T10.
  Task 4's effort sits entirely in pre-wipe slack when started early;
  repo work never delays machine work.
- **Post-wipe parallelism:** after Task 6, Tasks 7, 8, 9 may run
  concurrently on paper, but they share one physical machine —
  reboot-bearing work executes serially in practice (encoded in the
  tasks.md intro); Task 10 waits on 7, 8, **and 9**.
- **Deliberate non-edges (do not "fix"):**
  1. **T4 ↛ T8** — dropbear needs only the dedicated unlock public key
     on the host; no `op` CLI dependency.
  2. **T1 ↛ T3** — backup does not gate installer creation; both gate
     the wipe (T5).
  3. **T4 ↛ T5/T6** — repo work meets the machine only at Task 7.
- **Superseded non-edge:** the originally recorded T9 ↛ T10 non-edge
  (eGPU off the critical path) was replaced at the sign-off lens pass:
  Task 10 now depends on Task 9 so the final server-ready verification
  cannot be invalidated by later eGPU kernel-parameter changes and
  reboots. The critical path is unchanged (Task 7's chain dominates);
  eGPU remains non-essential to server duty, but its state changes
  land before the final verification.
- **Sequencing note:** the REQ-D1.2 baseline macOS playbook run is
  captured at the start of Task 4, before any split work lands — now
  encoded in Task 4's deliverables and done-when, not just here.

Signed off: 2026-07-22

## 7. Risk register

**Decision-domains gap check** (catalog resolved via
`scripts/resolve-catalog.sh decision-domains`; 11 seed domains, no
overlay additions): ten domains either not crossed or crossed and
decided (authn/authz → D-8/REQ-E1.1; secrets → REQ-F1.2/1Password;
deploy/migration → D-2; dependency adoption → design cross-cutting
notes). One gap surfaced — **observability** (always-on server duty
with no host-health visibility decided for the service-free window) —
resolved by minting **REQ-E1.6** (minimal *off-host* health signal,
homed in Task 10; off-host wording deliberately preserves the
no-services scope boundary). Mid-walk delta lens on the E1.6 mint: run
inline, no blocking findings; stale-reference sweep extended Task 10's
done-when enumeration.

**Register** (risk → mitigation / early signal):

1. **t2linux stream stalls / kernel supply-chain trust** → official
   t2linux org artifacts only; update path documented (REQ-B1.8).
   Signal: release-page inactivity, kernel update failure.
2. **Internet recovery is the only road back, untested by this spec** →
   firmware maximally current pre-wipe (REQ-A1.2), rollback runbook
   (REQ-A1.5). Residual risk accepted at sign-off.
3. **Installer live session may lack WiFi** until firmware retrieval →
   wired adapter (required anyway, D-9) or phone tether on hand at
   install time.
4. **dGPU resolution-change crashes** (T2 hybrid graphics), load-bearing
   for REQ-B1.9 → test-spec exercises one resolution change;
   instability documented, not blocking. Signal: crash during Task 6.
5. **Bluetooth glitches on 2.4 GHz WiFi** (T2 reports) → prefer 5 GHz.
   Signal: BT stutter while associated to 2.4 GHz.
6. **SMC autorestart may not survive the wipe** → verify at Task 10;
   Linux-native fallback researched (D-7). Signal: power-cut test fails.
7. **Ethernet adapter driver absent from initramfs** → Task 8 verifies
   from the initramfs; fallback is a different adapter chipset. Signal:
   dropbear unreachable at the unlock prompt.
8. **REQ-D1.2 comparison impossible without a pre-split baseline** →
   baseline macOS playbook run captured at Task 4 start (§6 note).
9. **Hygiene checks are review-time only** (no secret scanner in
   lefthook) → review pass on every amendment (test-spec REQ-F1.1);
   observation fragment recorded proposing the tooling for a future
   spec.
10. **Router VPN capability assumed, not yet verified** → REQ-E1.5's
    ordering retires the port-forward only after both paths verify.
    Signal: router VPN cannot reach dropbear in Task 10.

Rows 11–14, appended at the sign-off lens pass (2026-07-23):

11. **Evil-maid residual** — No Security boot policy + unencrypted
    initramfs means physical access can tamper the boot chain or steal
    the dropbear host key (which would defeat the fingerprint pin);
    LUKS protects data at rest, not the boot path. **Accepted residual
    risk** (home machine, physical threat model accepted); fingerprint
    pinning (REQ-B1.7) covers network-MITM impersonation without key
    theft, nothing more.
12. **Both remote paths down simultaneously** → physical presence is
    the only recovery. **Accepted consequence**, recorded in D-8's
    amendment; mitigation is path independence (router vs host).
13. **Backup is a single copy during the wipe-to-restore window** —
    network-drive failure in that window loses the non-secret cargo.
    Mitigated by the checksum manifest (detects, not prevents);
    residual **accepted** for the short window.
14. **Battery wear from 24/7 AC duty** on an 8-year-old battery
    (swelling is a known 2018-MBP failure mode). Early signal:
    battery-health checks during Task 10 and after; charge-limit
    tooling researched at execution if available for T2 Linux.

No open questions remain: every question raised during the walk was
resolved into a decision (runbook home, 1Password set, REQ-B1.9,
REQ-E1.6) or an explicitly accepted risk (rows 2, 11, 12, 13).

Signed off: 2026-07-23

## 8. Sign-off

### Discovery-Rigor lens review (first activation — full bundle)

Run 2026-07-23 via parallel fan-out: nine read-only sub-agents, one per
canonical lens, each briefed exhaustive-within-lens with
severity-pruning forbidden; coordinator merged and deduped (110 raw →
45 distinct), ran the mandatory self-critique pass (added the
hostname-continuity finding), and validated per validation-rigor
(three-pass with adversarial re-validation; convergence was
multi-lens for every major finding).

**Lens-coverage table (raw per-lens counts before dedup):**

| Lens | Findings | Notes |
| --- | --- | --- |
| Correctness, logic, edge cases | 12 | Startup-Security level, battery-vs-power-cut, pre-wipe staleness |
| Security | 17 | ISO integrity, host-key pinning, backup encryption, exposure window |
| Error handling and failure modes | 8 | Firmware fallback, kernel-update recovery, router-VPN branch |
| Performance | 12 | Fan daemon, thermal soak, backup sizing, Polaris workload fit |
| Concurrency / state | 9 | Reboot races, T9→T10 state race, sshd two-writer, apt locks |
| Naming, readability, structure | 9 | Stale titles/scope, runbook naming drift, REQ-E1.1 wording |
| Documentation | 12 | Runbook homing, Task 4 doc enumeration, repo-doc staleness |
| Tests / verification | 20 | Done-when ↔ test-spec divergences, one-shot/vacuous checks |
| Cross-file consistency | 11 | Brief/changelog omissions, decision-domains walk staleness |

**Dispositions.** 41 findings applied (clusters C1 mechanical
consistency ×12, C2 done-when/verification tightening ×15, C3 security
hardening ×10 — including the WAN-forward disable moved to wipe time
and the public-wording neutralization — C4 scope/homing ×14 including
the gitleaks hook, thermal soak, fan daemon, runbook pinning, and the
Task 10→9 edge; counts overlap where one edit resolves findings across
clusters), each approved cluster-wide by the operator on 2026-07-23.
4 findings **declined with rationale**: Task 6/10 effort-estimate
inflation (estimates are advisory; the router-VPN unknown is already
risk row 10), SSD-capacity recording (speculative for out-of-scope
service needs), deeper BridgeOS-lag detection (Software Update is the
only operator-available surface), SSH key rotation at migration
(optional hygiene, not migration-blocking). 0 deferred. No finding
remains undispositioned.

**Altitude check (REQ-H1.3):** untriggered bundle — the pinned seed
claims in `requirements.md` Sources carry no altitude assertion; the
deliverable is mechanism-altitude throughout and the task decomposition
matches. Not applicable; no altitude D-ID required.

### Panel review (`/panel-review --nested`, operator-directed)

Run 2026-07-23 after the lens dispositions, before the anchor (so its
fixes cannot stale it). Backend: Gemini (profile `personal` default),
one iteration, ~4 min. 7 raw findings → 1 dropped as false positive
(Intel-T2 vs Apple-Silicon partition-layout confusion; the bundle's
t2linux-cited partitioning stands), 2 merged (same root), leaving 5
validated Needs-sign-off items — none Auto-applicable (markdown prose
carries no citable tool rule), so the loop stopped at Human attention
required after one iteration. All 5 were operator-approved as one
cluster and applied: REQ-F1.2 monitoring-key exemption + corrected
sshd-fingerprint coverage, Task 10 sshd fingerprint pin, Task 10
router-VPN fallback hook, Task 4 Ollama-section homing, REQ-E1.4
hard-power-off alternative removed. A second backend iteration over
the fixed diff returned 5 strictly smaller-bore findings: 1 declined
(apt-timer verification is gold-plating over the two-clean-runs
criterion), 4 operator-approved and applied (risk-row-11 pinning
overclaim corrected, REQ-B1.1 instruction artifact removed, battery
test given prompt-recharge + health escape hatch, gitleaks custom-rule
note). Panel concluded at diminishing returns by operator decision:
prose findings carry no citable tool rule, so the auto-drain bucket is
structurally unreachable and each further iteration only shrinks
severity. Validator clean after every application.

**Post-lens stale-reference sweep:** run after the C1–C4 edit set
(REQ mints and re-scopes: none new in this pass; re-scoped REQ-A1.1,
A1.4, A1.5, B1.7, E1.1, E1.2, E1.4, E1.5, E1.6, F1.2): bundle grepped
for the old wordings ("reduced security", "SSH port-forward",
single-destination backup phrasing, "B1.3 through B1.6" ranges,
Task 10 dependency lists); brief sections 2, 3, 5, 6, 7 reconciled
above in place (this being the pre-sign-off window, sections are not
yet append-only).
