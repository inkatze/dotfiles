# Remote Shell — Design

**Status:** Draft
**Last reviewed:** 2026-08-05
**Format-version:** 2
**Execution:** derived — see the status render

Origin tags: `N` — new to this bundle. `C, <namespace> D-<n>` — carried from
another bundle's decision, namespace-qualified.

## Decision log

### D-1: The deliverable sits at mechanism and local value, not doctrine  (N)

**Decision:** This bundle is specced as **mechanism plus local value**: role
tasks, unit posture, client configuration, and one host's values. The
invocation's "load-bearing infrastructure, not a convenience" is recorded as
a claim about **stake** — it earns full rigor and must not silently degrade —
not as a claim that the deliverable belongs at doctrine or capability
altitude.

**Alternatives considered:**
- Treat it as a doctrine deliverable, authoring a general rule about durable
  remote access. Rejected because: the governing rule already exists at
  doctrine altitude — long-lived processes must reference stable indirections
  rather than capture ephemeral values — and was recorded after a stale
  forwarded agent socket broke commit signing across an entire orchestration
  run. Restating it here would be the mechanism-written-into-doctrine failure
  the altitude ladder exists to prevent, and would leave this bundle with no
  concrete deliverable.
- Treat it as a capability deliverable, building a general seam other hosts
  plug into. Rejected because: there is one Linux host and one client
  platform. A seam with a single implementation is speculation, and the
  cross-platform generalization that would justify it is already owned
  elsewhere (see D-7).
- Skip the altitude call and design straight to mechanism. Rejected because:
  an altitude trigger fired during seed gathering, and resolving altitude
  after the design exists is how a doctrine deliverable ends up specced as a
  one-repo script. The record is what a later kickoff lens pass can verify.

**Chosen because:** the honest reading of the seed claim is about stake, and
separating the two readings changes the task list materially. At doctrine
altitude this bundle would produce rules and no host changes; at mechanism
altitude it produces a declared posture, two closed gaps, and a verification
record — which is what the invocation actually asked for. Recording the call
as an early D-ID cited from the goal keeps the reasoning checkable rather
than conversational.

### D-2: Declare and harden the existing OpenSSH stack rather than adopt a new transport  (N)

**Decision:** The remote-shell layer is OpenSSH 10.2, reached through
kitty's `kitten ssh`, carried over the Tailscale network layer, with tmux
providing durability. No new transport is adopted. The bundle's work is to
declare this stack, close its gaps, and record the rejections.

**Alternatives considered:**
- **mosh.** Rejected because: it supports neither SSH agent forwarding nor
  port forwarding, both by design and both still absent in 1.4.0. Agent
  forwarding is load-bearing on this route (commit signing on the host runs
  against a forwarded agent), so mosh can never be the primary path. Its
  release history compounds this — 1.4.0 shipped October 2022 and was itself
  the first release in five years — and no maintained fork supplies the
  missing forwarding. Its server-side terminal emulator also silently drops
  sequences it does not understand, and `kitten ssh` cannot wrap it, so
  terminfo would need hand-installation.
- **Eternal Terminal.** Rejected because: it is the only single transport
  offering roaming, agent forwarding, and port forwarding together, but it is
  not packaged for this distribution, requires a root daemon with a new TCP
  listener, and carries a 2022–23 advisory set that includes a race letting
  an authenticated user steal another user's forwarded ssh-agent socket. Its
  sessions also die when its own server is upgraded, so tmux would be
  required anyway — at which point the chosen stack does the same job with
  components that are already present and already maintained.
- **Tailscale SSH.** Rejected on its own decision record; see D-8.
- **Newer entrants** (wezterm's multiplexer, zellij remote sessions, shpool,
  SSH3, dtach/abduco). Rejected because: wezterm's multiplexer requires
  adopting wezterm as the terminal and its last stable release predates this
  evaluation by over two years; zellij's remote sessions are a genuine 2026
  advance but replace tmux and add an HTTPS listener without supplying
  agent or port forwarding; shpool addresses session persistence only and is
  a possible future refinement rather than a transport; SSH3 self-describes
  as a proof of concept awaiting cryptographic review; dtach and abduco have
  been frozen for a decade and do nothing tmux does not.
