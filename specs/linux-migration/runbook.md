# Linux Migration — Runbook

Operational runbook for migrating the personal machine (MacBook Pro
15,1, 2018, T2) from macOS to Linux and running it as an always-on home
server. This is a single living artifact: each task in
`specs/linux-migration/tasks.md` contributes its own section as it
executes. Task 3 creates it with the install reference plus the two
recovery paths; later tasks append their sections (marked _To be
completed_ below).

**Hygiene (REQ-F1.1):** this file is committed to the repo. It must
never contain machine serials, MAC addresses, LAN IPs, real hostnames,
SSH host-key fingerprints, or any secret. Refer to hosts and the network
drive by role, not identity.

## Install reference (Task 3)

The parameters this migration was executed against, recorded at
installer-USB creation time.

| Item | Value |
|---|---|
| Target hardware | MacBook Pro 15,1 (2018, T2 chip, 6-core i9, 32 GB RAM) |
| Distribution | Ubuntu 26.04 LTS "Resolute Raccoon" (T2 remix) |
| t2linux release | `v7.0.9-1` (published 2026-05-21) |
| ISO | `ubuntu-26.04-7.0.9-t2-resolute.iso` (~5.9 GB, assembled from 4 parts) |
| ISO SHA-256 | `d8d3773a486d83b0e5f0d125645cfd4b4063a74c23695a1391a9d4bec47133a9` |
| Downloader | t2linux `iso.sh` from the release (pinned to `v7.0.9-1`; concatenates the `.iso.00`–`.iso.03` parts and self-verifies the digest) |
| BridgeOS/firmware at prep | `23P5067` (confirmed unchanged at Task 5 — see "Final pre-wipe firmware version") |

**Why this release (REQ-B1.1):** at execution time `v7.0.9-1` was the
newest t2linux Ubuntu release with no blocking issue noted for this
machine model, and its checksum matched the published digest. 26.04 LTS
was chosen over 24.04 LTS for its newer kernel (better T2 and AMD
Polaris support, relevant to the eGPU in Task 9).

### Writing the installer drive

macOS has only USB-C/Thunderbolt ports (no USB-A, no SD), so the
installer medium is a USB-C stick or external SSD. After
`iso.sh` reports "ISO saved to Downloads" (checksum verified):

```sh
diskutil list                                   # identify the target disk — verify by size/name
diskutil unmountDisk /dev/diskN
sudo dd if=<absolute-path>/ubuntu-26.04-7.0.9-t2-resolute.iso of=/dev/rdiskN bs=1m
diskutil eject /dev/diskN
```

- Use the raw device `/dev/rdiskN` (faster). macOS `dd` is silent; press
  Ctrl-T for progress.
- macOS may pop "disk not readable" after writing — that is expected
  (macOS cannot read the Linux filesystem). Choose **Ignore**, never
  Initialize.
- In `fish`, `~` does not expand after `if=`; use an absolute path for
  the ISO.
- On success, `dd` reports the bytes transferred; confirm the count
  equals the ISO's byte size.

### Booting the installer

Prerequisite (REQ-A1.4): Startup Security Utility, set in a macOS
Recovery session, must show **Secure Boot: No Security** and **external
media boot allowed**. Reduced Security is insufficient — it still
requires an Apple-signed OS.

1. Power on holding **⌥ Option** (the Startup Manager).
2. Select **EFI Boot** and press Return.
3. You land in the GRUB menu, then the live session.

**Verified (REQ-A1.3):** the machine boots this USB into a live session,
and the USB-C ethernet adapter passes traffic there (confirmed by
reaching the internet from the live session).

**WiFi caveat:** WiFi does not work in the live session until the
Broadcom firmware is restored (see Task 6 offline fallback). A **wired
USB-C ethernet adapter is required** during install — it is the only
network path in the live session.

## Rollback path — internet-recovery macOS reinstall (REQ-A1.5)

The road back if the migration must be abandoned. **This is destructive
to any Linux install** — it repartitions the internal SSD back to macOS.
It is the *only* rollback: the wipe (Task 5) removes the local macOS
recovery partition, so recovery must come from Apple over the network.

**Residual risk, accepted at sign-off:** this path is not exercised by
this spec. Its mitigation is keeping firmware maximally current before
the wipe (REQ-A1.2) so internet recovery has the best chance of
succeeding.

### Procedure

1. Ensure a working **network connection**. Internet Recovery downloads
   the macOS installer from Apple, so the network is mandatory. The T2's
   recovery environment has its own WiFi stack (it can join a WiFi
   network without an installed OS); wired ethernet also works. Expect a
   multi-GB download.
2. Power on and immediately hold one of:
   - **⌥⌘R** (Option-Command-R) — Internet Recovery, installs the
     **latest** macOS compatible with this Mac. **Preferred** after a
     wipe, since local recovery is gone.
   - **⇧⌥⌘R** (Shift-Option-Command-R) — Internet Recovery, the macOS the
     Mac originally shipped with (or nearest still offered).
   - **⌘R** (Command-R) — reinstalls the last-installed macOS from the
     local recovery partition; after the wipe this no longer exists and
     the Mac falls through to Internet Recovery.
   Hold until a spinning globe (Internet Recovery) appears, then join a
   network if prompted.
