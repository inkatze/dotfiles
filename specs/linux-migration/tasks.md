# Linux Migration — Tasks

**Status:** Draft
**Last reviewed:** 2026-07-22
**Format-version:** 2
**Execution:** derived — see the status render

Tasks 1–4 run before the wipe (Task 4 is repo work an agent can execute
immediately; 1–3 are guided manual work on the machine). Task 5 is the
human-directed irreversible step. Tasks 6–10 bring the new system up to
the spec's requirements. Post-wipe tasks share one physical machine:
reboot-bearing work (Tasks 6, 8, 9) and playbook runs (Task 7) execute
serially in practice even where the graph permits parallelism, and
Task 10's final verification runs last (it depends on 7, 8, and 9).

## Tasks

### Task 1 — Selective backup (1Password + network drive)

- **Deliverables:** A sized inventory of valuable local state, split by
  class: secret-class material (SSH private keys, tokens, credential
  exports) vaulted into 1Password; sensitive-but-bulky data (browser
  profiles, credential-bearing application data) in an encrypted
  archive on the LAN-attached network drive with the key in 1Password;
  plain non-secret data (unpushed git work, application data,
  macOS-only exports) copied to the network drive with a checksum
  manifest; a spot-check restore of representative files; 1Password
  access confirmed from a second device. The inventory itself lives
  with the backup, not in this repo.
- **Done when:** The size inventory fits confirmed drive capacity,
  every inventoried item exists in its class home, the checksum
  manifest verifies clean, a spot-check restore of at least one item
  per inventory category succeeds (categories are the inventory's
  finer groupings, not the three storage classes), and 1Password opens
  from a second device.
- **Dependencies:** none
- **Citations:** D-2 · REQ-A1.1, REQ-F1.1, REQ-F1.2
- **Estimated effort:** half day

### Task 2 — Pre-wipe machine prep

- **Deliverables:** macOS and BridgeOS firmware updated to latest;
  `pmset autorestart 1` set; Startup Security set to No Security with
  external-media boot allowed, verified in the macOS Recovery session;
  WiFi/BT firmware exported from macOS to the network drive via the
  t2linux firmware script, as an offline fallback for Task 6.
- **Done when:** Software Update reports nothing pending, `pmset -g`
  shows autorestart enabled, Startup Security shows No Security with
  external-media boot allowed, and the exported firmware bundle exists
  on the network drive.
- **Dependencies:** none
- **Citations:** D-2, D-7 · REQ-A1.2, REQ-A1.4, REQ-E1.4
- **Estimated effort:** half day

### Task 3 — T2-Ubuntu installer USB

- **Deliverables:** A USB stick written with the latest t2linux
  T2-Ubuntu ISO (release chosen from the project's release page at
  execution time, checksum verified against the release's published
  digest), boot-tested on this machine into a live session in which
  the USB-C ethernet adapter is confirmed working under Linux; the
  runbook created at `specs/linux-migration/runbook.md` with the
  rollback path (internet-recovery macOS reinstall) and the
  mid-install recovery section (installer re-run from USB after a
  partial failure).
- **Done when:** The ISO checksum matches the published digest, the
  machine boots the USB to a usable live session, the ethernet adapter
  passes traffic in that session, and the runbook contains the
  rollback and mid-install recovery sections.
- **Dependencies:** 2
- **Citations:** D-1, D-2, D-9 · REQ-A1.3, REQ-A1.5, REQ-B1.1
- **Estimated effort:** half day

### Task 4 — Ansible Linux platform split (repo work)

- **Deliverables:** A baseline playbook run captured against a macOS
  host before any split work lands (the REQ-D1.2 comparison basis); a
  new linux role (fish, mise, tmux, core CLI, SSH server config,
  Tailscale package, 1Password CLI (`op`)) alongside the existing
  macOS role; `os_family` guards in playbook wiring; an inventory
  entry for the migrated host using machine-local indirection (no LAN
  IP or real hostname committed; the hostname convention feeding fish
  guards and tmux session naming decided and noted); a secret/IP
  scanner (e.g. gitleaks) added to lefthook as a pre-commit backstop
  for REQ-F1.1; repo docs updated where they describe the host model:
  CLAUDE.md (Ansible role layout), README.md (Linux-host bootstrap
  entry point), specs/README.md (spec-table row and a
  tasks.md-format-v2 note), and the cross-host Ollama topology
  section.
- **Done when:** `ansible-playbook --syntax-check`, yamllint, and
  ansible-lint pass; the baseline capture exists; a macOS-host
  playbook run after the split shows no unexpected changed or failed
  tasks against the baseline; the enumerated docs are updated; and
  lefthook (including the new scanner) and CI are green.
- **Dependencies:** none
- **Citations:** D-5 · REQ-D1.1, REQ-D1.2, REQ-D1.4, REQ-F1.1,
  REQ-F1.2
- **Estimated effort:** 2 days

### Task 5 — Wipe and install Ubuntu with LUKS

- **Deliverables:** Immediately before erasing: Software Update
  re-checked (nothing pending), the final BridgeOS/firmware version
  recorded in the runbook (version string only), a backup delta-sweep
  covering state created since Task 1 completed, and the router's
  legacy WAN port-forward disabled. Then: macOS erased; Ubuntu
  installed to the whole internal SSD with LUKS full-disk encryption
  (manual partitioning preserving the EFI partition); first boot into
  the installed system with console unlock. Human-directed throughout:
  the agent prepares and verifies, the human executes the destructive
  steps.
- **Done when:** The pre-wipe re-checks are recorded in the runbook,
  the machine boots the installed system from the internal disk, the
  LUKS volume unlocks at the console, and the partition table shows
  Linux plus the preserved EFI partition and no macOS volumes.
