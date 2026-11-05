# Running clients and relays

## Two local game windows

Two ordinary launches share `user://user.key`. The relay intentionally rejects a
second live connection for the **same account**, preventing ambiguous account
membership, moderation and profile ownership. This is not a failed UDP connection.
The rejection now explicitly explains the shared account rather than reporting a
generic signature/connection failure. The first window stays connected.

For simultaneous local testing with separate temporary identities:

```sh
python3 tools/clients/launch.py --count 2 --relay 127.0.0.1 --port 7374
```

Start a relay separately first. Each client gets independent account/settings/cache
roots under `/tmp/opencode`; microphone starts muted. Closing the launcher removes
those temporary identities. It never overwrites or copies your real account key.
Use `--vr` to allow runtime XR initialization instead of forced desktop mode.
This launcher is for Linux/XDG development; it does not claim Windows/macOS user-data
isolation. Two different people/devices should use their own normal account stores.

Startup loads local play/menu without waiting for relay selection. Settings → Network
shows current connection state and Retry/Cancel. Edit the saved ordered relay rows
for future connections; obsolete scalar migration fields are hidden. TLS certificate
import has a separate port. Catalog outages do not open blocking error dialogs.

Use Godot **4.7** with the project's declared Forward Plus/Jolt configuration.
Import the project in the editor before running it. This is early development:
the repository's headless Compatibility tests do not certify the full GPU/XR stack.

```sh
godot --path . --non_vr
godot --path . --relay
```

Startup checks engine command-line arguments for those flags. `--non_vr` forces
desktop; without it startup attempts headset initialization and desktop fallback.
`--relay` or the dedicated-server feature selects server startup. The Linux export
preset is a **dedicated server**, and its configured output path points outside the
repository: do not export over unrelated files. Inspect/edit export paths explicitly.

Client default relay endpoint is `127.0.0.1:7374`; the production relay binds
`0.0.0.0:7374`. Running a local client therefore needs an appropriate local relay
for online features. Do not expose an experimental relay publicly without deployment
review, transport/firewall controls and the [privacy contract](../relay-data-lifecycle.md).

If World Explorer reports a disconnected relay, set **Settings → Network → Relay
address / Relay UDP port** to the actual relay, then press **Reload** in World
Explorer to retry without restarting. The default localhost address only works
when a relay is running on this same computer (`godot --path . --relay`, in a
separate process). Another computer needs the relay machine's reachable address
and UDP port access. Failed attempts now report the endpoint and retry guidance;
Reload shares an in-progress attempt rather than opening duplicate connections.
Reconnecting does not silently rejoin a previous instance; choose/create one again.

**Ordered-list update:** the old scalar endpoint is now migration-only. Use the
[ordered relay list](../guides/relay-preferences.md) in Network settings after
migration. Its top allowed entry is default and unavailable entries fall back in
order. [Federation setup](../guides/relay-federation-setup.md) documents the new
certificate-trusted TLS peering, LAN hints and routed gameplay, including limitations.

Normal client startup can generate an account key and migrate/write settings,
profiles, contacts and avatar selections. Back up user data before experimenting.
For automated verification use [isolated runners](../development/testing.md), not
normal startup against the real profile directory.

Player controls/settings are defined by [InputMap](../../project.godot) and the
[settings registry](../../scripts/settings/settings_registry.gd). The desktop view
has player-owned mouse look; VR camera pose is headset-owned. Avatars/rendering
are visual representations and must not drive the tracked camera.

On desktop, hold **Ctrl** while moving to sprint at **1.5×** walking speed
(default 4 → 6 m/s on both PC and VR); release to walk. Rebind **Sprint (hold)** in Settings →
Controls. Menus, focus loss, rebinding and session transitions suppress sprint;
release and press again after returning to play. In VR, hold **left joystick
click** while moving; see [VR controls](../guides/vr-controls.md).

Both players use **Settings → VR Movement → Base movement speed (PC and VR)**.
Walking is twice this base value and sprint is three times it, doubling both
speeds for existing settings as well as new installations.
The existing `vr.move_speed` saved key is retained, including any
custom value; desktop no longer has an independent fixed speed. Full-stick VR
matches desktop's maximum walk/sprint speed, while partial stick input stays
proportionally slower. Acceleration behavior remains platform-specific.

While airborne, both players retain horizontal momentum when movement input is
released. Steering toward a new direction uses 10% of ground acceleration, so
midair reversals are slower. Both players use a jump impulse of 9 m/s (previously
7 m/s); gravity is unchanged, so jump height still differs with platform gravity.
Ground movement speeds are unchanged;
menus/focus/session suppression still brake movement. Jump animation blends back
to standing over 0.55 seconds instead of the normal 0.22-second transition.
