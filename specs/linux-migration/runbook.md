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
_Task 6 is still open._ The kernel-update mechanism and its recovery path
(previous-kernel boot entry, USB rescue), plus which boot path (GRUB vs
rEFInd) works on this machine, are still to be written here. The two
subsections below are measured results recorded as they were produced, so
the numbers are not reconstructed later from memory.

#### WiFi firmware — the offline fallback was the path that worked

The macOS-less retrieval was not needed. The Task 2 export
(`firmware.tar`, 11.7 MB, 2026-07-23) was recovered from the LAN network
drive — a USB disk attached to the router and shared over SMB, browsable
as guest — and installed directly.

- The archive holds 163 files, of which 72 are the `brcmfmac4364b2-pcie.*`
  set this machine's BCM4364 (rev 03) needs; the rest are the `4377b3`
  set for Apple Silicon Macs. Nothing in it collided with the 118 files
  already in `/lib/firmware/brcm`.
- Firmware is selected at load time by Apple board codename via ACPI, not
  by anything derivable from DMI, so the whole set is installed and the
  driver picks. Install as **root-owned** (`install -o root -g root -m
  0644`); a plain `cp -a` under sudo preserves the *source* ownership and
  would leave kernel-loaded firmware writable by a normal user.
- Result: `wlp3s0` appears, `brcmfmac` binds with `brcmfmac_wcc`, and the
  interface scans and reports signal — presence alone is not the test.

If this ever has to be redone (a wiped `/lib/firmware`, a fresh install),
the export on the network drive is the fast path; the t2linux macOS-less
retrieval is the fallback to the fallback.

#### Fan control and the thermal baseline

`t2fanrd` (t2linux repo, 0.1.0-3) is the correct daemon. **Do not use
`mbpfan` or `macfanctld`**, which are also in the archive and look
plausible: both drive fans through `applesmc`, and on this machine
`applesmc` is loaded but exposes **no** hwmon fan inputs at all. They
would install, start, and silently control nothing — the worst failure
mode for a fan daemon on an always-on host.

T2 fans are not under `/sys/class/hwmon`. They live on the ACPI device:

    /sys/devices/.../APP0001:00/fan{1,2}_{input,min,max,manual,output,safe}

Measured envelope: fan1 min 2160 / max 5927 RPM, fan2 min 2000 / max 5489.

Load response, all 12 threads busy (baseline → sustained → release):

| Point | fan1 | fan2 | Package temp |
|---|---|---|---|
| idle | 2702 | 2474 | 57 °C |
| +15 s | 5927 | 5545 | 91 °C |
| 30–90 s | ~5930 | ~5480 | **100 °C** |
| +20 s after release | 5497 | 5094 | 71 °C |

Fans reach their maximum within 15 seconds and back off after release, so
fan control demonstrably works.

**The thermal ceiling is the finding worth carrying forward.** `temp1_max`
and `temp1_crit` are both 100 °C, and the package sat pinned at exactly
that for 75 seconds *with fans already maxed*, logging 4891 package
throttle events. This is the i9-8950HK in a 2018 15" chassis behaving as
designed — Intel throttles at Tjunction to protect the part — not a fault
and not a t2fanrd shortcoming. Nothing shut down.

Consequence for **Task 10's ~30-minute thermal soak**: expect it to run at
100 °C and throttling for its entire duration. That still satisfies the
requirement, which is no thermal *shutdown*, not no throttling — but the
soak should be scored against that expectation rather than treated as a
surprise. More broadly: this host suits I/O-bound and bursty work, and
will throttle hard under sustained all-core compute. Worth weighing when
choosing which services land here.

### Day-2 remote LUKS unlock routine (Task 8)
_To be completed by Task 8._ The router-VPN-in → dropbear SSH against the
pinned host-key fingerprint → `cryptroot-unlock` → console-fallback
routine. (Fingerprints are pinned on clients, not committed here.)

### eGPU attach/detach procedure (Task 9)

Everything below is measured on this host, recorded as produced.

#### Device inventory

Three GPUs. Bus addresses are **not** stable — they changed wholesale when
the Thunderbolt cable moved to a different port (the eGPU was `0000:0a:00.0`,
then `0000:80:00.0`), and `/sys/class/drm/cardN` numbering moved with them
(the eGPU was `card3`, then `card0`). Key everything to the PCI device ID:

