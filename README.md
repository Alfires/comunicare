# comunicare
Comunicare is a VR and desktop chatting game designed to let you explore worlds and connect with others.
Programmed in Godot.
Its in a very early release.

Join the office comunicare server on [Matrix](https://matrix.to/#/#comunicare:matrix.org) or Discord(coming soon) 

Development: 

- [x] Add a VR player that works
  - [ ] make movement work
  - [ ] animations
  - [ ] vr menue
  - [ ] vr movement IK and FBT and movement sync
- [x] add a desktop player
  - [x] movement
  - [ ] animations
- [x] add game menus
  - [ ] make the menus look good
  - [ ] make vr menu work
- [ ] in game avatar searcher 
- [ ] multiplayer
- [ ] multi relay support (user can use more than on relays at the same time and talk to players on a different relay) 
  - [x] movent/rotation sync
  - [ ] model sync
  - [ ] public key and message setup
  - [ ] friend system
  - [ ] public session/world list
  - [x] voice chat
- [x] make world load from URL
  - [ ] make world system good
  - [ ] add a proper world discovery
  - [ ] proper script execution
  - [ ] nodes/scenes good support
  - [ ] switch to .pck much better
  - [ ] godot editor plugin for the export and more
- [ ] mod system with .pck
  - [ ] mod menu and folder
    
# Development 
How to develop your own world
(A plugin to make this process easier is planed)

If not done jet download [Godot](https://godotengine.org).
Now after the install look at the [link](https://docs.godotengine.org/en/stable/getting_started/first_3d_game/01.game_setup.html) to the Godot docs the linked doc shows the setup for a basic 3d scene.

Now that you have created a symbol project test it:
1. Open the Project folder in your explorer.
2. Create a new file that is named **manifest.json**
3. In the file put following:
```json
   {
  "name": "A name you choose",
  "version": 1,
  "main_scene": "world.tscn",
  "spawn_point": [0, 1, 0]
    }
```
4. Now create a zip file with the world scene and the **manifest.json**.
5. To make the zip file valid cage the your_zip.zip to your_zip.cne
6. upload the file to your choose file Hosting Service (Github or a drive)
7. final test open up comunicare and go in to the World Explorer than paste the URL of file there finally hit join. 
