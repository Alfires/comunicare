# Roguelike foundation tests

```sh
python3 tests/roguelike_demo/test_runner.py
python3 tests/roguelike_demo/run.py
```

Set `GODOT=/path/to/godot` if needed. The runner imports four actual production
world scripts into a disposable Compatibility project under `/tmp/opencode` when
available. HOME and XDG locations are isolated; there are no game autoloads,
real accounts, external HTTP, relay connections, capture devices or XR startup.
Temporary saves and the project are removed afterward.

Exit codes: **0** all assertions passed, **1** assertion failures, **2** missing
prerequisites, timeout, crash, engine `ERROR:` output or missing completion marker.
These are opt-in tests, not added to release hooks.

## Actual coverage

- Real JSON persistence/reopening and deep-copy ownership; player and URL isolation.
- Rapid-write throttling without memory/disk mutation; byte/key quotas; invalid
  namespaces; temporary memory-only saves and loss on a new service instance.
- Wrong-shaped JSON and oversized-file preservation with writes disabled; future
  schema bytes are retained unchanged by the generic store. Game-level migrations
  and future-version rejection still require a progression implementation.
- VM storage capability checks, including forbidden code in an unselected branch.
- Actual WorldRuntime dispatch for four scoped Node3D entities named camp, shrine,
  chapel and crypt sharing one store; foreign targets and stopped scripts rejected.
- Invalid counter and unwritable-store rejection prevents partial scene/progress
  updates. The unwritable case uses the real store's `writable = false` guard,
  not a simulated operating-system disk-full condition.

The station fixture deliberately adds 5 XP per `use` to prove shared broker/storage
behavior. It is **not** the proposed game interaction: opening real menus must not
award XP. This test does not prove exactly-once rewards or working physical menus.

## Known limits

Ember Crypt has no implemented map, enemy controller, progression thresholds,
upgrade UI or rig/animation package to test yet. This suite does not create passing
dummy implementations of those features. It does not validate navigation, enemy
damage/death, menu input/pause, seed determinism, reward uniqueness, save coalescing,
game migrations/reset, exported builds, rendered art or headset comfort/performance.

An initial malformed-JSON fixture exposed existing `JSON.parse_string` engine error
output from `world_local_store.gd`; the runner correctly returned infrastructure
failure despite passing assertions. The green suite uses valid-but-wrong-shaped
JSON (`[]`) instead. Malformed JSON recovery without engine errors remains a
separate production bug, not fixed or covered here. No production files changed.