| Device ID | Device | Drives |
|---|---|---|
| `1002:67df` | Ellesmere / Polaris10 — **RX 580 8 GB, in the Razer Core** | the external monitor, via the card's own DisplayPort |
| `1002:67ef` | Baffin / Polaris11 — internal Radeon Pro | the built-in laptop panel (`eDP-1`) |
| `8086:3e9b` | CoffeeLake-H UHD 630 — Intel iGPU | nothing attached |

**Vulkan device indices are not stable either**, for the same reason. Confirm
with `llama-bench --list-devices` before pinning anything to `Vulkan1`; the
name in the output is the reliable identifier, not the index.

#### Thunderbolt authorization and topology

    boltctl list

Both nodes `status: authorized`, `policy: auto`, `authflags: boot` — so
authorization survives reboots with no per-boot action. Stored since
2026-07-24.

One physical enclosure presents **two** Thunderbolt nodes (`Razer Core` and
`Razer Core #2`, at route depth 1 and 2). The depth-2 node is internal to the
enclosure; there is only one cable in the system, and the keyboard (USB) and
monitor (DisplayPort) are not Thunderbolt devices.

The two hops train at different rates, and this is the diagnostic:

| Hop | Rate |
|---|---|
| `N-1` — host → enclosure, **over the cable** | 20 Gb/s = 2 lanes × 10 Gb/s |
| `N-101` — internal to the enclosure | 40 Gb/s = 2 lanes × 20 Gb/s |

The internal PCB link runs at full TB3 rate while the cabled hop runs at
half. **Moving the cable to a Thunderbolt port on the other side of the
machine did not change this** (the domain went from 0 to 1 and every PCI bus
number changed, confirming a genuinely different controller; the lane rate did
not budge). That isolates the cable itself, not the port.

#### The half-rate cable does not matter, and this is why

It is tempting to buy a certified 40 Gb/s cable. **Do not — it would change
nothing.** The PCIe tunnel is the narrower constraint, by a wide margin.

Chain walk from the root port down to `1002:67df`:

| Device | current | max |
|---|---|---|
| root port | 8.0 GT/s ×4 | 8.0 GT/s ×4 |
| DSL6540 bridge | 8.0 GT/s ×4 | 8.0 GT/s ×4 |
| JHL7540 bridge | 2.5 GT/s ×4 | **2.5 GT/s** ×4 |
| DSL6540 bridge | 2.5 GT/s ×4 | **2.5 GT/s** ×4 |
| DSL6540 bridge | 2.5 GT/s ×4 | 8.0 GT/s ×4 |
| RX 580 | 2.5 GT/s ×4 | 8.0 GT/s ×16 |

Two tunnel bridges advertise Gen1 as their *maximum*, so nothing downstream
can exceed it. The driver agrees — `pp_dpm_pcie` on the eGPU offers no Gen3
level at all, where the internal dGPU has one and uses it:

    eGPU RX 580     0: 2.5GT/s, x8 *      internal dGPU   0: 2.5GT/s, x8
                    1: 2.5GT/s, x8                        1: 8.0GT/s, x16 *

The arithmetic that settles the cable question:

| Ceiling | Bandwidth |
|---|---|
| PCIe Gen1 ×4 (8b/10b → 250 MB/s per lane) | **~1.0 GB/s** |
| Thunderbolt at the current 20 Gb/s | ~2.5 GB/s |
| Thunderbolt with a 40 Gb/s cable | ~5.0 GB/s |

The Thunderbolt link is already 2.5× wider than the PCIe tunnel it carries.
Doubling it widens the part that was never full. The Gen1 cap is structural to
this TB3 PCIe tunnel, not a cabling fault, and no cable changes it.

