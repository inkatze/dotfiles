# Media Server — Test Spec

**Status:** Draft
**Last reviewed:** 2026-11-26
**Format-version:** 2
**Execution:** derived — see the status render

Coverage mix: the Mac and the operator's players are not reachable from CI,
so the behaviour REQs are `[manual]`, run from the Tasks 1 to 5 checks with
`ssh mac` read-only and niced; role hygiene is `[test]` through the
repository's `yamllint` and `ansible-lint` CI.

### REQ-A1.1 — native Jellyfin under launchd [test + manual]

CI lints the role. Manual: the launchd agent is loaded in the fleet account,
no container runs, and a transcode log shows VideoToolbox.

### REQ-A1.2 — full catalog browsable in Infuse [manual]

The operator opens an imported catalog in Infuse on Apple TV and on the Mac
and pages past the first screen; a title plays.

### REQ-A1.3 — home and remote playback [manual]

A title plays at home and over Tailscale off the LAN, the latter transcoded
under the configured remote bitrate cap.

### REQ-A1.4 — Stremio external-player fallback [manual]

The runbook section exists and, on a bridge that fails REQ-A1.2, the operator
opens a title in Stremio and plays it in Infuse.

### REQ-B1.1 — both providers [manual]

The live-account check reports each provider live; with one provider's token
removed, the other still resolves a stream.

### REQ-B1.2 — tokens only in 0600 files [manual + test]

A scripted scan of the tracked tree, the plists, the logs, `ps` output and
the fleet home finds no token value outside 0600 files; file modes are
asserted.

### REQ-B1.3 — no resident credential [manual]

The keychain and the fleet home hold no `op` or service-account credential.

### REQ-B1.4 — live check prints no token [manual]

The check's output and logs contain only live or not-live.

### REQ-B1.5 — debrid-only streams [manual]

For a sample of titles, each source's stream list (through AIOStreams, and
the Stremio fallback's list) contains no magnet or info-hash-only entry; with
no debrid token configured the sources return no playable stream.

### REQ-B1.6 — no BitTorrent traffic [manual]

The Task 4 check script, run during a playback, reports no torrent-client
process, BitTorrent-style listener or peer connection among the fleet
account's processes; a planted torrent-style listener makes it fail.

### REQ-C1.1 — no sudo, fleet account only [test + manual]

The role contains no `become`; a diff of the owner's account and Homebrew
before and after a run is empty.

### REQ-C1.2 — shared-Mac priority [manual]

Runner and offload agents show the lowered priority; a heavy job started
during a transcode defers; library tasks are scheduled off-hours.

### REQ-C1.3 — listeners [manual]

The check script lists only loopback, LAN and Tailscale listeners; the
router-forwarding assertion is recorded by the operator.

### REQ-C1.4 — niced, with fallback [manual]

With `ssh mac` unreachable the check falls back at once without retrying.

### REQ-D1.1 — vetted set only [manual]

Installed versions match the Task 1 note; each caveat appears in the runbook.

### REQ-D1.2 — Spanish subtitles [manual]

A Spanish track arrives through the OpenSubtitles plugin or Bazarr+ and is
selectable in Infuse for a title.

### REQ-D1.3 — Trakt sync [manual]

A title watched in Infuse appears in the operator's Trakt history, and a
Trakt list appears in Jellyfin.
