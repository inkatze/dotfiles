# Remote Shell — Tasks

**Status:** Ready
**Last reviewed:** 2026-08-05
**Format-version:** 2
**Execution:** derived — see the status render

Every task here is an Ansible-managed configuration change: edit the tracked
source under `roles/`, never the materialized file on the host. Tasks 1
through 6 and Task 8 are independent of each other except where a
`Dependencies:` line says otherwise; Task 7 consolidates their verification
and therefore depends on all of them. Task 8 is listed before Task 7 because
this section is ordered by dependency, not by id.

## Tasks

### Task 1 — Declare the sshd unit posture

- **Deliverables:** An amended `roles/linux/tasks/ssh-server.yml` asserting
  `ssh.service` enabled and started and `ssh.socket` disabled and stopped, so
  exactly one unit owns port 22. The existing hardening drop-in and its
  restart handler stay in place, unchanged in effect.
- **Done when:** A run against the host converges both units to the asserted
  posture; an immediately following run reports zero changed tasks for this
  file; `systemctl is-enabled ssh.service ssh.socket` returns `enabled` and
  `disabled` respectively, and `is-active` returns `active` and `inactive`;
  the effective sshd configuration still refuses password authentication,
  keyboard-interactive authentication, and root login; an established session
  opened before the change is still alive after it; and the operator has an
  out-of-band way in (physical console or the router VPN) confirmed available
  *before* the change is applied, since this task can sever the session
  applying it.
- **Dependencies:** none
- **Citations:** D-3 · REQ-A1.1, REQ-A1.2, REQ-A1.3, REQ-A1.5 · obs:cee356fa
- **Estimated effort:** half day

### Task 2 — Route the default client path over the tailnet

- **Deliverables:** The client connection path resolving to the host's
  tailnet address through the existing machine-local indirection, with the
  address itself untracked. Any documentation in the repo describing the
  connection path updated to match.
- **Done when:** A connection made the normal way lands on the tailnet
  address rather than a LAN or WAN one; plain OpenSSH on port 22 still
  answers over the LAN with no client-side special-casing; agent forwarding
  and environment passing still work on the tailnet path; a local port
  forward and a remote port forward each succeed; no tailnet address, LAN
  address, or real hostname appears in any tracked file; and the repo's
  secret-scan hook passes on the change.
- **Dependencies:** none
- **Citations:** D-4 · REQ-B1.1, REQ-B1.2, REQ-B1.3, REQ-B1.4
- **Estimated effort:** half day

### Task 3 — Retune client keepalive for roaming

- **Deliverables:** Keepalive settings tuned for roaming, scoped to this
  host's stanza rather than the global `Host *` block, with a comment
  recording the trade being made.
- **Done when:** The tolerated stall before a connection to this host is
  declared dead is demonstrably longer than the current roughly-three-minute
  budget; a genuinely dead peer is still detected and the connection closed
  rather than hanging forever; and the settings every *other* ssh destination
  inherits are byte-for-byte unchanged, confirmed by diffing the effective
  configuration for an unrelated host before and after (`ssh -G <other-host>`)
  on a Mac.
- **Dependencies:** 2
- **Citations:** D-6 · REQ-C1.3
- **Estimated effort:** half day

### Task 4 — Declare and verify the existing agent-socket indirection

- **Deliverables:** No new mechanism. The existing `~/.ssh/auth_sock`
  indirection in `roles/fish/files/fish/config.fish` gains a comment
  recording that it is load-bearing for this route, that it resolves to the
  host's *own* 1Password agent rather than a forwarded one, and that
  REQ-D1.2 forbids relocating it into the `linux` role. Plus the recorded
  verification that the property actually holds.
- **Done when:** A shell started under one connection still reaches a live
  agent after that connection has been replaced by a later one; `ssh-add -l`
  inside such a shell lists keys rather than failing to connect; git commit
  signing succeeds in that shell; a macOS host's shell startup and
  `SSH_AUTH_SOCK` value are confirmed unchanged, verified on a Mac; the
  comment is in place; and the behaviour when `~/.1password/agent.sock` is
  absent has been observed and recorded, rather than reasoned about, so the
  dangling-symlink risk is characterized.
- **Dependencies:** none
- **Citations:** D-7 · REQ-D1.1, REQ-D1.2, REQ-D1.3 · obs:bd8cc9f0
- **Estimated effort:** half day

### Task 5 — Make tmux the durability layer, attaching or creating on connect

- **Deliverables:** tmux configuration and connection-path changes so that
  connecting attaches to the existing session or creates one, with the
  session resolving the agent through the existing `~/.ssh/auth_sock`
  indirection (D-7) rather than a captured per-connection value. That
  indirection already exists, so this task consumes it rather than waiting
  on Task 4, which only verifies and documents it.
- **Done when:** Work left running survives client disconnect, laptop
  suspend, and transport loss, and is present on reattach; connecting twice
  in a row lands in the same session rather than nesting or creating a
  second; a session created before a reconnect can still sign a git commit
  after it; and the operator can still get a plain shell without tmux when
  they want one.
