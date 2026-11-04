# Worlds, instances, settings and voice

## Safe world transitions

A URL selects content; a session code selects one running instance. Two instances
at the same URL remain separate. World Explorer combines a content catalog with
live public-instance summaries; private/social instances are not public discovery.
Code lookup is authenticated and does not itself admit the player.

```text
select instance → authorized resolve → stage/validate exact world revision
 → request join → relay admission/result → activate staged scene
```

Failure before acknowledgement leaves the old membership/world active. If the
relay may have committed a transition but the client cannot establish the outcome,
the coordinator disconnects rather than sending from the wrong world. Cache hits
never bypass admission. New instances can pin hashes; older unpinned peers cannot
provide the same consistency guarantee.

Remote worlds now require the versioned `comunicare.world` format. ZIP and Godot
text scenes/resources are parsed as data and reconstructed from reviewed built-in
types; downloaded scenes are never loaded through ResourceLoader. Legacy executable
worlds are rejected even if the old trust setting is enabled. This is a restricted
initial profile, not full Godot/Terrain3D compatibility or a security certification.
See [safe world authoring](safe-world-authoring.md) for supported content and limits.
Built-in `default_wold` keeps its legacy spelling and application-trusted scene.

Active Instance shows authoritative members/roles and acknowledged code. Admin
edits use revisions and correlated results, not optimistic local rights. Kick,
ban and promotion target stable identity plus peer guards; a reused peer number
must never redirect moderation to another person.

## Settings and microphone

Settings are registry-defined and typed. Changing a definition extends ordinary
load/save/default/UI behavior without putting profile fields into general config.
Invalid values are rejected; corrupt stores are preserved for recovery. Per-field
and per-category resets restore defaults, not account keys or signed profiles.

The shared voice controller owns mute across Home, Settings and desktop/VR capture.
First launch is muted, and saved mute is loaded before capture starts. V is the
default microphone toggle; B opens Emotes. Rebind under Controls. Typing, dialogs
and key capture suppress global shortcuts. Muting clears queued local samples;
unmuting must not replay stale speech. Input gain/threshold affect outgoing voice;
muting your microphone does not mute incoming voices.

Device availability and physical audio quality require manual checks. Headless
packet tests use fixtures, not your microphone. Inspect the actual error/status
rather than assuming a UI toggle means the device is recording successfully.

Sources: [coordinator](../../scripts/multiplayer/network_handler.gd),
[settings registry](../../scripts/settings/settings_registry.gd),
[voice owner](../../scripts/player/voice_controller.gd).
Verification and manual limitations: [testing](../development/testing.md).
