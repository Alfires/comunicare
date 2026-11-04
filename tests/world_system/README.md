# RED safe-world acceptance contracts

**Implementation update:** initial services and safe scene reconstruction now
pass **117 assertions**, with zero failures/blocked groups and no Godot errors.
The three Python runner self-tests also pass. The suite remains opt-in. Historical RED
notes below describe the test-first starting point, not current missing services.
Production DataLoader now uses the safe builder; see the authoring guide for its
limited supported profile. Full transport/gameplay/Terrain3D implementation is not
implied by passing service contracts.

**Original test-first status: intentionally failing; no implementation then.**
Implements the first executable contracts for the
[world rewrite roadmap](../../docs/roadmaps/safe-world-system-roadmap.md).

```sh
python3 tests/world_system/test_runner.py  # green tests of fixture/runner integrity
python3 tests/world_system/run.py          # RED future-feature acceptance suite
```

Set `GODOT=/path/to/godot` if necessary. The acceptance runner returns **1** for
assertion failures, **2** for missing prerequisites, Godot errors/crashes or timeout,
and **0** only when all currently executable assertions pass. It is deliberately
not added to normal green checks or release hooks. No failed runtime feature is
being passed off as a completed implementation.

## Verified initial baseline (historical)

Godot 4.7.2: **1 harness assertion passed, 6 component assertions failed, 6 dependent
behavioral groups blocked**, exit **1**, without Godot errors. The one pass only
checks absence of a fixture-execution sentinel; it is **not** evidence that the
missing loader rejects scripts. The three Python runner self-tests pass.

Missing services stop only their dependent group. The detailed behavioral tests
are present but **not yet executed**; their assertion count expands as production
components arrive. Do not count blocked checks as security coverage or passes.

## Isolation and fixture integrity

The runner builds a disposable Compatibility project under `/tmp/opencode`, copies
only future production `scripts/worlds`, and imports those trusted scripts first.
It then generates real ZIP packages outside editor import, including native Godot
TSCN/TRES fixtures and hostile archives. The fixtures are data, never directly
loaded as scenes. All Godot invocations use temporary XDG data/config/cache roots.
No real game startup, accounts, autoloads, relay, HTTP, addon installation, device
capture or XR session is used. Temporary files are removed afterward.

Python self-tests verify the valid archive hash, PNG chunk CRCs/decompression,
actual duplicate ZIP entries and symlink flags, attached script fixture, compressed
size attack, truncated archive and distinction between expected RED and errors.

## Proposed production interfaces

These paths/APIs are **test-first proposals**, not previously promised public APIs.
Implement real behavior or adapt tests with documented implementation evidence;
do not add passing dummy services. Services are detached instantiable GDScript
objects with no startup side effects. Methods are synchronous/bounded here; an
asynchronous production adapter may change the harness when needed.

Unless stated otherwise results are dictionaries: success has `ok: true`; rejection
has `ok: false` and nonempty string `error`. Inputs must not be mutated. A missing
service/method is an assertion failure; an engine/script error is infrastructure
failure. Use typed data, never engine resource execution to satisfy these tests.

