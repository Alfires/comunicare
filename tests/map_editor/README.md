# Collaborative in-game editor acceptance tests (RED)

Implementation update: 36 service assertions now pass, followed by real loopback
ENet host/client checks in `network_suite.gd`: fresh signed challenge authentication,
no pre-approval snapshot, viewer restriction, revocation, fresh rejoin approval,
editor mutation/snapshot convergence and disconnect permission cleanup. No external
relay, real account or UI is used. This is not a rendered two-window/headset test.
The runner copies profile/wire dependencies and parses the production editor panel.

```sh
python3 tests/map_editor/run.py
```

Use `GODOT=/path/to/godot` to select an executable. The opt-in runner copies
production world services and any implemented editor/addon services to a disposable
Compatibility project under `/tmp/opencode`, with isolated XDG directories. It
does not start the game, open accounts, contact friends/relays, capture audio or
enable an XR runtime. Fixtures do not implement editor/collaboration behavior.

Verified absent-editor baseline: **0 passed, 7 failed, 7 dependent groups BLOCKED**,
exit **1**, without engine errors. Exit **2** indicates infrastructure/parse/runtime
error, timeout or missing Godot. Existing green test runners do not invoke this
intentionally failing suite. Blocked dependent assertions never count as passes.

## Proposed interfaces

These are test-first seams for the
[editor roadmap](../../docs/roadmaps/collaborative-map-editor-roadmap.md), not current
production APIs. Adapt names/schemas with equivalent tests and evidence, not stubs
that return success. Results use `{ok, error}` plus the indicated data. Services may
be RefCounted or Node; missing methods fail their dependent group explicitly.

Components proposed under `scripts/editor/`:

| Component | Contract |
| --- | --- |
| `project_store.gd` | `save_project(document, path)`, `load_project(path)`, `recover_project(path)`; restored `document`, stable IDs/revision, invalid writes preserve source, interrupted `.tmp` does not replace valid main file. |
| `edit_commands.gd` | `apply_operation(document, operation)` → derived `document`, `inverse`; `undo_operation(document, inverse)` → derived document. Reject stale revisions, missing targets, nonfinite transforms and native execution commands. |
| `edit_authority.gd` | `configure(document, owner, generation)`, `admit(actor, member, role)`, `revoke(actor, member)`, `submit(authenticated_sender, operation)`, `snapshot(authenticated_recipient)`; explicit admission, viewer protection, owner-only role changes, generation/revision/replay checks. Sender/recipient arguments are trusted transport identities, never packet claims. Snapshot success is `{ok: true, document: ...}` and unauthorized access returns `{ok: false, error: ...}`. |
| `edit_leases.gd` | `acquire(session, entity, member, now_ms, duration_ms)`, `release(session, entity, member)`, `disconnect_member(member)`, `expire(now_ms)`; exclusive bounded leases, holder-only release, disconnect/expiry cleanup. Permission admission is authority-owned, not inferred by lease service. |
| `editor_input.gd` | `transform_operation(mode, entity, position, rotation, scale, blocked)` → canonical `operation`; desktop/VR parity, suppressed input emits nothing, singular scale rejected. This is input-policy testing, not physical tracker testing. |
| `editor_playtest.gd` | Awaitable `prepare(document, mode, export_path)` → `temporary_progress`, `token`; output must pass production world builder. `restore(token)` returns original `document`. No actual player process is launched by this test. |

Sample project: schema 1, world ID/title/revision, stable entities, assets,
behaviors and capabilities, consistent with the plugin suite's proposed schema.
Operations contain unique ID, generation, expected revision, operation kind and
entity target. The tests intentionally do not prescribe internal Godot node wiring.

## Covered versus future gates

Current executable contracts cover local persistence/recovery, edit/undo behavior,
permission/revocation, stale session/revision handling, duplicate delivery, lease
conflicts/disconnect/expiry, canonical input and safe playtest export/restoration.
Only existence guards execute while implementation is absent.

Not certified: actual collaborative networking, packet encoding/capability negotiation,
snapshot/delta convergence across processes, asset transfers, rate limiting, journal
compaction/quotas, collaborative undo conflicts, desktop gizmos, tablet UI, undo
selection state, VR tracking loss/rearm, visual quality, Forward Plus performance,
real OpenXR comfort or sustained multi-user editing. Add real loopback multi-client
fault tests and rendered/hardware tests as implementations land. The relay privacy
contract is not proven by these pure service calls.
