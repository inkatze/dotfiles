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

- Selective backup of valuable local state — secrets vaulted into
  1Password, non-secret data to the LAN-attached network drive —
  verified before any destructive step.
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
  LUKS unlock, headless-boot verification, retiring the router's
  legacy WAN-exposed port-forward.

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

- **REQ-A1.1** A selective backup of valuable local state SHALL be
  completed and verified before any destructive step runs, split by
  class: secret-class material (SSH private keys, tokens, credential
  exports) vaulted into 1Password; sensitive-but-bulky data (browser
  profiles and credential-bearing application data) written to the
  network drive only inside an encrypted archive whose key lives in
  1Password; and plain non-secret data (unpushed git work, remaining
  application data, macOS-only exports) copied to the LAN-attached
  network drive. Verification SHALL include a size inventory checked
  against drive capacity before copying, a checksum manifest
  confirming every copied item readable, and 1Password access
  confirmed from a second device, so post-wipe retrieval does not
  depend on this machine.
  *(Cites: drafting-session decision (2026-07-22), D-2, kickoff §3
  REQ-A (2026-07-22), kickoff lens pass (2026-07-23).)*
- **REQ-A1.2** macOS and BridgeOS firmware SHALL be updated to the
  latest available versions before the wipe, so the machine carries the
  newest firmware it will ever get without macOS.
  *(Cites: D-2.)*
- **REQ-A1.3** A bootable installer USB built from the current
  t2linux-patched ISO SHALL be created and boot-verified on this machine
  before the wipe.
  *(Cites: D-1, D-2.)*
- **REQ-A1.4** T2 Startup Security SHALL be configured to permit
  booting the installer and the installed system — Secure Boot set to
  No Security and external-media boot allowed; Reduced Security still
  requires an Apple-signed OS and cannot boot the installed system —
  before the wipe, verified in a macOS Recovery session.
  *(Cites: D-2, research: t2linux wiki (Sources), kickoff lens pass
  (2026-07-23).)*
- **REQ-A1.5** The rollback path (reinstalling macOS via internet
  recovery) and the lighter mid-install recovery path (re-running the
  installer from USB after a partial failure) SHALL be documented in
  the runbook — `specs/linux-migration/runbook.md`, committed to this
  repo, REQ-F1.1 hygiene applied — before the wipe, so failure at any
  point has a known exit.
  *(Cites: D-2, kickoff §2 (2026-07-22), kickoff lens pass
  (2026-07-23).)*

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
  both at the console and remotely over SSH during early boot. The
  remote unlock SHALL use a dedicated key pair (distinct from
  day-to-day SSH keys) and the dropbear host-key fingerprint SHALL be
  pinned on unlock clients before a passphrase is ever typed into a
  remote session.
  *(Cites: D-3, drafting-session decision (2026-07-22), kickoff lens
  pass (2026-07-23).)*
- **REQ-B1.8** The kernel/firmware update path SHALL be set up and
  documented so routine updates do not break boot (t2linux kernel-update
  mechanism installed and understood).
  *(Cites: D-1, research: t2linux wiki (Sources).)*
- **REQ-B1.9** At least one external display driven through the
  built-in Thunderbolt ports (dGPU, Radeon Pro 560X) SHALL work.
  *(Cites: kickoff §3 REQ-B (2026-07-22).)*

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

- **REQ-E1.1** OpenSSH SHALL be enabled with key-based authentication
  only: password authentication and root login disabled in the
  effective sshd configuration. The sshd configuration SHALL be owned
  by the repo's Ansible role (host-side hand edits are not a
  sanctioned writer).
  *(Cites: D-8, kickoff lens pass (2026-07-23).)*
- **REQ-E1.2** Remote access SHALL be hybrid: the home router's built-in
  VPN server as the into-the-LAN door (covers early-boot unlock and
  emergencies), plus a Tailscale mesh on the host for day-to-day access.
  The router VPN SHALL use a modern protocol (WireGuard- or
  IKEv2-class; PPTP or L2TP/PSK are not acceptable), and the identity
  account behind the Tailscale mesh SHALL have MFA enabled.
  *(Cites: D-8, research: 2026 overlay-VPN landscape review (Sources),
  kickoff lens pass (2026-07-23).)*
- **REQ-E1.3** The machine SHALL boot headless (no display or keyboard
  attached) to a state reachable over SSH, including the remote LUKS
  unlock path over wired ethernet.
  *(Cites: D-3, D-6, D-9.)*