3. In macOS Recovery → **Disk Utility**, erase the internal SSD (APFS,
   GUID partition map). This removes the Linux install and LUKS volume.
4. Quit Disk Utility → **Reinstall macOS** and follow the installer.
5. After macOS is back, re-tighten **Startup Security** (Full Security)
   and re-enable FileVault as desired; the No-Security posture set for
   the Linux boot is no longer needed.

## Mid-install recovery (REQ-A1.5)

The lighter recovery: the Ubuntu install failed partway (installer
crash, power loss, aborted partitioning) but macOS is already gone, so
you are recovering *forward* into Linux rather than rolling back.

### Procedure

1. Re-attach the installer USB. Power on holding **⌥ Option** → **EFI
   Boot** → live session (same as the install boot).
2. Re-run the Ubuntu installer from the live session. Redo the manual
   partitioning: whole-disk Linux with LUKS, **preserving the EFI
   partition** (Task 5's requirement).
3. If the internal disk is in a half-partitioned state, use the live
   session's `gparted` / `cryptsetup` to clear stale partitions and any
   orphaned LUKS header before re-running the installer.

### Known boot caveat — GRUB vs the Mac Startup Manager

The t2linux wiki notes that **Ubuntu's GRUB does not boot via the Mac
Startup Manager (⌥ Option picker) for many users** after install. If the
installed system will not boot that way:

- Boot the live USB again and install/configure **rEFInd Boot Manager**
  as the boot manager, or
- From the ⌥ Option picker, select **EFI Boot** rather than any macOS-
  style entry.

Record which boot path actually works for this machine in the Task 6
hardware bring-up section once the system is installed.

---

## Sections added by later tasks

These are part of this same runbook; each is written by its owning task
as it executes. Listed here so the structure is known up front.

### Final pre-wipe firmware version (Task 5)

The firmware version was not re-read from macOS immediately before
erasing. It is recoverable anyway: the T2/EFI firmware is not touched by
the OS install, so DMI on the installed Linux system reports the same
firmware that was running at wipe time.

| Item | Value |
|---|---|
| EFI/BootROM version | `2103.100.6.0.0` |
| BridgeOS (iBridge) firmware | `23.16.15067.0.0,0` |
| Firmware date | 2026-04-18 |
| Machine | `MacBookPro15,1` (board `Mac-937A206F2EE63C01`) |
| Read from | `/sys/class/dmi/id/bios_version`, installed system |

This is the same firmware recorded as `23P5067` at Task 2 prep —
`23P5067` is the BridgeOS build ID for iBridge `23.16.15067.0.0`. The
two records agreeing is positive evidence that no firmware-bearing
update landed between prep and the wipe.

#### Pre-wipe re-checks — disposition

Two of the Task 5 pre-wipe re-checks were not recorded at the time and
cannot be reconstructed now that macOS is erased. They are logged here
as unrecovered rather than left implicitly satisfied:

- **Software Update re-check (nothing pending):** not recorded;
  unrecoverable. The firmware agreement above is indirect evidence that
  no firmware-bearing update was applied in the window.
- **Backup delta-sweep since Task 1:** not recorded; unrecoverable from
  this host. Any state created on macOS between Task 1 and the wipe that
  was not in the Task 1 backup is gone.
- **Router legacy WAN port-forward disabled:** not recorded at wipe
  time. Task 10 independently requires an external scan showing the old
  port closed; that scan is the verification of record for REQ-E1.5, so
  this item is deferred to Task 10 rather than reconstructed.

#### Install verification (Done-when, verified post-install)

| Criterion | Evidence |
|---|---|
| Boots the installed system from the internal disk | Root on `nvme0n1p3` → LUKS `dm_crypt-0` → LVM `ubuntu--vg-ubuntu--lv` (ext4) |
| LUKS volume unlocks at the console | `/etc/crypttab` maps `dm_crypt-0` to the root LUKS partition with `none luks` (passphrase prompted at console; the volume UUID is deliberately not recorded here) |
| Linux plus preserved EFI, no macOS volumes | `nvme0n1p1` vfat *EFI System* (1G, preserved) · `p2` ext4 `/boot` · `p3` `crypto_LUKS`; no Apple APFS/HFS+ partitions present |

### T2 hardware bring-up: kernel-update mechanism + recovery (Task 6)
_To be completed by Task 6._ The kernel-update mechanism and its recovery
path (previous-kernel boot entry, USB rescue), plus which boot path
(GRUB vs rEFInd) works on this machine.

### Day-2 remote LUKS unlock routine (Task 8)
_To be completed by Task 8._ The router-VPN-in → dropbear SSH against the
pinned host-key fingerprint → `cryptroot-unlock` → console-fallback
routine. (Fingerprints are pinned on clients, not committed here.)

### eGPU attach/detach procedure (Task 9)
_To be completed by Task 9._ Thunderbolt authorization, hotplug vs
boot-attached posture, required kernel parameters, and known Polaris
limitations.

### Server readiness: access paths + health signal (Task 10)
_To be completed by Task 10._ The off-LAN access paths (router VPN,
Tailscale), power-loss-recovery behavior, and the off-host health signal
home (which machine runs it, restricted-key setup).
