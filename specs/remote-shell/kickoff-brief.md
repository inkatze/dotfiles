# Remote Shell — Kickoff Brief

**Spec path:** `specs/remote-shell`
**Spec commit at walkthrough start:** `75cac66fb8e951193b15ac1e3229658f473798ba`
**Walkthrough date:** 2026-08-05
**Mode:** First activation (Status Draft, no prior brief)
**Validator outcome (pre-flight):** `spec-validate.sh specs/remote-shell` — 0 errors, 0 warnings
**Config:** `commit_on_kickoff: true`, `mark_spec_pr_ready_on_kickoff: true`,
`kickoff_ready_ci_wait: 10m` (all defaults; no `planwright.local.yml` in this repo)
**Working location:** spec worktree `.claude/worktrees/remote-shell-spec`, branch
`planwright/remote-shell/spec`, clean at start.
**Independent cold read:** `/spec-walkthrough specs/remote-shell` offered as an
optional complement; not run, not a dependency of this sign-off.

---

## 2. Goal & glossary

**Restated goal.** Turn a working-but-undeclared access path into a stated
posture. The stack is unchanged — OpenSSH 10.2 via `kitten ssh`, over
Tailscale, with tmux for durability — and the deliverables are the declaration
plus its concrete closures: one systemd unit owning port 22, the default route
pinned to the tailnet, keepalive retuned toward patience, the existing
`SSH_AUTH_SOCK` indirection declared and verified, tmux attach-or-create, mosh
asserted absent, declared phone access, and the rejections recorded. *(The
`SSH_AUTH_SOCK` and phone items reflect R3.1 and R3.3, decided in section 3
after this section was written.)*

**What it rules out.** Any new transport. The dev services and their remote
reachability (`specs/dev-services`). The `linux` role's CI execution gap. Any
macOS host change. Session survival across a host reboot — REQ-C1.4 states that
non-guarantee explicitly and nothing here may be read as implying it. Scrubbing
identifiers already in git history.

**What it assumes** (none stated as preconditions in the spec):
Tailscale is up on the client platforms as well as the host; an out-of-band way
in exists before Task 1 touches the unit posture; `kitten ssh` is the client
wrapper; the operator is the only user of this route. *(The third and fourth
are amended by the phone-client scope decision in section 3.)*

**Implicit terms surfaced and resolved against the repo:**

| Term the spec uses | Resolved to |
|---|---|
| "the existing machine-local indirection" (REQ-B1.4) | **Decision below** — two candidates existed |
| "this host's stanza" (D-6, REQ-C1.3) | The `Host` blocks in `roles/ssh/files/config.lan.tpl`, rendered to `~/.ssh/config.local` by `scripts/ssh-lan-config-sync.sh` via `op inject`. Included *before* `Host *`; `ssh_config` is first-value-wins, so it wins |
| "the roughly-three-minute budget" (Task 3) | `ServerAliveInterval 60` (`roles/ssh/files/config`) with no `ServerAliveCountMax`, so the default 3 applies → 180s. Figure verified, not taken on trust |
| "the absent-packages list" (Task 6) | `linux_apt_packages_absent` in `roles/linux/defaults/main.yml`; mosh currently sits in the install list in the same file |
| "a stable indirection" for the agent socket | `~/.ssh/auth_sock`, per the standing machine-local-environment doctrine. Already present on the host — see the REQ-D finding in section 3 |

**Resolutions recorded:**

- **R2.1 — Which machine-local indirection carries the tailnet address.**
  The 1Password item's `server_host` field, feeding
  `roles/ssh/files/config.lan.tpl`. Grounded in mechanism: `server_host` is
  what an alias resolves to, so one edit moves both client paths at once, the
  committed template keeps the structure reviewable with no value in the repo,
  and the template's first block already matches the bare `server_ip`, leaving
  the LAN floor untouched by construction. Accepted cost: the sync needs an
  unlocked `op` session, and a host without `op` is skipped rather than failed.
- **R2.2 — Which form of the tailnet address.** The MagicDNS name
  (`<node>.<tailnet>.ts.net`). Readable, survives a node re-add, and resolves
  through the local `tailscaled` resolver from its cached netmap rather than
  requiring the control plane at connect time. Accepted cost: it does require
  `tailscaled` running with its DNS settings applied on the client — carried to
  the risk register.
