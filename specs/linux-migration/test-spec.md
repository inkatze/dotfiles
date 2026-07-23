# Linux Migration — Test Spec

**Status:** Draft
**Last reviewed:** 2026-07-22
**Format-version:** 2
**Execution:** derived — see the status render

Coverage mix: this is a physical-machine migration, so most requirements
verify manually by exercising the hardware or the network path
([manual]). Repo-side requirements verify through the repo's existing
automation — lefthook pre-commit (yamllint, ansible-lint, syntax check)
and the GitHub Actions workflow ([test]). Two documentation requirements
verify by the artifact existing with the required coverage
([design-level]).

### REQ-A1.1 — Verified selective backup [manual]

Walk the backup inventory on the network drive; restore at least one
item per category to a scratch location and open/read it. The wipe task
(Task 5) is blocked until this has been demonstrated.

### REQ-A1.2 — Firmware current before wipe [manual]

macOS Software Update reports no pending updates immediately before the
wipe; the BridgeOS/firmware version visible in System Information is
recorded in the runbook (version string only, no serials).

### REQ-A1.3 — Installer USB boot-verified [manual]

The machine boots the written USB into a live session (Task 3's Done
when). Failure to reach a live session blocks Task 5.

### REQ-A1.4 — Startup Security prepped [manual]

Startup Security Utility shows reduced security and external-media boot
allowed; verified in the same session that boots the USB.

### REQ-A1.5 — Rollback path documented [design-level]

The runbook contains an internet-recovery macOS reinstall section
covering: key-combination entry, network requirement, and expectation
that the wipe removed local recovery. Existence plus that coverage is
the verification.

### REQ-B1.1 — Latest compatible OS version [manual]

At execution time, the chosen ISO release is the newest on the t2linux
release page whose notes show no blocking issue for this machine model;
post-install, the package manager reports a fully updated system.

### REQ-B1.2 — Whole-disk install boots [manual]

The installed system boots from the internal SSD; the partition table
shows Linux plus the preserved EFI partition and no macOS volumes.

### REQ-B1.3 — Keyboard and trackpad [manual]

Direct use in the installed system: typing, pointer movement, click and
two-finger scroll.

### REQ-B1.4 — WiFi and Bluetooth [manual]

WiFi associates to the home network and passes traffic; a Bluetooth
device pairs and works. Firmware retrieved via the t2linux macOS-less
path (Task 6).

### REQ-B1.5 — Audio [manual]

Sound plays through the internal speakers at controllable volume.

### REQ-B1.6 — Internal display and brightness [manual]

Native-resolution output and working brightness keys in the installed
system.

### REQ-B1.7 — LUKS console and remote unlock [manual]

Two reboots: one unlocked at the console, one unlocked over SSH from
another machine on the LAN (Task 8's Done when).

### REQ-B1.8 — Kernel-update path [manual]

The t2linux kernel-update mechanism has been run at least once
post-install and the system rebooted successfully afterward; the
procedure is documented in the repo.

### REQ-C1.1 — eGPU drives external display [manual]

An external display attached to the eGPU enclosure shows the desktop.

### REQ-C1.2 — eGPU Vulkan compute [manual]

The RX 580 appears as a Vulkan device and completes a real compute
workload (e.g. a Vulkan-backend inference or benchmark run) attributed
to it.

### REQ-C1.3 — eGPU procedure documented [design-level]

The committed procedure covers: authorization step, hotplug vs
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
changed/failed tasks compared to before.

### REQ-D1.3 — Stabilization loop converges [manual]

Task 7's Done when: two consecutive playbook runs against the Linux
host with zero failures and no unexpected changes, with the fixes
committed to the repo.

### REQ-D1.4 — Repo lint and CI stay green [test]

lefthook pre-commit (yamllint, ansible-lint, syntax check) and the
GitHub Actions workflow pass on every commit of the platform-split and
stabilization work.

### REQ-E1.1 — SSH key-auth [manual]

Key-based SSH login succeeds from another machine; password
authentication is confirmed disabled in the effective sshd
configuration.

### REQ-E1.2 — Hybrid remote access [manual]

From off-LAN: (a) connecting through the router VPN reaches the host
over its LAN address; (b) connecting through Tailscale reaches the host
directly. Both demonstrated once.

### REQ-E1.3 — Headless boot with remote unlock [manual]

With no display or keyboard attached: power on, unlock over SSH via
wired ethernet, and reach a full multi-user system over SSH.

### REQ-E1.4 — Auto power-on after power loss [manual]

Cut power at the wall while running; restore power; the machine boots
to the LUKS prompt unattended (and is then remotely unlockable per
REQ-E1.3).

### REQ-E1.5 — WAN SSH forward retired [manual]

The router configuration no longer contains the SSH port-forward, and
an external port scan of the previous port shows it closed.

### REQ-F1.1 — Public-spec hygiene [manual]

Review pass over the committed bundle (and every later amendment)
against the security-posture data-hygiene rule: no serials, LAN IPs,
hostnames, credentials, or identifying operational detail. Noted for
the future: the repo currently has no general secret scanner in
lefthook, so this remains a review-time check.
