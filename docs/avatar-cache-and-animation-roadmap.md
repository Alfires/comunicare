# Avatar, world cache and synchronized animation roadmap

## Status and goals

**Follow-up direction:** [automatic-avatar-animation-roadmap.md](automatic-avatar-animation-roadmap.md) supersedes the manual animation-player UI and parallel/manual animation synchronization design below. It plans automatic application, one resolved animation state, and source-only configuration under User → Avatar. That follow-up is planning only; current runtime behavior is still described in the implementation section below.

**Implementation in progress — 2026-11-03.** The original design below remains the target, not a claim that every milestone is complete.

### Current implementation slice

Shared client-local content-addressed storage, atomic index writes, hash checks, bounded/coalesced fetches, conditional GET, failure backoff, offline fallback, no-store lifetimes, pinned local imports, quota/lease protection and corrupt-index preservation are implemented in `scripts/assets/asset_cache.gd`. DataLoader uses the cache for URL avatars and world archives, retains active revisions, and checks loaded avatars periodically. Desktop/VR/remote/preview consumers receive same-URL update notifications. Registry-driven Assets settings and confirmed unused-cache clearing are available.

`tests/asset_cache/run.py` exercises isolated real loopback HTTP and storage behavior. Remaining cache work includes broader recovery/fault injection, per-item management, complete stale/orphan-derived reclamation, safe redirect support and URL destination policy. World archives are **not sandboxed**; remote world loading now fails closed unless the user explicitly enables the Assets trusted-publisher setting. This is a coarse executable-content trust opt-in, not a per-publisher signature/allowlist system. Use trusted publishers only. Settings also offers an immediate loaded-assets refresh; a world refresh never swaps the active scene.

The next implemented slice adds negotiated world revision metadata to creation/lookup/join/results. New clients resolve the pinned revision before staging, reuse exact cached hashes, and reject mismatches before changing membership. Legacy unpinned sessions still exist; this is not retroactive consistency for old clients. Built-in revision hashing currently covers the scene file, not its entire transitive resource graph; exported-build verification remains required.

Home now opens an Animations subpage. Eight original procedural CC0 default clips are bundled with provenance and license text (no third-party motion downloads). A bounded worker-backed data-only runtime GLB/VRMA reader imports **rotation-only humanoid clips**, using declared humanoid mapping, hierarchical rest-rotation conversion and target rest rotations. It rejects translation, expression/gaze/custom-node tracks, sparse accessors, CUBICSPLINE interpolation and external dependencies. This is an initial importer, **not full VRMA conformance**; coordinate/rig differences still require real-avatar visual verification. Imported originals are cached and the menu rebuilds its library from cache metadata, with confirmed removal. Desktop locomotion uses defaults automatically; full-body VR playback is explicit opt-in, never camera/body root motion.

Animation wire ID **28** is capability-negotiated through authentication and a hello exchange. Reliable bounded state carries sequence, exact content hash/built-in library ID, relay time, loop/speed/playhead and per-connection generation. Instance-scoped snapshots recover late-load state; requested chunks distribute consented local/link-imported bytes without advertising filesystem paths or credential-bearing URLs. The relay forwards without persistent storage and drops departed-user state/references. The receiver verifies hashes and parses before playing, caching received originals as evictable content rather than permanently pinned library imports. Imported links are distributed as owner-served bytes rather than fetched independently by remote peers. Parsed motions remain bounded session-memory data.

`tests/animation_sync/run.py` checks the parser, mapped AnimationPlayer, actual import menu, production receiver, real ENet isolation/snapshots/clock/chunks/disconnect and world-revision mismatch. Remaining release work: derived-animation caching, broad rig verification, expression/translation support, richer reimport/library UI, persisted opt-out/player preferences, avatar-revision binding on wire, clock/drift/jitter benchmarks, transfer acknowledgements/retry/fairness stress tests, per-publisher trust enforcement, complete source-update UI and exported/full-renderer/VR checks. The original 100 ms synchronization target has **not** been measured or certified. The ten-phase roadmap is therefore not fully complete.

