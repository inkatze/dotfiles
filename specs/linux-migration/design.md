# Linux Migration — Design

**Status:** Draft
**Last reviewed:** 2026-07-22
**Format-version:** 2
**Execution:** derived — see the status render

Origin tags: `N` = new decision made in this bundle's drafting session
(2026-07-22).

## Decision log

### D-1: Distro is Ubuntu via the t2linux T2-Ubuntu ISO  (N)

**Decision:** Install Ubuntu using the latest release of the t2linux
project's T2-Ubuntu ISO (patched kernel with T2 support baked in), and
pick the exact release at execution time from the project's release page
rather than pinning one now.

**Alternatives considered:**
- Fedora with t2linux support. Rejected because: equally supported by
  t2linux, but the operator's stated preference and existing familiarity
  is Ubuntu, and the apt/LTS ecosystem suits a long-lived server.
- Arch / EndeavourOS t2 builds. Rejected because: rolling release means
  more ongoing maintenance on a machine meant to be a low-touch server.
- NixOS on T2. Rejected because: a different configuration paradigm than
  this repo's Ansible model; would fork the repo's management story.
- Vanilla Ubuntu ISO plus manual kernel patching. Rejected because: the
  t2linux ISOs exist precisely to avoid hand-maintaining the patchset.

**Chosen because:** The invocation named t2linux Ubuntu as the leading
candidate; the project is active (v7.0.9-1 released 2026-05-21); the
wiki documents a supported macOS-less path; and an Ubuntu base keeps the
server ecosystem (packages, guides, dropbear-initramfs pattern) boring
and well-trodden.

### D-2: Full wipe, staged safely  (N)

**Decision:** Erase macOS entirely (whole internal disk to Linux, EFI
partition preserved), reached only through a staged sequence: verified
selective backup → firmware/BridgeOS updated to latest → power-loss
auto-restart set → Startup Security relaxed → boot-verified installer →
wipe. WiFi/BT firmware is retrieved post-install via the t2linux
macOS-less path (`get-apple-firmware get_from_online`). Rollback is a
documented internet-recovery reinstall of macOS.

**Alternatives considered:**
- Keep a small macOS partition for firmware updates and recovery
  (t2linux community convention). Rejected because: the operator
  explicitly chose maximum resources; the firmware-update loss is
  mitigated by updating to the latest firmware immediately before the
  wipe, and internet recovery remains as the re-entry path.
- Dual boot. Rejected because: same objection, plus ongoing disk-space
  cost for an OS that will never be used.

**Chosen because:** Maximizing resources is the goal's first clause; the
staged ordering turns an irreversible act into one preceded by verified
safeguards, and the wipe step itself stays human-directed (the
deploy/migration decision-domain rule).

*(Amended at kickoff lens pass 2026-07-23: Startup Security target
corrected to No Security — Reduced Security still requires an
Apple-signed OS and cannot boot the installed system; WiFi/BT firmware
is additionally exported from macOS pre-wipe as an offline fallback for
the post-install retrieval; the router's legacy WAN port-forward is
disabled at wipe time so the fresh install is never internet-reachable
before hardening.)*

### D-3: LUKS full-disk encryption with dropbear-initramfs remote unlock  (N)

**Decision:** The root filesystem is LUKS-encrypted. Early boot runs
dropbear-initramfs with key-based SSH so the volume can be unlocked
remotely over wired ethernet; the console passphrase remains the
fallback. Consequence accepted: after any reboot (including power-loss
recovery) the machine waits at the unlock prompt until a human unlocks
it remotely or at the console.

**Alternatives considered:**
- No encryption. Rejected because: the machine will hold long-lived
  credentials and personal data as a server; at-rest protection was lost
  with FileVault and should be replaced.
- LUKS with console-only unlock. Rejected because: incompatible with
  the headless server future; every reboot would need physical presence.
- Auto-unlock via keyfile on attached USB or TPM-style sealing.
  Rejected because: the T2's secure enclave is unavailable to Linux, and
  a permanently attached keyfile defeats the at-rest protection.

**Chosen because:** The dropbear-initramfs pattern is current, confirmed
working on Ubuntu 24.04+ (keys under `/etc/dropbear/initramfs/`), and is
the standard headless-server answer to the LUKS-vs-remote tension.

### D-4: eGPU via native amdgpu; compute via Vulkan  (N)

