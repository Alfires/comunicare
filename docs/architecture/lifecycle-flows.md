# Lifecycle sequences and decision boundaries

The diagrams below describe control order, not independent implementations.
Function contracts are in [the API reference](../reference/functions.md), packet
shapes in [protocol](../reference/protocol.md), disk state in
[storage](../reference/storage-formats.md). All active scene/network work is main
thread; import parsing explicitly delegates detached work to workers.

## Startup and authentication

```text
Engine → DataLoader ready → SaveData settings/mute → NetworkHandler ready
Startup → load_acount → key/profile/contact configuration
Startup → create_peer → ENet connected → AUTH_HELLO(public key)
Relay → issue_challenge(peer/key/expiry) → client signature
Relay → verify_response(consumes challenge) → AUTH_RESULT/capabilities
Client → publish signed profile → startup creates local player/home scene
```

Server flags branch before client account writes. Invalid existing key is a
recovery error, not a reason to mint a new identity. Actual GPU/XR availability
determines desktop fallback; isolated tests replace physical devices/accounts.

## World admission and rollback

```text
WorldExplorer → join_session(exact session ID)
Coordinator → resolve authorized code/revision → prepare_world_from_url
Cache/loader → bounded validation/extraction → staged scene + leases
Coordinator → JOIN_SESSOIN(expected URL/hash)
Relay → access + bans + current-admin approval → SESSION_RESULT
Coordinator → matching success → activate_world → scene_changed → spawn
```

Before acknowledgement, rejection preserves old membership. After an uncertain
commit/activation failure, disconnect prevents broadcasting from the wrong world.
The relay carries active revision metadata but never downloads world content.
Friends/Request access and moderation remain separate checks; a cached world or
friend presence does not admit a user. Executable world trust is not a sandbox.

## Source Apply and resolved motion

```text
Avatar editor → import_source → cache staging → validator → immutable bytes
Editor → Apply → validate all candidate references → save account config
Configuration → restore role set (external > embedded > bundled)
Local state machine → resolve movement OR accepted emote intent
Renderer → bind humanoid rotations → blend from currently visible owned pose
Controller → resolved version-2 state → relay actor/session/schema checks
Remote → exact hash/model/clip available? → request typed bytes if missing
Remote → final hash/format validation → import → seek current phase → blend
```

Menus/layout browsing generate no motion commands. Custom share permission is
independent of hash validation. Mutable source updates revalidate/rebind with
generation guards; cache corruption never silently grants publisher trust.

## Rendering and local tracking

```text
Import worker → original intact mesh + prepared first-person derivative
Attach → local camera cull masks → other cameras keep original
Animation evaluates body → owned pose transition → final SkeletonModifier
External headset/controller targets → head alignment + bounded arm reach
Shared skeleton deforms original and local derivative
```

The avatar follows tracking; camera targets are never children of animated bones.
Current first-person filtering intentionally excludes interior torso/pelvis as well
as head, trading local torso visibility for camera-shell clearance. VR tracker
correction is local only; existing movement packets send body pose, not all trackers.
Author annotations/fallback skin weighting and controller calibration still need
visual tests on real assets/hardware. Do not describe this as complete VRChat IK.

## Consent delivery and presence

```text
Alice saves Bob key locally (not friendship)
Alice → signed request + durable outbox → authenticated relay → active Bob
Bob verifies recipient/signature → durable commit → receipt
Bob explicitly accepts → signed request-bound accept → Alice verifies/commits
Durable receipt confirms acceptance → fresh pairwise authorize → presence
Revocation/block → local terminal/outbox → retries → late accept cannot resurrect
```

No relay offline mailbox. Reconnect reauthenticates and republishes live grants;
client terminal records close stale restored relationships. DND suppresses social
interruptions, not microphone capture. Presence expires and does not grant access.

## Disconnect and UI cleanup

```text
ENet timeout/disconnect → relay peer_disconnected
 → auth/challenges + profile + membership + identifying caches removed
 → social pair proofs/subscriptions + asset requests/state/generations removed
 → pending candidate/moderator admissions fail closed → survivors notified
Client → transport flags/session cleared → remote profiles/players/state cleared
UI → subscriptions detached → input capture/focus restored once
```

Client contacts/config/cache persist under their owners; relay application state
does not. OS/network buffers and host logs require deployment controls beyond the
application erasure contract. Tests verify application references, not forensic RAM.

## Decisions

- [Relay lifecycle](../relay-data-lifecycle.md) supersedes old relay-retained bans.
- [Asset provenance](../../THIRD_PARTY_ASSETS.md) records adapted directional walks
  and static composed standing pose rather than claiming dedicated captured strafes.
- Git-only releases use explicit stable baseline/eligible branch, recoverable
  metadata and verified release notes; [release guide](../development/releases.md).
  No implicit first version, hook installation, remote tag or hosting API call.

Verification: [test commands](../development/testing.md) and local documentation/
versioning tests. Historical roadmap counts are not a current test result.
