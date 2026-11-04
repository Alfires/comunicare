# Wire protocol reference

Authority: [explicit IDs](../../relay_protocol/packet_info.gd),
[client dispatch](../../relay_protocol/relay_peer.gd),
[relay dispatch](../../scripts/multiplayer/relay.gd). All packets start with a
one-byte type; ENet channel is 0. Never renumber existing IDs to reorder this table.
The misspellings are compatibility identifiers, not recommended new names.

| ID | Enum | Contract |
| --- | --- | --- |
| 0 | ID_ASSINGMENT | Legacy byte ID plus remaining peer IDs; current client ignores it |
| 1 | CREATE_SESSION | Reliable JSON metadata: mode, name, description, world_url, optional world_revision |
| 2 | JOIN_SESSOIN | Reliable JSON session_id/world_url/world_revision; decoder also accepts legacy ID-only text |
| 3 | GET_SESSION_PEERS | Reliable JSON array of other peer IDs in recipient's instance |
| 4 | GET_PUBLIC_SESSIONS | Reliable JSON public summaries; no membership or account-key roster |
| 5 | SESSION_RESULT | Reliable JSON operation/session_id/success/message/world_url/world_revision |
| 9 | VOICE_DATA | Unsequenced sender byte and signed 16-bit PCM samples |
| 10 | PLAYER_DATA | Unsequenced 26-byte sender/position/Euler rotation record |
| 11–14 | AUTH_HELLO / AUTH_CHALLENGE / AUTH_RESPONSE / AUTH_RESULT | Public-key hello, bound challenge, signature, outcome/capabilities |
| 15–16 | PROFILE_PUBLISH / PROFILES_SNAPSHOT | Owner-signed profile, then same-instance replacement snapshot |
| 17–20 | INSTANCE_REQUEST / INSTANCE_RESULT / INSTANCE_SNAPSHOT / INSTANCE_EVICTED | Revisioned management, correlated outcome, authoritative roster, eviction |
| 21–23 | ADMISSION_QUERY / ADMISSION_REPLY / MODERATION_POLICY | Fresh admin policy decisions and client-owned ban policy updates |
| 24 | SOCIAL_DATA | Version-1 negotiated live social routing; signed consent and scoped presence |
| 25–27 | INSTANCE_LOOKUP / JOIN_REQUEST / JOIN_DECISION | Authorized code lookup and expiring admin approval |
| 28 | ANIMATION_DATA | Version-2 resolved animation plus requested typed asset delivery |
| 29 | WORLD_DATA | Negotiated version-1 ephemeral item leases, snapshots and bounded held poses |

### World item version 1

AUTH_RESULT advertises `world_items_version: 1`; client sends hello/version and
receives transport-derived peer ID plus random connection generation. Without this
exchange `send_world` does nothing. Requests carry exact `session_id`/`revision`;
grab/release/pose additionally carry stable entity, monotonic sender sequence and
lease epoch. Grip is left/right/virtual. Relay derives holder and generation, never
trusts a claimed actor, and limits 60 requests/s, two held items/sender and 256
tracked items/instance. Poses are finite bounded XYZ plus normalized quaternion.
Reliable item/pose broadcasts and snapshots contain an instance sequence watermark.
State/rates are active-memory only; disconnect releases leases and removes identity
references, empty instances are deleted. The relay has no world geometry, so it
cannot validate actual reach/item existence. Clients ignore unknown entity IDs and
validate scope/poses before moving scene objects. This is initial carrying, not
authoritative anti-cheat or cross-client free-body physics synchronization.

IDs 6–8 are not assigned here. Access modes are PUBLIC=0, PRIVAT=1, FRIENDS=2,
FRIENDSP=3, REQUEST=4. Friendship/presence never grants profile editing rights.

## JSON envelope and validation

`AccountPacket.create(type, dictionary)` marks reliable delivery; `encode()` adds
UTF-8 JSON after the type byte. `parse()` returns `{}` for non-object JSON or
2..256 KiB length violations. That generic bound is **not** authorization: relay
handlers apply smaller limits (e.g. animation 16 KiB), schemas, capability and
membership checks. Some legacy packet decoders call JSON parsing directly and
expect transport validation; do not use them as arbitrary hostile-input parsers.