- **R2.3 — "The default client path" is one edit point, not two.** Resolved
  from the repo rather than asked: `sshc` wraps `kitten ssh <target>` and both
  it and a plain `ssh <alias>` resolve the same alias through
  `config.lan.tpl`, so R2.1's single field moves both. `ssh <server_ip>`
  remains the LAN floor.

Signed off: 2026-08-05

---

## 3. Requirements walkthrough

**REQ-A — sshd unit posture.** Intent: make the role's existing assertion
truthful by having exactly one unit own port 22. Premise verified live on the
host: `systemctl is-enabled` and `is-active` both return `enabled` / `active`
for **both** `ssh.service` and `ssh.socket`. The gap is real. No edits.

**REQ-B — route and reachability.** Intent: pin the default path to a stable
tailnet address while keeping plain OpenSSH on the LAN as an unconditional
floor. Edited: REQ-B1.4 now names the 1Password `server_host` field and the
MagicDNS form, per R2.1/R2.2. `ForwardAgent yes` and `SendEnv` already sit on
the alias in `config.lan.tpl`, so REQ-B1.3 rests on an existing mechanism.

**REQ-C — session durability.** Intent: tmux owns session life, the network
layer owns roaming, and the two are not conflated. REQ-C1.4's reboot
non-guarantee is explicit and nothing else in the bundle implies otherwise
(checked). No edits.

**REQ-D — agent-socket continuity.** Re-scoped from build to declare-and-verify;
see decision R3.1 below.

**REQ-E — baseline and recorded rejections.** REQ-E1.1 was already correctly
scoped to the Linux apt baseline; the contradiction lived in Task 6 and the
test-spec entry. Resolved per R3.2.

**REQ-F — verification.** Intent: every behavioural REQ carries a recorded
manual verification, with roaming and suspend against real events. No edits.

**REQ-G — phone client access.** New group, added on operator request
mid-walkthrough; see R3.3.

### Decisions taken

- **R3.1 — REQ-D is declare-and-verify, not build.** Three independent checks
  falsified the drafted premise: the repo (`roles/fish/files/fish/config.fish`
  has a Linux arm resolving `~/.1password/agent.sock`), the git history
  (commit `8990a23` added it *after* obs:bd8cc9f0 was recorded on 2026-07-24),
  and the live host (`SSH_AUTH_SOCK` set to `~/.ssh/auth_sock`, resolving
  through that symlink to `~/.1password/agent.sock`). REQ-D1.2 re-attributed to the `fish` role with an
  explicit prohibition on relocating it; D-7 rewritten with an amendment
  annotation; Task 4 shrunk to verification plus a comment; the obs:bd8cc9f0
  Sources entry corrected to record the block as already remedied while the
  observation stays live for the rest of what it names. **Consequence worth
  carrying:** the symlink resolves to the host's *own* 1Password agent, not a
  forwarded one, so the stale-forwarded-agent failure the bundle was framed
  around does not arise on this route. Rejected alternatives are recorded in
  D-7 (relocate to `linux`; spec the residual gaps; drop REQ-D entirely).
- **R3.2 — Task 6 narrowed to the Linux baseline.** The drafted Done-when
  ("nothing else in the repo references mosh") and its test-spec entry could
  not both hold with `Brewfile:57` carrying `brew "mosh"`, because Out of
  scope excludes any macOS host change. Operator's reading: Linux baseline
  only. Both were narrowed, and the test-spec entry now states that a
  repo-wide grep returning the Brewfile line is the expected result, so a
  later reader does not "fix" it.
- **R3.3 — Phone access is in scope as REQ-G + D-10 + Task 8.** Two of my
  three drafted justifications were wrong and are recorded here so the record
  is honest: terminfo is a non-issue (the host carries `xterm-256color`,
  `screen-256color`, `tmux-256color`, `vt100`, `xterm`; `kitten ssh` ships
  terminfo only because `xterm-kitty` is non-standard), and
  `~/.ssh/authorized_keys` being unmanaged is a deliberate recorded decision
  (`specs/linux-migration` REQ-E1.6, argued in `61-monitoring.conf`), not
  drift. What survived: the phone key is declared nowhere. REQ-G therefore
  adds a separate role-owned key file, injected from 1Password rather than
  committed (operator's call, over the committed-public-key precedent, because
  this is an unrestricted shell key where the dropbear and monitoring keys are
  forced-command and `restrict`ed).
