# RED multiplayer and discovery reliability regressions

**Explicitly requested intentionally failing tests; no production fixes.**

```sh
python3 tests/multiplayer_reliability/run.py --suite client
python3 tests/multiplayer_reliability/run.py --suite discovery
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

Verified discovery baseline: **5 passed, 8 failed**, exit 1, no Godot errors.
The combined default command runs both even when the first fails assertions;
infrastructure errors stop immediately. Expected total: **10 passed, 13 failed**.

Discovery uses the actual WorldExplorer scene/script with only external catalog
request, network send and modal popup creation replaced. Production timeout/model/
render paths still run. It checks catalog byte/metadata bounds and last-good state,
strict summary shape, private filtering, silent-peer refresh latch, missing request
correlation and query intent separation. Large metadata is generated in memory
only; no external catalog is downloaded.

Guarded proposed APIs (not implementation claims): WorldExplorer
`receive_directory_result(envelope)` rejects stale request/generation IDs;
`classify_query(text)` distinguishes filter/url/code. A future discovery service
may own these with a tested facade. `relay_protocol/decode_result.gd` should expose
`json_object(bytes, max_bytes)` returning an `ok` boolean plus value/error. Its
malformed/wrong-type/oversized/valid-object assertions run only once it exists.
Current direct parsers are not called with malformed input because Godot errors
are infrastructure failures, not acceptable red evidence.

Missing future APIs fail one prerequisite assertion; dependent checks are not
counted as executed. Complete stream epochs, packet fuzzing, pagination, transfer
fairness, rendered multi-client appearance and a production relay remain subsequent
roadmap gates, not implied coverage.

These opt-in red suites are not added to normal green game/tooling checks. Fixes
must satisfy behavior, not replace the facades under test with passing stubs.
