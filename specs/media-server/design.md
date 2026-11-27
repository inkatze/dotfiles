# Media Server — Design

**Status:** Ready
**Last reviewed:** 2026-11-26
**Format-version:** 2
**Execution:** derived — see the status render

Origin tags: `N` = new decision, minted in the 2026-11-26 drafting session.
Research was read on 2026-11-26; vendor claims are marked as such. Release
dates on the pages read showed day and month only, so "maintained" below means
a release or tag within roughly the last few months; Task 1 re-verifies each
pick against its own repository before anything installs.

## Decision log

### D-1: Native Jellyfin under launchd in the fleet account  (N)

**Decision:** Run the upstream native macOS Jellyfin build, with its bundled
ffmpeg and VideoToolbox transcoding, as a launchd user agent of the fleet
account, installed from a pinned release archive into that account's home.
The Jellyfin major version is the current stable 12.x line, the operator's
decision (Sources, requirements.md), which is also what Gelato's README
targets.

**Alternatives considered:**
- Staying on 10.11 with Gelato's frozen final 10.11 build. Rejected because:
  the operator chose current 12.x, and the bridge's active releases target it.
- Docker or colima containers. Rejected because: hand-wired containers were a
  teardown reason, the Mac has no container runtime in the fleet account, and
  containers cannot reach the media engine.
- Homebrew cask. Rejected because: Homebrew belongs to the Mac owner's
  account (mission-control rule r-3).
- A hosted bridge service. See D-2.

**Chosen because:** Jellyfin's Apple hardware-acceleration docs describe
VideoToolbox use on Apple silicon, a native build needs no runtime beyond
launchd, and launchd's own restart-on-exit replaces the home-made watchdog.

### D-2: Gelato plus a self-hosted AIOStreams as the bridge  (N)

**Decision:** Use the Gelato Jellyfin plugin (GPL-3.0) backed by an AIOStreams
instance (AGPL-3.0) run by the fleet account. Gelato imports chosen addon
catalogs into ordinary Jellyfin libraries on a schedule, so any Jellyfin
client, Infuse included, browses them; streams resolve at play time and are
proxied through Jellyfin so the debrid service sees one IP. AIOStreams
aggregates addons and debrid services and lists Real-Debrid and AllDebrid
under its services.

Open items Task 1 must settle before the build: Infuse browsing and playing a
Gelato-imported library end to end (the Gelato tracker has closed Infuse
issues and merged Infuse-related fixes, but no page read states it works);
how AIOStreams stores its configuration and keys at rest and whether it runs
natively on Node in the fleet account; Gelato's plugin configuration at rest;
and that the pinned Gelato build pairs with the pinned Jellyfin 12.x.

**Alternatives considered:**
- JellyStreams (ElfHosted). Rejected because: closed source and runs only on
  the vendor's hosting, so debrid keys would live with a third party (vendor
  claims, not independently verified); it does present catalogs as browsable
  shelves in Infuse. The operator also declined a hosted bridge as the
  fallback (below).
- Polyfin and Remux (Jellyfin-compatible servers of their own). Rejected
  because: Polyfin is an early preview and both replace Jellyfin rather than
  using the transcoding and plugin set this spec wants; Remux stays the
  fallback if Gelato's upstream moves to it, as its README suggests.
- Jfresolve (plugin). Rejected because: it fills libraries from TMDB
  trending, popular and top-rated lists, not full addon catalogs; the pages
  read mention Real-Debrid only, show no license, and it requires Jellyfin
  12.4 or later.
- `.strm` generators (jf-resolve). Rejected because: they generate files
  rather than a live catalog, and re-create the hand-wired-script shape.
- Plain Stremio on Apple TV. Not possible: the vendor guide says there is no
  Apple TV Stremio app.