- **R3.4 — One mechanism constraint, recorded because it fails silently.**
  `AuthorizedKeysFile` replaces rather than extends, and sshd takes the first
  value it obtains. A second drop-in redeclaring it sorts later and is
  ignored, so the key simply never authenticates with nothing logged. REQ-G1.4
  and its test-spec entry pin the check to `sshd -T`, not to the file on disk.
  This is also a deliberate cross-bundle file touch, recorded in design.md's
  Cross-cutting concerns.

### Consolidated spec-edit list (applied during this section)

| File | Edit |
|---|---|
| `requirements.md` | In scope: phone bullet added |
| `requirements.md` | REQ-B1.4 pinned to the 1Password `server_host` field, MagicDNS form |
| `requirements.md` | REQ-D1.2 re-attributed to the `fish` role; relocation prohibited |
| `requirements.md` | REQ-G group added (G1.1–G1.6) |
| `requirements.md` | Out of scope: two entries added (unmanaged login lifeline; phone-side client config) |
| `requirements.md` | Sources: obs:bd8cc9f0 corrected to record the remedy and its residue |
| `requirements.md` | Changelog: kickoff entry added |
| `design.md` | D-7 rewritten with amendment annotation; four alternatives recorded |
| `design.md` | D-10 added (phone client posture and key delivery) |
| `design.md` | Cross-cutting concerns: cross-bundle `61-monitoring.conf` touch recorded |
| `tasks.md` | Task 4 rewritten to declare-and-verify; effort 1 day → half day |
| `tasks.md` | Task 6 Done-when narrowed to the Linux baseline |
| `tasks.md` | Task 8 added (phone), placed before Task 7 for dependency order |
| `tasks.md` | Task 7 dependencies extended to include 8; intro prose updated |
| `test-spec.md` | REQ-E1.1 entry narrowed, with the Brewfile expectation stated |
| `test-spec.md` | REQ-D1.1 entry extended: record which agent answered, plus the negative case |
| `test-spec.md` | REQ-G1.1–G1.6 entries added |

Validator re-run after these edits: 0 errors, 0 warnings.

Signed off: 2026-08-05

---

## 4. Design walkthrough

Reconciled ledger — every D-ID accounted for:

| D-ID | Disposition | Note |
|---|---|---|
| D-1 | Confirmed | Altitude call (mechanism + local value) holds. Lightly reworded: the "one client platform" premise became two once REQ-G landed, and its `(see D-7)` pointer now resolves to a decision saying the cross-platform generalization already exists |
| D-2 | **Amended** | Conclusion intact, two stated reasons falsified — see R4.1 |
| D-3 | Confirmed | Premise verified live: both `ssh.service` and `ssh.socket` enabled and active |
| D-4 | Confirmed | Sharpened by R2.1/R2.2 rather than changed |
| D-5 | Confirmed | tmux/transport layering intact; REQ-G leans on it harder, not differently |
| D-6 | Confirmed | The ~180s figure verified from `roles/ssh/files/config` plus OpenSSH's default `ServerAliveCountMax` |
| D-7 | **Amended** | Rewritten per R3.1 with an amendment annotation and four recorded alternatives |
| D-8 | Confirmed | Rests on session durability alone; nothing found today touches it |
| D-9 | Confirmed | Manual-only verification; REQ-G's entries follow the same shape |
| D-10 | **New** | Phone client posture and key delivery |

No design decision contradicts a walked requirement; the two that contradicted
*reality* (D-2, D-7) were corrected in place rather than carried.

### Decision taken

