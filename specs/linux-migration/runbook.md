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

#### Bluetooth — no firmware needed, and two real causes behind one misleading symptom

Bluetooth works (REQ-B1.4). An MX Master 2S pairs over Bluetooth LE and reports
`Paired: yes  Bonded: yes  Trusted: yes  Connected: yes`, with battery level
through the GATT Battery Service and both `MX Master Mouse` and `MX Master
Keyboard` input devices present.

It took a long time to get there because the symptom pointed at three things
that were all innocent. Recorded in full, because each one is individually
convincing:

**No Bluetooth firmware is needed on this model, and the log says otherwise.**
At every boot the kernel prints:

    Bluetooth: hci0: BCM4364B0 Maui Olympic GEN (MFG)
    Bluetooth: hci0: BCM: firmware Patch file not found, tried:
    Bluetooth: hci0: BCM: 'brcm/BCM.hcd'

There are no `.hcd` files in `/lib/firmware/brcm` and there should not be.
t2linux's own `firmware.sh` states that Bluetooth firmware is needed **only for
MacBookPro15,4, MacBookPro16,3 and MacBookAir9,1** — this machine is
MacBookPro15,1. `(MFG)` and the missing patch file are **normal here**. Do not
chase this: it leads to `firmware.sh` Method 5, which downloads a macOS Recovery
image and, on the way, offers to install `apfs-dkms`, `dmg2img` and Homebrew.
None of the three community firmware repos carries an Apple BCM4364 `.hcd`
anyway (`AdityaGarg8/Apple-Firmware` has 168 files and zero `.hcd`).

**`unknown advertising packet type` is noise.** The kernel logs a stream of
`Bluetooth: hci0: unknown advertising packet type: 0x10/0x12/0x14/0x20/0x24`.
The receive path is fine regardless — a scan sees eight other LE devices.

**ERTM is irrelevant.** `bluetooth.disable_ertm=1` is the standard internet
advice for Logitech pairing trouble. ERTM is a BR/EDR mechanism and this mouse
is LE-only (`AdvertisingFlags: 0x05` = LE Limited Discoverable + BR/EDR Not
Supported), so the setting cannot matter.

The two causes that were real:

1. **RF distance.** At roughly −69 dBm the LE connection would establish and
   then die ~330 ms in, during the first `LE Read Remote Used Features`, with
   `Connection Failed to be Established (0x3e)` — the peripheral simply stopped
   answering. SMP never began, which is why every theory about pairing methods
   was aimed at the wrong layer. Moving the mouse against the machine fixed the
   link outright.
2. **Pairing-agent capability.** With the link healthy, SMP negotiated and then
   failed: the host requested MITM protection, the mouse offered `No MITM,
   Legacy` (a mouse has no keypad, so Just Works is the only mode available to
   it), BlueZ raised a `User Confirmation Request`, nothing answered it, and
   BlueZ sent a **`User Confirmation Negative Reply`** — declining the pairing
   on our own behalf. The resulting `Pairing Failed: Passkey entry failed` reads
   as a rejection *by* the mouse and is the opposite.

**Pair from the desktop Bluetooth panel, not a scripted `bluetoothctl`.** The
desktop agent handles Just Works with a keypad-less peripheral correctly and
requests bonding; driving `bluetoothctl` through a pipe produced an agent that
either never answered the confirmation or requested `No bonding` plus MITM it
could not satisfy. Three captures were lost to fighting the harness rather than
the hardware.

**The diagnostic that actually worked** was `btmon`, because `bluetoothctl` only
ever reports generic D-Bus errors (`AuthenticationRejected`,
`ConnectionAttemptFailed`) that cover a dozen distinct causes. `btmon` shows the
SMP exchange and the HCI disconnect reason, which is what separated "the link
died before pairing" from "pairing was declined".

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