- **Do nothing.** Rejected because: the host is in an undeclared sshd
  posture, the forwarded agent socket goes stale on reconnect, and the
  keepalive is tuned to tear down sessions during exactly the network
  transitions the requirement says must survive. Those are real defects, not
  cosmetic ones.

**Chosen because:** every hard requirement on this route — agent forwarding,
environment passing, local and remote port forwarding, kitty terminfo and
shell integration, post-quantum key exchange — is met natively by the stack
already installed, and that stack is the most durable of the candidates
against server-side churn: restarting or upgrading sshd does not terminate
established sessions, because each is its own process. The roaming property
the invocation actually wants is supplied by the network layer, not the
transport: with the session pinned to a stable tailnet address, endpoint
rebinding underneath heals a network change rather than breaking it. Nothing
in the field beats that combination without giving up a hard requirement.

### D-3: Classic `ssh.service` posture, with `ssh.socket` asserted disabled  (N)

**Decision:** The `linux` role asserts `ssh.service` enabled and started and
`ssh.socket` disabled and stopped, so exactly one unit owns port 22.

**Alternatives considered:**
- **Socket activation** (`ssh.socket` enabled, `ssh.service` disabled), the
  distribution's own preset. Rejected because: the role's existing assertion
  would have to be rewritten, sshd would not be running as a process until
  the first connection, and the headless-boot verification the platform
  bundle already performs would observe something different from what it
  observes today. The benefit socket activation offers — not running a daemon
  until one is needed — is worth nothing on a host whose entire purpose is
  being reachable.
- **Leave both units enabled and document the state as intentional.**
  Rejected because: it preserves exactly the ambiguity the observation asked
  to resolve. Two units both claiming port 22 forces every later reader to
  re-derive that the arrangement is benign, and leaves the role asserting one
  half of a posture it does not actually own.

**Chosen because:** it makes the role's existing assertion truthful rather
than accidental, and it is the simplest posture to verify on a headless host.
The practical delta is genuinely small — because the socket unit does not
accept connections itself, socket activation only defers the daemon's start,
after which the persistent daemon runs either way — so the decision is won on
declarability rather than on behaviour. The known cost is divergence from the
distribution preset: a future release upgrade may re-enable the socket unit,
which is precisely why the role must keep asserting the disable rather than
assert it once by hand.

### D-4: Tailnet-primary route, with the LAN floor kept unconditionally open  (N)

**Decision:** The default client path resolves to the host's tailnet
address. Plain OpenSSH on port 22 stays reachable over the LAN
unconditionally, and the tailnet address lives in the existing machine-local
indirection rather than in this repo.

**Alternatives considered:**
- **Tailnet only, with port 22 firewalled to the tailscale interface.**
  Rejected because: it makes a tailnet or control-plane outage lock out the
  fallback as well as the primary, leaving only the router VPN and the
  physical console. The platform bundle's headless-boot requirement and the
  remote unlock path both depend on plain ssh existing, and neither should
  inherit a dependency on an external control plane.
- **Leave routing untouched and spec only persistence.** Rejected because:
  the roaming half of the requirement is supplied by the network layer, so a
  bundle that never says which address the client resolves leaves the
  transport-layer half of its own goal unaddressed.

**Chosen because:** pinning the session to a stable tailnet address is what
actually survives a client network change — the transport stalls and resumes
rather than tearing down — while an unconditional LAN floor keeps the
recovery path independent of the thing most likely to have failed. Keeping
the address machine-local follows the platform bundle's existing rule that
network topology does not enter this public repo, and reuses the indirection
already in place rather than inventing a second one.

