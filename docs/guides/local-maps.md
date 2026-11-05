# Open a local map

Open **World Explorer → Open local map…**, then choose a `.cworld`, `.zip` or
`.cne` file containing a supported world package. The extension alone does not
grant compatibility: the manifest, geometry, resources and restricted scripts
must pass the same validation as downloaded worlds. Arbitrary `.tscn`, `.pck`,
legacy executable maps and Godot projects are not loaded.

Validation happens before leaving the current multiplayer instance. An invalid
package leaves membership and the current world intact. A valid package switches
to offline play, disconnects the gameplay transport and enables local pickups.
The local path is never published to the relay or shared with other clients.
Loading a file does not host it; use a publicly reachable world URL to host a
multiplayer instance other players can download.

Local progress is scoped to the package content hash and account. Editing the
archive changes that local progress namespace. This differs from URL worlds,
whose saves follow the exact URL. No native or downloaded code is enabled.
