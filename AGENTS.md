# Repository guidance

## Commit and publication workflow
- Use Conventional Commits for every commit: `type(scope): description` (for example `feat`, `fix`, `docs`, `test`, `refactor`, `build` or `ci`). Mark real compatibility breaks with `!` and a `BREAKING CHANGE:` explanation; do not label documentation as a feature or fix.
- Work in small, coherent, independently verified parts. For bug fixes, reproduce the issue with a failing test first, then fix it and commit the passing unit with its tests. Do not publish broken intermediate snapshots merely to make commits smaller.
- Commit and push each completed verified part to the current branch's configured upstream, as requested by the repository owner. Review explicit staged paths and `git diff --cached --check`; never include unrelated user files, accounts, generated caches or private data. Do not force-push, rewrite history or change branches/remotes implicitly. If push is rejected or verification fails, report the blocker rather than bypassing it.
- Use ordinary Git commands for repository publication/versioning. Do not add GitHub workflows or use GitHub CLI, APIs, Actions, or other GitHub-specific tooling. Planned release automation must work locally through scripts and opt-in Git hooks, without a hosting-provider dependency.
- Planning documents belong under `docs/roadmaps/`; use its index for status/supersession and do not treat historical plans as current behavior.

## Runtime and wiring
- `project.godot` declares Godot **4.7**, Forward Plus and Jolt Physics; the isolated tests use Compatibility rendering instead and do not validate the full renderer/XR stack.
- The UID main scene resolves to `scenes/startup.tscn` → `scripts/startup/main.gd`. Startup loads the account, authenticates with the relay, then loads `scenes/world.tscn`; the local player is added under the scene-tree root so it survives world changes.
- Startup checks `OS.get_cmdline_args()` for `--non_vr` (desktop) and `--relay` (server). The `dedicated_server` feature also selects the relay scene. The **Linux export preset is a dedicated server**, not a desktop client; its configured output path points outside the repo.
- Autoloads are `DataLoader` (`scripts/startup/data_loader.gd`), `SaveData` (`scripts/settings/save_data.gd`) and `NetworkHandler` (`scripts/multiplayer/network_handler.gd`). Preserve their initialization ordering: settings/mute load before player capture starts.
- Normal startup can create `user://user.key`, migrate settings and write profiles. Prefer the isolated runners below for automated checks rather than launching the main scene against real user data.

## Focused verification
Run from the repository root with Python 3 and Godot available as `godot`:

```sh
python3 tests/microphone_settings/run.py
python3 tests/profile/run.py
python3 tests/public_discovery/run.py
python3 tests/active_instance/run.py
python3 tests/friends/run.py
python3 tests/avatar_loading/run.py
```

- Override the executable per command with `GODOT=/path/to/godot python3 tests/<suite>/run.py`.
- Each runner copies production code into a disposable project (under `/tmp/opencode` when available), imports it to register `class_name` scripts, then runs headless GDScript assertions. Use the runner, not a direct `--script` invocation in the game project: fixtures replace autoloads and exclude real accounts, external HTTP, VR and physical capture.
- Profile/discovery tests require loopback networking on ephemeral ports, not an external relay. Discovery runs both `suite.gd` and a second `startup_suite.gd` with the real NetworkHandler.
- Assertion failures exit 1; runners treat Godot `ERROR:` output as infrastructure failure (usually exit 2). Check skipped prerequisite groups too; a partial suite is not full coverage.
- `tests/.gdignore` intentionally excludes these scripts from the main project's import. If production code gains dependencies, update the runner's copied sources/fixtures as needed; it does not use the full repository project.
- These suites do not replace manual microphone/device, VR, avatar rendering or multi-client listening checks. Coverage details are in `tests/profile/README.md` and `tests/microphone_settings/README.md`; recorded pass counts there are historical, not a current baseline.

## Change boundaries and compatibility
- Project-wide relay privacy/lifecycle rule: no durable user/session data; keep only temporary state for active connections and delete all disconnected-user data, including indirect references in surviving users' caches, bans and subscriptions. Persistent contacts, consent and moderation policy are client-owned. `docs/relay-data-lifecycle.md` documents cleanup and client-owned admission: moderated joins need fresh approval from all current admins, and missing policy/support fails closed. Never restore disconnected-target relay ban history just to make reconnect tests pass.
- Multiplayer uses custom ENet packets: client state/acknowledged world transitions live in `scripts/multiplayer/network_handler.gd`, relay membership/authentication in `scripts/multiplayer/relay.gd`, and wire encoding in `relay_protocol/`. Client defaults to `127.0.0.1:7374`; production relay binds `0.0.0.0:7374`.
- A world URL identifies content; `session_id` identifies an instance. Do not join by URL alone or merge instance membership/profiles across instances of the same world. World downloads are staged/validated before acknowledged session transitions activate them.
- Preserve existing compatibility spellings such as `default_wold` (built-in world identifier and legacy config key), `load_acount`, `laod_data` and packet enum names; packet IDs in `relay_protocol/packet_info.gd` are explicit wire values, not freely reorderable enum positions.
- General settings are registry-driven (`scripts/settings/settings_registry.gd` → `settings_store.gd` → `scripts/GUI/settings_menue.gd`). Profile editing is separate: `SaveData.profile` owns signed, key-scoped profiles stored at `user://profiles/<fingerprint>.cfg`; do not reintroduce profile fields into general settings or bypass service-level ownership checks.
- `SaveData.friends` owns signed client-local contacts, consent events/tombstones/outbox and status preference at `user://friends/<fingerprint>.cfg`. Cached friend profiles are separate from instance-only `SaveData.profile.remote`. Social wire ID 24 requires capability negotiation; relay `FriendRouter` stores active-connection data only and clears pairwise references on disconnect. Saved contacts or presence alone never grant instance access or profile editing; instance friendship authorization is described below.
- Instance Friends/Request access checks direct fresh mutual grants with any current admin; Friends+ permits at most two mutual edges through connected relay users. Request additionally needs explicit admin approval; bans/moderator policy still apply. Non-public code lookup is authenticated (IDs 25–27); never expose these instances through public discovery or keep disconnected friendship edges. Friendship alone does not bypass these checks or grant profile editing.
- `SaveData.voice` is the persistent mute/input owner shared by desktop/VR capture; avoid independent UI/player mute state. Corrupt account keys, settings and signed profiles are preserved for recovery rather than silently replaced.
- Avatar DataLoader buffer/file imports are asynchronous worker-thread jobs. Await their results; do not access the active SceneTree or globally register per-request GLTF extensions from workers. Models are detached until callers attach them on the main thread. Preserve avatar generation guards and URL-change checks to avoid duplicate/stale loads.
- `docs/roadmaps/*roadmap.md` mixes implementation status with historical findings and proposed interfaces. Verify against current scripts and executable suites before treating a roadmap claim as current behavior.