Consequence for **Task 10's ~30-minute thermal soak**: throttling for the
whole duration, which still satisfies the requirement — the bar is no
thermal *shutdown*, not no throttling. More broadly: this host suits
I/O-bound and bursty work, and will throttle hard under sustained
all-core compute. Worth weighing when choosing which services land here.

**Amended after the Task 10 soak actually ran.** This section originally
predicted the soak would sit *at 100 °C* for its entire duration. It does
not. Over 30 minutes the package spikes to 100 °C in the first minute and
then settles to **70–78 °C**, with fans backing off from 5930 to 5001 as
clocks drop to a sustainable point. The measurements above are a
90-second burst, and a steady state cannot be extrapolated from one — the
equilibrium sits ~25 °C below the ceiling. See the Task 10 thermal-soak
subsection for the full table.

### Day-2 remote LUKS unlock routine (Task 8)

Verified working on this host. The routine is at the end; read the mechanism
note first, because the standard recipe for this does not apply here.

#### The mechanism is NOT dropbear-initramfs, and cannot be

D-3 names `dropbear-initramfs`, and every guide on the subject does too. **That
package is inert on this host.** It is an initramfs-tools package: it ships its
hooks under `/usr/share/initramfs-tools/hooks/`, and this machine builds its
initrd with **dracut**. `/usr/sbin/update-initramfs` here is only a
compatibility shim owned by the dracut package; initramfs-tools proper is not
installed, and dracut declares `Conflicts: initramfs-tools`.

Installing it would succeed, report success, and do nothing at boot — the worst
failure mode available, since you would discover it while locked out.

dracut ships no SSH module of its own (all ~100 enumerated) and Ubuntu packages
no dropbear-for-dracut, so the glue is repo-owned:
`roles/linux/files/dracut/dropbear-unlock/`, about 60 lines. Only the glue —
the server binary comes from apt's `dropbear-bin` so the network-facing half
stays on the patch stream, and networking from `dracut-network`.

Two further consequences of dracut that contradict the usual instructions:

- **The initrd runs systemd** (`systemd[1]: Running in initrd`), so the
  passphrase is delivered through the systemd password-agent protocol. The
  unlock command is `systemd-tty-ask-password-agent`, **not**
  `cryptroot-unlock` — the latter belongs to `cryptsetup-initramfs`, which this
  host does not have and never did.
- **`cryptsetup-initramfs` being absent is not a fault.** dracut's built-in
  `crypt` and `systemd-cryptsetup` modules handle LUKS natively. This was
  briefly mistaken for a latent brick risk during Task 8; it is not one.

Rejected alternatives, recorded so they are not re-tried: vendoring the
third-party `dracut-crypt-ssh` (last upstream push 2024-12, predating dracut
110); and migrating the host to initramfs-tools, which is the more dangerous
option — the T2 modules (`t2bce_core`, `t2bce_vhci`, `hid_appletb_kbd`) are what
provide a **keyboard at the LUKS prompt**, dracut supplies them by host-only
detection today, and getting them wrong under a different generator leaves no
keyboard to type the recovery with.

#### Networking needs no GRUB edit

`rd.neednet=1 ip=dhcp` is embedded **into the initrd** by dracut's
`kernel_cmdline+=` in `/etc/dracut.conf.d/60-remote-unlock.conf`, landing as
`/etc/cmdline.d/10-default.conf` inside the image. Confirmed at boot:

    dracut-cmdline: Using kernel command line parameters:
      rd.neednet=1 ip=dhcp rd.luks.uuid=... rd.lvm.lv=...

This matters for sequencing, not just tidiness: declaring
`GRUB_CMDLINE_LINUX_DEFAULT` in the repo is a follow-up meant to land *after*
this task, so remote unlock exists as a recovery path before the bootloader is
touched. Routing these two parameters through dracut keeps that order intact.

The address comes from a DHCP reservation, so no LAN address is committed
(REQ-F1.1). No interface is named either: the adapter's predictable name is
`enx<MAC>`, so naming it would commit this host's MAC. dracut probes each
interface instead. The **drivers** are named explicitly (`add_drivers+=" xhci_pci
r8152 "`) rather than left to host-only detection, so a rebuild performed with
the adapter unplugged cannot silently produce an initrd that can never reach the
network.

