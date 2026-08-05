# Remote Shell — Requirements

**Status:** Ready
**Last reviewed:** 2026-08-05
**Format-version:** 2
**Execution:** derived — see the status render

## Goal

Make the path to the Linux dev host a **declared, durable remote-shell
layer**: one the repo asserts rather than one the host drifted into. The
development loop runs on that host and is reached from a Mac, so the session
must survive laptop sleep, network changes, and roaming between networks.
This is the access-path successor `specs/dev-services` names in its Out of
scope, and it inherits the socket-activation observation that bundle
deliberately left unconsumed.

The field was evaluated rather than assumed. The conclusion is that the
stack already on this host — OpenSSH 10.2 reached through kitty's `kitten
ssh`, over a Tailscale network layer, with tmux for durability — is the
right one, and that the work is to **declare it, close its real gaps, and
record what was rejected**. No new transport is adopted. *(Cites: D-1,
D-2, the invocation (Sources), specs/dev-services (Sources), altitude seed
claim (Sources).)*

The deliverable sits at **mechanism and local value**, not doctrine: the
governing rule about stable indirections already exists at doctrine altitude
and this bundle applies it to one host. The invocation's "load-bearing
infrastructure, not a convenience" is read as a claim about **stake** — this
must not silently degrade, and it earns full rigor — not as a claim that the
deliverable belongs at a higher altitude. *(Cites: D-1.)*

## Scope

### In scope

- A deliberate `sshd` unit posture, asserted by the `linux` role, replacing
  the undeclared both-units-enabled state the host currently holds.
- Routing the default client path over the tailnet, while keeping plain
  OpenSSH on the LAN as an unconditional fallback floor.
- A tmux session-durability layer with attach-or-create on connect.
- The stable `SSH_AUTH_SOCK` indirection on the host declared and verified,
  so shells that outlive the connection that created them keep reaching a
  live agent. The mechanism already exists; this bundle asserts and checks
  it rather than building it (D-7).
- Client keepalive tuned for roaming rather than for fast failure detection.
- Declared phone-client access to the host, reusing the tailnet route and the
  repo's existing separate-authorized-keys-file pattern.
- Removal of `mosh` from the Linux apt baseline, asserted absent.
- Recorded rejections for mosh, Eternal Terminal, and Tailscale SSH, with
  the reasoning and sources, so the field is not re-evaluated from scratch.
- A recorded manual verification path for every behavioural requirement.

### Out of scope

- **Adopting a new remote-shell transport.** mosh, Eternal Terminal, and
  Tailscale SSH were each evaluated and rejected; the decisions record why.
  Reopening one is a new bundle, not an amendment.
- **Provisioning the dev services themselves.** PostgreSQL and Valkey belong
  to `specs/dev-services`. This bundle owns the access path to the host, not
  what runs on it — the mirror of that bundle's own Out-of-scope entry naming
  this one.
- **Remote reachability of those services.** They bind to loopback, and
  exposing either over the LAN or the tailnet is recorded there as a separate
  decision that neither bundle owns. This bundle requires only that the
  transport *retain* forwarding capability.
- **Closing the `linux` role's CI execution gap.** That role has lint and
  syntax coverage only. The observation recording the gap stays live and
  unconsumed, matching the neighbouring bundle's disposition of it.
- **Bringing `~/.ssh/authorized_keys` under Ansible.** It is the login
  lifeline into a headless host and is deliberately unmanaged per
  `specs/linux-migration` REQ-E1.6. REQ-G adds a *separate* role-owned file
  rather than touching it.
- **Phone-side client configuration.** Which client app is used, and its
  keepalive, key storage, and terminal settings, are the operator's and are
  not assertable from this repo. REQ-G covers only the host side.
- **Any change to macOS host behaviour.** The Macs are clients on this path.
  The cross-platform restructure of the shell config's macOS-only
  `SSH_AUTH_SOCK` block is `specs/linux-migration` Task 7 territory and is
  not reopened here.
- **Session survival across a reboot of the host.** Nothing in the evaluated
  field provides it; layout-restore tooling is orthogonal to transport choice
  and is not specced.
- **Scrubbing private identifiers already present in tracked artifacts or
  git history.** That belongs to the successor hygiene bundle named in
  `specs/dev-services`.
- **Self-hosting a Tailscale control plane.** Unchanged from
  `specs/linux-migration`, which already recorded it as a possible future
  migration.

## REQ-A — sshd unit posture

- **REQ-A1.1** The `linux` role SHALL assert that exactly one systemd unit
  owns port 22: `ssh.service` enabled and started, and `ssh.socket` disabled
  and stopped.
  *(Cites: D-3, obs:cee356fa.)*
- **REQ-A1.2** The role SHALL converge a host that currently has both units
  enabled to the REQ-A1.1 posture in a single run, and SHALL report no change
  on an immediately following run.
  *(Cites: D-3, REQ-A1.1.)*
- **REQ-A1.3** The sshd hardening drop-in SHALL remain the effective source
  of key-only authentication (password authentication, keyboard-interactive,
  and root login all disabled) after the posture change.
  *(Cites: D-3, specs/linux-migration REQ-E1.1 (Sources).)*
- **REQ-A1.4** The asserted posture SHALL survive a reboot: after an
  unattended boot with no display or keyboard attached, `ssh.service` SHALL
  be active and `ssh.socket` SHALL be inactive.
  *(Cites: D-3, specs/linux-migration REQ-E1.3 (Sources).)*
- **REQ-A1.5** Restarting sshd to apply configuration SHALL NOT terminate
  established sessions.
  *(Cites: D-3, research: 2026 remote-shell transport field review
  (Sources).)*

## REQ-B — Route and reachability

- **REQ-B1.1** The default client path from a Mac SHALL resolve to the
  host's tailnet address, so the session is pinned to a stable address and
  survives a client network change without the transport tearing down.
  *(Cites: D-4, research: 2026 remote-shell transport field review
  (Sources).)*
- **REQ-B1.2** Plain OpenSSH on port 22 SHALL remain reachable over the LAN
  unconditionally. It SHALL NOT be firewalled to the tailscale interface,
  gated behind tailnet availability, or displaced by any other transport.
  *(Cites: D-4, specs/linux-migration REQ-E1.3 (Sources).)*
- **REQ-B1.3** The transport SHALL retain working SSH agent forwarding and
  working local and remote port forwarding. Whether any specific forward is
  configured is the operator's call and is not specified here.
  *(Cites: D-2, REQ-D1.1.)*
- **REQ-B1.4** The tailnet address SHALL be carried in the existing
  machine-local indirection rather than committed to this repo —
  specifically the 1Password item's `server_host` field, rendered into
  `~/.ssh/config.local` from the committed `roles/ssh/files/config.lan.tpl`.
  The address SHALL take its MagicDNS form, so resolution goes through the
  local `tailscaled` resolver rather than requiring the control plane at
  connect time.
  *(Cites: D-4, specs/linux-migration REQ-F1.1 (Sources).)*

## REQ-C — Session durability

- **REQ-C1.1** A tmux session on the host SHALL be the durability layer:
  work in flight SHALL survive client disconnect, laptop suspend, and loss of
  the transport, and SHALL be resumable by reattaching.
  *(Cites: D-5.)*
- **REQ-C1.2** Connecting SHALL attach to the existing session or create one
  if none exists, without the operator choosing between those cases.
  *(Cites: D-5.)*
- **REQ-C1.3** Client keepalive SHALL be tuned so that a transient network
  stall the network layer heals does not tear down the session, accepting
  slower detection of genuinely dead connections as the trade. The retune
  SHALL be scoped to this host's stanza and SHALL NOT change the settings
  every other destination inherits.
  *(Cites: D-6, research: 2026 remote-shell transport field review
  (Sources).)*
- **REQ-C1.4** Session survival across a reboot of the host is explicitly
  NOT required. Nothing in the evaluated field provides it, and no
  requirement here SHALL be read as implying it.
  *(Cites: D-5, research: 2026 remote-shell transport field review
  (Sources).)*

## REQ-D — Agent-socket continuity

- **REQ-D1.1** `SSH_AUTH_SOCK` inside a persistent session SHALL resolve
  through a stable indirection, so a shell started under one connection
  continues to reach a live agent after that connection has been replaced by
  a later one.
  *(Cites: D-7, engineering doctrine: machine-local environment layer
  (Sources).)*
- **REQ-D1.2** The indirection SHALL be asserted by the cross-platform `fish`
  role, whose Linux arm already provides it, and SHALL NOT alter macOS host
  behaviour. It SHALL NOT be relocated into the `linux` role: splitting one
  working cross-platform block across two roles buys nothing on this route and
  would put the macOS-unchanged guarantee at risk.
  *(Cites: D-7, obs:bd8cc9f0.)*
- **REQ-D1.3** Git commit signing invoked inside a reattached session SHALL
  succeed after the connection that originally created that session has been
  replaced.
  *(Cites: D-7, REQ-D1.1.)*

## REQ-E — Baseline and recorded rejections

- **REQ-E1.1** `mosh` SHALL be removed from the Linux apt baseline and
  asserted absent, rather than merely un-declared.
  *(Cites: D-2, drafting-session decision (2026-08-05).)*
- **REQ-E1.2** Tailscale SSH SHALL remain disabled on the host.
  *(Cites: D-8.)*
- **REQ-E1.3** The evaluation SHALL be recorded as design decisions naming
  mosh, Eternal Terminal, and Tailscale SSH, each with the reason it was
  rejected and the sources consulted, so a later reader can see why the
  chosen stack won without re-running the research.
  *(Cites: D-2, D-8, research: 2026 remote-shell transport field review
  (Sources).)*

## REQ-F — Verification

- **REQ-F1.1** Every behavioural requirement in this bundle SHALL carry a
  recorded manual verification naming the exact command and the expected
  observation, executed against the real host.
  *(Cites: D-9.)*
- **REQ-F1.2** The roaming and suspend requirements SHALL be verified
  against a real network transition, not simulated by killing a connection.
  *(Cites: D-9, REQ-B1.1, REQ-C1.3.)*

## REQ-G — Phone client access

- **REQ-G1.1** The host SHALL accept SSH from a phone client over both the
  tailnet path and the LAN floor, with no phone-specific server-side
  transport and no change to the sshd authentication posture.
  *(Cites: D-10, REQ-A1.3, REQ-B1.1, REQ-B1.2.)*
- **REQ-G1.2** The phone's authorization SHALL be declared by the `linux`
  role in its own repo-owned authorized-keys file. `~/.ssh/authorized_keys`
  SHALL remain unmanaged by this repo, so a defect in a role-owned template
  cannot lock the operator out of a headless host.
  *(Cites: D-10, specs/linux-migration REQ-E1.6 (Sources).)*
- **REQ-G1.3** The phone's public key SHALL be carried in 1Password and
  injected at playbook time rather than committed, following the pattern
  `roles/ssh/files/config.lan.tpl` already establishes.
  *(Cites: D-10, REQ-B1.4.)*
- **REQ-G1.4** The phone's key file SHALL be added by extending the single
  effective `AuthorizedKeysFile` directive, never by a second drop-in
  declaring that keyword again, and the effective value SHALL be verified
  with `sshd -T` rather than assumed.
  *(Cites: D-10, REQ-A1.3.)*
- **REQ-G1.5** The phone path SHALL NOT depend on SSH agent forwarding from
  the phone. Signing on the host resolves through the host's own agent per
  REQ-D1.1; the availability of that agent is a recorded risk, not a
  guarantee this requirement makes.
  *(Cites: D-10, REQ-D1.1.)*
- **REQ-G1.6** Revoking phone access SHALL be a single-file change plus one
  playbook run, and SHALL NOT disturb the login lifeline or the monitoring
  key.
  *(Cites: D-10.)*

## Changelog

- 2026-08-05 — Kickoff walkthrough. Added REQ-G (phone client access) and D-10
  on operator request mid-walk. Pinned REQ-B1.4 to the 1Password `server_host`
  field in its MagicDNS form. Re-scoped REQ-D1.2 from the `linux` role to the
  `fish` role after verifying the indirection already exists (commit
  `8990a23`); corrected the obs:bd8cc9f0 Sources entry accordingly. Narrowed
  Task 6 and its test-spec entry to the Linux apt baseline, resolving a
  contradiction with the macOS Out-of-scope exclusion. Added two Out-of-scope
  entries (the unmanaged login lifeline, phone-side client configuration).
- 2026-08-05 — Bundle drafted. Fold-detection run against all bundles under
  `specs/`; spin-new confirmed from both sides, the neighbouring
  `specs/dev-services` having already declared this bundle as its access-path
  successor. Consumed obs:cee356fa.

## Sources

- **The invocation (2026-08-03).** The request for the most modern
  remote-shell setup this host can use, with mosh named as an example rather
  than a mandate, and the instruction to evaluate the field and recommend.
- **Altitude seed claim (2026-08-03).** The invocation's statement that "the
  remote-shell layer is load-bearing infrastructure, not a convenience".
  Pinned during seed gathering as an altitude assertion; resolved in D-1.
- **`specs/dev-services`.** The dev-services bundle (Status Draft at
  drafting time). Its Out of scope names the remote-shell / access layer as a
  successor bundle, hands off the socket-activation observation unconsumed,
  binds its services to loopback, and records remote reachability of those
  services as a separate decision. Its REQ-D governs public-repo hygiene for
  its own artifacts; this bundle observes the same rule in what it commits.
- **`specs/linux-migration`.** The platform baseline. REQ-E1.1 (key-only
  sshd owned by the role), REQ-E1.2 (hybrid remote access: router VPN plus
  Tailscale mesh), REQ-E1.3 (headless boot reachable over SSH including the
  remote LUKS unlock path), and REQ-F1.1 (no LAN topology in committed
  artifacts) are the neighbouring requirements this bundle must not break.
- **obs:cee356fa.** The recorded observation that Ubuntu 26.04 ships OpenSSH
  socket-activated while the role asserts a classic service, flagged as a
  posture to decide deliberately. Consumed by this bundle.
- **obs:bd8cc9f0.** The recorded observation (2026-07-24) that the shell
  config's `SSH_AUTH_SOCK` stabilization block was macOS-only with no
  host-side arm. **Already remedied for this block** by commit `8990a23`
  ("chore(fish): make config.fish cross-platform"), which added the Linux arm
  resolving `~/.1password/agent.sock`; verified on the host, where
  `~/.ssh/auth_sock` exists and `SSH_AUTH_SOCK` resolves through it. The
  observation stays live for the *rest* of what it names (the `brew --prefix`
  and `DYLD_FALLBACK_LIBRARY_PATH` assumptions), which remain
  `specs/linux-migration` Task 7's cross-platform restructure. REQ-D is
  therefore scoped to declaring and verifying the existing mechanism, not
  building one.
- **Research: 2026 remote-shell transport field review.** Commissioned
  during drafting; covered mosh, Eternal Terminal, Tailscale SSH, OpenSSH
  with connection multiplexing, wezterm's multiplexer, zellij remote
  sessions, shpool, SSH3, and dtach/abduco, against maintenance health,
  roaming guarantees, forwarding support, and security history. Load-bearing
  primary sources: the Tailscale SSH documentation (port 22 claimed for the
  tailnet address only, sshd configuration and authorized-keys left
  unmodified, and daemon restart terminating existing sessions); Tailscale
  issue 4478 and the package-upgrade restart issue, both open; the mosh
  release history (1.4.0, October 2022, itself the first release in five
  years) and its documented absence of port and agent forwarding; the
  Eternal Terminal 2022–23 advisory set including the forwarded-agent-socket
  race; and the removal of OpenSSH client roaming in 7.1p2 following
  CVE-2016-0777, never reinstated.
- **Engineering doctrine: machine-local environment layer.** The standing
  rule that long-lived processes must reference stable indirections rather
  than capturing ephemeral values, recorded after a stale forwarded SSH agent
  socket broke commit signing across every worker in a prior orchestration
  run. D-1 places this bundle as an application of that rule, not an author
  of it.
- **Measured host facts (2026-08-03 and 2026-08-05).** Ubuntu 26.04 LTS;
  OpenSSH 10.2p1; mosh 1.4.0 installed but unconfigured; Tailscale 1.98.10
  with its SSH server disabled; Eternal Terminal absent; tmux 3.6a from apt.
  Both `ssh.service` and `ssh.socket` enabled and active, the service's
  enablement symlink dated to the Ansible run the observation predicted,
  with `sshd -D` holding the inherited listener and no unit failures in three
  months of uptime.
