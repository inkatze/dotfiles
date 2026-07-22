# Media Server Cleanup — Design

**Status:** Draft
**Last reviewed:** 2026-07-22
**Format-version:** 2
**Execution:** derived — see the status render

Origin tags: `N` = new decision, minted in the 2026-07-22 drafting session.

## Decision log

### D-1: Teardown ordering — supervisors before services  (N)

**Decision:** The machine teardown proceeds in this order: (1) bootout the
`com.inkatze.stremio-watchdog` launchd agent and remove its plist and logs;
(2) stop and remove the `stremio-server`, `zurg`, and `autoheal` containers
and delete their volumes; (3) remove `~/.config/stremio-server/`; (4) stop
Plex (helper launchd agent, then the server) and uninstall the Plex casks;
(5) remove leftover application data; (6) delete the
`OP_SERVICE_ACCOUNT_TOKEN` keychain entry last.

**Alternatives considered:**
- Arbitrary-order checklist. Rejected because: the watchdog restarts
  unresponsive containers (and colima itself) every 5 minutes, and
  autoheal restarts unhealthy containers — tearing services down under a
  live supervisor races the supervisor's recovery loop.
- Keychain entry first. Rejected because: deleting the credential before
  the services are gone gains nothing and removes the ability to re-render
  config if the teardown has to be aborted midway.

**Chosen because:** disabling the recovery layers first makes every later
step race-free, and deleting the credential last keeps the teardown
abortable until the destructive steps are done.

### D-2: Repo untracking lands before the machine teardown executes  (N)

**Decision:** The repo-side removal (Task 1) merges conceptually before the
teardown script runs on the machine (Task 3 depends on Task 1).

**Alternatives considered:**
- Machine-first. Rejected because: with the repo still tracking the stack,
  a `mise run stremio` or full playbook run in the window would re-create
  the config directory, re-render the zurg config, and restart the stack.

**Chosen because:** once the repo no longer knows about the stack, no
Ansible run can resurrect what the teardown removes; the ordering closes
the resurrection window at zero cost.

**Consequence the teardown script must honor:** after Task 1, the symlinks
in `~/.config/stremio-server/` (compose file, watchdog script) dangle
because their targets are deleted from the repo. The script therefore uses
direct `docker rm`/`docker volume rm` commands and `launchctl bootout` by
label, never `docker compose -f <symlink>` or any path into the repo.

### D-3: colima lifecycle tasks are retained and retagged  (N)

**Decision:** The colima tasks (brew service start, readiness wait, and
the mountInotify Gatekeeper-churn fix) stay in `roles/services/tasks/`
under tags `[services, colima]`, keeping the personal-host guard. The
`stremio` tag disappears with the stack.

**Alternatives considered:**
- Delete the colima tasks with the stremio block. Rejected because: colima
  hosts non-media dev containers and stays installed; unmanaged, the
  mountInotify fix would silently stop being enforced and a colima config
  reset would bring back the Gatekeeper "Verifying" churn the fix exists
  to prevent.
- Defer colima ownership to the future media re-add spec. Rejected
  because: colima's dev-container role is independent of media; leaving it
  unmanaged in the interim is a regression with no compensating benefit.

**Chosen because:** the fix is colima-generic (its own task comment says
so), colima's remaining consumer is dev tooling, and single Ansible
ownership resolves the dual-ownership concern recorded in obs:552c0512 —
the watchdog side of the dual ownership is removed, Ansible remains the
sole owner.

### D-4: Application removal via `brew uninstall --zap`  (N)

**Decision:** The three Plex casks and the untracked Stremio cask are
removed with `brew uninstall --zap`, followed by a manual sweep for
leftover `~/Library` paths the zap stanzas miss.

**Alternatives considered:**
- Plain `brew uninstall` plus hand-written `rm` list. Rejected because:
  the cask zap stanzas encode the cask author's maintained list of data
  paths (Application Support, Caches, Preferences, LaunchAgents);
  re-deriving that list by hand is strictly more error-prone.
- Manually dragging apps to Trash. Rejected because: leaves brew's cask
  bookkeeping stale and all data paths behind.

**Chosen because:** zap is the mechanism designed for exactly this, and
the post-zap sweep catches the residue (verified against the checklist in
`test-spec.md`, e.g. the ~589 MB Plex library measured during discovery).

### D-5: The teardown ships as a script that is deleted after verified execution  (N)

**Decision:** The machine teardown is an idempotent
`scripts/teardown-media-server.sh`, committed in the task PR, executed and
verified on the personal host, then removed in the spec's close-out
commit. Git history preserves it for the future re-add spec.

**Alternatives considered:**
- Keep the script permanently under `scripts/`. Rejected because: a
  one-shot teardown script with no remaining consumer rots in place and
  drifts from reality; history retention gives the same reference value.
- Runbook-only (ordered commands in the task block, no script). Rejected
  because: REQ-D1.2's idempotency proof wants a re-runnable artifact, and
  a reviewed script is testable in a way an agent re-deriving state per
  step is not.
- Ansible absent-state tasks. Rejected because: permanent declarative
  teardown code for a one-time removal is the heaviest option and would
  itself need removing later.

**Chosen because:** the script form gets review, ordering (D-1), and
idempotency (REQ-D1.2) into one testable artifact, while deletion after
verified execution keeps the repo free of dead tooling.

## Cross-cutting concerns

- **Escalated stake-bearing domains** (decision-domains catalog walk,
  2026-07-22): *Secrets & configuration* (keychain entry deletion,
  1Password service-account revocation) and *Data storage* (irreversible
  deletion of the Plex library and Docker volumes) were escalated to the
  human during elicitation and resolved as recorded in the requirements
  (full teardown; revocation as a manual task). No other catalog domain is
  touched: no auth, API surface, caching, queueing, observability,
  deploy/migration, dependency-adoption, or versioning decision arises
  from a removal.
- **Data hygiene:** no artifact of this spec repeats credential values,
  the rendered zurg config's contents, or LAN addresses; references name
  the item, never its value (REQ-C1.2).
