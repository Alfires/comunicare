# RED multiplayer and discovery reliability regressions

**Explicitly requested intentionally failing tests; no production fixes.**

```sh
python3 tests/multiplayer_reliability/run.py --suite client
python3 tests/multiplayer_reliability/run.py
```

Exit 1 means acceptance assertions fail; exit 2/Godot `ERROR:` means infrastructure
failure, never an acceptable red baseline. The runner uses a disposable project
under `/tmp/opencode`, Compatibility rendering, generated temporary account keys
and fixture source URLs (never fetched). No production startup, user data, capture,
XR, external relay/catalog or real downloaded avatars are used.

Client tests use the **production NetworkHandler and RelayPeer.on_packet** with a
transport-only recording peer, real signed profile verification and a recording
remote appearance node. The delayed DataLoader fixture enables an actual await
boundary. They check appearance application/deduplication, transport/coordinator
agreement after rejected results and stale staging across connection replacement.
The appearance fixture records requests; it does not certify rendered avatars.

Verified initial client baseline: **5 passed, 5 failed**, exit 1, no Godot errors.

These opt-in red suites are not added to normal green game/tooling checks. Fixes
must satisfy behavior, not replace the facades under test with passing stubs.
