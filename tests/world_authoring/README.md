# World-authoring plugin acceptance tests (RED)

Implementation update: initial production services now pass **34 assertions**, no
blocked groups, exit 0. Runner also enables the plugin in the disposable editor
and checks clean startup/shutdown. Historical absent-plugin baseline below is
retained as test-first evidence. Actual dock interaction/player launches remain
outside these tests. Current primitives-only scope is in the addon README.

Run explicitly from the repository root:

```sh
python3 tests/world_authoring/run.py
```

Override the executable with `GODOT=/path/to/godot`. The runner copies production
world services and, when present, `addons/comunicare_world_tools` into an isolated
Compatibility project under `/tmp/opencode`. It imports trusted copied scripts,
then runs headless assertions. No real account, microphone, relay, external asset
request or actual game/player process is launched. EditorPlugin is **not enabled**
by this runner: plugin lifecycle/UI acceptance requires separate editor tests.

## Verified baseline

With the plugin absent: **0 passed, 6 failed, 6 dependent groups BLOCKED**, exit 1,
without Godot errors. This is a deliberate test-first baseline, not a passing plugin.
Exit 2 indicates infrastructure/parse/runtime error, missing Godot or timeout.
Existing green runners do not automatically invoke this suite.

## Proposed interfaces

These names/schema are acceptance seams for the
[plugin roadmap](../../docs/roadmaps/world-authoring-plugin-roadmap.md), not existing
APIs or a complete specification. Implementations may refine them with equivalent
behavioral evidence; do not substitute passing fixtures or remove security checks.
Results are dictionaries with `ok`, plus `error` on rejection. Components may be
Nodes or RefCounted services; no implementation is supplied in the tests.

| Component under `addons/comunicare_world_tools/` | Proposed contract |
| --- | --- |
| `plugin.cfg` | Named plugin with a relative existing script entry inside the addon. Only descriptor structure is checked. |
| `authoring_document.gd` | `validate(document)`, `save_project(document, path)`, `load_project(path)` returning `document`; rejects duplicate IDs, future schema and dangling behavior owners; invalid saves preserve previous bytes. |
| `interaction_tools.gd` | `make_pickup(document, id)`, `bind_behavior(document, id, event, actions)`, `duplicate_entity(document, id)`; returns derived data/new `entity_id`, never mutates source, rejects missing targets/native commands. |
| `world_exporter.gd` | Awaitable `export_package(document, path)`; actual output must pass production reader/builder, omit preview players and preserve old export on rejected asset paths. |
| `playtest_launcher.gd` | `plan(package, desktop_or_vr, count)` returns `clients` with distinct `user_data`, `temporary_identity: true`, `microphone_muted: true`; planning only, not process startup evidence. |
| `world_optimizer.gd` | `analyze(document)`, `optimize(document, options)`; report/derived `document`, preserve source, pickup IDs and behavior bindings, reject unknown presets. |

The sample authoring schema is version 1: world ID/title, entity arrays with stable
IDs/type/position/collider, asset inventory, behavior bindings and capability list.
The export format remains the production runtime package schema; these are separate.

## Not certified by these tests

- Real EditorPlugin enable/disable, dock creation or cleanup.
- Undo/redo, rename/delete reference repair, corruption/crash recovery or migrations.
- Actual production desktop/VR launches, spawn/collision quality, process cleanup,
  two-client play or physical OpenXR comfort.
- Imported textured model parity, asset attribution completeness or visual quality.
- Export determinism, optimization image comparison or measured performance gains.
- Collaborative in-game editing (covered by a separate roadmap).

Missing components stop only their dependent groups; blocked assertions never count
as passes. Once the components exist, expand the suite with hostile inputs, exact
export round trips, editor integration and rendered/hardware gates before release.
