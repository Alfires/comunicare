# Asset cache checks

Run `python3 tests/asset_cache/run.py` from the repository root. Override Godot with
`GODOT=/path/to/godot`. The runner uses a disposable project under `/tmp/opencode`
and an ephemeral loopback HTTP server; it never reads the real account or cache.

Checks cover content-addressed persistence, concurrent consumers, conditional
HTTP/304, same-URL revisions, active leases, validation failures, no-store file
lifetime, restart, local imports, quota protection and corrupt-index preservation.
They do not establish world sandboxing, production Internet URL safety, animation
retargeting, XR rendering or synchronized playback; those are separate milestones.
