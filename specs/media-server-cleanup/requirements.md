# Media Server Cleanup — Requirements

**Status:** Ready
**Last reviewed:** 2026-07-22
**Format-version:** 2
**Execution:** derived — see the status render

## Goal

Remove the media-server stack — the Stremio/zurg/autoheal Docker services,
their watchdog, the Plex applications, and all supporting plumbing — from
both the dotfiles repo and the personal machine, leaving no tracked
config, running services, credentials, or local data behind. The removal is
deliberate and total ("full teardown"): a future spec will rethink and
rebuild the media setup from a clean slate, using this bundle and the git
history of the removed files as its reference for what existed and why it
was shaped that way. *(Cites: the invocation (Sources), drafting-session
decision (2026-07-22).)*

## Scope

### In scope

- The Stremio server stack tracked in `roles/services/`: the stremio task
  block in `tasks/main.yml`, `files/stremio/` (compose file, zurg config
  template, watchdog script), and the watchdog launchd plist template.
- The `[tasks.stremio]` entry in `mise.toml`.
- The `plex`, `plex-media-player`, and `plex-media-server` casks in
  `Brewfile.personal`.
- Machine-side teardown on the personal host: the running
  stremio-server/zurg/autoheal containers and their volumes, the watchdog
  launchd agent and its logs, `~/.config/stremio-server/` (including the
  rendered zurg config carrying the Real-Debrid token), the Plex
  applications and their local data (including the Plex library), the
  installed-but-untracked Stremio cask, and the `OP_SERVICE_ACCOUNT_TOKEN`
  keychain entry.
- Revocation of the 1Password service account whose only consumer was this
  stack (manual step).
- Regeneration of the Real-Debrid API token after the revocation (manual
  step, REQ-C1.3; the vault item itself stays).

### Out of scope

- Transmission (cask and app): stays installed and tracked.
- colima, docker, and docker-compose: they host non-media dev containers
  and stay installed and Ansible-managed (their lifecycle tasks are
  retagged, not removed — see REQ-A1.4).
- VLC and Infuse: standalone players, not server infrastructure.
- `resign-ipa.fish`: a general iOS sideloading tool; its default bundle-id
  string mentioning Stremio is inert and stays.
- The `my.cnf` management in `roles/services/`.
- The Real-Debrid credential item in the 1Password vault (deletion): the
  item outlives the service account that read it. Its token value is
  regenerated per REQ-C1.3; the item itself stays.
- The design of the future media-server re-add: a separate spec, which
  should cite this one.

## REQ-A — Repo untracking

- **REQ-A1.1** After removal, `roles/services/` SHALL contain no Stremio,
  zurg, autoheal, or watchdog tasks, files, or templates; the `my.cnf`
  management SHALL be retained unchanged.
  *(Cites: D-2, drafting-session decision (2026-07-22).)*
- **REQ-A1.2** `mise.toml` SHALL NOT define a `stremio` task.
  *(Cites: drafting-session decision (2026-07-22).)*
- **REQ-A1.3** `Brewfile.personal` SHALL NOT list the `plex`,
  `plex-media-player`, or `plex-media-server` casks.
  *(Cites: drafting-session decision (2026-07-22).)*
- **REQ-A1.4** The colima lifecycle tasks (service start, readiness wait,
  and the mountInotify Gatekeeper fix) SHALL be retained in
  `roles/services/` under tags `[services, colima]`, keeping the
  personal-host guard; the `stremio` tag SHALL cease to exist.
  *(Cites: D-3, obs:552c0512.)*
- **REQ-A1.5** A repo-wide search for stremio, zurg, plex, autoheal, or
  watchdog references SHALL return no matches outside `specs/`, git
  history, and the out-of-scope surfaces listed above (`resign-ipa.fish`).
  *(Cites: drafting-session decision (2026-07-22), kickoff §8 lens pass
  (2026-07-22).)*

## REQ-B — Machine teardown

All REQ-B requirements apply to the personal host the stack runs on.

- **REQ-B1.1** The `stremio-server`, `zurg`, and `autoheal` containers
  SHALL be stopped and removed, and the `stremio-server_stremio-data` and
  `stremio-server_zurg-data` Docker volumes deleted (compose-project-prefixed
  names as they exist on the host). *(Cites: D-1, kickoff §3 REQ-B
  (2026-07-22).)*
- **REQ-B1.2** The `com.inkatze.stremio-watchdog` launchd agent SHALL be
  booted out, its plist removed from `~/Library/LaunchAgents/`, and its
  log files removed from `/tmp/`. *(Cites: D-1, obs:552c0512.)*
- **REQ-B1.3** `~/.config/stremio-server/` SHALL be removed entirely,
  including the rendered zurg config file carrying the Real-Debrid token.
  *(Cites: D-1.)*