Authentication challenges encode a domain-tagged array bound to a peer/account and
expire; consumed challenges cannot replay. Profiles sign a fixed ordered array:
`["comunicare/profile/v1", public_key, revision, username, description, icon, avatar]`.
Use the production serializer/verifier, not a differently ordered JSON object.

## Binary records

PlayerData: byte 0 type 10, byte 1 relay-derived actor, float32 positions at byte
offsets 2/6/10, Euler rotation at 14/18/22. Total 26 bytes. VoiceData: byte 0 type 9,
byte 1 actor, then little-endian signed 16-bit mono samples at offset 2, encoded
from clamped float input (`sample * 32767`). Neither is a durable history. Relay
replaces claimed sender IDs and routes only inside acknowledged membership.

## Acknowledged instance transition example

The following is an illustrative object after decoding; fields must still be
validated and values resolved from the actual relay, not copied as credentials:

```json
{"operation":"join","session_id":"Ab12C","success":true,"message":"","world_url":"default_wold","world_revision":""}
```

Create/join require authentication. A negotiated pinned revision must match staged
content before requesting membership; cached bytes do not bypass admission. Admin
metadata uses expected revision, request ID and stable target fingerprint/peer
guards. Snapshots require unique fingerprints/peer IDs, 1..256 members, role
`admin`/`member`, valid metadata and a nonempty session. Client results from another
instance/request cannot complete the current operation.

## Resolved animation and asset delivery

Tracked poses use a separate negotiated `tracking_version: 1` capability and
`pose_hello` inside ID 28. `pose` carries version/sequence/session/avatar hash/
calibration revision and up to six avatar-root-relative seven-number transforms
(position xyz + quaternion xyzw). Roles: head, leftHand, rightHand, hips, leftFoot,
rightFoot. Positions are finite within 4 m, quaternion norm checked. Relay adds
authenticated actor/generation/time, accepts at most 30 pose packets/s and expires
current pose after one second; sends only to opted-in capability peers in the same
instance. Client emits at 20 Hz when sharing enabled, interpolates matching-revision
targets and fades stale head/hand overrides. No room mesh, device ID or durable
tracking history. This is avatar target replication, not a second animation player.

Handshake advertises animation version 2; a version-2 hello enables it. Manual
version-1 Play/Pause/Stop controls are rejected. Example builtin state:

```json
{"op":"state","version":2,"session_id":"Ab12C","sequence":1,"action":"resolved","kind":"locomotion","role":"walk","mask":"full","configuration_revision":0,"avatar_revision":"","offset":0.0,"speed":1.0,"loop":true,"duration":1.3333333730697632,"builtin":"walk","library":"quaternius.directional.v4","hash":""}
```

Relay adds actor ID, random connection generation and monotonic `started` time.
Bounds: sequence 1..2^31−1, offset 0..600, speed .25..2, duration .001..600;
mask `full` or `tracked_head_hands`. Custom motion needs SHA-256 hash, 20..16 MiB
size and clip index 0..63; optional model hash needs 20..64 MiB size. Builtin
library ID/duration must agree exactly enough with the active implementation.
The asset library version is independent of app SemVer and animation capability.

Clock samples carry nonce/time. Snapshots carry current same-instance state for
late loading. Missing assets are requested by owner/hash and `asset_kind`
(`animation`/`avatar`). Chunks are base64, at most 8,192 decoded bytes, with exact
ordered offsets and a receiver-bound pending request. Receivers verify final hash
and format before import. No local path or source URL secret is advertised. Current
router allows 16 control packets / 256 KiB JSON per second per connection;
transfer queues are bounded and removed on completion/expiry/owner departure.
Reliability does not imply unlimited bandwidth or validated Internet drift.

## Social consent and disconnect

Friend events use domain `comunicare/friendship/v1`, random event/relationship IDs,
canonical actor/recipient keys, signed fixed-order fields and a nested request
digest for accept/decline/cancel/revoke. Payload maximum is 24,000 JSON characters.
Only the intended actor may route an event; presence requires fresh pairwise
authorization, connection generation, monotonic sequence and client expiry.

Every disconnect erases direct and indirect relay references, including pending
admissions, animation transfers and social subscriptions. Persisted consent and
moderation belong on clients. See [lifecycle](../relay-data-lifecycle.md).

Evidence: profile, discovery, active-instance, friends and animation
[isolated runners](../development/testing.md). They cover spoofing, replay,
isolation and cleanup; they do not prove transport encryption or a full renderer.
