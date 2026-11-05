# Welcome island asset sample and provenance

## Realistic surface palette — 2026-11-05

Four additional Poly Haven CC0 PBR sets are bundled and applied to the graybox:
[Sparse Grass](https://polyhaven.com/a/sparse_grass) and
[Rock Path](https://polyhaven.com/a/rock_path) by Amal Kumar,
[Rock 01](https://polyhaven.com/a/rock_01) by Rob Tuytel, and
[Weathered Planks](https://polyhaven.com/a/weathered_planks) by Dario Barresi
(processing) / Dimitrios Savva (photography). Each uses unchanged 1K JPEG diffuse,
OpenGL normal and roughness maps. Exact sources/hashes/notices are in the manifest
and generated inventory; Credits discovers the additions automatically.

World-space triplanar mapping uses approximately 2–4 metre tiles to avoid stretched
untextured graybox surfaces; roughness reads the red channel. Texture variation,
terrain blending and final timber alignment remain the later landscape pass.
These materials are not imported island/house presets or a displacement/collision
change. Test-first missing-palette assertions failed before acquisition; afterward
90 asset assertions and 34 rendered layout checks passed. Spawn-view screenshot
inspected on Compatibility/Intel UHD 630; no Forward Plus/XR quality claim.

## Optimized runtime variants — 2026-11-05

Use `models/runtime/*.scn` when assembling the future island, not the source glTF
collection. Source downloads remain unchanged for reproducibility. Rebuild locally:

```sh
python3 tools/assets/optimize_island.py
python3 tools/assets/provenance.py --write-doc
python3 tests/welcome_island/run_assets.py --rendered
```

The rebuild uses a disposable project, Godot 4.7's meshoptimizer LOD generator
(60-degree normal merge), selects at most 7,000 triangles per surface, compacts
every vertex channel, splits individual saplings and generates further distance
LODs. It updates derived file records/modification notices in the manifest;
review changes and regenerate the readable inventory afterward. `.scn` hashes can
vary between Godot versions; rebuilds are authoring operations, not runtime work.
Materials reference shared original 1K textures, not duplicated baked textures.

| Model | Source triangles | Reduced base triangles |
| --- | --- | --- |
| Three saplings combined | 398,144 | 16,121 (3,879 / 5,974 / 6,268) |
| Boulder | 66,122 | 4,132 |

Four compressed scenes total about 578 KiB. Normals, materials, compaction and
additional LODs pass executable checks (70 asset checks total). Rendered sample
inspected on Compatibility/Intel UHD 630. Whole-island draw calls, collision proxies,
real-headset foliage quality and final Forward Plus budgets remain open. Older
source-quality warnings below apply to source glTF, not these variants.

This is a **parts library for inspection**, not the island or a preset map. Nothing
here replaces `scenes/world.tscn` yet. Four individual Poly Haven asset entries
are bundled locally; all use CC0 1.0. Existing avatar/animation provenance remains
in the separate sections of `THIRD_PARTY_ASSETS.md`.

## Inventory ownership

`manifest.json` records author, source, retrieval date, full local license path/hash,
notices/modifications and each shipped file's path/download URL, original filename,
original SHA-256 and shipped SHA-256. These samples are unmodified: both hashes
must agree. Publisher-download MD5 values were also checked during acquisition;
SHA-256 is the local integrity authority. A hash is not proof of permission.

The readable marked section of [`THIRD_PARTY_ASSETS.md`](../../THIRD_PARTY_ASSETS.md)
is generated from this manifest and checked for drift:

```sh
python3 tests/welcome_island/test_provenance.py
python3 tools/assets/provenance.py
python3 tools/assets/provenance.py --write-doc
python3 tests/welcome_island/run_assets.py
python3 tests/welcome_island/run_assets.py --rendered
```

The validator runs offline. `--write-doc` only replaces the marked section after
validation; it never changes existing avatar/animation sections. It rejects
unlisted payloads under `models/`, `textures/`, `sky/`, duplicate IDs/paths, missing
or changed files/licenses, unsafe paths/symlink escapes and unsupported licenses.
Generated Godot `.import`/`.uid` sidecars are not asset payloads. Do not put caches,
original authoring archives or personal files in these payload directories.

CC0 is preferred. The only allowed attribution-bearing exception is CC BY 4.0,
with attribution, full terms and modification notices; legal/source review is
still required. NC/ND/editorial/unknown terms are rejected. Never invent approval
by changing a license string. Credits UI is part 03; the manifest is ready for it
but does not claim that the UI or a complete all-project Credits manifest exists.

## Reproduce acquisition/import

No network is needed at runtime or for tests. To recover a missing original file,
use its exact HTTPS `download` URL and `original_name` in the manifest, download
to a separate directory under `/tmp/opencode`, and compare SHA-256 with
`original_sha256` **before** copying to the recorded shipped path. Do not overwrite
a changed file blindly. Preserve the glTF directory layout, including `.bin` and
`textures/`; glTF references are relative. Downloads were obtained with curl using
an identifying user agent; provider APIs were used only to inspect these specific
assets, not bulk scrape the catalog.

No Blender/conversion is required for this sample. Import using the disposable
runner, never the main project against real account data. If a later part creates
decimated/retargeted/resized variants, first add tests, retain the original download
hash, record exact tools/options and a truthful modification notice, and update
the shipped hash. Converted source archives can stay outside the runtime tree.

The terms were verified at <https://polyhaven.com/license> on 2026-11-05: the
publisher licenses downloadable models/textures/HDRIs under CC0, explicitly permits
commercial use and redistribution, and does not require attribution. Full CC0
terms are in `licenses/CC0-1.0.txt` (same legal text already bundled for animations).
Credits voluntarily names every author. No website logos, screenshots or preview
renders are bundled under the assumption that they share the asset license.

## Import inspection and limits — 2026-11-05

- Pine Sapling Small: Rob Tuytel (photography), Rico Cilliers (modeling). Three
  individual sapling variants in one glTF parts file, **398,144 triangles total**;
  approximately 1.30 m tall, combined bounds 2.64 × 1.30 × 0.77 m. Alpha-cutout,
  double-sided twig material and vertex normals confirmed. This is source-quality
  geometry, **not approved for dense runtime instancing**; extract variants and
  optimize/LOD before final landscape work. Pine Tree 01 was rejected for this
  sample because its glTF buffer alone is about 949 MB.
- Boulder 01: Rico Cilliers. Imported glTF has **66,122 triangles**, bounds about
  1.27 × 1.00 × 1.83 m. PBR/vertex normals confirmed. Collision/LOD optimization
  is a later gate; do not use this detailed mesh directly as collision geometry.
- Forest Floor: eye-candy.xyz. Unmodified 1K diffuse, OpenGL normal and roughness
  maps; correct Godot normal convention, plausible leaf/dirt scale to tune when
  mapping onto our own terrain. No publisher material-preview mesh is included.
- Kloofendal pure sky: Greg Zaal (original), Jarod Guest (sky edits), 1K HDR. Future
  lighting work must align the sun and review the lower-hemisphere stretch rather
  than treating this sample as a final floating-island sky solution.

Godot 4.7.2 isolated import: 40 checks passed. Rendered X11/Compatibility inspection
on Mesa Intel UHD 630: 41 checks passed; screenshot inspected at
`/tmp/opencode/welcome-assets.png`, outside version control. Trees, cutouts, boulder,
ground maps and sky render together. This inspection is not final art direction,
Forward Plus/Jolt validation, VR comfort or performance certification. No full
scene or environment preset was downloaded. The sample payload is about 31 MiB.

## Later assets: candidates, not bundled inventory

Hull/dock, house/furniture and appliances/kitchenware are selected/acquired when
their respective parts need them. These sources are research leads only:

- [Kenney Watercraft Kit](https://kenney.nl/assets/watercraft-kit): free CC0 boat
  parts; [publisher distribution](https://kenney-assets.itch.io/watercraft-kit).
- [Kenney Furniture Kit](https://kenney.nl/assets/furniture-kit): individual beds,
  seating and kitchen fixtures; [publisher CC0 policy](https://kenney.nl/support).
- [Kenney Food Kit](https://kenney.nl/assets/food-kit): individual kitchen/food
  props, publisher page declares CC0.

These low-poly packs may not fit the desired believable PBR aesthetic unchanged.
Review individual models, included terms and material adaptation before selecting
them; no paid all-in-one bundle or complete house scene is authorized. Exact hull,
dock, structure and eight kitchen-object inventory remain open in parts 07–11.
Every selected addition must pass the manifest/license/import gate again.