Build one client-local asset folder that automatically caches every successfully validated avatar and world the client loads, and also caches animation assets. Detect source changes, download replacements safely, and keep known-good content when a refresh fails. Include freely reusable default animations, allow users to import animation files or links, and synchronize playback with every other eligible player in the same instance.

“All” means every encountered/loaded asset, not crawling the Internet or downloading every relay user's avatar. Retention remains subject to configurable storage limits and explicit deletion. Active content and user-imported originals need protection from automatic eviction.

Terminology: **`.vrm` is an avatar/model; `.vrma` is VRM Animation**, applied to an avatar. The UI should allow an avatar and an animation to be selected independently, or together. “Upload file” initially means import a local file into the client library; sharing that file with other players requires the explicit distribution work below, not merely sending a local path.

## Verified starting point

- `scripts/startup/data_loader.gd::load_vrm_from_url()` downloads each request into memory with a 30-second timeout and 64 MiB limit. It does not keep a persistent source cache or HTTP validators.
- Avatar buffer/file import already runs asynchronously on a bounded worker queue. Preserve detached results, awaited callers, main-thread attachment and no per-request global GLTF extension registration.
- `prepare_world_from_url()` downloads `.cne` archives, extracts into timestamped `user://worlds/` directories, removes the downloaded archive and returns staged scene/spawn data. This is staging, not a versioned cache with cleanup or update checks. Current limits are 128 MiB downloaded, 256 MiB extracted and 4,096 archive entries.
- World activation is coordinated with an acknowledged instance transition in `scripts/multiplayer/network_handler.gd`. A cache hit must not skip admission or session acknowledgement.
- Desktop, VR and remote player scripts already guard asynchronous avatar replacement with generations; desktop/VR additionally skip an unchanged URL. Same-URL content updates therefore need an explicit revision signal, not just another profile notification.
- `relay_protocol/player_data.gd` carries position/rotation only. There is no synchronized animation state in this packet.
- `addons/vrm/1.0/VRMC_vrm_animation.gd` is a three-line stub; its global registration is commented out in `addons/vrm/plugin.gd`. The add-on README explicitly marks VRM Animation as unimplemented. Existing expression/look-at animation support is not a VRMA importer.
- Settings use the registry/store and shared UI; signed profile ownership belongs to `SaveData.profile`. The relay is not a persistent asset host: [relay-data-lifecycle.md](relay-data-lifecycle.md) remains authoritative.

## 1. Shared persistent asset cache

### Folder and ownership

Proposed default root: `user://asset_cache/`. Keep the whole cache in one discoverable folder with an **Open cache folder** action; an arbitrary custom location can be a later feature with explicit migration/permission handling.

```text
user://asset_cache/
  index.json                       # Versioned URL/import-to-revision metadata
  blobs/sha256/<digest>             # Immutable verified original bytes
  derived/worlds/<digest>-<schema>/ # Validated extracted world content
  derived/animations/<key>/         # Rebuildable, importer-versioned data
  staging/<request-id>/             # Incomplete downloads and extraction
  licenses/<digest>/               # Supplied license/provenance records
```

- Introduce an `AssetCache` service under `scripts/assets/`; DataLoader remains the loading facade. Initialize client-side only, preserving existing settings/mute initialization ordering. Do not open/write this store in relay/dedicated-server mode.
- Cache originals separately from derived resources. Avatar instances must remain independent scene trees; never share a live avatar node between players. Any derived avatar cache must include importer/add-on/Godot compatibility in its key.
- Use SHA-256 bytes as revision identity. The same URL may yield different hashes; different URLs may share one blob. Hash equality is integrity/deduplication, not proof of publisher identity or permission.
- Index records include asset kind, source key, blob hash, size, media/format, ETag, Last-Modified, last successful check, access time, validation/importer version, pin state and optional provenance. Keep failure/backoff state separate from the last known-good revision.
- Preserve meaningful URL query parameters; do not collapse signed URLs or lowercase case-sensitive paths. Never use source names/URLs as filesystem paths. Redact secrets from logs; protect credential-bearing source metadata locally and never advertise it automatically.
- Copy user-imported files into managed originals so moving/deleting the external file does not break the library. Keep their library references pinned until explicit removal; generated derivatives remain disposable. Cache cleanup must never delete an external source file.

