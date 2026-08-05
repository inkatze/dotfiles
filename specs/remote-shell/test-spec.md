# Remote Shell — Test Spec

**Status:** Draft
**Last reviewed:** 2026-08-05
**Format-version:** 2
**Execution:** derived — see the status render

Coverage mix is deliberately `[manual]`-heavy, per D-9. The behaviours
carrying this bundle's risk — a session surviving suspend, surviving a real
network transition, an agent socket surviving reconnection, a unit posture
holding across an unattended reboot — need a real host and a real network
change, which no hosted runner reproduces. Adding a CI leg that covered only
the mechanically checkable remainder would imply broader coverage than it
has, and the neighbouring bundle already owns the one scoped Linux execution
job while deliberately leaving the role's broader gap open.

The accepted consequence, stated rather than hidden: there is no mechanical
regression guard for this bundle. Each entry below therefore names the exact
command and the expected observation, so re-running a check later is cheap
and unambiguous. A requirement that cannot be verified is recorded as
unverified with its reason, never marked passed by inference.

### REQ-A1.1 — Exactly one unit owns port 22 [manual]

`systemctl is-enabled ssh.service ssh.socket` returns `enabled` then
`disabled`; `systemctl is-active ssh.service ssh.socket` returns `active`
then `inactive`. The listening socket on port 22 is owned by the sshd
process, not by the socket unit. Run after the role has converged the host.

### REQ-A1.2 — Convergence and idempotency [manual]

Run the Linux role against a host in the current both-units-enabled state:
it reports changed for the posture tasks and the host reaches REQ-A1.1's
state. Run it again immediately: zero changed tasks for
`roles/linux/tasks/ssh-server.yml`. The second run is the real assertion —
a first run that converges but never settles is a defect, not a pass.

### REQ-A1.3 — Key-only authentication survives the posture change [manual]

After the change, `sshd -T` shows password authentication, keyboard-
interactive authentication, and root login all disabled, and the values come
from the role's drop-in rather than the distribution default. Confirm
negatively as well: a password-authentication attempt is refused rather than
prompted.

### REQ-A1.4 — Posture survives an unattended reboot [manual]

Reboot the host with no display and no keyboard attached. After it comes
back, REQ-A1.1's checks still hold and the host is reachable over SSH. This
entry is the one that catches a posture asserted only in the running system
and never persisted, so it must be a real reboot, not a unit restart.

### REQ-A1.5 — Restarting sshd does not kill established sessions [manual]

From an established session, restart sshd via the role's handler path. The
session issuing the restart stays alive and usable, and a second
pre-existing session is also unaffected. A new connection can still be
opened afterwards.

### REQ-B1.1 — Default path resolves over the tailnet [manual]

Connect the normal way and confirm from the server side which address the
connection arrived on: it is the tailnet address, not a LAN or WAN one.
Paired with REQ-C1.3's roaming check, since the point of the address is what
happens when the client's network changes.

### REQ-B1.2 — LAN floor stays open unconditionally [manual]

With the tailnet path in place, connect to the host by its LAN address with
plain `ssh` and no client-side special-casing: it succeeds. Then confirm the
negative case that matters — the LAN path still works when the tailnet path
is unavailable, exercised by stopping the Tailscale daemon on the client and
reconnecting over the LAN. This is the requirement that keeps a control-plane
outage from being a lockout, so verifying it only while the tailnet is
healthy proves nothing.

### REQ-B1.3 — Agent and port forwarding retained [manual]

On a tailnet connection: `ssh-add -l` on the host lists the client's keys
(agent forwarding); a local forward reaches a loopback-bound service on the
host; a remote forward reaches a service on the client. All three on one
connection, since this is the property that disqualified the rejected
alternatives.

### REQ-B1.4 — No topology in tracked files [test + manual]

The repo's existing secret-scan pre-commit hook passes on the change
(automated, already wired). Manually: `git grep` for the tailnet address, the
LAN address, and the real hostname across tracked files returns nothing. The
scanner does not match bare undotted hostnames, so the manual sweep is the
load-bearing half here, not a formality.

