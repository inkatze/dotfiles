# Linux Migration — Test Spec

**Status:** Draft
**Last reviewed:** 2026-07-22
**Format-version:** 2
**Execution:** derived — see the status render

Coverage mix: this is a physical-machine migration, so most requirements
verify manually by exercising the hardware or the network path
([manual]). Repo-side requirements verify through the repo's existing
automation — lefthook pre-commit (yamllint, ansible-lint, syntax check,
plus the secret scanner Task 4 adds) and the GitHub Actions workflow
([test]). Two documentation requirements verify by the artifact
existing with the required coverage ([design-level]).

### REQ-A1.1 — Verified selective backup [manual]

Walk the backup inventory by storage class: secret-class items present
in 1Password (opened from a second device); the sensitive-bulk
encrypted archive on the network drive opens with its 1Password-held
key; plain items on the network drive verify against the checksum
manifest with zero mismatches. The size inventory was checked against
drive capacity before copying. Restore at least one item per inventory
category (the finer groupings, not the three classes) to a scratch
location and open/read it. The wipe task (Task 5) is blocked until
this has been demonstrated, and Task 5's delta-sweep re-verifies state
created after Task 1 completed.

### REQ-A1.2 — Firmware current before wipe [manual]

macOS Software Update reports no pending updates at Task 2 **and is
re-checked immediately before the wipe in Task 5**; the final
BridgeOS/firmware version is recorded in the runbook during Task 5's
pre-wipe re-check (version string only, no serials).

### REQ-A1.3 — Installer USB boot-verified [manual]

The machine boots the written USB into a live session (Task 3's Done
when), in which the USB-C ethernet adapter is also confirmed working.
Failure to reach a live session blocks Task 5.

### REQ-A1.4 — Startup Security prepped [manual]

