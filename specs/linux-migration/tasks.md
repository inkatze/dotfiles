# Linux Migration — Tasks

**Status:** Draft
**Last reviewed:** 2026-07-22
**Format-version:** 2
**Execution:** derived — see the status render

Tasks 1–4 run before the wipe (Task 4 is repo work an agent can execute
immediately; 1–3 are guided manual work on the machine). Task 5 is the
human-directed irreversible step. Tasks 6–10 bring the new system up to
the spec's requirements.

## Tasks

### Task 1 — Selective backup to the network drive

- **Deliverables:** An inventory of valuable local state (unpushed git
  work, SSH material not vaulted, application data, browser profiles,
  macOS-only exports) copied to the LAN-attached network drive; a
  spot-check restore of representative files. The inventory itself lives
  with the backup, not in this repo.
- **Done when:** Every inventoried item exists on the network drive and
  a spot-check restore of at least one item per category succeeds.
- **Dependencies:** none
- **Citations:** D-2 · REQ-A1.1, REQ-F1.1
- **Estimated effort:** half day

### Task 2 — Pre-wipe machine prep

- **Deliverables:** macOS and BridgeOS firmware updated to latest;
  `pmset autorestart 1` set; Startup Security Utility set to reduced
  security with external-media boot allowed.
- **Done when:** Software Update reports nothing pending, `pmset -g`
  shows autorestart enabled, and Startup Security shows the relaxed
  settings.
- **Dependencies:** none
- **Citations:** D-2, D-7 · REQ-A1.2, REQ-A1.4, REQ-E1.4
- **Estimated effort:** half day

### Task 3 — T2-Ubuntu installer USB

- **Deliverables:** A USB stick written with the latest t2linux
  T2-Ubuntu ISO (release chosen from the project's release page at
  execution time), boot-tested on this machine into a live session; the
  rollback path (internet-recovery macOS reinstall) written into the
  runbook.
- **Done when:** The machine boots the USB to a usable live session and
  the runbook contains the rollback section.
- **Dependencies:** 2
- **Citations:** D-1, D-2 · REQ-A1.3, REQ-A1.5, REQ-B1.1
- **Estimated effort:** half day

### Task 4 — Ansible Linux platform split (repo work)

- **Deliverables:** A new linux role (fish, mise, tmux, core CLI, SSH
  server config, Tailscale package) alongside the existing macOS role;
  `os_family` guards in playbook wiring; an inventory entry for the
  migrated host; docs touched where the repo describes its host model.
- **Done when:** `ansible-playbook --syntax-check`, yamllint, and
  ansible-lint pass; a macOS-host playbook run (or its CI equivalent)
  shows no behavior change; lefthook and CI are green.
- **Dependencies:** none
- **Citations:** D-5 · REQ-D1.1, REQ-D1.2, REQ-D1.4
- **Estimated effort:** 2 days

### Task 5 — Wipe and install Ubuntu with LUKS

- **Deliverables:** macOS erased; Ubuntu installed to the whole internal
  SSD with LUKS full-disk encryption (manual partitioning preserving the
  EFI partition); first boot into the installed system with console
  unlock. Human-directed throughout: the agent prepares and verifies,
  the human executes the destructive steps.
- **Done when:** The machine boots the installed system from the
  internal disk and the LUKS volume unlocks at the console.
- **Dependencies:** 1, 2, 3
- **Citations:** D-2, D-3 · REQ-B1.2, REQ-B1.7
- **Estimated effort:** half day

### Task 6 — T2 hardware bring-up

- **Deliverables:** WiFi/BT firmware retrieved via the t2linux
  macOS-less path; audio configured; keyboard, trackpad, internal
  display and brightness verified; the t2linux kernel-update mechanism
  installed and its use documented; full system update applied; suspend
  disabled.
- **Done when:** REQ-B1.3 through B1.6 all verify by direct use, the
  documented kernel-update path has run at least once, and suspend is
  confirmed off.
- **Dependencies:** 5
- **Citations:** D-1, D-6 · REQ-B1.1, REQ-B1.3, REQ-B1.4, REQ-B1.5,
  REQ-B1.6, REQ-B1.8
- **Estimated effort:** 1 day

### Task 7 — Dotfiles stabilization loop

- **Deliverables:** The repo's playbook run against the Linux host, with
  every first-run failure fixed (repo-side or host-side) and each fix
  committed; iterate until converged.
- **Done when:** Two consecutive playbook runs complete with zero
  failures and no unexpected changes.
- **Dependencies:** 4, 6
- **Citations:** D-5 · REQ-D1.1, REQ-D1.2, REQ-D1.3, REQ-D1.4
- **Estimated effort:** 2 days

### Task 8 — Remote LUKS unlock via dropbear

- **Deliverables:** dropbear-initramfs installed and configured with the
  operator's key; the wired ethernet adapter confirmed usable from the
  initramfs; unlock exercised over the LAN from another machine.
- **Done when:** A reboot is unlocked via SSH from another machine over
  wired ethernet, and console unlock still works as fallback.
- **Dependencies:** 6
- **Citations:** D-3, D-9 · REQ-B1.7, REQ-E1.3
- **Estimated effort:** half day

### Task 9 — eGPU bring-up

- **Deliverables:** Thunderbolt authorization for the enclosure; the
  RX 580 driving an external display; a Vulkan compute workload run on
  the eGPU; the attach/detach procedure (including any required kernel
  parameters and known limitations) documented in the repo.
- **Done when:** External display output and a completed Vulkan compute
  run are both demonstrated, and the procedure doc is committed.
- **Dependencies:** 6
- **Citations:** D-4 · REQ-C1.1, REQ-C1.2, REQ-C1.3
- **Estimated effort:** 1 day

### Task 10 — Server readiness

- **Deliverables:** SSH key-auth hardened; Tailscale up with the host
  reachable off-LAN; the home router's VPN server configured as the
  into-the-LAN door and verified to reach dropbear during early boot;
  the WAN-exposed SSH port-forward retired; a headless boot test (no
  display or keyboard) passing; auto power-on after power loss
  verified, with a Linux-native fallback researched if the pre-wipe
  setting did not survive.
- **Done when:** Every REQ-E requirement verifies: headless reboot is
  remotely unlockable and reachable over both access paths, the old
  port-forward is gone, and a power-cut test brings the machine back
  unattended.
- **Dependencies:** 7, 8
- **Citations:** D-3, D-6, D-7, D-8, D-9 · REQ-E1.1, REQ-E1.2,
  REQ-E1.3, REQ-E1.4, REQ-E1.5
- **Estimated effort:** 1 day

## Awaiting input

(none yet)

## Deferred

(none yet)

## Out of scope

- Deploying long-running services (media stack rebuild, containers,
  schedulers): future specs own these; this spec ends at server-ready.
- Changes to the other Ansible-managed macOS hosts beyond the
  no-behavior-change guarantee of the platform split.
- Setting up the future Mac Studio as the replacement personal machine.
- Self-hosting an overlay-VPN control plane (Headscale-class): revisit
  in a future server spec if third-party coordination becomes
  unacceptable; the Tailscale-compatible client protocol keeps the exit
  open (D-8).