| File under `scripts/worlds/` | Contract |
| --- | --- |
| `world_package_reader.gd` | `inspect_package(path, limits)` → result with archive `revision` and normalized `document`. `entities` keyed by stable metadata ID; item has `pickup: true`. `materials` keyed by package-relative path, with `textures` channel→path, `uv1_scale` three-number array and metallic/roughness scalars. Unknown/hostile package content fails closed, even if unreferenced. Supported limit overrides: `max_entries`, `max_expanded_bytes`, `max_texture_dimension`; no installed extensions by default. |
| `world_extension_registry.gd` | `validate_requirements(requirements, installed, package_paths)` → result. Only the application supplies `installed` registry ID→`data_schemas`. Check required integrations, supported data versions and in-package data paths; reject code URLs/unknown executable fields. |
| `world_script_vm.gd` | `run_event(operations, context, limits)` → result plus `commands`. Validated-IR event boundary: `command`, `repeat(count, body)`, `allocate(bytes)` exercise broker/fuel/heap boundaries. `command` uses capability/entity/property/value. Context grants only approved capabilities and current entities, never OS APIs. On failure pending commands are empty. These IR fixtures do not test a text-language frontend. |
| `world_interaction.gd` | `configure(config)`, `apply(authenticated_sender, event)` → result, `snapshot()` → state, `disconnect_member(id, generation)`. Members map IDs to generations. Items map IDs to pickup/max_hands settings; snapshots include holder/grip/epoch. Reliable accepted control sequences increase per sender; rejected requests do not change ownership. Configure creates a fresh isolated instance. |
| `world_state_replicator.gd` | `configure(session_id, revision, members)`, `accept_snapshot(sender, generation, snapshot)` and `apply_event(sender, event)` → results, `snapshot()` → state. Check generation/revision/session, strictly ordered tail, replay rejection and no rollback. |
| `world_instance_policy.gd` | `configure(config)`, `authorize(id, generation, action)` → bool, `disconnect_member(id, generation)`, `snapshot()` → members/admins, `can_admit()` → bool. Config contains ordered member records, admins, moderation flag and policy-readiness map. Only kick/ban; earliest present fallback admin; missing successor policy closes admission; last departure removes members/admins. |

Event envelopes contain `kind`, session/revision, connection generation, stable
entity, lease epoch and sequence. No sender ID supplied inside an event is trusted.
The test's short session/hash/ID strings are opaque fixtures, not proposed wire
encodings or identity validation rules. Unknown node rejection permits a reviewed
adapter later; it does not ban supported custom nodes.

**API correction during implementation:** item and policy cleanup use
`disconnect_member(id, generation)`, because `disconnect` is Godot Object's native
signal method and cannot be overridden with this signature. Builder contract:
`world_builder.gd::build_package(path)` returns `ok`, constructed `PackedScene`,
`spawn_point`, exact archive `revision` and validated `document`; failure returns
the ordinary diagnostic result. It never loads downloaded PackedScenes.

## Covered contracts and explicit limits

- Native Godot source scene/material ZIP with pickup metadata and basic PBR/UV
  preservation; no author import cache, publishing plugin or compiler required.
- Traversal/absolute/backslash/symlink paths, duplicate/case-colliding entries,
  malformed archives/metadata, missing dependencies, invalid numbers, unsupported
  nodes, attached scripts, native extensions, project autoloads, method animation,
  arbitrary signal methods, external textures, shader source and size limits.
- Terrain3D requirement negotiation, missing data/schema/integration and code-URL
  rejection. This is **not actual Terrain3D rendering, baking or adapter coverage**.
- Restricted-IR useful commands, forbidden APIs despite malicious grants,
  world-scoped entities, aggregate commands/fuel/heap and transaction rollback.
- VR and desktop requests sharing exclusive lease state, remote holder/grip data,
  forged ownership, stale leases, nonmembers and disconnect cleanup.
- Snapshot scoping, held-item late-join state, event replay/gap handling and rollback.
- Kick/ban-only creator/admin policy, automatic succession, fail-closed admission
  when ban history is unavailable, and empty-instance membership cleanup.

Not covered yet: production DataLoader/relay/UI wiring, real packet transport,
full dependency graph/UID resolution, inheritance/cycles, import-sidecar semantics,
streamed decoder allocation/timing, VM text parsing/handle generations/determinism,
snapshot corroboration, policy persistence/transfer, cache/update consent, throws,
two-handed handoff, physical collision, real Terrain3D data, texture render parity,
renderer isolation or hardware performance. Add those tests as separate coherent
units; passing these policy/service contracts cannot certify the complete roadmap.
Trusted offline preview, real desktop/VR sessions and hostile-content security
review remain required. Never describe dummy state snapshots as proof that remote
players visually see held items.