Note the unlock NIC is the USB adapter plugged **directly into the Mac**, served
by the Thunderbolt chip's integrated xHCI. The host's other gigabit adapter
lives inside the Razer Core behind the PCIe tunnel and is deliberately not the
unlock path: using it would make booting depend on the eGPU enclosure being
powered on.

#### The ordering trap — the one thing that will bite a future reader

The unit must be ordered against the **network stack**, never against
`dracut-initqueue.service`. Ordering `After=dracut-initqueue.service` looks
correct ("wait for the network, then start") and is wrong: that service does not
*finish* until the root device appears, which here means until the LUKS volume
has been unlocked. The first attempt did exactly this, and dropbear started 102
seconds too late — immediately after the passphrase had already been typed at
the console:

| Time | Event |
|---|---|
| 17:49:56 | Starting `dracut-initqueue.service` |
| 17:51:38 | `dracut-initqueue: Scanning dm-0 for LVM` — already unlocked |
| 17:51:38 | Started `dropbear-unlock.service` — too late |
| 17:51:38 | `dropbear: Early exit: Terminated by signal` |

Correct ordering is `After=nm-initrd.service systemd-networkd.service
dracut-cmdline.service` and `Before=dracut-initqueue.service`. Starting before
an address exists is fine and deliberate — dropbear binds the wildcard address
and accepts as soon as DHCP completes; gating on a lease would add a dependency
that can fail. `Conflicts=initrd-switch-root.target` is also load-bearing:
without it dropbear survives the handover to the real root and hangs the
transition, presenting as a boot that stalls *after* a successful unlock.

#### Verified boot

| Time | Event |
|---|---|
| 19:56:57 | Started `dropbear-unlock.service` — 3s **before** carrier |
| 19:57:00 | `r8152 ...: carrier on` |
| 19:57:07 | `dhcp4: state changed new lease` |
| 19:57:08 | Starting `dracut-initqueue.service` — passphrase window opens |
| 19:57:10 | `Child connection from <client>` |
| 19:57:19 | `Pubkey auth succeeded for 'root' with ssh-ed25519 key` |
| 19:57:27 | `Exit (root): Disconnect received` |
| 19:57:30 | `Scanning devices dm-0 ... Finished` — unlocked |

The initrd journal survives into the booted system, which is what made both the
failure and the success a five-minute diagnosis rather than guesswork:

    journalctl -b 0 -u dropbear-unlock

#### The routine

1. Reach the LAN — physically, or via the router VPN, or Tailscale. (Tailscale
   is **not** available at this point: it lives on the encrypted root. Router
   VPN or local LAN only.)
2. SSH to the host on **port 2222**, as `root`:

       ssh -p 2222 root@<host>

   Port 2222 rather than 22 on purpose: dropbear has its own host key, so
   sharing 22 with sshd makes every unlock print a host-key-mismatch warning —
   training you to click through exactly the warning REQ-B1.7 depends on. The
   separate port lets both be pinned side by side, keyed as `[host]:2222`.
3. **Verify the host-key fingerprint before typing anything.** This is the
   substance of REQ-B1.7, not a formality: it is the only thing between you and
   typing your disk passphrase into an impostor.

   The fingerprint is **deliberately not recorded here** — see "Where the
   fingerprints live" below. Compare against the 1Password note, or against the
   `[host]:2222` entry already in your client's `known_hosts` from a previous
   verified connection.

   To read it on the host itself (useful after a rebuild, when the fingerprint
   has legitimately changed):

       sudo dropbearkey -y -f /etc/dropbear/initramfs/dropbear_ed25519_host_key \
         | grep -i Fingerprint

4. The unlock key's forced command drops you straight into
   `systemd-tty-ask-password-agent --query`. There is no shell. Type the
   passphrase at the prompt.
