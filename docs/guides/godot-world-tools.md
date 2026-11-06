# Create a world with Godot World Tools

## Enable the plugin

Open Comunicare's `project.godot` in Godot 4.7, let imports finish, then enable
**Comunicare World Tools** in **Project → Project Settings → Plugins**. The
scrollable **World Tools** dock appears on the right. It is opt-in; the project
does not enable it automatically.

The addon depends on Comunicare's `scripts/worlds/` validators. Copying only the
addon folder into an unrelated project is not a standalone installation.

## Create and edit

1. Click **New world**. The draft contains one spawn and a box floor.
2. Choose **Add scenery**, **Add pickup** or **Add interactable**.
3. Select an entity from the dropdown. Names are display labels; the underlying
   stable entity ID is retained when editing the name.
4. Edit the name, **Position X/Y/Z** and **Box size X/Y/Z**, then click
   **Apply entity fields**. Values do not commit merely by typing them.
5. Use **Duplicate selected** for a copy with a fresh ID. Duplication currently
   copies the entity, not its behavior bindings; add behavior explicitly.
6. **Delete selected** removes an unreferenced entity. Deleting the only spawn or
   an entity still referenced by behavior is rejected with a validation message.

The current format is box-based primitive scenery, pickups, interactables and a
single spawn. Spawn has position but no box-size editing. Rotation, model-import
UI, scene gizmos and general Godot scene conversion are not implemented.

## Add behavior

Select an entity and click **Add hide-on-use behavior**. This binds the reviewed
`use` action to that entity's stable ID and declares the required visual capability.
It is not an arbitrary GDScript attachment. Repeating the action appends another
binding; inspect the JSON when editing an existing behavior.

The JSON field exposes the complete authoring draft for advanced changes. Click
**Validate** after editing; invalid JSON, duplicate IDs, missing spawn, dangling
targets, unsupported assets or forbidden operations block save/export.

## Undo and redo

**Undo tool action** and **Redo tool action** restore plugin-local draft snapshots,
up to 32 undo entries. These cover entity field application, addition, duplication,
deletion and behavior tool actions. They are not Godot scene-editor undo or a history
of every keystroke in the JSON field. New/Open clears tool history. Invalid JSON
must be corrected before a tool action (including undo/redo) can proceed.

Save before New/Open or closing the editor: there is no unsaved-change confirmation.

## Save, export and play

- **Save project…** writes editable authoring JSON. Keep this file: the plugin
  cannot reconstruct authoring source from a `.cworld` package.
- **Open project…** loads/validates that JSON and preserves its world/entity IDs.
- **Export .cworld…** compiles reviewed scene/resource/script data to a temporary
  archive, runs the production world builder, then replaces the output on success.
  Invalid exports do not replace the last working package.
- In the running game, open **World Explorer → Open local map…** and select the
  exported package. This is offline play, not an upload or shared instance.

Production player preview rigs are not included in the package. Automated desktop/
VR client launching is not implemented: the playtest service only makes validated
launch plans. For multiplayer publishing, use the supported URL-hosted package
workflow rather than sharing a local filesystem path with the relay.

## Optimization and verification

**Analyze optimization** reports entity/dynamic-body counts and recommendations.
The optimization service currently offers lossless entity ordering, not mesh
reduction, batching, texture conversion or a measured FPS boost. It does not merge
independent interactables or silently discard unsupported content.

Run from the repository root:

```sh
python3 tests/world_authoring/run.py
python3 tests/world_system/run.py
```

Authoring tests cover service behavior and a disposable headless Godot plugin
enable/shutdown smoke. They do not certify all rendered dock interactions, native
file dialogs, physical VR comfort or full visual level editing.

See also [safe authoring](safe-world-authoring.md),
[package model conversion](downloadable-world-models.md),
[in-game collaboration](editing-with-friends.md), and the
[remaining plugin roadmap](../roadmaps/world-authoring-plugin-roadmap.md).