**Chosen because:** it is the only option read whose catalogs become real
library items (the full-catalogue requirement), that keeps credentials on the
Mac, that is open source, and that was releasing within days of this draft
(Gelato v0.26.31.0, 24 Nov 2026; AIOStreams nightlies the same week, with no
stable tag seen on the first page). The unverified items above are the reason
Task 1 is a gate. **Failure branch (operator decision):** if Infuse cannot
browse a full Gelato-imported catalog, the fallback is Stremio for browsing
with Infuse set as its external player, in the operator's words "we can use
stremio or something and use it as a external player. I'm fine with that".
That is neither a stop nor a hosted bridge: Jellyfin and the role still ship
for transcoding and library playback, and the runbook documents the
Stremio-plus-external-player path for browsing.

### D-3: Recommended catalog, addon and plugin set  (N)

**Decision:** One recommended set, installed only at versions Task 1 records
as vetted:

- Catalog and metadata through AIOStreams: the TMDB addon (Apache-2.0; needs
  the operator's own TMDB and Fanart.tv API keys; optional Trakt and MDBList
  list integration) for catalogs and metadata in the operator's languages.
- Stream sources through AIOStreams with both debrid services, all three
  included at the operator's request, in this order of preference: Comet
  (GPL-3.0; lists Real-Debrid and AllDebrid; includes a peer network that
  shares torrent metadata, which can be left off), then MediaFusion (MIT),
  then Torrentio (Apache-2.0). The order is a drafting-session choice:
  Comet's README names both required debrid services and metadata options;
  MediaFusion's names both too and carries an explicit personal-use
  disclaimer; Torrentio goes last because its last-commit date was not
  visible, so its maintenance is the least verified of the three. Task 1
  re-checks each and may reorder.
- Jellyfin plugins: Gelato; the official Trakt plugin for watch-history and
  list sync, which the operator uses (it supports 10.11; the newest release
  read is from this year; no 12.x statement seen, so Task 1 checks it against
  the pinned Jellyfin 12.x); the official OpenSubtitles plugin plus
  Bazarr+ for Spanish subtitles, the operator's choice (the Bazarr+ plugin
  is a 10.11+ provider needing a self-hosted Bazarr+ backend, which the role
  runs as a third launchd agent; no release was listed on the page read, so
  Task 1 verifies both, 12.x support included).

The operator accepted the legal and terms-of-service responsibility for these
sources ("can we do 1 and 2?", answering an offer to accept Comet then
MediaFusion or Torrentio first, read as accepting all three). Caveats, stated
plainly and carried into the runbook: the stream sources
(Comet, MediaFusion, Torrentio) scrape torrent indexers and resolve through
debrid services, so what they return may be copyrighted material; the
operator is responsible for the law where they live and for each debrid
provider's terms of service; the project READMEs disclaim endorsement of
infringement and say the same. Gelato sends an IMDb id and a random install
id to a third party (RemuxDB) by default; Task 3 turns this off, the
operator's decision ("Turn it off (Recommended)"). The TMDB addon needs third-party API keys under the
operator's own accounts. Every plugin outside Jellyfin's official catalog is
third-party code running inside the server; Task 1 records each one's
license and last release.

**Alternatives considered:**
- Torrentio first. Rejected because: its last-commit date was not visible,
  so it ranks below the two sources whose pages state both required debrid
  services; it stays included at the operator's request.
- Subbuzz for subtitles. Rejected because: it supports only the
  opensubtitles.com domain, which the official plugin already covers.
- WhisperSubs (local AI subtitle generation) as the Spanish fallback.
  Rejected because: the operator chose the OpenSubtitles-plus-Bazarr+ option
  over an AI-translated fallback.
- No third-party plugins beyond Gelato. Rejected because: the operator asked
  for a good set, and Spanish subtitles need one.

**Chosen because:** each pick is open source, lists the required providers or
languages in its own README, and was read on its project page; the
unverified-maintenance cells are what Task 1 closes.

### D-4: Secrets through the agents vault, rendered 0600, no resident credential  (N)