### Download, validate, commit

1. Resolve a managed asset handle from a permitted URL, built-in ID or explicit local file selection.
2. Coalesce concurrent fetches for the same source/revision, with bounded download/import concurrency. Cancelling one waiter must not cancel other consumers.
3. Stream into a unique staging file, enforce timeout/byte limits, hash bytes and validate format and dependencies. Do not publish a successful index entry for a partial download.
4. Import/validate in staging, then atomically promote immutable bytes/derived directories and replace the index using a same-filesystem temporary file. Never overwrite active world directories or a known-good revision in place.
5. Emit `asset_revision_available(source, old_hash, new_hash)` only after successful validation. Consumers use revision plus generation guards before swapping.
6. On failure retain the previous valid revision, report the error and remove only this job's staging content. On startup recover interrupted index writes and safely remove abandoned, unreferenced staging jobs.

Retain existing limits as initial ceilings, add animation-specific limits, and enforce unpacked size, entry count, image dimensions, skeleton/track/keyframe counts and processing deadlines. Reject traversal, absolute paths, symlinks/unsafe archive entries and dependencies escaping the asset root. Content sniffing/validation is required; extensions and Content-Type alone are insufficient.

### Retention, offline behavior and controls

- Default to cache-on-load, automatic checks on use and bounded background refresh for active/recent assets. Never silently fetch the entire history forever.
- Proposed starting defaults: 4 GiB total managed bytes, 15-minute on-use revalidation interval and one jittered active-asset check every 15 minutes. These are tunable product defaults, not current behavior. Account for originals, extracted files, derivatives and staging reservations; explain when pinned content exceeds the budget.
- LRU-evict unpinned, unreferenced assets; reference-count shared blobs. Pin active and staged transitions until completion, active avatars/animations and user library originals. If there is no safe space, fail the new operation without damaging existing content.
- Settings show usage, quota, automatic-refresh preference and download progress; provide **Check now**, per-item **Redownload**, **Remove**, **Clear unused cache**, and **Reset downloaded cache** with confirmation and active-use rules. User imports require a separate explicit deletion choice.
- Offline cached avatars/animations remain usable. Cached world bytes can be prepared offline, but joining a multiplayer instance still requires a live authorized acknowledgement. Warn when the source cannot be checked; do not call stale content current.
- Treat cached source history as private local data; do not store account fingerprints, friend relationships or session rosters in the shared content index. Provide clear-history controls and no relay-side cache inventory.

## 2. Register source updates and safely redownload

- Use conditional **GET** with `If-None-Match` and/or `If-Modified-Since`. A `304` is valid only when a verified local blob exists; otherwise retry unconditionally. Do not depend on HEAD support.
- A changed `200` body produces a new hash; identical bytes only update validation metadata. If validators are missing/unreliable, use rate-limited full GET plus hashing. Manual Redownload bypasses validators. Support HTTP Cache-Control semantics, including no-store (temporary session use only) and no-cache/revalidation; clearly explain when a source forbids persistent caching.
- Polling is the baseline change detector, not instant push notification. A future publisher revision manifest/push hint may trigger revalidation, but hints must never replace local validation or grant access.
- Retry transient failures with bounded exponential backoff/jitter; show 404/permission/expired-link failures without erasing known-good content. Never loop downloads on every frame or profile change.
- Local file imports are immutable snapshots by default. Offer **Reimport source**; optional file watching must compare bytes and ask before publishing a changed shared revision.
- For avatars, notify local/remote/preview consumers even when the URL is unchanged. Publish the owner's selected revision through a negotiated authenticated descriptor; bind remote requests to the current profile/instance, verify downloaded hashes and retain a placeholder/old model on mismatch. A cache refresh alone must not claim to be a signed profile edit.
- **World updates are not hot scene replacements.** Pin the validated world hash for each instance. Add capability-negotiated instance revision metadata and an acknowledged revision check: the creator selects a validated hash, the relay carries only bounded active-instance metadata, and joiners prepare that exact revision before membership changes. A URL alone cannot guarantee everyone loaded the same world.
- If the URL has advanced and the pinned world bytes are unavailable, fail with a clear revision-mismatch error; do not silently join using a newer world. Content-addressed publisher URLs are recommended. An updated world becomes available for a new instance, or a separately designed unanimous/coordinated transition; the first release offers new-instance creation rather than live migration.
- On old relays, expose the lack of revision pinning rather than asserting consistency. Require compatible support for revision-pinned instances; retain a clearly labeled legacy path only where existing admission policy permits it. Preserve `default_wold` as a built-in asset with an application-version/content revision.

