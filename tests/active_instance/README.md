# Active Instance acceptance tests

These tests specify the behavior in [`docs/active-instance-roadmap.md`](../../docs/active-instance-roadmap.md). The suite was written red before implementation and now checks the production implementation. Production files are copied unchanged into a disposable Godot project.

## Run

From the repository root:

```sh
python3 tests/active_instance/run.py
# Optional executable override:
GODOT=/path/to/godot python3 tests/active_instance/run.py
# Optional real-display checks (requires a reachable desktop display):
python3 tests/active_instance/run.py --display
# Optional screenshot directory:
python3 tests/active_instance/run.py --display --artifacts /tmp/opencode/active-instance-visual
```

Requires Python 3, Godot 4 and loopback networking. Verified initially with Godot 4.7.2. The runner uses headless Compatibility rendering and an ephemeral loopback relay port, not `7374`. It never starts the normal game, loads an account from disk, writes real user settings/profiles, contacts an external relay, downloads worlds or starts physical microphone/XR capture. RSA keys are generated in memory. The temporary project lives under `/tmp/opencode` when available and is removed after the run.

Exit codes:

- **0:** all assertions passed and no dependent groups were deferred.
- **1:** acceptance assertions failed (the original pre-implementation result).
- **2:** infrastructure error, Godot import/runtime error, process timeout or missing executable. Errors are not accepted as red-test evidence.

The suite continues through failed assertions so current working behavior remains visible. Every absent prerequisite causes a failing assertion and prints the dependent group as **NOT RUN**. Missing APIs never silently count as passing behaviors. No unconditional failure placeholders or expected-failure annotations are used.

### Initial verified red result

`python3 tests/active_instance/run.py` with Godot 4.7.2: **10 passed, 16 failed, 5 dependent groups not run**, exit **1**, with no Godot import/runtime errors. Failures identify old tab labels, missing code/roster/profile-name/count presentation, missing disconnected controls/status, missing authoritative coordinator state, whitespace-only instance-name acceptance and four missing management packet types. Passing checks cover existing lifecycle/privacy/network behavior; they do not imply the new feature works.

### Verified implementation result

With Godot 4.7.2: **125 passed, 0 failed, 0 dependent groups not run**, exit **0**. Includes actual encoded voice packets between same-instance clients, isolation from another instance, and rejection of both outgoing/incoming instance voice after eviction. These checks validate routing, not audible playback.

Relay-lifecycle coverage now checks removal of authentication/profile/challenge mappings, cross-user management caches, disconnected-target bans and authored metadata; a scan of application-owned relay collections for the departed account's key/fingerprint; idempotent cleanup and empty fresh-relay state; no project-file creation during the loopback relay lifecycle; client-local moderation persistence, wrong-account/corrupt-file preservation; and fresh admission rejection via moderator-client policy after reconnect. Missing policy, pending-candidate disconnect and moderator timeout fail closed while preserving previous membership. See `docs/relay-data-lifecycle.md` for exact guarantees and limitations.

Ban history is now stored on admin clients, not retained on the relay after the target disconnects. Wire IDs 21–23 add admission queries/replies and client policy events. Every current admin must approve a moderated join; policy does not automatically transfer to new admins, so missing policy closes admissions rather than silently forgetting bans. Transport-only test peers use in-memory client policy; persistence tests explicitly use disposable `res://` fixtures, not real user data.

Display-backed run: **27 passed, 0 failed**, exit **0**, on X11 / Intel UHD 630 OpenGL Compatibility rendering. Exact 1000×700 and 640×480 GPU viewports are displayed in a real window (the tiling compositor controls the top-level window size). Checks cover metadata placement, roster/action bounds, editor Save visibility, actual clipboard round-trip with previous contents restored, focus traversal, profile/Back, confirmation bounds, long names and crowded roster scrolling. Screenshots are saved under `/tmp/opencode/active-instance-visual` by default. Screenshot review found and corrected an oversized fingerprint confirmation; long player names now ellipsize instead of displacing moderation controls. The renderer logged failed NVIDIA driver probes before successfully using Intel; no Godot runtime/import errors occurred.

Regression runners also passed: profile **109**, discovery **51 + 24 startup**, microphone/settings **92**. Profile and microphone/settings runs emitted ObjectDB leak warnings; these isolated results do not establish leak-free full-game behavior.

## Coverage

### Original production-entry-point coverage

- Shared menu scene title/metadata and desktop label override; VR player has no obsolete override. Player scenes are inspected as text rather than importing their capture/XR dependencies.
- Actual `share_session_menue.tscn` and production `_ready()` path: acknowledged session code, initial roster including self, profile names, clickable names, complete count, disconnect cleanup, disabled Copy and no-instance state.
- Relay discovery isolation/privacy, last-admin succession and shared creation-field validation, including a currently accepted whitespace-only name that should be rejected.
- Four actual ENet clients authenticate to the production relay with ephemeral accounts, create two instances of the same URL, and exchange membership scoped to the exact instance.
- Required management protocol availability, explicitly failing before trying unsupported messages.