**Decision:** Real-Debrid and AllDebrid tokens (each regenerated by the
operator into the personal 1Password agents vault) are read on the operator's
controller at playbook time and written to the fleet account as 0600 files
that the AIOStreams launch wrapper reads into its environment; a launchd plist
carries only the file path, never a value. The Mac holds no `op` credential
and no service-account token. A live-account check calls each provider's
account endpoint from the wrapper's environment and prints only
live/not-live.

**Alternatives considered:**
- A service-account token in the keychain so the Mac can read 1Password.
  Rejected because: it is a teardown reason.
- Tokens in plist `EnvironmentVariables` or the Jellyfin plugin XML. Rejected
  because: both are world-readable by default or logged; Task 1 confirms what
  Gelato's configuration holds (an AIOStreams URL, not a raw token).
- A manual copy of the token on the Mac. Rejected because: the render path is
  repeatable and keeps the vault the only source.

**Chosen because:** it removes both secret-handling teardown reasons without a
resident credential, and reuses the repo's existing render-from-1Password
pattern.

### D-5: Shared-Mac priority, network and checks  (N)

**Decision:** Jellyfin runs with launchd `ProcessType` Interactive; the CI
runner and offload agents get a lower niceness and `ProcessType` Background,
and the runner's job-started hook defers heavy jobs while a Jellyfin
ffmpeg process (the transcoder) is alive, a process check that needs no API
key. Scheduled library scans and thumbnail tasks are set to off-hours.
Listeners are bound to loopback (AIOStreams) and to the LAN and Tailscale
interfaces (Jellyfin) through Jellyfin's own network settings, since no
firewall change is possible without sudo; that nothing is forwarded from the
router is an operator assertion, recorded in the runbook. Remote playback is
Infuse over Tailscale with Jellyfin's remote bitrate cap set to a home-upload
value. Every check of the Mac runs `nice` through `ssh mac`, read-only, and
falls back to the controller when the Mac does not answer.

**Alternatives considered:**
- Pausing CI while anyone streams. Rejected because: it starves CI during
  direct play, which costs the Mac nothing.
- A macOS firewall rule. Rejected because: it needs sudo (REQ-C1.1).
- Tailscale in the fleet account. Rejected because: the operator chose the
  standard app, which installs in the owner's login.

**Chosen because:** it enforces the shared-Mac priority inside the fleet
account with the tools available there.

### D-6: Debrid-only streams and a no-BitTorrent-traffic check  (N)

**Decision:** Every stream source is configured to return debrid-resolved
streams only, and AIOStreams, the single point every source feeds, also drops
any result that is not served through a debrid service (a magnet or bare
info-hash result). Per source: Torrentio, Comet and MediaFusion each carry a
debrid provider in their addon configuration (Real-Debrid or AllDebrid) with
the setting that omits non-debrid results where the source offers one; Task 1
records each source's documented option and proves it by listing the streams
for a title and finding no non-debrid entry. The Stremio fallback (D-2)
installs AIOStreams as its only stream addon, so Stremio's own torrent
engine never receives a magnet. A read-only check run during playback lists
the fleet account's processes' network sockets and fails on a torrent
client process, a BitTorrent-style listener, or a peer connection; it covers
the fleet account because capturing packets machine-wide needs sudo
(REQ-C1.1), a limit the runbook states.

**Alternatives considered:**
- Trusting each addon's setting alone. Rejected because: one misconfigured
  source would reintroduce P2P silently, so the shared filter and the
  traffic check are the backstops.
- A machine-wide packet capture. Rejected because: it needs sudo.

**Chosen because:** the operator made debrid-only a hard rule, and a rule
that is configured in the sources, filtered at the choke point and checked on
the wire fails in one place at a time.

## Cross-cutting concerns

- **Hostnames and addresses:** the Mac's alias and addresses come from the
  machine-local host file and inventory, never a tracked file.
- **Operator steps** (never a worker's): installing Tailscale, signing in to
  it, configuring Infuse on both devices, regenerating the provider tokens
  into the vault, and the legal and terms-of-service acceptance in D-3.
