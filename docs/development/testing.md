# Verification

Run from the repository root, with Python 3 and `godot` available:

```sh
python3 tests/microphone_settings/run.py
python3 tests/profile/run.py
python3 tests/public_discovery/run.py
python3 tests/active_instance/run.py
python3 tests/friends/run.py
python3 tests/avatar_loading/run.py
python3 tests/asset_cache/run.py
python3 tests/animation_sync/run.py
```

Override Godot per invocation with `GODOT=/path/to/godot`. Runners copy production
sources/fixtures into disposable projects, normally under `/tmp/opencode`.
They use Compatibility rendering, ephemeral loopback networking where needed,
and no real account, external relay or physical microphone/headset.

Animation tests accept `AVATAR_FIXTURE=/path/to/permitted/avatar.vrm` for optional
real-rig checks. Without it, that group is skipped. Never redistribute the fixture
without permission. Discovery also runs a production-startup integration suite;
animation also checks production controller/menu lifecycle.

Assertion failures exit 1; Godot `ERROR:` is infrastructure failure. Inspect warnings
and skipped groups. Some voice timing assertions have failed under parallel load
and passed standalone: record both runs, not only the successful retry.

Headless tests do not prove Forward Plus/XR rendering, headset/controller comfort,
mirror/shadow appearance, physical audio or Internet latency targets. Perform and
record those manually on the applicable hardware. Do not run ordinary startup
against real user data merely to automate a smoke test.