5. The session ends and boot continues. The disk unlocked ~3 seconds after
   disconnect in the verified run.

**Console fallback** is verified — see below.

#### Where the fingerprints live

Host-key fingerprints for this machine — dropbear's and sshd's — are recorded in
**1Password**, not in this file, and pinned in each client's `known_hosts`.

This is the hygiene rule at the top of this runbook (REQ-F1.1) being applied
rather than waived, and it is worth understanding why the rule exists. A
fingerprint is only a public hash, so it is not a secret in the usual sense. But
this repo is public, and a fingerprint recorded here links the repo to a
specific, scannable machine: anyone who can reach the host can confirm they have
found *this* one. That linkability is the thing REQ-F1.1 is protecting, and it is
not undone by the hash being public.

The Task 8 and Task 10 deliverables originally said "recorded in the runbook",
which contradicted this rule; that wording was amended rather than the rule (see
the requirements changelog). Task 8's own placeholder had it right from the
start: *"Fingerprints are pinned on clients, not committed here."*

#### Keys

| Key | Where | Notes |
|---|---|---|
| dropbear **host** key | `/etc/dropbear/initramfs/dropbear_ed25519_host_key`, generated on the host | Exists as a file by mechanism; REQ-F1.2 exempts it. Integrity comes from the pinned fingerprint above. Generated under a `creates` guard — without it, every playbook run would mint a new key and change the fingerprint under the clients that pinned it |
| **unlock** key (client side) | private half in 1Password `dotfiles-luks-unlock`, public half in `roles/linux/files/dropbear/authorized_keys` | Dedicated and distinct from day-to-day keys per REQ-B1.7. The initrd sits on the **unencrypted** `/boot`, so anyone with disk access can read the public key and host key there — which is exactly why the matching private key must not be the one that also signs commits |

The unlock key is restricted by a forced command plus
`no-port-forwarding,no-agent-forwarding,no-X11-forwarding`, so it cannot open a
shell or forward anything. `no-pty` is deliberately **absent**: the agent
prompts interactively, and without a PTY the passphrase would be echoed in the
client's terminal as it is typed.

It is listed in `roles/ssh/files/1password-agent.toml`, so any machine with
1Password unlocked can unlock this host.

#### Console fallback — verified

Console unlock works with the dracut module and the rebuilt initrd in place. It
was demonstrated by the *failed* remote-unlock boot, which is the cleanest
possible evidence: dropbear was present but mis-ordered, so it could not serve
the passphrase, and the machine booted anyway.

| Evidence, boot of 17:49:45 | |
|---|---|
| Kernel cmdline | carried `rd.neednet=1 ip=dhcp` — the dracut config was active |
| `dropbear-unlock.service` | started (once) |
| dropbear connections | **0** — no remote client at all |
| 17:51:35 | `systemd-cryptsetup: Set cipher aes ...` — volume unlocked |

So the passphrase came from the console with everything in place. Both halves of
REQ-B1.7 are satisfied by measurement rather than by assumption.

#### Verified after an initramfs regeneration

The initrd was regenerated at 19:06 and the next boot (19:57) unlocked remotely,
so a regeneration does not break the unlock path. Worth stating precisely what
that covers: remote unlock is demonstrated *after* a regeneration, not both
before and after one. The regeneration in question was a `dracut --force` run
via the role's handler; a kernel-update-driven regeneration has not yet occurred
on this host, and dracut picks the configuration up through its
`/usr/lib/kernel/install.d/` hook rather than anything task-specific.

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

Measured, Qwen2.5-0.5B Q8_0 (639 MiB), three repetitions, idle machine:

| Device | pp512 (t/s) | tg128 (t/s) |
|---|---|---|
| **RX 580 eGPU** | **3219.85 ± 23.33** | **119.43 ± 0.50** |
| internal Radeon Pro *(clamped, see below)* | 334.85 ± 0.00 | 24.30 ± 0.09 |
| CPU (i9-8950HK) | 231.03 ± 42.71 | 39.27 ± 0.31 |

