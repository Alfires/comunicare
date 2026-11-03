# Service contracts and flow reference

This is a reviewed service-level reference, **not yet an exhaustive function
inventory**. Exact signatures and private helpers remain in the linked source.
Read authorization and lifetime requirements before calling services directly.

## Startup and settings

- [`main.gd`](../../scripts/startup/main.gd): `_ready()` selects relay/client;
  `load_initial_scene()` creates the root-owned player and home world. Client
  startup loads the account before relay authentication. Account failure is
  reported rather than silently replacing a damaged key.
- [`save_data.gd`](../../scripts/settings/save_data.gd): `load_acount()` loads or
  creates a private account key, then `initialize_profile()` configures key-owned
  profile/friends services and avatar configuration. `laod_data()` preserves the
  legacy spelling and migrates general settings. These functions write client
  persistence; never call them in relay mode or tests with real user paths.
- [`settings_registry.gd`](../../scripts/settings/settings_registry.gd):
  `register_setting()` rejects duplicate/invalid definitions; `validate()` checks
  typed values; `register_defaults()` supplies production definitions.
- [`settings_store.gd`](../../scripts/settings/settings_store.gd): owns typed
  configuration persistence and change notifications. UI renders definitions;
  it must not create a second value owner or mix signed profile fields into it.
- [`voice_controller.gd`](../../scripts/player/voice_controller.gd): shared mute,
  key binding, capture registration and input suppression. Only one active
  capture owns microphone samples. Saved mute applies before capture begins.

## Instances and social state

- [`network_handler.gd`](../../scripts/multiplayer/network_handler.gd):
  `create_peer()` awaits authentication; `join_session()` and `host_world()` stage
  content before a relay operation and await correlated results. Failure before
  admission preserves the old world/session. Activation failure after admission
  disconnects to avoid wrong-world broadcasts. `get_animation_controller()` owns
  one recoverable service outside its remote-player cleanup list.
- [`relay_peer.gd`](../../relay_protocol/relay_peer.gd): encodes requests,
  dispatches bounded messages and exposes authenticated/capability state.
  `handle_events()` is polled by the coordinator; connection/session snapshots
  are replaced rather than merged across instances.
- [`relay.gd`](../../scripts/multiplayer/relay.gd): `on_packed()` dispatches
  authenticated wire operations; `peer_disconnected()` removes indirect as well
  as direct references. Membership/admin roles are relay-authoritative, not UI
  claims. Follow [the lifecycle contract](../relay-data-lifecycle.md).
- [`profile_service.gd`](../../scripts/profile/profile_service.gd) owns signed
  key-scoped fields and remote instance profiles. Call ownership checks before
  editing; instance admin rights never grant another profile's signing key.
- [`friend_service.gd`](../../scripts/profile/friend_service.gd) owns local
  signed contacts/consent/outbox/tombstones and status preferences.
  [`friend_router.gd`](../../relay_protocol/friend_router.gd) routes active
  connection state only. Friendship/presence is not unconditional admission.

## Asset and animation pipeline

```text
source URL/file → AssetCache → validator → immutable hash + lease
  → DataLoader worker → detached model/data → generation check → main-thread attach
configuration → resolved locomotion/emote → local renderer + instance descriptor
  → requested hash-verified transfer → remote renderer
```

- [`asset_cache.gd`](../../scripts/assets/asset_cache.gd): awaited `fetch()`
  coalesces bounded remote acquisition and conditional validation; `import_file()`
  copies originals before publishing. Returned handles carry a path/hash/lease.
  Keep the lease while resources depend on bytes. `revision_handle()` requires
  valid cached bytes; `clear_unused()` must respect active/pinned ownership.
- [`data_loader.gd`](../../scripts/startup/data_loader.gd): await avatar and
  animation imports. `_build_avatar()` is worker-only and returns a detached tree;
  callers attach on the main thread. `prepare_world_from_url()` stages content;
  `activate_world()` changes scenes only after coordinator acknowledgement.
- [`avatar_configuration.gd`](../../scripts/assets/avatar_configuration.gd):
  `import_source()` validates managed sources but does not equip them; awaited
  `apply()` validates/saves a complete account-scoped candidate. Failed work must
  not replace the last good selection. Source paths are not public profile URLs.
- [`animation_controller.gd`](../../scripts/assets/animation_controller.gd):
  `resolve_motion()` chooses movement state; `request_emote()`/`cancel_emote()` are
  gameplay intents, not a separate network player. `toggle_emote_menu()` needs an
  attached service and safely declines detached calls. Tracking masks and strafe
  composition precede rendering; remote state uses the same resolved rules.
- [`avatar_animator.gd`](../../scripts/assets/avatar_animator.gd): `attach()`
  creates a dedicated AnimationPlayer; `play_clip()` retargets safe channels and
  blends from visible owned-bone poses. It never owns camera or collision motion.
- [`first_person_avatar.gd`](../../scripts/assets/first_person_avatar.gd):
  `prepare()` builds detached local-view derivatives without replacing original
  mesh resources. `apply()` selects camera layers, not runtime geometry cutting.
- [`avatar_tracking.gd`](../../scripts/assets/avatar_tracking.gd): final local
  SkeletonModifier head/arm target correction. External targets stay independent;
  reach is bounded. No remote live-tracker protocol or full-body IK is implied.

Evidence: [isolated testing commands](../development/testing.md), especially
production lifecycle, optional real-VRM, animation and cache groups. Remaining
manual constraints: renderer/XR visuals, controller calibration, actual listening,
large transfer fairness, real Internet drift and unusual avatar skinning.