**Decision:** The RX 580 eGPU runs on the in-kernel amdgpu driver with
boltd handling Thunderbolt authorization. Compute verification uses a
real Vulkan (RADV) workload. `pcie_ports=native` is the documented
first remedy if hotplug misbehaves. Display duty and compute are both
verified; quirks and the safe attach/detach procedure get documented in
the repo.

**Alternatives considered:**
- ROCm/OpenCL compute stack. Rejected because: AMD dropped official
  ROCm support for Polaris-generation cards (RX 580); Vulkan is the
  supported compute path that still works.
- Boot-attached-only policy (never hotplug). Not rejected outright:
  kept as the fallback posture if hotplug proves unreliable on T2
  Thunderbolt; the attach/detach documentation records whichever
  posture verification supports.

**Chosen because:** amdgpu+RADV is the zero-added-dependency path with
mainline support; the t2linux wiki confirms Thunderbolt works on T2
Macs with known parameters; and a documented procedure converts known
flakiness into an operational routine.

### D-5: Ansible platform split — new linux role, os_family guards  (N)

**Decision:** The repo gains a Linux platform baseline: a new linux role
alongside `roles/osx/`, `os_family`-guarded playbook wiring, and an
inventory entry for the migrated host. macOS roles stay untouched for
the remaining Mac hosts. The baseline covers fish, mise, tmux, core CLI
tooling, SSH server config, and the Tailscale package.
*(Amended at kickoff 2026-07-22: the baseline also carries the
1Password CLI (`op`), per REQ-F1.2.)*

**Alternatives considered:**
- Making `roles/osx/` tasks individually conditional on platform.
  Rejected because: scatters platform logic through a role named for one
  platform; violates least-surprise for anyone reading the repo.
- A separate playbook (or separate repo) for the Linux host. Rejected
  because: forks the source-of-truth story the repo exists to provide;
  inventory-plus-guards is the Ansible-idiomatic shape.

**Chosen because:** Role-per-platform with inventory-driven selection is
the framework idiom (engineering-decisions rung 1), keeps the macOS
hosts' blast radius at zero, and is authorable and lintable before the
migration happens (repo work front-loaded to shrink machine downtime).

### D-6: Sleep and suspend disabled  (N)

**Decision:** Suspend/sleep is disabled on the installed system from the
start.

**Alternatives considered:**
- Leave suspend enabled while the machine is still a personal laptop.
  Rejected because: suspend is broken on T2 Macs with current
  (post-Sonoma) firmware anyway, and an accidental suspend on the future
  server means an unreachable machine.

**Chosen because:** The server posture wants always-on; the platform's
known suspend breakage makes this a non-sacrifice.

### D-7: Power-loss auto-restart set from macOS before the wipe  (N)

**Decision:** Set the SMC auto-restart-on-power-loss behavior from macOS
(`pmset autorestart 1`) before the wipe, on the expectation that the SMC
setting persists across the OS change; verify under Linux and research a
Linux-native fallback at execution time if it does not survive.

**Alternatives considered:**
- Configure from Linux only. Rejected as the primary path because: SMC
  power settings on Macs are most reliably set from macOS, and after the
  wipe that lever is gone; setting it while macOS exists costs nothing.

**Chosen because:** It is a zero-cost pre-wipe step with a verification
task behind it, and REQ-E1.4 has no other cheap path on this hardware.

### D-8: Hybrid remote access — router VPN door plus Tailscale mesh  (N)

**Decision:** Two complementary paths, each covering the other's blind
spot: the home router's built-in VPN server is the into-the-LAN door
(reaches dropbear during early boot, works when the host VPN is down),
and Tailscale on the host is the day-to-day mesh across the operator's
devices. The router's pre-existing legacy WAN-exposed port-forward is
disabled at wipe time and permanently retired once both paths are
verified.

**Alternatives considered:**
- Tailscale only. Rejected because: the host's Tailscale is not up
  during initramfs, so remote LUKS unlock from off-LAN would have no
  path; host-VPN-down emergencies would need physical presence.
- Plain WireGuard on the host (port-forward + dynamic DNS). Rejected
  because: manual per-device key/peer management, breaks under CGNAT,
  and still does not cover early boot without a second path.
- Self-hosted control plane (Headscale, self-hosted NetBird). Rejected
  because: a long-running service, which this spec's scope explicitly
  refuses to deploy; on the server itself it is a chicken-and-egg (the
  control plane needed to reach the machine lives on the machine), and
  done properly it wants a VPS. Kept as a future exit: Headscale speaks
  the Tailscale client protocol, so this decision is not a lock-in.
