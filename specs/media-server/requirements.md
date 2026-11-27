# Media Server — Requirements

**Status:** Ready
**Last reviewed:** 2026-11-26
**Format-version:** 2
**Execution:** derived — see the status render

## Goal

Rebuild the media server that `specs/media-server-cleanup/` tore down, as a
Jellyfin server on the shared home Mac, run by the fleet account under an
Ansible role. Jellyfin does the encoding and transcoding on the Mac's media
engine, a Stremio-to-Jellyfin bridge brings the operator's Stremio catalogs
and debrid streams into Jellyfin libraries, and Infuse (Apple TV and Mac) is
the player. The same setup works away from home over Tailscale. The Mac is
shared, so the media service gets priority over CI and offload work, and the
rebuild avoids each reason the old stack was removed: a plaintext debrid
token in a rendered file, a long-lived service-account token in the keychain,
a home-made watchdog, and hand-wired containers.
*(Cites: the operator's ask (Sources), media-server-cleanup (Sources),
D-1, D-2.)*

## Scope

### In scope

- A Darwin-only Ansible role that installs and runs Jellyfin (with its
  bundled ffmpeg) and the chosen bridge in the fleet account, with no sudo.
- Real-Debrid and AllDebrid support, tokens held in the personal 1Password
  agents vault.
- A vetted catalog, add-on and Jellyfin-plugin set (D-3), including Spanish
  subtitles.
- Priority and network rules for the shared Mac, and a read-only check of the
  result.
- A short operator runbook for the steps that are not the fleet account's.

### Out of scope

- Installing Tailscale: the operator does it in the Mac owner's login (the
  standard app).
- Anything in the Mac owner's account, Homebrew or system settings.
- Exposing anything to the open internet.
- Acquiring or hosting media: the server holds no media of its own.
- A Docker or colima stack: the old design is not rebuilt.
- Changing the CI runners beyond the niceness, launchd `ProcessType`
  Background setting and pre-job check REQ-C1.2 and D-5 ask.

## REQ-A — Server and player

- **REQ-A1.1** The role SHALL run Jellyfin natively (no containers) as a
  launchd agent in the fleet account, with hardware transcoding through
  VideoToolbox enabled.
  *(Cites: D-1, research: Jellyfin Apple hardware-acceleration docs.)*
