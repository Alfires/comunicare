# Configuration, scene wiring and compatibility

## Engine and launch

[`project.godot`](../../project.godot) declares Godot 4.7, Forward Plus, Jolt,
OpenXR and UID scene/autoload resources. The UID main scene resolves to
`scenes/startup.tscn`; autoload order DataLoader → SaveData → NetworkHandler is
significant. Do not replace engine `config/features` when setting application
`config/version`. [`export_presets.cfg`](../../export_presets.cfg) Linux preset is
dedicated-server and writes outside the repository; inspect path before exporting.

Engine args `--non_vr`/`--relay` are checked with OS.get_cmdline_args, not gameplay
InputMap. Dedicated-server feature also selects relay. The startup implementation
does not turn an arbitrary Linux server export into a desktop client.

## Registry-driven preferences

Canonical definitions live in
[`settings_registry.gd`](../../scripts/settings/settings_registry.gd). Query
get_definitions/get_definition rather than hardcoding independent UI defaults.
Categories currently include Assets, Audio, Controls and Interface. The typed
store owns persistence; profile fields are deliberately excluded.

| Family | Purpose / application |
| --- | --- |
| `cache.*` | Storage budget, automatic revalidation, development HTTP and explicit executable-world trust |
| `audio.*` | Shared microphone mute, master/other-player volume, outgoing gain and threshold |
| `input.*` | Physical microphone V / emote B rebinding and XR emote action selection |
| `controls.*` | Mouse sensitivity and inverted Y; typing/modal key capture suppresses global shortcuts |
| `interface.*` | Nameplates, emote haptics, wheel diameter/dead zone |

Add ordinary settings by registering validated metadata/default/range and wiring
application behavior where needed. Registration alone does not make a preference
affect the engine. Dynamic registration updates UI/store through signals.

## Scene and UI contracts

Home is a 2×2 grid with World Explorer, Active Instance, Emotes and one unassigned
cell. Friends remains a separate social page; profile owner/visitor views share a
service API. Resource names `menue`, `share_session_menue`, `default_wold` and
legacy function spellings remain compatibility identifiers.

The local player is root-owned across scene swaps. NetworkHandler children are
remote-player instances and cleared during transitions; animation service is
DataLoader-hosted to survive that cleanup. Never insert arbitrary service nodes
into the remote-player list. The emote wheel owns temporary capture/focus;
queue-free/detach must restore input just as Cancel does.

Player camera has adjustable `first_person_forward_offset` default 0.15 m. Desktop
calibrates from rest eyes and permits ±85° pitch; VR offsets avatar shell behind
the headset instead of moving tracked camera. Cameras exclude first-person
derivative layer 19 (bit 18), local first-person excludes original-avatar layer 20
(bit 19). Coordinate special camera/light layer policies with these reservations;
they are not arbitrary user-defined free bits for world content.

## Version boundaries

App SemVer, Godot engine feature version, explicit packet IDs, animation capability
version 2, builtin library `quaternius.directional.v4`, and disk schema revisions
are different contracts. Local release tooling updates only VERSION, CHANGELOG
and application config/version; no automatic protocol renumbering or cache reset.

No baseline VERSION is checked in until the owner explicitly chooses an initial
release policy. Test release tooling only in disposable histories; normal small
commits/pushes do not publish stable tags.