Startup Security Utility, opened in a macOS Recovery session, shows
Secure Boot at No Security and external-media boot allowed. (Reduced
Security is insufficient: it still requires an Apple-signed OS and
would block the installed system's first boot.)

### REQ-A1.5 — Rollback path documented [design-level]

The runbook (`specs/linux-migration/runbook.md`) contains an
internet-recovery macOS reinstall section covering: key-combination
entry, network requirement, and the expectation that the wipe removed
local recovery — plus the lighter mid-install recovery section
(re-running the installer from USB after a partial failure). Existence
plus that coverage is the verification.

### REQ-B1.1 — Latest compatible OS version [manual]

At execution time, the chosen ISO release is the newest on the t2linux
release page whose notes show no blocking issue for this machine
model, and its checksum matches the published digest; post-install,
the package manager reports a fully updated system (Task 6's Done
when carries this condition).

### REQ-B1.2 — Whole-disk install boots [manual]

The installed system boots from the internal SSD; the partition table
shows Linux plus the preserved EFI partition and no macOS volumes
(Task 5's Done when carries this condition).

### REQ-B1.3 — Keyboard and trackpad [manual]

Direct use in the installed system: typing, pointer movement, click and
two-finger scroll.

### REQ-B1.4 — WiFi and Bluetooth [manual]

WiFi associates to the home network and passes traffic; a Bluetooth
device pairs and works. Firmware retrieved via the t2linux macOS-less
path, or from the Task 2 offline export if online retrieval fails
(Task 6).

### REQ-B1.5 — Audio [manual]

Sound plays through the internal speakers at controllable volume.

### REQ-B1.6 — Internal display and brightness [manual]

Native-resolution output and working brightness keys in the installed
system.

### REQ-B1.7 — LUKS console and remote unlock [manual]

Two reboots: one unlocked at the console, one unlocked over SSH from
another machine on the LAN using the dedicated unlock key against the
pinned dropbear host-key fingerprint (Task 8's Done when). The unlock
path is re-verified after an initramfs regeneration, and the pinned
fingerprint matches the one recorded in the runbook.

### REQ-B1.8 — Kernel-update path [manual]

The t2linux kernel-update mechanism has been exercised post-install —
a real update when one is available, otherwise a verified no-op run
with the distinction recorded in the runbook — and the system rebooted
successfully afterward; the procedure and its recovery path
(previous-kernel boot entry, USB rescue) are documented in the
runbook.

### REQ-B1.9 — dGPU external display [manual]

An external display attached to a built-in Thunderbolt port shows the
desktop at native resolution. Known T2 hybrid-graphics
resolution-change crash reports: exercise one resolution change; any
instability found is recorded in the runbook rather than blocking.

### REQ-C1.1 — eGPU drives external display [manual]

An external display attached to the eGPU enclosure shows the desktop.

### REQ-C1.2 — eGPU Vulkan compute [manual]

The RX 580 appears as a Vulkan device, the negotiated link status is
recorded, and a Polaris-capable compute workload (no FP16-dependent
backend) completes with the tool's own output attributing the work to
the eGPU device (not the internal dGPU).

### REQ-C1.3 — eGPU procedure documented [design-level]

The committed runbook section covers: authorization step, hotplug vs
boot-attached posture chosen by verification, any required kernel
parameters, and known limitations. Existence plus that coverage is the
verification.

### REQ-D1.1 — Playbook converges on Linux [test + manual]

[test]: syntax check, yamllint, and ansible-lint pass in lefthook and
CI for the new role and wiring. [manual]: a full playbook run against
the Linux host completes with zero failures (Task 7).

### REQ-D1.2 — Platform split leaves macOS hosts unaffected [test + manual]

[test]: lint and syntax checks cover the guard wiring. [manual]: a
playbook run against a macOS host after the split shows no unexpected
changed/failed tasks compared to the baseline run captured at the
start of Task 4, before any split work landed. Where the remaining
macOS hosts carry host-specific guards, the comparison covers at
minimum the host whose guards differ.

### REQ-D1.3 — Stabilization loop converges [manual]

Task 7's Done when: two consecutive playbook runs against the Linux
host with zero failed tasks and changed=0 on the second run, with the
fixes committed to the repo.

### REQ-D1.4 — Repo lint and CI stay green [test]

lefthook pre-commit (yamllint, ansible-lint, syntax check, and the
secret scanner once Task 4 adds it) and the GitHub Actions workflow
pass on every commit of the platform-split and stabilization work.

### REQ-E1.1 — SSH key-auth [manual]

Key-based SSH login succeeds from another machine; password
authentication and root login are confirmed disabled in the effective
sshd configuration (`sshd -T`); the configuration is asserted by the
repo role, and a subsequent playbook run leaves it unchanged
(single-writer check).

### REQ-E1.2 — Hybrid remote access [manual]

From off-LAN: (a) connecting through the router VPN reaches the host
over its LAN address, and the same VPN path reaches the dropbear
unlock prompt during a deliberate early-boot window; (b) connecting
through Tailscale reaches the running host directly. The router VPN's
protocol is confirmed WireGuard- or IKEv2-class (not PPTP/L2TP-PSK)
and MFA is confirmed on the identity account behind the mesh. Both
paths demonstrated; the day-2 unlock routine in the runbook keeps the
check repeatable after auth expiries.

### REQ-E1.3 — Headless boot with remote unlock [manual]

With no display or keyboard attached: power on, unlock over SSH via
wired ethernet, and reach a full multi-user system over SSH.

### REQ-E1.4 — Auto power-on after power loss [manual]

Battery-aware: sustain an AC outage until the battery drains to
power-off, then restore wall power promptly (no deep-discharge dwell);
the machine boots to the LUKS prompt unattended (and is then remotely
unlockable per REQ-E1.3). Two invalid passes: a wall-cut with a
charged battery (the battery bridges it; nothing is exercised) and a
user-initiated hard power-off with AC present (no power-loss event
occurs, so autorestart never fires). Escape hatch: if battery health
contraindicates the drain (swelling, failing health readout), verify
the autorestart setting's persistence only and record the untested
drain path as an accepted residual in the runbook.

### REQ-E1.5 — Legacy WAN forward retired [manual]

The router's legacy WAN-exposed port-forward is disabled at Task 5
(before the fresh install first boots) and its absence confirmed at
Task 10: the router configuration no longer contains the forward, and
an external port scan of the previous port shows it closed.

### REQ-E1.6 — Minimal host-health signal [manual]

The configured off-host check (another machine over SSH with a
dedicated forced-command key, or an external uptime monitor using the
existing access paths — no new WAN exposure) reports the host healthy,
and detects **both** induced conditions: the host taken offline, and a
disk-space threshold breach, each within its check interval. The
check's home and restricted-key setup are documented in the runbook.

### REQ-F1.1 — Public-spec hygiene [manual + test]

[manual]: review pass over the committed bundle (and every later
amendment) against the security-posture data-hygiene rule: no serials,
LAN IPs, hostnames, credentials, or identifying operational detail.
[test]: once Task 4 lands the lefthook secret/IP scanner, every commit
of the new operational docs (runbook sections) passes it as the
mechanical backstop.

### REQ-F1.2 — Secrets live in 1Password [manual]

Spot-check at execution: **every** secret class the requirement names —
SSH private keys, the dedicated dropbear unlock key, VPN credentials,
Tailscale auth, and the LUKS passphrase record — is present in
1Password and retrieved from it at use time; the backup manifest and
the network drive listing are checked for secret-shaped files (none
outside the encrypted archive); repo diffs pass the secret scanner.
The Task 1 second-device access check is demonstrated before the wipe.
The mechanism-required host-side key files (dropbear/sshd host keys)
are the named exemption, covered by REQ-B1.7's fingerprint pinning.