So the eGPU is **9.6×** the internal dGPU and **13.9×** the CPU on prompt
processing, and **3.0×** the CPU on token generation.

**These numbers replace an earlier set that was measured on a crippled card,
and the correction matters more than the numbers.** The first pass recorded
1196.48 pp512 / 33.96 tg128 for the eGPU — 2.7× and 3.5× low — because a udev
rule was pinning it to DPM level 0 (300 MHz core against 1360 MHz, 300 MHz
memory against 2000 MHz). See the amdgpu power-management note below.

Two consequences worth carrying:

- **A conclusion recorded here previously was wrong.** The earlier text said
  token generation "does not reward a GPU the way prompt processing does" and
  advised judging this host on `pp512` rather than `tg128`, because the eGPU
  then beat the CPU by only 1.3× and the internal dGPU came in *slower* than
  the CPU. That was an artifact of the clamp. Unclamped, the eGPU is 3.0× the
  CPU on `tg128` and 4.9× the internal dGPU. `tg128` is still the
  bandwidth-bound, weakly-parallel case and still the less impressive number,
  but it is not the wash it appeared to be.
- **The internal Radeon Pro's figures are policy, not capability.** It is
  deliberately held at DPM level 0 for thermal headroom (that clamp is
  correct and retained), so its row measures the configured state of a card
  that is idle-by-design, not what Polaris11 can do.

**The slow PCIe link costs far less than it looks like it should.** PCIe is
paid once, uploading weights; steady-state inference runs out of VRAM. The
eGPU wins by ~10-14× despite the Gen1 ×4 tunnel. The one-off cost is roughly a
second of extra load time for a 639 MiB model (measured page-cache-warm, so
disk is out of the path).

Note the CPU row's ±42.71 spread on `pp512`. That is thermal throttling
inside a single benchmark, consistent with the Task 6 finding that this chassis
pins the package at 100 °C under sustained all-core load. Treat CPU figures on
this host as a band, not a point.

#### The amdgpu power-management clamp

`/etc/udev/rules.d/30-amdgpu-pm.rules` holds the **internal** dGPU at its
lowest power state for thermal headroom, which is a sound trade on this
chassis. It is now repo-owned (`roles/linux/files/udev/`) and matches on **PCI
vendor+device**, not card number.

It previously matched `KERNEL=="card[012]"`, and that is the finding worth
remembering: because card numbering is not stable here, the rule clamped
*whichever* GPUs happened to land on those numbers. The eGPU's performance was
therefore **non-deterministic across boots** — it measured ~9.6× the internal
dGPU on one boot and ~3.6× on another, with no configuration change between
them, purely from enumeration order. A card-number match in any rule on this
host should be treated as a bug.

The symptom is deliberately confusing and worth recognising: a workload can be
correctly placed on the eGPU (device attribution in the tool's own output,
`DRI_PRIME` honoured, 8 GB VRAM reported) and still run several times slower
than it should. Check `power_dpm_force_performance_level` and `pp_dpm_sclk`
before concluding that device selection is wrong.

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

_Task 10 is still open._ Following the Task 6 pattern, verified results are
recorded here as they are produced rather than reconstructed at the end. What
remains is listed at the bottom.

#### SSH hardening — verified in effect (REQ-E1.1)

Read back from the **running daemon**, not from the drop-in on disk. That
distinction is the point of the check: `roles/linux/files/sshd/60-hardening.conf`
being correct proves only that Ansible wrote a file, whereas `sshd -T` renders
the config sshd actually loaded, after every `Include` and default has been
resolved.

    sudo sshd -T | grep -iE '^(passwordauthentication|permitrootlogin|pubkeyauthentication|kbdinteractiveauthentication|permitemptypasswords)'

| Setting | Value |
|---|---|
| `permitrootlogin` | `no` |
| `pubkeyauthentication` | `yes` |
| `passwordauthentication` | `no` |
| `kbdinteractiveauthentication` | `no` |
| `permitemptypasswords` | `no` |

