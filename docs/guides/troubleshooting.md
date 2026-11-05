# Troubleshooting and evidence collection

## Startup or menu failure

Capture the exact Godot error, script/function/line, steps, desktop versus headset,
and current commit (`git rev-parse --short HEAD`). Do not paste private keys,
signed private URLs or complete user stores. Reproduce in isolated runners first;
factory/lifecycle tests cover detached/retiring animation controllers and input
ownership, not every renderer/device path.

## Avatar is stuck, clipped or differently animated

Check applied source validation and role names, share permission, importer errors,
and whether the peer supports the same animation capability/library. Unsupported
VRMA tracks are an explicit importer limit; a `.glb` extension alone does not prove
humanoid metadata. Local tracker targets can override head/hands; synthetic pose
tests are not visual headset calibration.

For clipping provide screenshots from first/third person and avatar format/version,
not private model bytes. First-person intentionally hides interior torso/head;
original third-person model remains intact. A source update can change hashes;
failed updates should retain the last valid selection. Do not clear account keys
to fix rendering. See [usage](../asset-cache-and-animation-usage.md).

## Join or presence unavailable

Check relay connection/authentication, exact session identity, negotiated world
revision, trust/format errors and admin admission expiry. Friendship/presence alone
does not bypass bans or Private mode. Offline/DND preference and mic mute are
independent. Missing cached pinned world bytes cannot be replaced silently by newer
URL content for an already pinned instance.

## Storage and release failures

### Asset-cache index trailing-data repair

The normal project now checks the index before the first asset load and inspects
it every 60 seconds on a background worker while the cache is idle. An intact
schema-1 document followed by trailing junk is repaired automatically, without
dialogs, after saving an exact `.corrupt-<hash>.bak` beside the index. All records
are retained; account/settings/profile files are excluded. Periodic results are
applied only when no cache job is active and the file still matches the inspected
bytes. Index writes use process-specific temporary names to avoid shared `.tmp`
collisions. This is not a complete multi-process cache transaction/locking system.

Truncation, unsupported schemas and invalid records remain read-only: background
maintenance must not guess or discard potentially valuable data. Repairs do not
change URL validation, model format limits or permissions. Startup inspection is
bounded to 16 MiB; recurring inspection runs off the frame thread.

The optional standalone Python tool remains available for offline diagnostics:

Close **all Comunicare clients** before repair. The standalone Python script
detects a complete, valid schema-1 cache index followed by junk and automatically
removes only that trailing junk. It preserves every record and first writes an
exact, content-hashed `.bak` of the original beside the index; replacement uses a
unique temporary file and atomic rename. It does not edit keys, settings,
profiles, avatar configuration or model blobs. This standalone command is optional;
the equivalent safe recovery is built into the cache as described above.

```sh
python3 tools/repair_asset_cache.py --dry-run
python3 tools/repair_asset_cache.py
```

The default path is the Linux Comunicare user cache (honoring `XDG_DATA_HOME`).
For another installation/platform, pass the actual index path:

```sh
python3 tools/repair_asset_cache.py /path/to/asset_cache/index.json
```

Healthy files are untouched. Truncated/unparseable JSON, duplicate keys, invalid
records, future schemas, symlinks and unreadable/oversized files are refused,
not silently reset. A detected concurrent change aborts replacement; keep clients
closed because a standalone repair cannot lock out an application that does not
cooperate with locking. Backups can contain cache metadata; keep them private.
Restart the client after repair to clear its in-memory read-only cache state.
This repairs the diagnosed trailing-data failure, not every possible storage or
model-import error. Isolated regression tests:
`python3 tools/test_repair_asset_cache.py`.

Back up originals before recovery; wrong-owner/signature/future-version errors
must not be suppressed through destructive reset. Cache cleanup is separate from
account recovery. Release journal recovery is separate again: inspect repository
metadata diff and follow [releases](../development/releases.md); never force-push
or delete remote tags after a failed atomic push without understanding remote state.

## Verification claims

Run applicable [isolated suites](../development/testing.md), record failures plus
reruns/skips/warnings and attach a minimal reproduction. Internet latency, physical
voice, renderer/shadows and headset comfort require manual tests. “Tests pass” is
not a substitute for describing the actual observed visual/device failure.