### D-5: tmux owns session durability; the transport owns roaming  (N)

**Decision:** The two guarantees are layered explicitly. The network and
transport layers keep a connection alive across address changes; tmux keeps
the *session* alive across disconnection, suspend, and transport loss.
Connecting attaches to the existing session or creates one. Survival across
a host reboot is explicitly not promised.

**Alternatives considered:**
- **tmux only, with a transport required merely to reconnect cleanly.**
  Rejected because: it discards the roaming property the invocation named
  first, and makes every network transition a visible interruption when the
  network layer could have absorbed it.
- **The transport owns everything, with tmux left optional and unspecced.**
  Rejected because: no candidate transport survives its own server-side
  process being killed or upgraded, so a bundle relying on the transport
  alone would silently inherit that limit — and long-running work would die
  with it. This is the failure the layering exists to prevent.

**Chosen because:** the two guarantees are genuinely different and no single
component provides both. Naming which layer owns which makes the gap visible
rather than assumed, and stating the reboot non-guarantee explicitly stops a
later reader from inferring a promise the design does not make. tmux is
already in the host's package baseline by deliberate choice, so the
durability layer costs nothing new.

### D-6: Keepalive tuned for roaming, not for fast failure detection  (N)

**Decision:** Client keepalive is retuned so a transient stall the network
layer can heal does not tear the session down, accepting slower detection of
genuinely dead connections. The retune is scoped to this host's stanza, not
the global `Host *` block.

**Alternatives considered:**
- **Leave the current settings.** Rejected because: the present combination
  declares a connection dead after roughly three minutes of stall, which is
  short enough to kill sessions during network transitions that would
  otherwise have recovered — the precise event the bundle exists to survive.
- **Disable keepalives entirely.** Rejected because: a connection that is
  genuinely dead would then hang indefinitely, and the client would hold
  state for a peer that is never coming back.

**Chosen because:** with tmux underneath, the two failure modes are not
symmetric. A connection wrongly declared dead costs a real interruption; a
connection detected late costs a few idle seconds before a reattach that was
going to happen anyway. Tuning toward patience is therefore the cheaper
error, and it is the direction the roaming requirement points. Scoping the
change to this host's stanza is what keeps it compatible with the
macOS-unchanged constraint: the current values live in the shared `Host *`
block that every destination inherits, so retuning them there would silently
change how the Macs talk to everything else.

### D-7: The agent-socket indirection lands host-side, guarded to Linux  (N)

**Decision:** The stable `SSH_AUTH_SOCK` indirection is asserted by the
`linux` role on the host being connected *to*, guarded so macOS host
behaviour is unchanged.

**Alternatives considered:**
- **One cross-platform mechanism covering both platforms.** Rejected
  because: it means restructuring live macOS shell configuration, which needs
  a macOS regression run to prove the no-change constraint holds — and that
  restructure is already recorded as the largest remaining shell-parity item,
  owned by the platform bundle's stabilization task. Taking it here would
  pull that bundle's work into this one and put the no-change guarantee at
  risk for no gain on this route.
- **Handle it client-side from the Mac's ssh configuration.** Rejected
  because: the lifetime of a forwarded agent socket is owned by the server
  end, so a client-side fix addresses the symptom from the weaker end while
  still modifying configuration every host reads.

**Chosen because:** the failure only occurs on the machine being connected
to — the Macs are clients on this route — so a host-side, os-guarded fix
satisfies the macOS-unchanged constraint by construction rather than by
testing. It is also the direct application of the standing doctrine about
stable indirections, which is what D-1 places this bundle as doing. The
accepted cost is that a Mac becoming an ssh target later would not be
covered, and the existing macOS-only stabilization block keeps its own
separate logic until the platform bundle unifies them.

### D-8: Tailscale SSH evaluated and rejected; the SSH server stays disabled  (N)