- **REQ-E1.4** The machine SHALL power back on automatically after
  power loss. Verification SHALL account for the internal battery
  (wall-power loss is bridged by the battery, not a shutdown): the
  recovery behavior is exercised from a genuine power-off state with
  wall power then restored.
  *(Cites: D-7, kickoff lens pass (2026-07-23).)*
- **REQ-E1.5** The router's legacy WAN-exposed remote-access
  port-forward SHALL be disabled at wipe time (so the fresh install is
  never internet-reachable before hardening is verified) and its
  permanent retirement confirmed once the hybrid remote-access path is
  verified.
  *(Cites: D-8, kickoff lens pass (2026-07-23).)*
- **REQ-E1.6** A minimal host-health signal SHALL exist for the
  service-free window: a periodic reachability and disk-space check run
  from another machine (e.g. over SSH) or an external uptime monitor —
  nothing new long-running is deployed on the host itself, preserving
  the no-services scope, and the check SHALL NOT introduce new WAN
  exposure (it observes through the existing access paths). A
  monitoring SSH credential SHALL be least-privilege: a dedicated key
  restricted to a forced command, no interactive shell. Full
  monitoring belongs to future service specs.
  *(Cites: kickoff §7 (2026-07-23), kickoff lens pass (2026-07-23).)*

## REQ-F — Public-spec hygiene

- **REQ-F1.1** The committed bundle SHALL contain no serial numbers,
  LAN IPs, hostnames, credentials, router or drive product identifiers
  beyond what hardware support requires, or other sensitive operational
  detail; machine-specific values live in machine-local, untracked
  files.
  *(Cites: drafting-session decision (2026-07-22), security-posture
  doctrine (Sources).)*
- **REQ-F1.2** Every secret this migration needs (SSH private keys,
  dropbear key material, VPN credentials, Tailscale auth, LUKS
  passphrase records) SHALL live in 1Password — never in this repo and
  never as plain files on the network drive — and execution steps that
  need one SHALL retrieve it from 1Password at use time. Host-side
  operational key material that must exist as files by mechanism (the
  dropbear initramfs host key, the host's sshd host keys) is exempt
  from the vault-only rule; its integrity is covered by the REQ-B1.7
  fingerprint pinning.
  *(Cites: kickoff §3 REQ-F (2026-07-22), security-posture doctrine
  (Sources), kickoff lens pass (2026-07-23).)*

## Changelog

- 2026-07-22 — Initial draft authored via `/spec-draft` (goal, scope,
  REQ groups A–F, D-1 through D-9, tasks 1–10, test-spec coverage).
- 2026-07-22 — Kickoff walkthrough edits: runbook pinned to the repo
  (REQ-A1.5); 1Password named the secrets vault of record (REQ-A1.1
  reworded, REQ-F1.2 added, Task 1 cargo split, Task 4 gains the op
  CLI, design cross-cutting note updated); dGPU external display made
  a requirement (REQ-B1.9 added, homed in Task 6).
- 2026-07-23 — Kickoff gap check (decision-domains, observability):
  REQ-E1.6 minted (minimal off-host host-health signal for the
  service-free window), homed in Task 10. (For completeness: the two
  2026-07-22 entries' edit sets also touched test-spec.md — the
  REQ-A1.1 entry update and the new REQ-B1.9/REQ-F1.2 entries.)
- 2026-07-23 — Kickoff sign-off lens pass (41 dispositioned findings,
  all applied): REQ-A1.1 (encrypted archive class, sizing, checksum
  manifest), REQ-A1.4 (No Security correction, Recovery-session
  verification), REQ-A1.5 (runbook path pinned, mid-install recovery),
  REQ-B1.7 (dedicated unlock key, fingerprint pinning), REQ-E1.1
  (hardening enumerated, role-owned sshd), REQ-E1.2 (protocol floor,
  MFA), REQ-E1.4 (battery-aware verification), REQ-E1.5 (disable at
  wipe, neutral wording), REQ-E1.6 (least-privilege, no new WAN
  exposure), REQ-F1.2 (host-key-material exemption); scope bullet
  aligned; tasks 1–10 done-when/deliverable tightening incl. Task 4
  baseline capture + doc enumeration + secret-scanner hook, Task 10
  dependency on Task 9, fan daemon and thermal soak added; test-spec
  entries reconciled to the tightened REQs; design cross-cutting
  notes updated (observability/concurrency domains, secrets wording,
  D-2/D-8 amendment annotations).

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
