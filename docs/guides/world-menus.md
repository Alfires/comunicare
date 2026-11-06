# Safe world menus: initial capability

Lifecycle regression checks reject actions emitted by retired pages after a new
menu opens. Only the currently owned menu can dispatch its bound actions. VM
validation also inspects zero-count repeat bodies, so dormant instructions cannot
hide unsupported capabilities. Local-save write throttling is per file: switching
to a different account/world namespace resets the previous file's throttle.

Declare `ui.local` in the package manifest. Add `ui/menu.worldui`:

```json
{"version":1,"pages":{"credits":{"title":"Credits","widgets":[
  {"id":"author","type":"text","text":"Created by your team"},
  {"id":"xp","type":"progress","bind":"state.xp","max":100},
  {"id":"upgrade","type":"button","text":"Upgrade","entity":"station",
   "actions":[{"op":"state_add","key":"xp","value":10}]}
]}}}
```

This example also needs `state.local`. Bind a restricted world program to the
`station` entity with a `use` event containing `{"op":"menu","page":"credits"}`.
An empty page closes the menu. Production desktop/VR pickup adapters dispatch
nearby use through the trusted world runtime; use/grab/release are client-local,
not authoritative multiplayer gameplay events.

Reviewed widgets: plain `text`, `button`, `progress`, `list`. Rich markup, external
links/images, custom classes and callback methods are not accepted. Text/progress/
lists bind to `state.<key>` or `saved.<key>`; buttons may have an `enabled_bind`
whose value must be boolean true. Lists show up to 32 bounded text entries. Bindings
refresh at 10 Hz. Menu/action counts, values and VM work are bounded.

`state_set` / `state_add` use `key` and `value`, separate from permanent saves.
Run state is reset on runtime configuration. No general calculations, timers,
observations, rewards, combat or seeded-random APIs are delivered by this slice.

Desktop uses application-created Controls with focus and Escape/close handling.
VR uses the shipped panel helper and right-controller trigger ray; rendered and
physical headset acceptance remains open. World menu opening blocks existing
gameplay movement/interaction through input ownership without disabling application
controls. Opening the VR application menu closes the world page. World script ticks
pause while the page is open; this does **not** pause physics, other clients, or any
future combat system. Transition/script-stop removes the menu and releases ownership.

Package tests create a real ZIP with a menu/program, validate it using the production
reader/builder, dispatch station use via the shared interaction adapter, click an
actual Button, check a ProgressBar binding and test unload cleanup. These are not
full rendered desktop/VR journeys or the actual exported Ember Crypt map.

Still pending from the requested Ember Crypt requirements: full UI page navigation/
rich text/Label3D, numeric gameplay/timers/observations/reward deduplication, navigation/
combat/rigged enemies, environment import parity, progression schema migrations and
coalesced writes/stable local-save identity, audio/effects and target-device profiling.
No package limits were raised and downloaded GDScript remains forbidden.