- **REQ-B1.4** Plex SHALL be stopped (the `tv.plex.player-helper` launchd
  agent and the Plex Media Server process), and the three Plex casks uninstalled with their
  application data zapped, including the Plex library under
  `~/Library/Application Support/`. *(Cites: D-1, D-4.)*
- **REQ-B1.5** The installed-but-untracked Stremio cask SHALL be
  uninstalled with its application data zapped. *(Cites: D-4.)*
- **REQ-B1.6** The `OP_SERVICE_ACCOUNT_TOKEN` generic-password keychain
  entry SHALL be deleted. *(Cites: D-1.)*
- **REQ-B1.7** colima, the docker tooling, and non-media containers (the
  Firebird dev container) SHALL remain installed and functional after the
  teardown. *(Cites: D-3, obs:552c0512.)*

## REQ-C — Credentials

- **REQ-C1.1** The 1Password service account whose only consumer was the
  media stack SHALL be revoked by the human after the machine teardown
  completes. *(Cites: drafting-session decision (2026-07-22).)*
- **REQ-C1.2** No committed artifact of this spec (bundle files, teardown
  script, PR bodies) SHALL contain secret material — tokens, credential
  values, or the rendered zurg config's contents.
  *(Cites: drafting-session decision (2026-07-22).)*
- **REQ-C1.3** After the service-account revocation, the Real-Debrid API
  token SHALL be regenerated by the human in the Real-Debrid dashboard and
  the vault item's value updated in place, invalidating the copy that
  existed in plaintext in the rendered zurg config; the vault item itself
  SHALL be retained. *(Cites: kickoff §8 lens pass (2026-07-22).)*

## REQ-D — Verification

- **REQ-D1.1** After untracking, `yamllint`, `ansible-lint`, and a full
  playbook run SHALL complete cleanly, with no task referencing the
  removed stack. *(Cites: D-2.)*
- **REQ-D1.2** The machine teardown SHALL be idempotent: a second run of
  the teardown script SHALL complete as a no-op. *(Cites: D-5.)*
- **REQ-D1.3** Completion SHALL be evidenced by the verification checklist
  in `test-spec.md`: no media containers, volumes, launchd agents,
  applications, application data, or keychain entry remain, and REQ-B1.7's
  survivors are intact. *(Cites: D-1, D-5.)*

## Changelog

- 2026-07-22 — Bundle drafted via `/spec-draft`; scope, depth (full
  teardown), colima retention, and 1Password handling decided in the
  drafting session.
- 2026-07-22 — Kickoff walkthrough precision edits (host-verified):
  word-bounded the REQ-A1.5 sweep pattern (`-iwE`), corrected the Docker
  volume names to their compose-project-prefixed forms in REQ-B1.1 /
  Task 2 / test-spec, and pinned the Plex helper label
  `tv.plex.player-helper` in D-1 / Task 2 / test-spec REQ-B1.4; scoped
  test-spec REQ-C1.2's lefthook clause to lint only (the repo has no
  general secret scanner — review at Tasks 2/5 is the verification).
- 2026-07-22 — Kickoff sign-off lens pass (21 findings applied, operator-
  approved): D-1 refined (autoheal removed first among the containers,
  in-flight watchdog invocation drained after bootout, Plex-stop verified
  before zap, the untracked Stremio cask placed in step 4, the stale
  abortability rationale corrected); Task 2 guard semantics (absent vs
  undeterminable, docker-daemon reachability) and Done-when timing fixed;
  Task 3 host-sync precondition added; REQ-A1.5 sweep extended to
  autoheal/watchdog; REQ-B1.4 helper attribution corrected; REQ-C1.3
  minted (Real-Debrid token rotation, operator decision) with Task 4 and
  test-spec updates; test-spec tightened (my.cnf-unchanged, B1.5 residue,
  A1.4 guard/tag, B1.7 running, C1.2 Task-3 checkpoint, D1.1 absence
  clause, intro tag accounting); out-of-scope lists synced; design.md
  cross-cutting domain accounting aligned with the kickoff gap check.

## Sources

- **The invocation** (2026-07-22): "cleanup the media server stuff I have
  from my dotfiles and this machine. I'll add them back later and
  rethink." Scope, the full-teardown depth, and the exclusion of
  Transmission were confirmed as drafting-session decisions on the same
  date.
- **obs:552c0512** (recorded 2026-07-15, consumed by this spec): the dual
  ownership of colima's lifecycle between Ansible and the stremio
  watchdog. Removing the watchdog resolves the concern; the colima tasks'
  retag (REQ-A1.4, D-3) records the surviving single owner.
- **Discovery survey** (drafting-session decision (2026-07-22)): a
  read-only sweep of the repo and the personal machine that produced the
  removal inventory — the `roles/services/` stremio block, the compose
  stack and its volumes, the watchdog agent, the Plex casks/apps/library,
  the untracked Stremio cask, and the keychain entry.
