# Key-owned profile acceptance tests

Layout redesign result: **89 checks pass**. Tests cover owner-only popup editing, Save/Cancel/conflict/error draft retention, local-file image preview without changing public sources, two-column positioning at two sizes, independent preview World3D/model, finite framing, reset, hidden cleanup, stale-result suppression and visitor departure. Main profile views are read-only for owners too; `is_editable()` now means the owner may open Edit, not that inline editors exist. Full local-file persistence is not implemented; file selection is explicitly preview-only.

```sh
python3 tests/profile/run.py
# Optional executable override:
GODOT=/path/to/godot python3 tests/profile/run.py
```

Python 3 + Godot 4. The runner copies code into a disposable project under `/tmp/opencode` when available. It does not launch the full game, real microphone, external HTTP or production account creation. Wire tests use a loopback-only relay on an ephemeral port. Real SaveData initialization runs against a disposable ConfigFile; crypto tests generate ephemeral RSA keys in memory only. Actual Home and Settings scene `_ready()` paths run.

**Exit 1** means acceptance assertions failed (expected before implementation). **Exit 2** means an import/runtime error, not an intended failing test. Missing planned APIs fail prerequisites cleanly and dependent groups are listed as **not run**, never counted as passing. Fixtures do not implement profile/auth features.

Initial verified result: **5 baseline checks pass, 7 acceptance checks fail, 5 dependent groups not run**, with no Godot script/import errors.

Current implementation: **69 checks pass, 0 fail, 0 dependent groups skipped**. In addition to the original contracts, the suite now exercises loopback ENet authentication and signed profile exchange with three accounts, duplicate-key rejection, forged profile denial, same-world/different-instance isolation, late snapshot rejection, unauthenticated raw create denial, disconnect cleanup, actual Home navigation, draft save/cancel/conflict, legacy migration and corrupt-key preservation. Loopback sockets are now used (ephemeral ports only); no external network/account files are accessed.

## Coverage

- Top-left icon-only profile button with default icon, hit area, tooltip and signal wiring; right-hand mic remains icon-only and flush right.
- Layout inside a real TabContainer with deliberately nonzero theme padding at two sizes; no shared-theme mutation.
- General Settings has neither Profile category nor editable profile fields; Audio/Controls remain.
- Guarded profile service contracts: private-key ownership, four fields, safe defaults, atomic validation, blank names/description bounds, direct unauthorized writes, same-key persistence and wrong-key file separation.
- Guarded real profile scene: self-edit vs remote read-only, actual full public key display (not only fingerprint), no editable visitor text.
- Guarded authenticator: valid proof of possession, wrong signer, consumed/expired/cross-connection challenges and disconnect cleanup.
- Guarded relay exchange: verified peers share profiles/public keys only within their current instance, not across instances of the same URL; unauthenticated fetch/publish and author spoofing rejected; departure cleanup; directory/private-key privacy.

## Proposed interfaces (test adapters, not implementation)

Names are proposed seams for future production code. Equivalent internals may be adapted without weakening behavior:

- `scripts/profile/profile_service.gd`: `configure(private_key, config_path)`, `get_local_fingerprint()`, `get_profile(owner) -> Dictionary`, `can_edit(owner)`, `save_profile(owner, fields) -> bool`, `load_profile() -> bool`. Four field IDs match the roadmap. `cache_remote_profile(session, verified_public_key, fields) -> fingerprint` is an **internal authenticated-message adapter**, never a public untrusted input endpoint.
- Profile scene: `open_profile(service, fingerprint)`, `is_editable()`, `get_displayed_public_key()`, `cancel_edit()`. Service authorization must still reject direct unauthorized writes independent of UI mode.
- `scripts/profile/identity_authenticator.gd`: `issue_challenge(connection_id, public_key) -> PackedByteArray`, `verify_response(connection_id, signature) -> bool`, `get_identity(connection_id) -> Dictionary`, `expire_challenges()` (testable expiry seam), `disconnect_peer(connection_id)`. Tests sign SHA-256 of returned canonical challenge bytes using Godot Crypto; production challenge bytes must include domain/version/connection/key context plus secure randomness. `expire_challenges()` must represent deadline invalidation, not bypass verification.
- Relay adapters: `authenticate_peer(id, verified_public_key)` installs an **already verified** identity; `publish_profile(id, fields) -> bool`; `get_profiles_for_peer(id) -> Array`. Real wire requests must authenticate through the challenge flow, never call the install adapter directly with an unverified key. These tests use real relay membership storage and methods without starting sockets.

## Remaining tests to add alongside implementation

Remaining coverage: profile write-failure/draft retry UI, leaving while a visitor panel is open, actual icon/VRM failure/caching/network policies, real local avatar replacement/camera/VR skeleton behavior, authenticated NetworkHandler publication end-to-end, session leave/rejoin replay generations, complete challenge format/entropy/key limits, platform permissions and VR playtesting. Packet tests do not prove encrypted transport or an authenticated relay; neither is currently provided.
# Home navigation refinement

The profile runner also checks the Home dashboard at 1000×700 and 640×480: four equal 2×2 cells below the status selector, use of the remaining page height, empty/non-actionable bottom cells, real Active Instance scene opening, Back and hidden-page cleanup. The focused NetworkHandler fixture supplies read-only disconnected instance state; it does not implement production networking. Verified result after this change: **121 passed, 0 failed**, with the existing ObjectDB leak warning and no runtime/import errors.
