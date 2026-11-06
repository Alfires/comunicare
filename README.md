# Comunicare

Comunicare is an early-development **VR and desktop social game** built with
**Godot 4.7**. Explore worlds, talk with other players, and use custom humanoid
avatars with animations and emotes.

**[Documentation](docs/README.md)** · **[Contributing](CONTRIBUTING.md)** ·
**[Roadmaps](docs/roadmaps/README.md)** ·
**[Matrix community](https://matrix.to/#/#comunicare:matrix.org)**

## What is implemented

- Desktop and VR player paths, configurable controls, menus and tracking support.
- Relay-based multiplayer with voice, player movement, instance discovery and
  client-owned profiles, contacts and access preferences.
- An offline home world, world browsing, and validated downloadable world packages.
- An in-game avatar/animation browser, local model imports, bundled animations,
  emote organization and a local mirror.
- First-person avatar geometry that preserves your body, arms and legs while
  hiding your head; original geometry remains available to other cameras.

These are implemented systems, not a claim of release readiness. Headset comfort,
microphone/device behavior, rendering and production networking still require
manual verification. See the [VR validation status](docs/development/vr-validation.md)
and [roadmaps](docs/roadmaps/README.md) for limitations and remaining work.

## Run from source

Install **Godot 4.7**, open `project.godot` in the editor, and let the project
import. The project uses **Forward Plus** rendering and **Jolt Physics**.

Run these commands from the repository root:

```sh
# Desktop client
godot --path . --non_vr

# VR startup, with desktop fallback if XR initialization is unavailable
godot --path .

# Relay server (run in a separate process for local online testing)
godot --path . --relay
```

The default client relay is `127.0.0.1:7374`. Configure connections under
**Settings → Network** using the ordered relay list. Local play and menus do not
require a connected relay; online features do.

**Important:** the Linux export preset is a **dedicated server**, not a desktop
client. Normal client startup can create an account key and write settings,
profiles and other user data. Back up your data before experimenting, and use
isolated test runners for automated checks.

See [running clients and relays](docs/getting-started/runtime.md) for details,
including isolated multi-client testing and deployment cautions.

## Avatars and performance

Supported avatar imports are self-contained humanoid **VRM/GLB** models. Under
**Settings → Assets**, configure the large-avatar warning and hard file-size limit:

- **Default warning:** above **256 MiB**, loading requires confirmation.
- **Default hard limit:** **1 GiB**, also the maximum supported setting.
- Standalone animations remain limited to **16 MiB**.

Size approval does not bypass format or rig validation. Large models can consume
much more RAM/VRAM than their file size.

Avatar decoding and world preparation use worker jobs. First-person preparation
reuses resolved skin-bind information, and inactive tracking skips unnecessary
bone updates. These reduce specific CPU workloads; they do not guarantee frame
rates for arbitrary models, devices or worlds.

Read the [avatar browser guide](docs/guides/avatar-browser.md),
[avatar and animation usage guide](docs/asset-cache-and-animation-usage.md), and
[VR controls guide](docs/guides/vr-controls.md).

## Create worlds

Use the [safe world-authoring guide](docs/guides/safe-world-authoring.md) for the
supported authoring, validation and export workflow. Runtime world packages are
validated data; arbitrary Godot scenes, scripts and native resources are not
accepted simply by renaming a ZIP archive. The old README's scene-ZIP instructions
are obsolete.

See [world-loading behavior and limits](docs/guides/world-loading.md) for details
about preparation and progressive visual reveal.

## Development and verification

Contributors need **Godot 4.7** and **Python 3**. Start with
[CONTRIBUTING.md](CONTRIBUTING.md) and the [verification guide](docs/development/testing.md).
Examples of focused checks:

```sh
python3 tests/avatar_loading/run.py
python3 tests/avatar_tracking/run.py
python3 tests/animation_sync/run.py
python3 tools/check_repository.py
```

Game test runners use disposable projects rather than real account data. Headless
tests use Compatibility rendering and do not validate the full Forward Plus/XR,
audio-device or multi-client visual experience. Optional real-avatar fixtures and
manual checks are documented in the verification guide.

Third-party asset attribution and redistribution terms are recorded in
[THIRD_PARTY_ASSETS.md](THIRD_PARTY_ASSETS.md). Relay privacy and transient-state
rules are documented in the [relay data lifecycle contract](docs/relay-data-lifecycle.md).