## 3. Default animations with genuinely reusable licenses

Ship a small offline-ready humanoid library: idle, walk, run, jump/fall/land and a few emotes such as wave and cheer. Exact clip selection is a release gate, not a claim that a particular free pack includes every listed clip.

### Candidate source and license gate

- Preferred candidate: [Quaternius Universal Animation Library](https://quaternius.com/packs/universalanimationlibrary.html). Its publisher page identifies CC0 and personal/educational/commercial use, but distinguishes free Standard from paid Pro/Source tiers. Select only clips actually included in the no-cost Standard download; do not assume all 120+ animations or engine-ready/source files are free downloads.
- [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) is the preferred default because it permits modification and redistribution without downstream attribution obligations. Still bundle provenance, creator credit and the license text for auditability.
- For any missing required clip, create an original project-owned animation with an explicit CC0 dedication, or review another source clip-by-clip. Do not fill gaps using assets merely described as “royalty-free,” noncommercial-only, no-derivatives or downloadable without explicit redistribution permission.
- Avoid Mixamo or other restricted raw-asset redistribution sources for bundled defaults unless a separate legal review establishes permission. VRMA format support and code licenses do not grant rights to example motions or avatar models.
- Before vendoring, record source URL, author, exact download/version/date, original filename/hash, license identifier/text and conversion edits in an asset manifest plus `THIRD_PARTY_ASSETS.md`. Inspect the downloaded archive's actual terms; do not rely solely on the website label.
- Convert/retarget reviewed clips at development time into the project's canonical humanoid library; bundle those outputs under `res://` with stable namespaced IDs and hashes. Users need no account or download for defaults. Import bundled defaults into cache metadata as read-only built-ins, not duplicate writable originals unnecessarily.

**Acceptance:** a clean offline install plays each required default; every shipped clip has traceable redistribution/modification rights; exported builds include the manifest and notices.

## 4. User animation files, links and avatar retargeting

### Runtime importer milestone

- Implement and test a runtime `.vrma` adapter against the [VRM Animation specification](https://github.com/vrm-c/vrm-specification/tree/master/specification/VRMC_vrm_animation-1.0) and [format overview](https://vrm.dev/en/vrma/). Do not assume the existing stub or editor import process supports runtime files.
- First supported user formats: `.vrma` and self-contained `.glb` containing skeletal animation and a compatible humanoid mapping. Permit `.vrm` avatar selection separately. Defer BVH/FBX/multi-file glTF until safe converters/dependency handling exist; show explicit unsupported-format errors rather than pretending every animation file works.
- Parse into a canonical humanoid animation representation, then retarget through VRM humanoid metadata/Godot bone maps, rest-pose and scale correction. Validate missing/duplicate bones, VRM 0.x versus 1.0 conventions and coordinate systems. Bare bone-name matching alone is not sufficient.
- Initial support covers humanoid rotations and bounded hips translation. Explicitly report unsupported expression/gaze/custom-bone tracks; extend with safe mappings later, without replacing existing VRM expression libraries.
- Build sanitized `AnimationLibrary` resources for a dedicated avatar `AnimationPlayer`, with `AnimationTree` blending where appropriate. Allow only approved transform/blend-shape tracks targeting that avatar. Reject method/audio/property paths that escape the whitelist, script-bearing resources and arbitrary remote `.tscn`/`.tres` animation imports.
- Keep import jobs detached and bounded; attach animation nodes/libraries on the main thread. Cache derived results by source hash, target rig/rest-pose signature and importer schema. Avatar swaps rebind the currently selected animation, subject to generation checks.

### User-facing animation library/player

- Add a shared desktop/VR **Animations** page with defaults and user library entries, **Import file**, **Add link**, avatar selection/preview, clip selection for multi-clip files, play/pause/stop, loop, bounded speed and remove/reimport actions.
- Import/local playback is enabled by default. A standard file picker and URL field must work without developer tools; VR must have usable text entry/file-selection fallback. Separate preview playback from broadcasting to the instance.
- Show source, validation progress, duration, rig compatibility, license/provenance and sharing availability. Preserve the previous working selection if import fails. Persist local library/preferences outside signed profile data; only approved shareable descriptors belong in network publication.
- Integrate locomotion defaults with actual movement/ground state. Define layer priority: locomotion base, optional upper-body emote, then tracked head/hands/IK. VR tracking wins by default; full-body emotes require opt-in and never move the real camera or collision body. Default to in-place clips with root motion disabled.

### Distributing custom assets to other players

A local file cannot synchronize visually unless receivers can obtain the same bytes. Include this in the feature, rather than synchronizing an unresolvable filename:

1. **Link mode:** publish a permitted HTTPS source plus expected hash/clip and license declaration. Receivers fetch through the cache, validate and play the exact revision. Do not broadcast local paths, embedded credentials or signed private links without explicit consent. Mutable links must retain the selected revision or report unavailable.
2. **Local-file mode:** after explicit sharing consent and permission confirmation, offer a bounded, rate-limited chunk-transfer protocol through the existing relay transport to current same-instance participants. The relay forwards chunks without durable storage, disk cache or offline mailbox. Limit chunk size, total advertised bytes, parallel transfers, buffer lifetime and traffic so animation imports cannot starve voice/control packets.
3. Receivers request missing blobs by hash from the connected owner; validate the final digest and animation structure before promotion. Deduplicate concurrent requests, allow cancellation/remote-content opt-out and clear pending buffers on departure. Never accept arbitrary filesystem requests or fan out unsolicited binary assets.
4. In local-file mode, late joiners can fetch while the owner remains connected and sharing. On owner departure cancel transfer/playback and clean live descriptors. Persistent public hosting is an optional future service with separate consent/privacy policy, not part of the ephemeral relay.

Synchronizing custom animations is on by default for valid permitted content; asking to share a newly imported local file remains explicit. A user opt-out, incompatible rig, failed download or unavailable rights yields a neutral fallback and visible status, not arbitrary execution or a false synchronized indicator. Cached private imports are not made into a public file server.

## 5. Same-instance animation synchronization

- Extend the custom ENet protocol in `relay_protocol/`, client coordinator and relay together. Negotiate animation state, revision pinning and asset-transfer capabilities separately. Allocate unused explicit packet IDs at implementation time after checking the current enum; never reorder existing IDs or overload position/voice payloads incompatibly.
- Define a versioned asset descriptor: stable built-in ID or SHA-256 revision, permitted distribution mode/source, selected clip, canonical duration, rig/format metadata and bounded size. Built-in IDs also need a library version/hash so clients cannot silently use different motions.
- Define reliable state/control messages: authenticated sender binding, relay connection/session generation, `session_id`, avatar revision/generation, increasing sequence, clip hash/ID, layer, play/pause/stop, loop, bounded speed, effective start time and playhead offset. Stop/pause/replacement are reliable, not fire-and-forget movement packets.
- The relay derives the sender from its authenticated connection, validates bounds and sequences, and routes only to acknowledged participants in that exact instance. Never trust a claimed peer/account ID, URL-based membership or friendship as authorization. Ignore sends during world transitions; clear old-instance state on transition/eviction/disconnect.
- Establish an instance clock using monotonic relay time and bounded RTT/offset sampling; never compare raw wall-clock timestamps from different machines. Clamp unreasonable future/old start times. Receivers compute playhead from the effective start, speed and offset; loop modulo duration or stop at the end for one-shots.
- Apply reliable state idempotently; reject duplicates/out-of-order updates, stale session/avatar generations and reused peer IDs. Send bounded periodic state/keyframes for drift recovery, not every bone every frame. Smooth small errors and seek on large drift; movement and camera authority remain separate.
- Relay keeps only the latest bounded animation state/descriptors for connected users. Send a same-instance late-join snapshot after membership acknowledgement; receivers that finish downloading later seek to the current playhead rather than restarting at zero. Paused snapshots preserve their frozen offset.
- On rig replacement, resolve the new mapping and apply only a compatible current state. If unavailable or unsafe, stop the affected layer and use default locomotion. New avatar/world hashes do not implicitly restart an unrelated animation.
- Older clients continue normal movement/voice and show defaults where possible; incompatible animation features are explicitly unavailable. Do not weaken moderated admission or revision guarantees to accommodate missing capabilities.
- No durable relay animation history, transfer log, source URL inventory or disconnected-user snapshots. Remove indirect references in surviving transfer queues/snapshots when a participant leaves, following the lifecycle document.

**Synchronization target:** in a two-or-more-client loopback test, every ready compatible participant renders the same clip/revision and playhead within 100 ms under normal latency after convergence. Test latency, jitter, loss, pause/resume, variable speed and delayed downloads separately; document measured limits instead of promising frame-exact playback over arbitrary networks.

## 6. Security and trust boundaries

- Remote asset fetches reveal a client's IP to content hosts. Show this and provide a remote-content policy. Production uses HTTPS; loopback HTTP belongs in isolated tests or an explicit development setting. Block credentials in peer-provided URLs, unexpected schemes, unsafe redirects, HTTPS downgrade and private/link-local/loopback destinations including IPv6; account for DNS rebinding and each redirect. The relay never fetches advertised URLs itself.
- A validated world archive is **not automatically sandboxed**: Godot scenes/resources can reference scripts or other executable behavior. Before expanding automatic world downloads, define an enforceable allowlist for passive worlds and reject external/script-bearing dependencies, or require an explicit trusted-publisher workflow. A hash only pins bytes. Do not describe archive path checks as a complete execution sandbox.
- Importers handle untrusted binary data: fuzz malformed inputs, constrain memory/work before allocations where possible and reject external URI dependencies in initially supported self-contained formats. Do not evaluate animation callbacks or arbitrary serialized objects.
- Respect creator permissions independently of cache integrity. A user's permission declaration is not license verification; default bundled assets require audited rights, and reported/custom unlicensed assets must be removable. No automatic rehosting of avatars/worlds merely because they were cached.

## 7. Delivery sequence and proposed semantic commits

Each step includes its focused tests/fixtures and documentation update. These are future titles, not commits created by this planning document.

| Phase | Proposed commit | Deliverable / exit gate |
| --- | --- | --- |
| 1 | `feat(cache): add transactional content-addressed asset storage` | Schema/recovery, source handles, immutable blobs, independent consumers, limits and no relay writes; unit tests pass. |
| 2 | `feat(cache): revalidate remote assets and manage retention` | Conditional GET, retry/offline policy, quota/pinning, privacy and settings controls; fake HTTP/filesystem cases pass. |
| 3 | `feat(avatar): load and refresh avatars through the asset cache` | Local/remote/preview use shared bytes, separate nodes and revision notifications; existing generation/worker regressions pass. |
| 4 | `feat(world): cache validated worlds with instance revision pinning` | Immutable extraction, trust policy, exact-hash staging, negotiated client/relay acknowledgement and cleanup; mismatch fails without replacing membership. |
| 5 | `feat(animation): bundle audited reusable default motions` | Free-download clip/license audit, provenance/notices, canonical rig, offline locomotion playback. |
| 6 | `feat(animation): import and retarget VRMA and GLB clips` | Real runtime adapter, safe tracks, rig mapping, cache schema and malformed-input tests. |
| 7 | `feat(animation): add desktop and VR animation library controls` | File/link import, preview/player, persistence, IK/layer rules and accessible error states. |
| 8 | `feat(network): synchronize instance animation playback` | Capability negotiation, authenticated reliable state, clock, revisions, late joins and lifecycle cleanup; defaults and public-link clips work end to end. |
| 9 | `feat(animation): share consented local clips within instances` | Bounded requested chunk transfer, integrity, license/consent UX, cancellation and voice fairness. Required before calling local-file playback fully synchronized. |
| 10 | `test(assets): verify cache updates and multiplayer animation recovery` | Cross-feature failure/recovery, export licensing audit and documented manual desktop/VR release checks; remaining measured limits recorded. |

Do not ship a dependent UI/network step as complete before its importer/distribution dependency exists. If protocol/trust work cannot be safely split, merge the necessary units into a coherent tested change.

## 8. Verification and release checklist

Add isolated disposable-project runners following existing `tests/*/run.py` patterns: proposed `tests/asset_cache/` and `tests/animation_sync/`, with copied production dependencies and fixtures instead of real accounts, external hosts or physical devices.

- **Cache:** initial download, repeat hit, identical bytes under different URLs, query-sensitive keys, 304/no local blob, changed ETag/same ETag with forced refresh, no validators, no-store/no-cache, redirect rules, timeout/404/expired credentials, disk full, corrupt index/blob, crash recovery, concurrent waiters, cancellation and offline restart.
- **Retention:** count extracted/derived/staging bytes; preserve active pins and user imports, reference-count deduplication, quota exhaustion, safe clear/reset and no deletion outside the managed root. Verify relay mode never creates cache files.
- **Avatars:** repeated same-URL loads avoid redundant transfers; accepted new hash replaces each relevant consumer once; stale completion cannot overwrite newer selection, independent skeletons animate independently and failed refresh retains the old avatar.
- **Worlds:** traversal/oversize/dependency attacks, unsafe scenes, cache reuse, immutable active files, exact revision matching across clients, missing old revision, rejected admission, relay loss and failed activation preserve the existing transition guarantees. Two sessions at one URL remain isolated.
- **Animations:** bundled offline defaults/provenance, valid official-format VRMA fixtures, GLB multi-clip selection, rest-pose/scale/VRM version cases, missing bones, malformed extensions, oversized tracks, prohibited callbacks, avatar swap, source reimport and unchanged original file.
- **Networking:** two/three real loopback clients with controllable clock/network conditions; start/pause/resume/stop/loop/speed, order/replay/spoof attempts, late join, delayed/missing blob, revision mismatch, chunk corruption/cancellation, owner departure, peer-ID reuse, instance transition, eviction, older capability set and cross-instance isolation. Scan relay state for disconnected-user references.
- **Performance:** measure cache-hit latency, worker/frame stalls, memory/disk peaks, concurrent avatar/import work, asset bandwidth limits and voice/control fairness. State fixture sizes and hardware; do not infer XR performance from headless Compatibility tests.

Run all existing isolated regression runners when implementation touches their paths:

```sh
python3 tests/microphone_settings/run.py
python3 tests/profile/run.py
python3 tests/public_discovery/run.py
python3 tests/active_instance/run.py
python3 tests/friends/run.py
python3 tests/avatar_loading/run.py
```

Manual release gates: clean exported offline defaults and notices; real desktop/VR file/link input; different humanoid rigs; animation/tracking/camera comfort; two-client visible synchronization and third-client late join; large world/avatar cache behavior; physical microphone/listening checks during transfer. These are future requirements, not checks performed for this documentation-only roadmap.

**Done means:** encountered permitted assets survive restart in one managed folder; source updates are detected and safely redownloaded; old/active revisions remain consistent; freely reusable defaults ship with evidence; users can select a VRM avatar and import VRMA/GLB animation files or links; and all compatible, consenting same-instance players receive the exact animation and synchronized state, including local-file distribution and late-join recovery.