- ZeroTier / NetBird cloud. Rejected because: ZeroTier's layer-2
  custom-protocol model is the wrong shape here; NetBird cloud offers no
  advantage over Tailscale at this scale and loses the Headscale exit.
- Keep the legacy WAN-exposed forward. Rejected because: continuously
  scanned attack surface; both replacement paths strictly dominate it.

**Chosen because:** The 2026 landscape review (Sources) showed managed
Tailscale is free at this scale with a transparent security record,
while the router VPN uniquely covers the early-boot and
host-down cases; together they retire the exposed SSH port with no new
self-hosted services.

*(Amended at kickoff lens pass 2026-07-23: a minimum protocol bar is
set for the router VPN (WireGuard- or IKEv2-class; no PPTP/L2TP-PSK,
REQ-E1.2); the combined-failure state — both access paths down, leaving
physical presence as the only recovery — is an explicitly accepted
consequence, mirroring D-3's reboot-wait acceptance; and a fallback
branch is recorded if the router VPN proves unusable: a
WireGuard-capable device or Tailscale subnet-router on another LAN host
becomes the into-the-LAN door before the legacy forward is permanently
retired.)*

### D-9: Wired ethernet via adapter for unlock path and server duty  (N)

**Decision:** The unlock path (and server networking generally) runs
over wired ethernet through a USB-C/Thunderbolt ethernet adapter whose
driver is available in the initramfs; verifying the adapter is part of
the remote-unlock task.

**Alternatives considered:**
- WiFi in initramfs. Rejected because: requires wpa_supplicant plus
  firmware inside the initramfs, a fragile and poorly supported pattern;
  and a server's primary link should be wired regardless.

**Chosen because:** This machine has no built-in ethernet; dropbear in
initramfs needs a NIC the early-boot kernel can drive; and a wired link
is the correct default for the always-on role.

## Cross-cutting concerns

- **Decision-domains walk (2026-07-22; updated at kickoff
  2026-07-23).** Domains crossed and where they are decided:
  deploy/migration strategy (the wipe; human-directed irreversible
  step, D-2, Task 5), authentication/authorization (SSH key-auth, VPN
  identity; D-8, REQ-E1.1), secrets & configuration (all migration
  secrets live in 1Password, the vault of record per REQ-F1.2, never
  in this repo; on-machine key files exist only where the mechanism
  requires them, covered by REQ-B1.7 fingerprint pinning; REQ-F1.1),
  dependency adoption (t2linux kernel stream, Tailscale,
  dropbear-initramfs; see below), observability (crossed and decided
  at kickoff: REQ-E1.6, minimal off-host signal only), concurrency
  (task-graph serialization decided at kickoff: one physical machine,
  reboot-bearing tasks execute serially, Task 10 verifies last with a
  dependency on Task 9). Domains not crossed: data storage/modeling,
  caching, queues, API surface, versioning.
- **Dependency adoption notes.** t2linux kernel stream: community-
  maintained third-party kernel binaries — active org, multi-distro
  user base, but a supply-chain trust decision; mitigated by using the
  official t2linux GitHub org artifacts and its documented kernel-update
  mechanism (REQ-B1.8). Tailscale: managed control plane, open-source
  client, free personal tier covering this scale; exit path via
  Headscale-compatible clients (D-8). dropbear-initramfs: Debian/Ubuntu
  archive package, standard pattern.
- **Altitude gate (autopilot-reflex).** No seed-claim or mid-flow
  altitude trigger fired during drafting: the deliverable is a
  machine-migration project at mechanism altitude throughout, and the
  one altitude-adjacent fork (runbook-only vs repo-managed baseline)
  was resolved as a scope decision in the goal phase. Per
  proportionality, no altitude D-ID is recorded.
- **Known-risk residue for the kickoff risk register.** Bluetooth
  glitches reported on some T2 chips when on 2.4 GHz WiFi; dGPU
  (Radeon Pro 560X) resolution-change crashes reported on T2 hybrid
  graphics; trackpad lacks force-touch/palm-rejection parity; Touch ID
  unavailable on Linux (T2 secure enclave unsupported); internet
  recovery after a wipe is the only road back to macOS and is untested
  by this spec; the installer live session may lack WiFi until the
  firmware-retrieval step runs, so the wired ethernet adapter (or a
  phone tether) must be on hand at install time.
