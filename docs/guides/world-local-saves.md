# Local world progress

World packages may declare `"storage.local"` in `script_capabilities` to save small
client-local progress records. This grants no arbitrary file access and sends no
save data to the relay. Scope is the current account and **exact world URL**;
instances/releases at that URL share progress. A different URL starts a separate
save. This is not publisher-authenticated storage: whoever controls that URL can
read/change that world's progress through a future package at the same URL.

Example manifest field:

```json
"script_capabilities": ["storage.local", "entity.visual"]
```

Example `.worldscript` event instructions:

```json
{
  "use": [
    {"op": "save_add", "key": "xp", "value": 10},
    {"op": "save_set", "key": "level", "value": 2}
  ],
  "start": [
    {"op": "if_saved", "key": "level", "equals": 2,
      "then": [{"op": "command", "capability": "entity.visual",
        "entity": "reward", "property": "visible", "value": true}]}
  ]
}
```

`save_set` stores JSON data; `save_add` increments a numeric counter (default 0);
`save_delete` removes a key. `if_saved` selects `then`/`else` using the saved value
at the **start of the event**, not pending writes from that same event. Keys are
limited to 64 characters. At most 128 keys, 16 KiB serialized JSON and bounded
nesting/data are accepted. Disk writes are limited to one per second; batch changes
in one event and do not save every tick. A rejected save applies no visual commands
from that event. Handle gameplay accordingly; storage is not shared authority.

Files live under `user://world_saves/<hashed-account>/<hashed-url>.json`. Writes
replace a temporary file; corrupt/oversized saves are preserved and become read-only,
not silently reset. Temporary second-window identities use memory-only progress.
Two clients sharing the same account/save file are last-writer-wins; there is no
cross-process merge. Users can inspect/delete/edit these files. Never use local
progress for secure rankings, purchases, secrets or anti-cheat decisions.

There is no automatic cloud sync, file-picker access, user-profile access or
cross-world save access. World-script disable settings also disable save commands.