- **Dependencies:** 1, 2, 3
- **Citations:** D-2, D-3 · REQ-A1.1, REQ-A1.2, REQ-B1.2, REQ-B1.7,
  REQ-E1.5
- **Estimated effort:** half day

### Task 6 — T2 hardware bring-up

- **Deliverables:** WiFi/BT firmware retrieved via the t2linux
  macOS-less path (falling back to the Task 2 offline export if online
  retrieval fails); audio configured; keyboard, trackpad, internal
  display and brightness verified; an external display verified on a
  built-in Thunderbolt port (dGPU); the t2linux fan-control daemon
  (t2fanrd or equivalent) installed with fans observed responding to
  load; the t2linux kernel-update mechanism installed and its use plus
  recovery path (previous-kernel boot entry, USB rescue) documented in
  the runbook; full system update applied; suspend disabled.
- **Done when:** REQ-B1.3 through B1.6 and B1.9 all verify by direct
  use, the package manager reports a fully updated system, the
  kernel-update mechanism has been exercised (a real update when one
  is available, otherwise a verified no-op run with the distinction
  recorded in the runbook) followed by a successful reboot, fan
  response under load is observed, and suspend is confirmed off.
- **Dependencies:** 5
- **Citations:** D-1, D-6 · REQ-B1.1, REQ-B1.3, REQ-B1.4, REQ-B1.5,
  REQ-B1.6, REQ-B1.8, REQ-B1.9
- **Estimated effort:** 1 day

### Task 7 — Dotfiles stabilization loop

- **Deliverables:** The repo's playbook run against the Linux host,
  with every first-run failure fixed (repo-side or host-side) and each
  fix committed; apt daily/unattended-upgrade timers accounted for so
  dpkg-lock contention cannot produce spurious failures; iterate until
  converged.
- **Done when:** Two consecutive playbook runs complete with zero
  failed tasks and the second run reports zero changed tasks
  (changed=0 is the convergence criterion; an always-changed task is
  fixed or made idempotent rather than waved through).
- **Dependencies:** 4, 6
- **Citations:** D-5 · REQ-D1.1, REQ-D1.2, REQ-D1.3, REQ-D1.4
- **Estimated effort:** 2 days

### Task 8 — Remote LUKS unlock via dropbear

- **Deliverables:** dropbear-initramfs installed and configured with a
  dedicated unlock key pair (distinct from day-to-day SSH keys,
  private half in 1Password); the dropbear host-key fingerprint
  recorded in the runbook and pinned on unlock clients; the wired
  gigabit-class ethernet adapter confirmed usable from the initramfs;
  unlock exercised over the LAN from another machine; the unlock path
  re-verified after an initramfs regeneration (kernel update or
  update-initramfs run); the day-2 remote-unlock routine (router VPN
  in, dropbear SSH against the pinned fingerprint, cryptroot-unlock,
  console fallback) documented in the runbook.
- **Done when:** A reboot is unlocked via SSH from another machine
  over wired ethernet against the pinned fingerprint, the unlock still
  works after an initramfs regeneration, console unlock still works as
  fallback, and the runbook carries the day-2 unlock routine.
- **Dependencies:** 6
- **Citations:** D-3, D-9 · REQ-B1.7, REQ-E1.3, REQ-F1.2
- **Estimated effort:** half day

### Task 9 — eGPU bring-up

- **Deliverables:** Thunderbolt authorization for the enclosure; the
  RX 580 driving an external display; the negotiated PCIe/Thunderbolt
  link checked for sanity (link status recorded in the runbook); a
  Vulkan compute workload chosen for Polaris capability (no
  FP16-dependent backend) run to completion with device attribution to
  the eGPU confirmed in the tool's own output; the attach/detach
  procedure (hotplug vs boot-attached posture chosen by verification,
  any required kernel parameters, known limitations) documented in the
  runbook.
- **Done when:** External display output and a completed,
  eGPU-attributed Vulkan compute run are both demonstrated, and the
  procedure section is committed to the runbook.
- **Dependencies:** 6
- **Citations:** D-4 · REQ-C1.1, REQ-C1.2, REQ-C1.3
- **Estimated effort:** 1 day

### Task 10 — Server readiness

- **Deliverables:** SSH hardening applied through the repo role
  (key-only, password authentication and root login disabled);
  Tailscale up with the host reachable from off-LAN; the home router's
  VPN server (modern protocol per REQ-E1.2) configured and verified
  from off-LAN to reach dropbear during early boot; the legacy WAN
  port-forward (disabled at Task 5) confirmed permanently retired; a
  headless boot test (no display or keyboard) passing; power-loss
  recovery exercised from a genuine power-off state (battery-aware:
  full drain or equivalent hard-off, then wall power restored), with a
  Linux-native fallback researched if the pre-wipe setting did not
  survive; a bounded thermal soak (~30 minutes sustained load)
  recorded with no thermal shutdown; the minimal off-host health
  signal configured (its home — which machine or monitor runs it, and
  the restricted-key setup — documented in the runbook), detecting
  both induced conditions.
- **Done when:** Every REQ-E requirement verifies, from off-LAN where
  the requirement implies remote access: a headless reboot is remotely
  unlockable over the router-VPN path to dropbear, the running system
  is reachable over both access paths from off-LAN, an external scan
  shows the old port closed, power-loss recovery from a genuine
  power-off is demonstrated, the soak completes without thermal
  shutdown, and the health signal both reports healthy and detects an
  induced outage and an induced disk-threshold breach.
- **Dependencies:** 7, 8, 9
- **Citations:** D-3, D-6, D-7, D-8, D-9 · REQ-E1.1, REQ-E1.2,
  REQ-E1.3, REQ-E1.4, REQ-E1.5, REQ-E1.6
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