- **REQ-A1.2** The full catalog of each configured Stremio catalog source
  SHALL be browsable from Infuse on Apple TV and on the Mac through the
  Jellyfin libraries, not only through search or a watchlist.
  *(Cites: D-2, the operator's decision (Sources).)*
- **REQ-A1.3** Playback SHALL work from Infuse at home (direct play) and away
  from home over Tailscale, with remote transcodes sized for a home upload.
  *(Cites: D-1, D-5.)*
- **REQ-A1.4** If REQ-A1.2 cannot be met through the chosen bridge, the
  runbook SHALL document browsing the catalog in Stremio with Infuse as its
  external player, and the rest of the role SHALL still ship.
  *(Cites: D-2, the operator's decision of 2026-11-26 (Sources).)*

## REQ-B — Providers and secrets

- **REQ-B1.1** The setup SHALL support both Real-Debrid and AllDebrid, each
  usable without the other.
  *(Cites: D-2, the operator's decision (Sources).)*
- **REQ-B1.2** Every provider token SHALL come from the personal 1Password
  agents vault and land only in files of mode 0600 owned by the fleet account;
  no token SHALL appear in a tracked file, a launchd plist, a log, a process
  argument list or any world-readable file.
  *(Cites: D-4, mission-control rule r-92 (Sources).)*
- **REQ-B1.3** The role SHALL NOT store a 1Password service-account token or
  any other long-lived credential in the keychain or on the Mac.
  *(Cites: D-4, media-server-cleanup (Sources).)*
- **REQ-B1.4** Which provider accounts are live SHALL be confirmable without
  printing or logging a token.
  *(Cites: D-4.)*
- **REQ-B1.5** Every stream SHALL resolve through a debrid provider: no
  direct-torrent or peer-to-peer result SHALL be offered or played from any
  source (Torrentio, Comet, MediaFusion, AIOStreams, or the Stremio
  fallback of REQ-A1.4), each source being configured debrid-only per D-6.
  *(Cites: D-6, the operator's decision of 2026-11-26 (Sources).)*
- **REQ-B1.6** A check SHALL confirm that the fleet account's processes on
  the Mac make no BitTorrent traffic during playback.
  *(Cites: D-6, the operator's decision of 2026-11-26 (Sources).)*

## REQ-C — Shared Mac

- **REQ-C1.1** The media service SHALL run at interactive priority; the role
  SHALL NOT elevate with sudo or change anything outside the fleet account.
  *(Cites: D-5, mission-control rule r-3 (Sources).)*
- **REQ-C1.2** CI runner and offload work SHALL run niced, and a runner
  pre-job check SHALL defer heavy jobs while Jellyfin has an active transcode.
  Library scans and thumbnail work SHALL run off-hours.
  *(Cites: D-5.)*
- **REQ-C1.3** Jellyfin and the bridge SHALL listen only on the loopback,
  the LAN and the Tailscale interfaces as each needs; nothing SHALL be
  reachable from the open internet without the operator's explicit yes.
  *(Cites: D-5, mission-control rule r-3 (Sources).)*
- **REQ-C1.4** The role and every check of the Mac SHALL run niced and fall
  back, without retrying, when the Mac does not answer.
  *(Cites: mission-control rule r-23 (Sources).)*

## REQ-D — Catalog and plugin set

- **REQ-D1.1** The role SHALL install the recommended catalog, add-on and
  plugin set from D-3 only at versions recorded as vetted, each with its
  legal, terms-of-service or privacy caveat recorded in the runbook.
  *(Cites: D-3.)*
- **REQ-D1.2** Spanish subtitles SHALL be available for playback in Infuse,
  through the OpenSubtitles plugin plus a self-hosted Bazarr+.
  *(Cites: D-3, the operator's ask and decision of 2026-11-26 (Sources).)*
- **REQ-D1.3** Watch history and lists SHALL sync with the operator's Trakt
  account.
  *(Cites: D-3, the operator's decision of 2026-11-26 (Sources).)*

## Changelog

- 2026-11-26 — Bundle drafted via `/spec-draft` from the operator's decisions
  relayed through mission control and the research recorded in `design.md`.
- 2026-11-26 — Operator answers to kickoff questions 1 to 4 folded in
  (drafting-session decision): Jellyfin 12.x, Stremio-plus-external-player
  failure branch (REQ-A1.4), all three stream sources with the legal
  acceptance, RemuxDB telemetry off.
- 2026-11-26 — Kickoff walk (`kickoff-brief.md`): Task 4 now depends on
  Task 3, Task 2 verifies VideoToolbox with a synthetic clip, the remote
  bitrate cap is a role variable, Task 4 verifies loopback and LAN with
  Tailscale re-checked in Task 5, and the runner scope line names the
  `ProcessType` setting.
- 2026-11-26 — Operator answers to kickoff questions 5 to 7 and the
  debrid-only rule folded in (drafting-session decision): Bazarr+ for Spanish
  subtitles, Trakt included, operator steps scheduled, REQ-B1.5 and REQ-B1.6.

## Sources

- **The operator's ask** (2026-11-26, via mission control): a media server on
  the other Mac that encodes and transcodes and keeps working while
  travelling; Stremio is the main client, played in Infuse on Apple TV and on
  the Mac. Decisions given the same day: Jellyfin plus a Stremio-to-Jellyfin
  bridge with Infuse as player ("yes, as long as I can browse the catalog"),
  Tailscale (standard app) for remote access, both Real-Debrid and AllDebrid,
  and a short spec followed by the build.
- **media-server-cleanup** (`specs/media-server-cleanup/`): the teardown that
  says the rebuild is its own spec; its goal records what the old stack was.
- **Operator answers to the kickoff questions** (2026-11-26, via mission
  control): Jellyfin "Current 12.x (Recommended)"; if Infuse cannot browse
  the full catalogue, "we can use stremio or something and use it as a
  external player. I'm fine with that"; stream sources "can we do 1 and 2?"
  (read as accepting Comet, MediaFusion and Torrentio, with the legal and
  terms-of-service responsibility); RemuxDB telemetry "Turn it off
  (Recommended)".
- **Operator answers, second round** (2026-11-26, via mission control):
  Spanish subtitles "Recommendation" (the OpenSubtitles plugin plus a
  self-hosted Bazarr+); Trakt, asked whether they use it, "Yes" (sync watch
  history and lists); scheduling the Tailscale install and the Infuse
  browse and playback checks as their own steps, "Yes"; and, after asking
  whether Torrentio looks suspicious, a hard rule that streams come only
  through debrid with no direct-torrent or P2P results anywhere, plus a
  check that the Mac sends no BitTorrent traffic during playback, "Yes".
- **Mission control rules** (dotfiles program): r-3 (Mac workers stay inside
  the fleet account), r-23 (the Mac is shared and may be down), r-92 (secrets
  only through the personal 1Password agents vault, 0600).
- **Prior research** (mission control's research worker, 2026-11-26): the Mac
  is an M3 Max with ample memory and disk and Infuse installed, with no
  Jellyfin, Docker or Tailscale in the fleet account and four CI runners
  running there.
- **Drafting-session research** (2026-11-26): the sources recorded in
  `design.md`, read for this draft.
