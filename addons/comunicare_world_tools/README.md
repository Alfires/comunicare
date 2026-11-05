# Comunicare World Tools — initial plugin

Enable **Project → Project Settings → Plugins → Comunicare World Tools**.
The **World Tools** dock appears on the right. It is not enabled automatically.
This addon currently depends on the game's `scripts/worlds/` runtime validators;
copying only the addon into an unrelated project is not sufficient.

1. Choose **New world** for a spawn and floor.
2. Add pickups or interactables. Edit positions, sizes and names in the JSON field.
3. **Add hide-on-use behavior** targets the last entity. Other supported restricted
   behaviors can be entered in the JSON; validation checks capabilities/references.
4. Save the editable JSON project separately from the playable package.
5. Validate, then **Export .cworld…**. The production world builder checks staging
   output before the final export is replaced.
6. Open the export through the game's **World Explorer → Open local map…**.

Only box-based primitive scenery, pickups, interactables and a single spawn are
supported by this initial authoring schema. External asset inventories and unknown
fields fail explicitly; unsupported native scripts are never silently omitted.
Stable IDs are separate from display names. Source files are not modified by export.

Optimization currently provides workload counts/recommendations and a lossless
canonical-ordering service, not mesh reduction, draw-call batching or an FPS boost.
Playtest service produces validated isolated launch **plans only** and explicitly
returns `launch_supported: false`; it does not start PC/VR clients. Full model
import, gizmos, typed behavior forms, undo/redo and player launch integration remain
in the [roadmap](../../docs/roadmaps/world-authoring-plugin-roadmap.md).

Run `python3 tests/world_authoring/run.py`: production service contracts plus
isolated headless editor enable/shutdown smoke. Rendered dock interaction, native
dialogs and physical VR are not certified by those checks.
