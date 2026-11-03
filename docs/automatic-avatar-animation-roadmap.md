# Automatic avatar animation and source-only configuration roadmap

## Status and interpretation

**Planning only — 2026-11-03.** This document specifies a replacement for the current manual animation-player experience. No runtime behavior changes with this roadmap.

This plan supersedes the manual playback/control UI and parallel animation synchronization proposals in [avatar-cache-and-animation-roadmap.md](avatar-cache-and-animation-roadmap.md). Its cache, licensing, admission and privacy requirements remain applicable.

Requested experience:

1. Animations automatically apply to the user's equipped avatar, without clicking Play or selecting a separate synchronization mode.
2. Other players see the **same automatically resolved avatar animation**. There is one authoritative animation state, not separate manual-player and automatic-locomotion streams.
3. Remove the standalone Home animation/avatar shortcut and put avatar/animation configuration inside the existing **User → Avatar** menu.
4. Animation configuration only selects a model file/URL, a model with embedded animations, and/or **multiple external animation files/URLs**. It is not a playback console.

**Scope of “remove other syncs”:** remove redundant/manual **animation** synchronization paths. Do not remove movement, voice, authenticated profiles, world transitions/revision checks, friendship or moderation networking. Clock samples, same-instance snapshots and requested asset delivery are supporting transport for the single animation state, not additional independently controlled animations.

**Button clarification:** the current Home header button is labeled **Animations**, not Avatar. Remove that standalone entry and route configuration through the existing self-profile/User menu's Avatar section. Keep the profile/account entry itself; otherwise users would lose the requested destination.

## Current implementation to replace

- `scripts/GUI/home_menue.gd::_ready()` creates an Animations header button and `open_home_menu()` accepts `animation_menue`.
- `scripts/GUI/animation_menue.gd` exposes clip selection, Play/Pause/Resume/Stop, Loop, speed, a manual automatic-locomotion switch, full-body VR and sharing toggles. Imports currently replace neither the equipped model nor its automatic motion mapping.
- `scripts/assets/animation_controller.gd` has a limited automatic desktop selector plus independently callable `play()`, `pause()` and `stop()` controls. Manual selection can disable automatic movement animation.
- Defaults provide idle/walk/run/jump/fall/land/wave/cheer, but automatic selection currently chooses only idle/walk/run/jump/fall. It does not provide a complete landing transition or an embedded/custom replacement set.
- `scripts/GUI/profile_menue.gd` already contains owner-only avatar editing and an independent preview. Local model selection currently previews only; it does not equip/share a local avatar.
- The importer accepts a rotation-only VRMA/VRM-mapped GLB subset. A generic animated GLB is not automatically a compatible humanoid avatar. Do not advertise arbitrary models or full VRMA support without implementing and testing them.
- Wire ID 28 carries reliable clip/playback state and requested animation chunks. Movement uses its existing separate protocol. Preserve explicit wire IDs and the relay's no-durable-data lifecycle.

## 1. User/Avatar navigation and source-only UI

Navigation becomes:

```text
Home → existing User/profile entry → Avatar (owner only)
  Model
    Select file… OR enter URL
  External animation sources (zero or more)
    Add files… / Add URL
    Source rows: filename/host, loading/error status, Remove
  Embedded animations: discovered automatically from selected model
  Read-only summary: active automatic roles / missing-role fallbacks
  Apply / Cancel
```

- Reuse the current profile owner/service checks. Other users' profiles remain read-only; being an instance admin must not grant avatar configuration rights.
- Remove the extra Home header button, its submenu route and its focus-return assumptions. Do not add a second Avatar top-level tab or alter the Home 2×2 grid.
- Place the source editor in the self User/Avatar menu; the animation section there is strictly a source list. Remove manual clip playback selection, Play/Pause/Resume/Stop, Loop, speed and “Use automatic desktop locomotion” controls.
- Allow one model source and multiple external animation sources at once, including multiple files in a file picker and repeated URL additions. Deduplicate exact source/revision references without collapsing meaningful URL queries.
- Embedded clips are discovered, not added again as external files. A model without compatible animations still works with defaults plus external replacements.
- Apply validates a complete candidate and equips it atomically; Cancel discards only the draft. Opening/closing a menu never pauses, stops, restarts or disables the actual avatar's animation.
- Keep error/progress text and read-only preview feedback. An optional preview is isolated and automatic; it cannot emit instance animation state or control the equipped player.
- Move privacy, remote-content and VR policy into appropriate account/settings UI, not playback widgets in this source selector. Preserve explicit redistribution permission when importing local content: source selection is not permission to publish files. No-store/private sources must never silently become shareable.

**Acceptance:** all requested inputs are available from self User → Avatar, with no standalone Home shortcut and no playback controls. Existing profile navigation, microphone placement, small-window layouts and visitor read-only behavior remain intact.

## 2. Avatar configuration and automatic role resolution

Introduce a client-owned avatar configuration service, separate from general settings and signed public profile fields. Persist a versioned, account-scoped selection:

- model source type and managed revision;
- ordered external source references and revisions;
- selected embedded/external clip-to-role resolution;
- redistribution permission/provenance where supplied;
- schema/importer version and configuration revision.

Local absolute paths remain local and must not appear in public profiles, instance snapshots or relay state. Signed profiles can continue advertising a valid public avatar URL; local model references need a separate capability-negotiated same-instance descriptor, not a fake `file://` profile URL. Preserve existing profile ownership and corrupt-store recovery behavior.

### Automatic role mapping

Define canonical movement roles: **idle, walk, run, jump, fall, land**. Wave/cheer are not automatically triggered without a separate gameplay event and are not exposed as manual playback choices in this change.

Resolution order:

1. Compatible external clips with explicit role metadata, or recognized normalized names such as `Idle`, `Walk`, `Run`, `Jump`, `Fall` and `Land`.
2. Compatible embedded clips using the same role discovery rules.
3. Bundled CC0 defaults for roles not supplied by either source.

For conflicts, later external source rows override earlier ones; stable clip index/name ordering resolves duplicates within a source. Show the outcome read-only. Unknown/ambiguous names are reported and left unused, not assigned randomly. Supporting an optional data manifest for explicit role names keeps the menu source-only; defer manual clip-mapping controls unless separately requested.

- Multiple files may supply different roles, and one file may supply many roles. Never treat “multiple external animations” as a selector that discards the previous import.
- Validate humanoid metadata, rest transforms, clip duration and safe tracks before activation. Preserve generation guards, bounded worker imports, detached model construction and main-thread attachment.
- Define loop and blend behavior in the runtime: locomotion loops; jump/land are bounded one-shots; fall follows airborne state. No per-user speed/loop console. Playback speed may derive from movement speed within validated bounds.
- Evaluate actual player velocity, grounded transitions and movement state. Add transition hysteresis, a landing edge and blend durations; do not restart idle/walk every poll or infer a remote player's grounding from unrelated local physics.
- Avatar replacement, account change and same-URL source updates rebuild the candidate role set and rebind once. Failed validation retains the last complete working avatar/set. Updating an inactive source does not reset the active playhead.

**Acceptance:** a default install immediately animates the equipped avatar; a custom walk file replaces walking automatically while other roles retain defaults; several external files and embedded clips cooperate predictably after restart.

## 3. One runtime animation authority

Separate responsibilities:

- **Configuration service:** owns sources, revisions, permissions and the resolved role set.
- **Avatar animation state machine:** selects roles and blends from real gameplay/tracking state; owns local playback.
- **Network adapter:** publishes that resolved state and applies remote state. It never decides independently which local clip should play.
- **Avatar renderer:** binds the validated role set to one AnimationPlayer/AnimationTree layer per avatar.

Desktop and VR use the same lifecycle/configuration service. In VR, tracked head/hands and IK retain priority; automatic animation fills safe untracked bones/lower-body locomotion only. Do not automatically replay a full-body desktop clip over headset tracking, move the camera or introduce root-motion collision movement. If safe masks cannot be built, fall back to tracking/neutral pose and report compatibility rather than requiring a manual Play toggle.

Remove the old `automatic_motion` mode switch and UI-owned manual playback API once all callers migrate. Internal AnimationPlayer operations can still exist as rendering primitives; there must be no second public manual controller or separately networked clip stream.

**Acceptance:** one local state machine drives animation regardless of menu visibility or network connectivity. Reopening configuration cannot create duplicate players, controllers, animation tracks or subscriptions.

## 4. Synchronize only the automatic result

The local state machine publishes one descriptor representing its **currently resolved automatic animation**, with enough information to reproduce the result:

- acknowledged `session_id` and connection generation;
- actor identity derived by the relay, never trusted from client claims;
- avatar/configuration/animation-set revisions;
- canonical role and exact resolved clip/blob/built-in library revision;
- sequence, transition/blend parameters, effective monotonic start/playhead and bounded derived speed;
- any declared layer/mask version required for safe compatible rendering.

- Publish role/configuration transitions and bounded correction keyframes, not every bone every frame and not a second movement packet. Keep existing movement/voice packets unchanged.
- Remove remotely callable manual Play/Pause/Resume/Stop semantics. A private preview or changing a highlighted source must emit **zero** animation packets. Avatar disappearance, transition and disconnect use lifecycle cleanup/fallback rather than a competing manual Stop action.
- Remote clients render the sender's resolved role/clip and phase, not an independently guessed locomotion state that competes with it. Until the exact data is ready, use a clearly defined default/neutral fallback; when it arrives, seek to the current phase without restarting the sender's animation.
- Retain capability negotiation, authenticated same-instance authorization, monotonic clock estimation, latest-state late-join snapshots, replay rejection and reused-peer-ID/session-generation guards.
- Retain requested content delivery as a dependency of this one state. Bound requests/chunks/rates and verify hashes/permissions before use. Remove orphaned descriptors/queues when their automatic state or owner is gone. Do not remove the only means for receivers to obtain local imported models/motions and still claim matching results.
- Extend delivery for **equipped local model files/model-with-animations**, not just animation-only files. Keep avatar and animation format/size validators distinct, preserve cache leases, and never blindly raise animation limits to avatar limits.
- Negotiate a new automatic-state version explicitly. Preserve numeric wire IDs; reject unsupported/old manual-state messages after the switch instead of routing them into the new controller. Old clients retain movement/voice and safe visual fallback, not hidden manual-sync compatibility code.
- Keep the relay ephemeral: only current connection/instance state, no durable avatar library, local paths, source secrets, playback history or disconnected-user references. Follow [relay-data-lifecycle.md](relay-data-lifecycle.md).