Two earlier claims are corrected by the above, deliberately recorded rather
than quietly dropped: that the advertised Gen1 rate did not establish a real
bandwidth deficit (it does — the deficit is real, just not the cable's fault),
and that a 40 Gb/s cable was the cheap fix (it is not a fix at all).

#### Resizable BAR does not work here

`pci=realloc` is on the kernel command line to try to map the full 8 GB
aperture. It fails:

    amdgpu 0000:80:00.0: BAR 0 [mem size 0x200000000 64bit pref]: failed to assign
    amdgpu 0000:80:00.0: [drm] Detected VRAM RAM=8192M, BAR=256M

The card supports it — `resource0_resize` reads `0x3f00`, i.e. 256M through
8G — and the kernel attempts 8G and is refused for want of MMIO space below
the tunnel. It falls back to the legacy 256 MB window, the same size the
internal dGPU uses. These four `failed to assign` lines are the **only**
amdgpu or thunderbolt errors in the boot log.

This is a performance characteristic, not a fault: all 8192 MB of VRAM is
usable and Vulkan reports it. Host writes to VRAM are just paged through a
256 MB window. Combined with Gen1 ×4, it is why upload throughput is modest.

#### The compute run

Model kept deliberately **outside the repo**, in a regenerable location:

    mkdir -p ~/.cache/llama.cpp/models
    curl -L --output-dir ~/.cache/llama.cpp/models -O \
      https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q8_0.gguf

    llama-bench -m ~/.cache/llama.cpp/models/qwen2.5-0.5b-instruct-q8_0.gguf \
      -dev Vulkan1 -ngl 99 -r 2

Device attribution in the tool's own output — the Task 9 bar:

    Vulkan1: AMD Radeon RX 580 Series (RADV POLARIS10) (8192 MiB, 8003 MiB free)

Measured, Qwen2.5-0.5B Q8_0 (639 MiB), two repetitions:

| Device | pp512 (t/s) | tg128 (t/s) |
|---|---|---|
| **RX 580 eGPU** | **1196.48 ± 0.08** | **33.96 ± 0.45** |
| internal Radeon Pro | 335.03 ± 0.06 | 24.04 ± 0.00 |
| CPU (i9-8950HK) | 65.18 ± 1.44 | 26.71 ± 0.27 |

**The slow link costs far less than it looks like it should.** PCIe is paid
once, uploading weights; steady-state inference runs out of VRAM. So the eGPU
is 3.6× the internal dGPU and 18× the CPU on prompt processing despite the
Gen1 tunnel. The one-off cost is roughly a second of extra load time for a
639 MiB model (measured with the page cache warm, so disk is out of the path).

Note `tg128`: the eGPU beats the CPU by only 1.3×, and the internal dGPU is
*slower* than the CPU. Token generation is memory-bandwidth bound and barely
parallel at batch 1 — it does not reward a GPU the way prompt processing
does. Judge this host's GPU acceleration on `pp512`, not `tg128`.

#### Polaris limitations

Both AMD cards report, via ggml:

    uma: 0 | fp16: 0 | bf16: 0 | warp size: 64 | int dot: 0 | matrix cores: none

GCN 4 has no fast FP16, no bf16, no integer dot product, no matrix cores. So
FP16-dependent and matrix-core-dependent backends are out; the FP32 paths are
what runs. llama.cpp's Vulkan backend handles this correctly — it reports
`fp16: 0` and benchmarks to completion anyway. This is the reason the baseline
picks the Vulkan backend rather than anything ROCm- or tensor-core-oriented.

#### Posture: boot-attached; hotplug not exercised

Chosen posture is **boot-attached**, powered on before the host and left
connected. Supported by `authflags: boot` plus a clean amdgpu init at every
boot.

**Live hotplug was deliberately not tested**, and this is a gap rather than a
finding: the eGPU drives the only external display, so detaching blacks out
the monitor and risks wedging the driver. Any re-cabling here has been done
powered off. If live detach is ever needed, test it with the monitor moved to
the internal panel first.

#### Kernel parameters — undeclared host state

    intel_iommu=on iommu=pt pm_async=off pci=realloc

These are hand-edited into `/etc/default/grub` and are **not declared in this
repo**, so a rebuilt host would not have them. Left that way on purpose: a bad
`GRUB_CMDLINE_LINUX_DEFAULT` means an unbootable machine, this host already
carries the GRUB-vs-Startup-Manager caveat above, and Task 8's remote-unlock
recovery path does not exist yet. Declaring them via a
`/etc/default/grub.d/` drop-in plus an `update-grub` handler is a follow-up
sequenced **after** Task 8.

`pci=realloc` is worth keeping despite the BAR failure above; it is the
mechanism that would work if MMIO space ever allows it.

### Server readiness: access paths + health signal (Task 10)
_To be completed by Task 10._ The off-LAN access paths (router VPN,
Tailscale), power-loss-recovery behavior, and the off-host health signal
home (which machine runs it, restricted-key setup).