- **R4.1 — D-2's rationale corrected, conclusion unchanged.** Two claims fell
  to R3.1: that commit signing on the host runs against a *forwarded* agent
  (it runs against the host's own 1Password agent), and that the forwarded
  agent socket goes stale on reconnect (it does not). The mosh bullet now
  leads with port forwarding, which mosh lacks entirely and REQ-B1.3 requires
  in both directions; the "Do nothing" bullet drops to two defects, both
  verified on the host. Both bullets carry amendment annotations naming the
  event. Rejected alternatives: reopening the mosh evaluation (Out of scope
  says reopening a rejected transport is a new bundle, not an amendment);
  softening REQ-B1.3 (forwarding is still wanted, only its justification
  changed); leaving D-2 as drafted (REQ-E1.3 cites it as the artifact a later
  reader uses to reconstruct why the chosen stack won, so leaving two false
  claims in it defeats its purpose).

Signed off: 2026-08-05

---

## 5. Verification approach

**Coverage mix.** One test-spec entry per REQ, with no REQ unverified and no
orphan entry — checked by comparing `test-spec.md`'s headings against
`requirements.md`'s REQ list rather than by transcribing a count. The mix is
overwhelmingly `[manual]`, with a small number of `[test + manual]` and
`[design-level]` entries; the exact tallies live in `test-spec.md` and are not
copied here.

**Ownership.** Every manual sweep is the operator's. There is no CI execution
leg and this bundle adds none (D-9). The automated half of the
`[test + manual]` entries rides the existing gitleaks pre-commit hook, already
wired through `lefthook.yml`; this bundle consumes that hook and does not
extend it.

**Dead paths — all entries checked, none found.** The two likeliest candidates
survive scrutiny. REQ-D1.2 ("macOS behaviour unchanged") stays runnable and
meaningful because Task 4 became comment-only, so nothing in this bundle
alters macOS `SSH_AUTH_SOCK`. REQ-C1.3's scoping check is what covers the one
Mac-visible change in the bundle — Task 3 edits `config.lan.tpl`, which
renders onto the Macs as well — which is exactly the leak D-6 scoped the
retune to prevent.

Signed off: 2026-08-05

---

## 6. Task graph

Reconstructed from the `Dependencies:` lines, which are authoritative; the
diagram below is derived from them, not the other way round.

```
  T1 ────────────────────────────────────┐
  T6 ────────────────────────────────────┤
  T2 ──┬── T3 ───────────────────────────┤
       └────────────┐                    ├── T7
  T4 ───────────────┤                    │
  T5 ───────────────┴── T8 ──────────────┘
```

**Parallelism.** Five tasks are startable immediately (T1, T2, T4, T5, T6).
**Critical path** (effort-weighted, efforts from `tasks.md`): T5 → T8 → T7.
Everything else carries slack.

**Deliberate non-edges, recorded so nobody "fixes" them later:**

- **T1 ⊥ T2.** Which systemd unit answers is orthogonal to which address the
  connection arrives on. No edge.
- **T6 has no dependencies.** Removing a package is independent of everything
  else here.
- **T3 → depends on T2** only because both edit the same host stanza, not
  because keepalive needs the tailnet route. Kept to avoid a merge collision,
  not for correctness.
- **T8 → depends on T5** only because its `Done when` exercises attach-on-
  connect from the phone. The authorization work itself does not need tmux.
- **T4 ⊥ T5 — edge removed during this walkthrough (R6.1).** Task 5's
  deliverable previously described the session inheriting "the stable
  agent-socket indirection from Task 4". After R3.1, Task 4 produces only a
  comment and a verification record, which Task 5 does not consume, so the
  edge was a leftover of the pre-walkthrough framing. Dropping it shortened
  the critical path by half a day and widened immediate parallelism from four
  tasks to five. Rejected alternatives: keeping it as a sequencing preference
  (buys diagnostic clarity, but leaves a preference masquerading as a
  dependency, which is the exact thing this non-edge record exists to expose);
  folding Task 4 into Task 7 (loses the `Done when` that characterizes the
  dangling-symlink behaviour, and defers it to last).

Signed off: 2026-08-05

---

## 7. Risk register

Sources: risks surfaced during the walk, plus the `decision-domains` gap
check. The catalog resolved through `scripts/resolve-catalog.sh
decision-domains` (11 domains). Domains the spec touches **and decides**:
`auth` (REQ-A1.3, REQ-G1.2–G1.6, D-10), `secrets-config` (REQ-B1.4, REQ-G1.3),
`dependency-adoption` (D-2). Domains touched but **not** decided become rows 9,
10 and 13 below. `data-storage`, `caching`, `queues-async`, `api-surface`,
`concurrency` and `versioning-scheme` are not touched by this bundle.

| # | Risk | Mitigation / early signal |
|---|---|---|
| 1 | Task 1's unit flip severs the session applying it — stopping `ssh.socket` when sshd inherited its listener may stop the service with it | Task 1's `Done when` requires an out-of-band way in confirmed *before* applying; apply from the console or the router VPN, never from the session being changed. Early signal: the session dies at the disable step |
| 2 | A distribution release upgrade re-enables `ssh.socket`, silently restoring the two-unit ambiguity (D-3 names this cost) | The role keeps asserting the disable rather than asserting it once by hand. Early signal: re-run REQ-A1.1's checks after any release upgrade |
| 3 | MagicDNS resolution needs `tailscaled` running with its DNS settings applied on the client; without it the primary path fails to resolve even though the peer is up | REQ-B1.2's LAN floor is the fallback by design. Early signal: name resolution fails while `tailscale status` shows the peer reachable |
| 4 | `~/.ssh/auth_sock` dangles when the host's 1Password agent is not running (locked app, unattended reboot); signing then fails in a way that reads as a broken key — the same shape as the gh-keyring failure this repo already recorded | Task 4's `Done when` requires observing and recording this case rather than reasoning about it. Not otherwise mitigated |
| 5 | REQ-B1.4 and REQ-G1.3 both need an unlocked `op` session, and the sync script *skips* a host without `op` rather than failing — so a fresh or headless run can leave the tailnet route and phone access silently absent | Early signal: the sync's own `OK` / `CHANGED` / `FAILED:` line. Treat a skip as a finding, not a pass |
| 6 | A second sshd drop-in redeclaring `AuthorizedKeysFile` silently disables the phone key, with nothing logged anywhere | REQ-G1.4 and its test-spec entry pin the check to `sudo sshd -T`, never to the file on disk |
| 7 | Task 8 edits a file `specs/linux-migration` Task 10 owns; concurrent work on that bundle could collide | Recorded in design.md's Cross-cutting concerns. The edit is additive and confined to one directive |
| 8 | `ControlPersist 12h` plus kitty's `share_connections yes` means a stale control socket can outlive a network change and wedge new connections to this host. No REQ addresses it | Undecided by this bundle. Early signal: new connections hang while `ssh -S none` to the same host succeeds |
| 9 | **`observability` — catalogued domain touched but undecided.** Nothing signals when the sshd posture drifts, the phone key stops authenticating, or `auth_sock` dangles. D-9 accepts no CI guard but the bundle never decides whether the existing `dotfiles-health-report` path should carry a signal | Recorded gap, not mitigated |
| 10 | **`deploy-migration` — catalogued domain touched but undecided.** Task 1's unit flip cannot roll back atomically once access is severed, and no rollback procedure is stated beyond "have an out-of-band way in" | Partially mitigated by Task 1's `Done when`; the procedure itself is undecided |
| 11 | The phone is easier to lose than a laptop and carries an unrestricted shell key | REQ-G1.6 makes revocation one file plus one playbook run; its test-spec entry verifies revocation without breaking login or the monitoring poll |
| 12 | No mechanical regression guard anywhere in this bundle — a later change can silently undo the posture (D-9's accepted cost, stated not hidden) | The recorded verifications are the mitigation; Task 7 is what makes re-running them cheap and unambiguous |
| 13 | **`secrets-config` — partially decided.** Phone-key *revocation* is specced (REQ-G1.6); rotation cadence is not | Recorded gap |

No open questions remain: rows 8, 9, 10 and 13 are recorded as explicitly
accepted gaps rather than unresolved questions.

Signed off: 2026-08-05

---

## 8. Sign-off

**Mode:** first activation. **Scope:** full bundle.
**Validator:** `spec-validate.sh specs/remote-shell` — 0 errors, 0 warnings,
re-run after the Draft→Ready flip (at Ready, findings are errors).

### Lens review pass

Discovery-Rigor review of the whole bundle. **Path: walked inline, not fanned
out** — the doctrine prefers one read-only sub-agent per lens for a delta this
size, but this session's operating rules forbid dispatching sub-agents without
an explicit request, so all nine lenses were walked inline and the substitution
is declared rather than silent.

| Lens | Findings | Notes |
|---|---|---|
| Correctness, logic, edge cases | 5 | 4 dispositioned during the walk (R3.1, R3.2, R4.1, R6.1); 1 applied at sign-off — REQ-A1.2's idempotency entry named only `ssh-server.yml` and missed Task 8's sshd surface |
| Security | 1 | The gitleaks blocker; dispositioned as S8.1 below. The phone key's unrestricted scope was reviewed and accepted under D-10; the `AuthorizedKeysFile` replace-not-extend hazard is captured by REQ-G1.4 |
| Error handling and failure modes | 2 | Both already risk-register rows (`op` skips rather than fails, row 5; `auth_sock` dangles without the local agent, row 4). Nothing new |
| Performance | n/a | Configuration-only bundle: no hot path, allocation, or IO characteristic to assess |
| Concurrency / state | 1 | Cross-bundle touch of a `specs/linux-migration`-owned file (row 7). No shared mutable state otherwise |
| Naming, readability, structure | 3 | All applied during the walk: REQ-G ordered after REQ-F, D-10 after D-9, Task 8 before Task 7 with the dependency-order note |
| Documentation | none | Task 2 already requires connection-path docs updated. `roles/ssh/README.md`, the root `README.md`, and CLAUDE.md's machine-local table were checked against R2.1 for contradictions; none found |
| Tests / verification | 2 | Coverage re-derived mechanically (see below): no orphans either way, no dead paths. 1 applied (Task 8 idempotency folded into REQ-A1.2's entry); 1 accepted (no mechanical guard — D-9's stated cost, row 12) |
| Cross-file consistency | 4 | Post-lens stale-reference sweep, run because REQ-G was minted and REQ-D re-scoped: the goal's "two real gaps", the In-scope `SSH_AUTH_SOCK` bullet, D-1's "one client platform" and its `(see D-7)` pointer, and D-2's "two closed gaps" — all reconciled before the anchor |

**Altitude check (REQ-H1.3 — a check item, not a tenth lens): pass.** A trigger
did fire: `requirements.md`'s `## Sources` pins the seed claim *"the
remote-shell layer is load-bearing infrastructure, not a convenience"*. D-1 is
the altitude record, it is cited from the bundle's goal, and the task
decomposition is mechanism plus local value exactly as D-1 claims. Determined
bundle-locally from the pinned Sources entry, not from drafting-session memory.

### Finding dispositions

Every finding above is dispositioned; none deferred without a named home.

- **S8.1 — gitleaks false positives blocked the sign-off commit. Applied.**
  The walkthrough's edits introduced 11 `internal-hostname` hits and
  `gitleaks git --staged` exited 1. Validated three ways: reproduced with the
  exact pre-commit command; isolated to this run's edits (the bundle at HEAD
  scans clean); and identified as an established false-positive class — every
  match is a repo-owned *filename* (`config.local`, `config.lan`,
  `planwright.local`), and the same class is already committed across ~20
  tracked files including `roles/ssh/README.md`, both `CLAUDE.md` copies, and
  the whole `specs/pair-flow` bundle. Resolved by three anchored allowlist
  regexes in `.gitleaks.toml`, scoped to the exact matched strings. Verified in
  both directions: the staged hook now exits 0, and a negative control — an
  `Hostname` line naming a fabricated machine under the `.local` mDNS suffix —
  still fires, so the REQ-F1.1 backstop is intact. Recorded in prose rather
  than as a literal on purpose: the first draft of this line embedded the
  example string and the rule blocked the commit on it, which is the backstop
  behaving correctly. It cannot tell a fabricated host name from a real one,
  and it should not try.
  Rejected alternatives: rewording the bundle to avoid naming the files (removes
  the precision section 2's glossary exists to provide); `--no-verify` (disables
  all five pre-commit checks for that commit, including the LAN-IP rule);
  tightening the rule's regex (broader change to a security backstop than this
  bundle's scope, and easy to get subtly wrong).
- The remaining lens findings were applied in place during the walk and are
  recorded against their sections (R3.1, R3.2, R3.3, R4.1, R6.1) or carried as
  risk-register rows. No finding was declined, and none was deferred to a
  backlog.

### Pre-flip verification

- **Stale-reference sweep:** completed before the anchor; four references
  reconciled (row above).
- **Lint of edited surfaces:** `mise run lint` (yamllint, ansible-lint,
  `ansible-playbook --syntax-check`) exits 0. `.gitleaks.toml`'s parse is
  proven by gitleaks running successfully against it.
  `check-doc-links.sh` reports all links and anchors resolving for each of the
  five bundle files.
- **Recorded-claim re-derivation:** the coverage claim was re-derived
  mechanically rather than transcribed — REQ ids extracted from
  `requirements.md` and entry headings from `test-spec.md` by fixed pattern and
  compared as sets. Result: equal counts, no duplicates, **no REQ without an
  entry and no entry without a REQ**. Task ids carry no duplicates; D-1 through
  D-10 are all present. D-1 is cited by no task, which is correct rather than a
  gap: it is the altitude decision, cited from the goal.

### Record

Class: meaning
Lens-pass: the *Lens review pass* section immediately above, with all findings dispositioned (S8.1 applied; the rest applied in place during the walk)
Anchor: `8a7b5f18fd515f08a413ff7b492cbb4c82b692c9` — computed as
`scripts/spec-anchor.sh specs/remote-shell`

---

## 9. Amendment log

(no entries yet — later contract changes are appended here as amendment,
re-walkthrough, or re-anchor entries, each carrying its own sign-off record.)