**Acceptance:** two clients show matching automatic idle/walk/jump/fall/land choices and compatible phase; a late joiner recovers that same state. Manual legacy packets and menu-only operations cannot alter remote animation. Movement, voice, admission and profiles still work.

## 5. Migration and cleanup boundaries

- Remove only the obsolete Home button/route, manual widgets, associated callbacks, old manual wire schema/dispatch and tests specifically asserting that replaced behavior. Inventory references before deleting a scene/script; reuse `animation_menue` paths where useful rather than renaming compatibility resources gratuitously.
- Preserve cached original imports. Convert pinned imports into available source candidates; do not silently attach every historic received/cached motion to the current avatar. Persist explicit applied configuration only.
- Do not migrate transient manual playhead/speed/loop/full-body state into automatic configuration. Existing imported permissions must not be inferred from pinning or download history.
- Missing configuration starts with the existing avatar plus defaults. Corrupt configuration is preserved and reported, not overwritten. Account switching clears live/draft references without exposing another account's local choices.
- Update [asset-cache-and-animation-usage.md](asset-cache-and-animation-usage.md) and the parent roadmap when runtime migration lands. Until then, their current UI description remains the actual shipped behavior.

## 6. Proposed semantic implementation sequence

| Commit | Coherent deliverable |
| --- | --- |
| `feat(avatar): persist model and multiple animation source selections` | Account-scoped configuration, managed local models, embedded clip discovery, deterministic role resolution and migration tests. |
| `feat(animation): apply resolved motions automatically to avatars` | One desktop/VR-safe state machine, defaults/custom roles, landing/blending, generation-safe rebinds and no UI dependency. |
| `refactor(network): synchronize only resolved automatic avatar motion` | Coordinated client/relay schema negotiation, exact revisions, sole automatic state stream, required model/motion transfer and lifecycle tests; reject old manual state. |
| `refactor(ui): move source-only avatar setup into the user menu` | Owner-only User → Avatar source editor, multiple file/URL inputs, Apply/Cancel, removal of Home shortcut/manual widgets and navigation tests. |
| `test(avatar): cover automatic animation lifecycle and compatibility` | End-to-end default/custom/embedded/multiple-source cases, stale work/reconnect/late join, release documentation and measured limitations. |

Keep intermediate revisions runnable; combine mutually dependent changes when needed. This roadmap itself does not authorize removing unrelated networking or claim these implementation commits exist.

## 7. Verification gates

Extend isolated `tests/animation_sync/`, `tests/asset_cache/` and profile/navigation fixtures rather than launching normal startup against real user data.

- **UI:** standalone Home entry absent, User/profile entry preserved, self-only Avatar editor, file/URL model and multi-animation input, no manual playback controls, Apply/Cancel and Back/focus behavior at desktop/small/VR menu sizes.
- **Import/configuration:** model-only, model with embedded clips, multiple external files/URLs, duplicate/ambiguous roles, deterministic precedence, malformed metadata, incompatible rigs, source removal, offline restart and account isolation.
- **Automatic runtime:** spawn starts idle without UI; movement/ground transitions select expected roles, land plays once, transitions do not restart continuously, missing custom roles use defaults, source/rig swaps preserve the latest valid generation and independent avatars own separate nodes.
- **Networking:** one resolved-state stream, no manual control packets, previews/drafts produce no broadcasts, custom exact hashes, late-load phase recovery, clock correction, replay/spoof rejection, stale avatar/configuration revisions, chunk cancellation, owner departure and two instances at the same URL remain isolated.
- **Non-regression:** run all existing microphone/settings, profile, public discovery/startup, active-instance, friends and avatar-loading suites, plus both asset/animation suites. Retain moderation fail-closed behavior and relay disconnected-user cleanup checks.
- **Manual release:** real avatars with distinct rest rigs, desktop locomotion, headset tracking/IK masks, automatic-animation comfort, two/three-client visual comparison, latency/jitter drift measurement, transfer/voice fairness and exported builds. Record warnings and unmet gates rather than claiming complete support from synthetic headless checks.

**Done:** the user chooses avatar/animation sources once in User → Avatar; compatible animations apply automatically, including custom/embedded replacements; only that automatic avatar state is synchronized; no standalone Home shortcut or manual playback/sync mode remains; unrelated networking and client/relay privacy guarantees are preserved.