**Decision:** Tailscale SSH is not enabled. The host keeps Tailscale as a
network layer only, and sshd remains the sole authenticator on every path.

**Alternatives considered:**
- **Enable it as the primary path for this route.** Rejected because: its
  sessions are children of the Tailscale daemon, so restarting or upgrading
  that daemon terminates every session — documented by the vendor, with the
  fix issue still open. The distribution package restarts the daemon on
  upgrade, so an unattended upgrade severs sessions mid-flight. Against a
  requirement that sessions survive, this is strictly worse than
  kernel-owned sshd, where a daemon restart leaves established sessions
  untouched.
- **Enable it as a secondary break-glass path.** Rejected because: it would
  put two authentication authorities on the host, standing in tension with
  the platform bundle's requirement that sshd hold key-only authentication
  under the role's ownership, and would add an access-control surface to
  maintain for a path the router VPN and physical console already cover.
- **Say nothing about it.** Rejected because: the host would keep the
  feature disabled by default rather than by decision, and the question would
  resurface with none of this evaluation recorded.

**Chosen because:** its genuine advantages — no key management, identity-
based access control — buy nothing this route needs, while its session
fragility contradicts the bundle's central requirement. Worth recording
precisely: it is *not* rejected for conflicting with the existing sshd
posture. It claims port 22 only for the tailnet address and leaves sshd
configuration and authorized-keys files unmodified, so the two coexist
cleanly. The rejection rests on session durability alone.

### D-9: Manual verification, recorded, rather than a CI execution leg  (N)

**Decision:** Requirements are verified by hand against the real host, with
each verification recording the exact command and expected observation. No
CI job is added by this bundle.

**Alternatives considered:**
- **Add a scoped Linux CI execution job.** Rejected because: the behaviours
  that carry this bundle's risk — a session surviving suspend, surviving a
  real network transition, an agent socket surviving reconnection — need a
  real host and a real network change, which no hosted runner reproduces. The
  job would cover only the mechanically checkable remainder while implying
  broader coverage than it has.
- **Both, split by what each can prove.** Rejected because: the neighbouring
  bundle already adds a scoped Linux execution job for its own tasks and
  explicitly leaves the role's broader execution gap open, with the
  observation recording that gap deliberately unconsumed. Opening a second
  partial leg here would duplicate that decision without closing the gap
  either.

**Chosen because:** honest coverage beats the appearance of coverage. The
accepted cost is real and is stated rather than hidden: there is no
mechanical regression guard, so a later change can silently undo this
bundle's posture. Recording each verification as an exact command with an
expected observation is the mitigation — it makes re-running the check cheap
and unambiguous, which is what a guard would otherwise have provided.

## Cross-cutting concerns

**The neighbouring bundles.** Three bundles touch this host concurrently.
`specs/dev-services` owns what runs on it and has already declared this
bundle as its access-path successor; the boundary is mirrored here so both
sides agree. The successor hygiene bundle owns scrubbing private identifiers
from existing artifacts and history. `specs/linux-migration` owns the
platform baseline, and its REQ-E requirements are constraints on this bundle
rather than targets for it. File-level overlap is expected to be small: this
bundle touches the ssh server tasks, the client configuration, the shell and
tmux roles, and the Linux package baseline.

**The no-naming rule.** This repo is public and the consuming project's
repository is private. No artifact this bundle commits names that project,
its repository, its features, or its file paths. The neighbouring bundle's
REQ-D states the same rule for its own artifacts and adds a secret-scanner
backstop; that backstop is already wired into the repo's pre-commit hooks and
covers commits from this bundle too.

**Reversibility.** Every change here is a configuration assertion in a
tracked role, one revert from undone, with no migration, no data, and no
irreversible external effect. The one change that could lock the operator out
if wrong is the sshd unit posture, which is why its task carries an explicit
out-of-band recovery path rather than relying on the session applying it.