### REQ-C1.1 — Work survives disconnect, suspend, and transport loss [manual]

Start a long-running, observable process inside the session. Then, as three
separate trials: close the client cleanly; suspend the laptop past the
keepalive budget and resume; and drop the transport abruptly. In each case
reattach and confirm the process is still running and its output intact.

### REQ-C1.2 — Attach-or-create on connect [manual]

Connect with no session running: one is created. Connect again while it
exists: the same session is attached, not a second one created and not a
nested session. Confirm from a second client that both land in the same
session.

### REQ-C1.3 — Keepalive tolerates a healed stall [manual]

Perform a real network transition on the client — wifi to tether and back,
or between two networks — while a session is open, and confirm the session
survives rather than being declared dead. Then verify the opposite bound: a
genuinely dead peer is still detected and the connection closed rather than
hanging indefinitely. REQ-F1.2 forbids simulating this by killing the
connection, because a killed connection tests the wrong branch.

Scoping is verified separately and on a Mac: `ssh -G` for an unrelated
destination returns the same keepalive values before and after the change.
The current settings live in the shared `Host *` block, so this is the check
that the retune did not leak into every other destination.

### REQ-C1.4 — Reboot non-guarantee is stated, not tested [design-level]

No test. The requirement records that session survival across a host reboot
is explicitly not promised; its verification is the presence of the
statement in the bundle and the absence of any other requirement implying
the contrary. Listed rather than omitted so the non-guarantee is visibly
covered.

### REQ-D1.1 — Agent socket survives connection replacement [manual]

Start a shell inside the session under one connection. Drop that connection
and reconnect. In the original shell, `ssh-add -l` still lists keys rather
than reporting a failure to connect to the agent. This is the exact failure
the standing doctrine was recorded from, so it is checked directly rather
than inferred from the symlink existing.

### REQ-D1.2 — macOS behaviour unchanged [manual]

On a Mac: shell startup produces no new output or error, and
`SSH_AUTH_SOCK` resolves to the same value as before the change. Run before
and after, comparing directly. Verified on a Mac, not reasoned about from
the Linux host.

### REQ-D1.3 — Signing works in a reattached session [manual]

In a session created before a reconnect, make a real commit after the
reconnect and confirm it is signed — `git log --show-signature` on the new
commit shows a good signature. The end-to-end check that REQ-D1.1's
indirection actually reaches the signer, not just an agent.

### REQ-E1.1 — mosh removed and asserted absent [manual]

After a run, `mosh-server` is not present on the host and the package is
gone. An immediately following run reports no change. `git grep` for mosh
across the repo returns only the design record of the rejection, not any
live configuration.

### REQ-E1.2 — Tailscale SSH stays disabled [manual]

The host's Tailscale preferences show its SSH server disabled. Confirm the
consequence rather than only the flag: an SSH connection over the tailnet is
served by sshd and authenticates against keys, not by the Tailscale daemon.

### REQ-E1.3 — Rejections recorded [design-level]

D-2 and D-8 exist and each names mosh, Eternal Terminal, and Tailscale SSH
with the reason it was rejected and the sources consulted. The artifact's
existence and coverage is the verification; the check is that a reader can
reconstruct why the chosen stack won without re-running the research.

### REQ-F1.1 — Every behavioural requirement has a recorded verification [design-level]

Every REQ in this bundle has an entry in this file, and Task 7 records an
executed result for each with the command run and what was observed. The
check is coverage plus execution: an entry with no recorded result is an
unverified requirement, and must be recorded as such.

### REQ-F1.2 — Roaming and suspend verified against real events [manual]

The recorded results for REQ-C1.1 and REQ-C1.3 describe an actual network
transition and an actual client suspend, naming what was done. A result
describing a killed connection or a simulated stall does not satisfy this
requirement and is recorded as unverified instead.
