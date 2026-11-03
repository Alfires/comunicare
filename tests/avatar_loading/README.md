# Avatar import responsiveness regression

```sh
python3 tests/avatar_loading/run.py
GODOT=/path/to/godot python3 tests/avatar_loading/run.py
```

Uses a disposable Godot Compatibility project, the real production DataLoader and generated local glTF fixtures. No accounts, downloads, microphones, XR plugins or main game startup are used. Exit 1 is an assertion failure; Godot runtime/import errors return 2.

The slow-loader fixture adds 180 ms of deterministic work inside the importer worker, then calls the real GLTFDocument implementation. Assertions check that main-loop timers continue during two concurrent imports, parsing/construction occur on a worker thread, workers are joined after completion, local paths use the same asynchronous importer, and each request returns its own detached model. A generated triangle exercises real mesh resources and attachment on the main thread, not just an empty Node3D.

Verified with Godot 4.7.2: **10 passed, 0 failed**, no runtime/import errors. This catches main-thread blocking in the import scheduling path; it is not a benchmark of a production-sized VRM. Large mesh/texture uploads, first-use shader compilation, model attachment, animation/IK setup and full Forward+/XR performance still need visual hardware testing. The worker never touches the active SceneTree or globally registers per-request GLTF extensions. Imports are serialized with up to eight waiting callers to prevent simultaneous scene builds from saturating the machine. Shutdown joins any outstanding worker and frees its detached result.

The existing URL/preview/player paths await the asynchronous result. Equipped desktop/VR players skip loads when the avatar URL is unchanged; profile refreshes no longer reload an already displayed unchanged preview. Remote-player loads retain the old avatar on failure and reject stale completion. Profile tests additionally verify that an unchanged refresh starts no new request.
