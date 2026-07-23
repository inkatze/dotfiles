# Linux Migration — Requirements

**Status:** Draft
**Last reviewed:** 2026-07-22
**Format-version:** 2
**Execution:** derived — see the status render

## Goal

Migrate the personal machine — a MacBook Pro 15,1 (2018, T2 chip, 6-core
i9, 32 GB RAM, AMD Radeon Pro 560X dGPU, AMD RX 580 eGPU) — from macOS to
Linux, wiping macOS entirely to maximize available resources. The machine
stays under this repo's Ansible management via a new Linux platform
baseline, and every choice favors its near-future role as the always-on
home server for long-running services (a Mac Studio will take over as the
personal computer when it arrives). The eGPU must work for both displays
and compute from day one. No services are deployed by this spec; service
stacks arrive as their own future specs. *(Cites: the invocation
(Sources), drafting-session decision (2026-07-22).)*

## Scope

### In scope

- Selective backup of valuable local state to the LAN-attached network
  drive, verified before any destructive step.
- Pre-wipe machine preparation: firmware update, power-loss auto-restart
  setting, T2 Startup Security changes, installer media.
- Full wipe of macOS and installation of Linux (t2linux-patched Ubuntu)
  with LUKS full-disk encryption on the whole internal disk.
- T2 hardware bring-up: WiFi, Bluetooth, audio, keyboard, trackpad,
  internal display, kernel-update path.
- eGPU (RX 580) bring-up for external displays and Vulkan compute.
- Extending this repo with a Linux platform baseline (new role, platform
  guards, inventory entry) and iterating the playbook against the new
  host until it converges.
- Server readiness: hardened SSH, hybrid remote access (home-router VPN
  as the into-the-LAN door plus a Tailscale mesh on the host), remote
  LUKS unlock, headless-boot verification, retiring the WAN-exposed SSH
  port-forward.

### Out of scope

- Deploying any long-running service (media stack rebuild, containers,
  schedulers). Future specs own those; this spec only makes the machine
  ready for them.
- Any change to the other Ansible-managed hosts beyond keeping their
  playbook runs unaffected by the platform split.
- Setting up the future Mac Studio.
- Self-hosting an overlay-VPN control plane (e.g. Headscale). Noted as a
  possible future migration; the client protocol keeps that exit open.

## REQ-A — Pre-migration safeguards

- **REQ-A1.1** A selective backup of valuable local state (unpushed git
  work, SSH material not vaulted, application data worth keeping,
  browser profiles, macOS-only exports) SHALL be completed to the
  LAN-attached network drive and verified readable before any
  destructive step runs.
  *(Cites: drafting-session decision (2026-07-22), D-2.)*
- **REQ-A1.2** macOS and BridgeOS firmware SHALL be updated to the
  latest available versions before the wipe, so the machine carries the
  newest firmware it will ever get without macOS.
  *(Cites: D-2.)*
- **REQ-A1.3** A bootable installer USB built from the current
  t2linux-patched ISO SHALL be created and boot-verified on this machine
  before the wipe.
  *(Cites: D-1, D-2.)*
- **REQ-A1.4** T2 Startup Security SHALL be configured to permit
  booting the installer and the installed system (reduced security,
  external-media boot allowed) before the wipe.
  *(Cites: D-2, research: t2linux wiki (Sources).)*
- **REQ-A1.5** The rollback path (reinstalling macOS via internet
  recovery) SHALL be documented in the runbook before the wipe, so
  failure at any point has a known exit.
  *(Cites: D-2.)*

## REQ-B — Core OS on T2 hardware

- **REQ-B1.1** The installed OS version SHALL be chosen from current
  t2linux compatibility guidance at execution time — the latest release
  with solid T2 support, not model memory — and the system SHALL be
  fully updated post-install.
  *(Cites: D-1, research: t2linux/T2-Ubuntu releases (Sources).)*
- **REQ-B1.2** The system SHALL install to and boot from the internal
  SSD with the whole disk allocated to Linux (no macOS partition
  retained; the existing EFI partition is preserved).
  *(Cites: D-2, drafting-session decision (2026-07-22).)*
- **REQ-B1.3** The internal keyboard and trackpad SHALL work.
  *(Cites: D-1, research: t2linux wiki (Sources).)*
- **REQ-B1.4** WiFi and Bluetooth SHALL work, using firmware retrieved
  via the t2linux macOS-less path.
  *(Cites: D-1, D-2, research: t2linux wiki (Sources).)*
- **REQ-B1.5** Audio output SHALL work.
  *(Cites: D-1, research: t2linux wiki (Sources).)*
- **REQ-B1.6** The internal display SHALL work, including brightness
  control.
  *(Cites: D-1, research: t2linux wiki (Sources).)*
- **REQ-B1.7** The root filesystem SHALL be LUKS-encrypted, unlockable
  both at the console and remotely over SSH during early boot.
  *(Cites: D-3, drafting-session decision (2026-07-22).)*