- **Dependencies:** none
- **Citations:** D-5 · REQ-C1.1, REQ-C1.2, REQ-D1.1
- **Estimated effort:** 1 day

### Task 6 — Remove mosh from the Linux baseline

- **Deliverables:** `mosh` moved out of the Linux apt package list and into
  the absent-packages list, so it is asserted removed rather than merely
  un-declared, following the existing pattern in that role.
- **Done when:** A run removes the package from the host; an immediately
  following run reports no change; `mosh-server` is absent from the host;
  nothing in the *Linux* baseline references mosh outside the design record
  of the rejection; and no firewall rule or configuration was added for it
  that now dangles. The `brew "mosh"` line in the `Brewfile` is deliberately
  left in place: it is macOS territory, which this bundle's Out of scope
  excludes, so a repo-wide `git grep` still returns it.
- **Dependencies:** none
- **Citations:** D-2 · REQ-E1.1, REQ-E1.3
- **Estimated effort:** half day

### Task 8 — Declare phone client access

- **Deliverables:** A committed template rendering the phone's public key
  from 1Password (the `roles/ssh/files/config.lan.tpl` +
  `scripts/ssh-lan-config-sync.sh` pattern), a `linux`-role task installing
  the rendered result to a dedicated `~/.ssh/authorized_keys.phone`, and the
  **existing** `AuthorizedKeysFile` directive in
  `roles/linux/files/sshd/61-monitoring.conf` extended to list it. No second
  drop-in declaring that keyword, and no change to `~/.ssh/authorized_keys`.
- **Done when:** The phone connects over the tailnet path and, separately,
  over the LAN floor; `sudo sshd -T | grep -i authorizedkeysfile` lists all
  three files in one value, confirming the directive was extended rather than
  shadowed; `~/.ssh/authorized_keys` is byte-for-byte unchanged by the run;
  no public key, device name, or address appears in any tracked file and the
  secret-scan hook passes; emptying the phone file and re-running the
  playbook revokes phone access while login and the monitoring poll both
  still work; and a session opened from the phone attaches the existing tmux
  session and survives the link dropping.
- **Dependencies:** 2, 5
- **Citations:** D-10 · REQ-G1.1, REQ-G1.2, REQ-G1.3, REQ-G1.4, REQ-G1.5,
  REQ-G1.6
- **Estimated effort:** 1 day

### Task 7 — Record the verification

- **Deliverables:** A verification record covering every behavioural
  requirement, each with the exact command run and the observation expected,
  executed against the real host — including the reboot check for the sshd
  posture and a real network transition for the roaming and keepalive
  requirements.
- **Done when:** Every REQ in this bundle has a recorded verification result;
  the sshd posture has been confirmed after an actual unattended reboot with
  no display or keyboard attached; the roaming check was performed across a
  genuine network change rather than by killing a connection; the suspend
  check was performed by actually suspending the client; and any requirement
  that could not be verified is recorded as such with the reason, rather than
  being marked passed by inference.
- **Dependencies:** 1, 2, 3, 4, 5, 6, 8
- **Citations:** D-9 · REQ-F1.1, REQ-F1.2
- **Estimated effort:** 1 day

## Awaiting input

(none yet)

## Deferred

- **Shell-side session persistence as a tmux alternative.** A
  persistence-only daemon that preserves native terminal scrollback, rather
  than re-rendering the way tmux does, is a credible refinement of Task 5 but
  not a transport concern and not a gap in the current design. Confidence:
  low. **Gate:** revisit only if tmux's scrollback and copy-paste model
  proves to be a recurring friction in day-to-day use. Citations: D-5,
  research: 2026 remote-shell transport field review (Sources).
- **Reaching the dev services from the Mac.** The services bind to loopback
  and their remote reachability is recorded in `specs/dev-services` as a
  separate decision neither bundle owns. This bundle guarantees the transport
  retains forwarding capability; whether to use a forward, expose the
  services on the tailnet, or neither, stays open. Confidence: medium.
  **Gate:** decide when a client on the Mac actually needs to reach one of
  them. Citations: REQ-B1.3, specs/dev-services (Sources).

## Out of scope

- **Adopting mosh, Eternal Terminal, or Tailscale SSH.** Each was evaluated
  and rejected with its reasoning recorded (D-2, D-8). Reopening one is a new
  bundle, not an amendment to this one.
- **Provisioning or configuring the dev services.** Owned by
  `specs/dev-services`, which named this bundle as its access-path successor.
- **Closing the Linux role's CI execution gap.** The observation recording it
  stays live and unconsumed, matching the neighbouring bundle's disposition.
- **The cross-platform restructure of the shell configuration's macOS-only
  agent-socket block.** Owned by `specs/linux-migration` Task 7.
- **Scrubbing private identifiers from existing artifacts or git history.**
  Owned by the successor hygiene bundle.
- **Session survival across a reboot of the host.** No candidate provides it;
  REQ-C1.4 states the non-guarantee explicitly.