### Originally prerequisite-gated contracts

These contracts now execute against the implemented APIs. The historical initial red run did **not** execute them; prerequisite guards remain so a removed API reports a failure and explicit deferred group instead of crashing the harness.

- Real coordinator snapshot validation, exact-session/revision filtering, malformed data and conflicting replay rejection, live menu metadata updates, roster/count independent of profile arrival, duplicate display names, departure and reopen behavior.
- Actual name-button signals open the existing profile scene for the correct fingerprint; remote profiles remain read-only, self profiles remain editable, and Back returns to Active Instance.
- Admin-only adjacent Kick/Ban/Make admin controls, no self-kick/ban, permission loss and disconnect cleanup.
- Real encoded management requests and correlated results through production relay dispatch: non-admin and cross-instance denials, target identity mismatch, self-actions, unknown actions, invalid field types/lengths/modes, immutable world URL, stale revisions, successful metadata editing, discovery visibility changes and promotion.
- Kick eviction with relay connectivity preserved, explicit rejoin after kick, account-scoped ban, same-request-ID retry, reconnect with the same key and joining a different instance of the same world after a ban.

## Proposed test-facing contracts

These are the test-facing interfaces adopted by the implementation. They are **not** implementations supplied by fixtures. If implementation chooses equivalent APIs later, update adapters here while retaining the behavioral assertions.

- `NetworkHandler.active_instance: Dictionary`, `active_instance_changed` signal and `_on_instance_snapshot(snapshot: Dictionary)` entry point. Tests use the real coordinator autoload, not a fake state owner.
- Active state matches the roadmap: `session_id`, nonnegative monotonic `revision`, `world_url`, `name`, `description`, `mode`, and complete `members: [{peer_id, fingerprint, role}]`. Role strings are `admin` and `member`. Wire JSON numbers may decode as floats, so revision assertions compare integer values.
- Player row roots expose `fingerprint` metadata exactly once per participant. Player-name buttons use the profile name; self may append a You marker. Controls use labels `Kick`, `Ban`, `Make admin`, `Copy code`; the count is `Players (N)` and disconnected status includes `No active instance`. Resource/node paths stay at the existing names for now.
- Explicit unused packet enum keys: `INSTANCE_REQUEST`, `INSTANCE_RESULT`, `INSTANCE_SNAPSHOT`, `INSTANCE_EVICTED`. These tests do not prescribe their numeric IDs. Management payloads use the roadmap's one-byte packet type plus JSON-object convention, encoded directly by the tests so relay checks cannot be bypassed by a client helper.
- `INSTANCE_REQUEST`: `request_id`, `session_id`, `expected_revision`, `action`, `changes`, and for targeted operations `target_fingerprint`/`target_peer_id`. Actions are `update_metadata`, `kick`, `ban`, `make_admin`.
- `INSTANCE_RESULT`: matching `request_id`/`session_id`, boolean `success`, nonempty `error_code` on rejection. A repeated request ID yields its original result without another mutation.
- `INSTANCE_SNAPSHOT` carries the state object directly. `INSTANCE_EVICTED` carries `session_id` and reason `kicked`/`banned`; production client dispatch clears current session/peer state while keeping the relay connected.

The recording peer fixture only records raw received management messages, then calls production packet dispatch. It does not generate management results, roles, permissions, rosters or bans. SaveData/DataLoader fixtures replace account persistence and heavy resource loading, not feature behavior.

## Deliberate limits / remaining roadmap tests

Additional implementation coverage exercises the actual metadata editor Save/Cancel, draft preservation/rejection and revision conflicts; Ban confirmation with fingerprint/peer guard; unmatched results, management timeout with refresh, state restoration and real coordinator eviction cleanup. A transport-only request sink records requests made by the real coordinator; it does not supply management behavior. Snapshot validation also checks malformed identities, fractional peer IDs, duplicate members and unknown roles. Signed-profile fixtures now use valid HTTPS avatar URLs: the initial empty URLs failed the existing profile signature/schema validation and incorrectly prevented the profile-dependent tests from exercising their intended path. No production profile validation was relaxed.

This is not complete release coverage. Still to add: unauthenticated/forged-actor/oversized malformed-wire traffic, comprehensive result reordering and connection-generation replay, transitions during requests, movement suppression on the actual wire after eviction, ban expiry on instance deletion/restart, full profile-departure/peer-ID-reuse navigation, and old-relay compatibility. The current identity-mismatch check covers target binding but is not a complete peer-ID-reuse integration test.

Remaining hardware/manual checks: actual headset rendering, VR controller hit targets/navigation, physical microphone and human multi-client listening/spatial playback. The display suite enumerates XR interfaces only; finding the OpenXR interface is not evidence of an available headset or a running XR session. Display tests use Dummy audio and network tests use synthetic PCM; neither records the physical microphone or claims audible listening. Profile/discovery/microphone regression runners remain separate.