- **REQ-B1.8** The kernel/firmware update path SHALL be set up and
  documented so routine updates do not break boot (t2linux kernel-update
  mechanism installed and understood).
  *(Cites: D-1, research: t2linux wiki (Sources).)*

## REQ-C — eGPU (RX 580)

- **REQ-C1.1** The eGPU SHALL drive at least one external display.
  *(Cites: D-4.)*
- **REQ-C1.2** Vulkan compute on the eGPU SHALL be available and
  verified with a real workload.
  *(Cites: D-4.)*
- **REQ-C1.3** The eGPU attach/detach procedure (hotplug vs
  boot-attached, authorization steps, known limitations) SHALL be
  documented in the repo.
  *(Cites: D-4.)*

## REQ-D — Dotfiles Linux baseline

- **REQ-D1.1** The repo's playbook SHALL converge cleanly on the Linux
  host, covering at least fish, mise, tmux, core CLI tooling, and the
  SSH server configuration.
  *(Cites: D-5.)*
- **REQ-D1.2** Platform support SHALL be split so macOS-specific tasks
  are cleanly skipped or scoped away on Linux, and the existing macOS
  hosts' playbook runs remain unaffected.
  *(Cites: D-5.)*
- **REQ-D1.3** First-run failures of the playbook on the fresh install
  SHALL be driven to zero through an explicit stabilization loop,
  finishing only after two consecutive fully clean runs.
  *(Cites: drafting-session decision (2026-07-22), D-5.)*
- **REQ-D1.4** Existing repo lint and CI checks SHALL stay green
  throughout the platform split.
  *(Cites: D-5.)*

## REQ-E — Server readiness (no services)

- **REQ-E1.1** OpenSSH SHALL be enabled with key-based authentication.
  *(Cites: D-8.)*
- **REQ-E1.2** Remote access SHALL be hybrid: the home router's built-in
  VPN server as the into-the-LAN door (covers early-boot unlock and
  emergencies), plus a Tailscale mesh on the host for day-to-day access.
  *(Cites: D-8, research: 2026 overlay-VPN landscape review (Sources).)*
- **REQ-E1.3** The machine SHALL boot headless (no display or keyboard
  attached) to a state reachable over SSH, including the remote LUKS
  unlock path over wired ethernet.
  *(Cites: D-3, D-6, D-9.)*
- **REQ-E1.4** The machine SHALL power back on automatically after
  power loss.
  *(Cites: D-7.)*
- **REQ-E1.5** The WAN-exposed SSH port-forward on the home router
  SHALL be retired once the hybrid remote-access path is verified.
  *(Cites: D-8.)*

## REQ-F — Public-spec hygiene

- **REQ-F1.1** The committed bundle SHALL contain no serial numbers,
  LAN IPs, hostnames, credentials, router or drive product identifiers
  beyond what hardware support requires, or other sensitive operational
  detail; machine-specific values live in machine-local, untracked
  files.
  *(Cites: drafting-session decision (2026-07-22), security-posture
  doctrine (Sources).)*

## Changelog

- 2026-07-22 — Initial draft authored via `/spec-draft` (goal, scope,
  REQ groups A–F, D-1 through D-9, tasks 1–10, test-spec coverage).

## Sources

- **The invocation (2026-07-22).** The migration idea and its
  constraints: t2linux Ubuntu preference, eGPU must work, machine
  becomes the long-running-services server when a Mac Studio takes over
  as the personal computer.
- **Hardware inventory (2026-07-22).** Session-local read of the target
  machine's model, CPU, RAM, GPUs, and attached eGPU; identifying
  values not committed.
- **research: t2linux wiki.** wiki.t2linux.org — supported distros,
  device support state (WiFi/BT firmware paths, apple-bce dependency,
  suspend broken on current firmware, Thunderbolt notes), Ubuntu install
  guide including the macOS-less firmware retrieval path.
- **research: t2linux/T2-Ubuntu releases.** Active release stream
  (v7.0.9-1, 2026-05-21) of Ubuntu ISOs with the T2 patchset.
- **research: dropbear-initramfs remote LUKS unlock.** Multiple current
  guides confirming the pattern on Ubuntu 24.04+ (dropbear-initramfs,
  authorized keys under /etc/dropbear/initramfs/).
- **research: 2026 overlay-VPN landscape review.** Comparison of
  Tailscale (free personal tier: 6 users, no device cap; public
  security-bulletin record), Headscale (production-stable, but a
  self-hosted long-running control plane), NetBird, ZeroTier, and plain
  WireGuard; basis for D-8.
- **security-posture doctrine.** planwright's artifact data-hygiene
  rule, applied here as REQ-F1.1 because the repo is public.
- **Drafting-session decisions (2026-07-22).** Full wipe over dual-boot;
  selective backup to the LAN network drive; server-ready-no-services
  scope; eGPU displays-and-compute from day one; hybrid remote access.
