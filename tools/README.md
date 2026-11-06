# Local development tools

Run tools from the repository root. These are development/maintenance utilities,
not downloaded-world capabilities. Do not move their generated output into source
folders unless the individual tool explicitly produces a reviewed source asset.

| Location | Purpose |
| --- | --- |
| `assets/` | Asset provenance, built-in world revision, model optimization and Quaternius animation conversion |
| `clients/` | Isolated local client launches and launcher tests |
| `docs/` | Documentation links, contracts, symbol inventory and privacy checks |
| `gui/` | GUI authoring/checking tools |
| `relays/` | Local relay development tooling |
| `versioning/` | Local version/release tooling and opt-in hooks |
| `worlds/` | Safe world model authoring conversions |
| `check_repository.py` | Repository verification entry point |
| `repair_asset_cache.py` | Explicit user cache recovery; read its usage before changing cache data |
| `test_repair_asset_cache.py` | Cache recovery tests |

The animation converter is now
`python3 tools/assets/convert_quaternius.py /path/to/archive.zip`.
Its source/license records remain in [THIRD_PARTY_ASSETS](../THIRD_PARTY_ASSETS.md).

Repository layout: runtime code belongs in `scripts/` and `relay_protocol/`, scene
resources in `scenes/`, UI theme resources in `themes/`, imported/source art and
licenses in `assets/`, trusted editor plugins in `addons/`, isolated tests in
`tests/`, author examples in `examples/`, and plans under `docs/roadmaps/`.

Python `__pycache__`/`.pyc` files and Godot's `.godot/` are generated and ignored.
Godot `.uid` and `.import` sidecars are not interchangeable with that cache: do
not delete them indiscriminately. Preserve test fixtures, asset licenses and
historical roadmaps even when they are not loaded by normal gameplay.