`kbdinteractiveauthentication no` is worth naming separately rather than assuming
it follows from `passwordauthentication no`. It does not: keyboard-interactive is
a distinct method that can reach PAM and accept a password even when password
authentication is off, so leaving it on is a known way to think you have
key-only auth and not have it.

Host-key fingerprints for pinning are in 1Password, not here — see "Where the
fingerprints live" in the Task 8 section.

#### Thermal soak — passed, and it corrects the Task 6 prediction

30 minutes of all-12-thread CPU spin, sampled every 30 s, same stressor shape as
the Task 6 load-response measurement so the numbers are comparable.

| Elapsed | Package | fan1 | fan2 | Throttle events (cumulative) |
|---|---|---|---|---|
| peak (early) | **100 °C** | 5933 | 5541 | — |
| 300 s | 78 °C | 5930 | 5458 | 5,682 |
| 600 s | 75 °C | 5906 | 5438 | 8,857 |
| 900 s | 74 °C | 5860 | 5359 | 11,414 |
| 1200 s | 75 °C | 5883 | 5399 | 13,811 |
| 1500 s | 74 °C | 5571 | 5115 | 15,957 |
| 1800 s | 70 °C | 5001 | 4644 | 17,922 |

**Result: no thermal shutdown.** The requirement is met — 17,922 throttle events
across the soak, and the machine stayed up throughout.

**The interesting part contradicts what this runbook previously predicted.** The
Task 6 section said to expect the soak to "run at 100 °C and throttling for its
entire duration". Throttling for the entire duration is right. Running at 100 °C
is not: the package spikes to 100 °C in the first minute, then **settles to
70–78 °C and stays there**, with the fans *backing off* from 5930 to 5001 as it
does.

That is the thermal governor working as designed rather than anything anomalous —
sustained load cannot hold 100 °C, so clocks drop until heat generation matches
what the chassis can dissipate, and the equilibrium is ~25 °C below the ceiling.
The Task 6 figure was a 90-second burst measurement, and extrapolating a
steady state from it was wrong. Fans tracking temperature down also confirms
`t2fanrd` is responding to real readings rather than pinning to maximum.

Consequence worth carrying: this host's sustained all-core throughput is set by
the throttled equilibrium, not by its boost clocks, and the CPU benchmark spread
recorded in the Task 9 section (±42.71 on `pp512`) is the same effect seen inside
a single short run. Sizing anything CPU-bound here should assume the throttled
figure.

Caveat on the numbers: the baseline row reads 75 °C with fans already at 5935,
because a 60-second smoke test had just run. The machine started this soak warm,
which if anything makes the settling behaviour more convincing rather than less.

Reproduce with `~/.cache/thermal-soak.sh 1800` (no root, installs nothing).

#### Still to do

- **Tailscale is not logged in.** `tailscaled` runs but the host is
  unauthenticated (`tailscale status` → `Logged out`), so the mesh access path
  does not exist yet. Needs `tailscale up` and a browser login.
- Router VPN configured and verified **from off-LAN** to reach dropbear during
  early boot, at the REQ-E1.2 protocol floor — or the D-8 fallback if the router
  cannot meet it.
- Legacy WAN port-forward confirmed permanently retired, by external scan from
  off-LAN.
- Headless boot test with no display or keyboard attached.
- Power-loss recovery, battery-aware: outage sustained until the battery drains
  to power-off, then wall power restored.
- Bounded thermal soak (~30 minutes sustained load) with no thermal shutdown.
  Expect the package pinned at 100 °C with fans maxed throughout and throttling
  logged — that is this chassis behaving as designed (see the Task 6 thermal
  baseline), and the requirement is no thermal *shutdown*, not no throttling.
- Minimal off-host health signal: which machine runs it, the restricted
  forced-command key setup, and detection of both an induced outage and an
  induced disk-threshold breach.
