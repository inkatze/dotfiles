# Media Server — Tasks

**Status:** Draft
**Last reviewed:** 2026-11-26
**Format-version:** 2
**Execution:** derived — see the status render

## Tasks

### Task 1 — Vet the bridge and the add-on set

- **Deliverables:** a vetting note in `docs/media-server.md` recording, per
  D-2 and D-3 pick, the pinned version, last release or commit, license,
  how it stores tokens at rest, and its caveat; a throwaway Jellyfin plus
  Gelato plus AIOStreams run in the fleet account (read-only reach through
  `ssh mac`, niced) that imports one catalog; the pinned Jellyfin 12.x build.
- **Operator step:** the operator checks browse and playback in Infuse on
  Apple TV and on the Mac, and confirms the Trakt account is the one to sync.
- **Done when:** the operator confirms in Infuse on Apple TV and on the Mac
  that the full imported catalog is browsable and one title plays; each D-2
  open item is answered in the note; a failed pick is replaced by its
  alternative; each source's debrid-only option is recorded and a title's
  stream list shows no non-debrid entry; Trakt and Bazarr+ are confirmed on
  Jellyfin 12.x; if Infuse cannot browse the full imported catalog, the D-2
  failure branch applies (Stremio for browsing with Infuse as its external
  player) and the role proceeds; the throwaway run is removed and holds
  no token in any file other than 0600 files.
- **Dependencies:** none
- **Citations:** D-2, D-3, D-6 · REQ-A1.2, REQ-A1.4, REQ-B1.1, REQ-B1.5,
  REQ-D1.1
- **Estimated effort:** 2 days

### Task 2 — Media-server role: Jellyfin and AIOStreams under launchd

- **Deliverables:** `roles/media-server/` with a Darwin-only guard resolved
  through the inventory, installing the pinned Jellyfin, AIOStreams and Bazarr+ into the fleet
  account and running each as a launchd agent; no sudo and nothing
  outside the fleet account; added to `main.yml`.
- **Done when:** `yamllint` and `ansible-lint` pass; a run against the Mac
  (niced, with fallback) is idempotent on its second pass; VideoToolbox
  transcoding is confirmed in a Jellyfin playback log.
- **Dependencies:** 1
- **Citations:** D-1, D-2, D-5 · REQ-A1.1, REQ-C1.1, REQ-C1.4
- **Estimated effort:** 2 days

### Task 3 — Secrets, providers, plugins and catalogs

- **Deliverables:** the 1Password render of the provider tokens to 0600 files
  and the AIOStreams launch wrapper; the live-account check; Gelato and the
  D-3 plugins configured at their vetted versions, with the RemuxDB
  contribution off (verified in the plugin settings); the OpenSubtitles plugin and the Bazarr+ provider configured for Spanish;
  the Trakt plugin linked to the operator's account for watch history and
  lists; every source configured debrid-only with the AIOStreams filter
  (D-6).
- **Done when:** no token appears in any tracked file, plist, log or
  `ps` output (a scripted scan); each provider reports live or not live
  without printing a token; Spanish subtitles are selectable in Infuse; a
  watched title appears in Trakt.
- **Operator step:** the operator links their Trakt account in the plugin
  and regenerates each provider token into the agents vault.
- **Dependencies:** 2
- **Citations:** D-3, D-4, D-6 · REQ-B1.1, REQ-B1.2, REQ-B1.3, REQ-B1.4,
  REQ-B1.5, REQ-D1.1, REQ-D1.2, REQ-D1.3
- **Estimated effort:** 2 days

### Task 4 — Shared-Mac priority and network rules

- **Deliverables:** niceness and `ProcessType` for the runner and offload
  agents, the runner job-started check, off-hours library tasks, Jellyfin's
  bind and remote-bitrate settings, and a read-only check script that reports
  listeners, priorities and the transcode deferral, and fails on BitTorrent
  traffic from the fleet account's processes during playback (D-6).
- **Done when:** the check script reports only loopback, LAN and Tailscale
  listeners; a heavy job started during a test transcode defers and then
  runs; a test playback shows no BitTorrent traffic; the check is niced and falls back when the Mac does not answer.
- **Dependencies:** 2
- **Citations:** D-5, D-6 · REQ-B1.6, REQ-C1.1, REQ-C1.2, REQ-C1.3,
  REQ-C1.4
- **Estimated effort:** 1 day

### Task 5 — Runbook and remote verification

- **Deliverables:** the operator runbook in `docs/media-server.md` (Tailscale
  install and sign-in, Infuse setup, token regeneration, the D-3 caveats and
  the router-forwarding assertion).
- **Operator step:** the operator installs and signs in to the Tailscale
  app in the Mac owner's login, sets up Infuse on Apple TV and the Mac, and
  does the playback checks below.
- **Done when:** the operator, following only the runbook, plays a title from
  Infuse at home and over Tailscale away from the LAN.
- **Dependencies:** 3, 4
- **Citations:** D-3, D-5 · REQ-A1.3, REQ-D1.1
- **Estimated effort:** half day

## Awaiting input

(none yet)

## Deferred

(none yet)

## Out of scope

- Installing Tailscale, anything in the Mac owner's account, and any
  internet exposure: see Scope in `requirements.md`.
