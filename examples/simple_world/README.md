# Simple Pickup Courtyard

A normal Godot project for exercising Comunicare's initial safe world format.
Open **this directory's `project.godot`** in Godot 4.7 to edit the world. The parent
`examples/.gdignore` prevents the main game from importing nested author projects;
it does not need to be copied into this project or package.

Contents: a textured 10 m floor with collision, directional light, spawn marker,
orange checkerboard pickup cube and blue beacon. All artwork is original example
content under this repository's applicable terms; no external assets are required.

## Package manually

From this directory:

```sh
zip -r /tmp/opencode/simple-world.cworld manifest.json scenes materials textures logic \
  -x '*.uid' '*.import'
```

Do not package `project.godot`, `.godot`, `.git`, README or editor plugins. Upload
the archive to your ordinary world hosting, then enter its HTTP(S) URL in World
Explorer and create an instance. Local development HTTP needs the existing Assets
HTTP opt-in. No hosting/upload is performed by the tests.

The current application has no local-file preview UI. Automated local loading:

```sh
python3 tests/world_system/run.py
```

That runner packages **these actual source files**, reconstructs the scene through
the production builder, checks floor physics, texture decoding, spawn, restricted
beacon events and local/remote pickup scene movement. It also imports the original
project separately to check native Godot compatibility. Temporary projects and
user data are isolated. Generated archives/logs live under `/tmp/opencode`.
The runner additionally starts two authenticated clients and a real ENet relay,
loads separate scene/physics copies and checks both directions of networked
carrying, exclusive ownership, release and disconnect cleanup (16 checks).
It needs no external relay or help from another player; automated hand poses
replace real controllers without claiming hardware/visual verification.

Native Godot Run does not provide Comunicare's player or script runtime; inspect
the scene in Godot's 3D editor. The beacon starts hidden in the source and becomes
visible when the client runs its restricted `start` event. Its `use` event is tested
by trusted dispatch; there is not yet a player-facing Use control. In Comunicare,
desktop **E** toggles nearby pickup/drop; VR grip holds/releases. Real headset
visual quality, collision-safe carrying and free-body synchronization remain
outside this example's automated acceptance.
