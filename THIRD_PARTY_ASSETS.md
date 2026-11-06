# Bundled third-party asset provenance

## Offline robot avatar placeholder — RobotExpressive

- Creator: Tomás Laulhé / Quaternius; CC0 1.0 Universal.
- Publisher: https://quaternius.com/packs/animatedrobot.html
- Redistribution/conversion: Don McCurdy; facial morph targets, FBX2GLTF
  conversion, duplicate-material removal and reduced metalness.
- Source: https://github.com/mrdoob/three.js/tree/dev/examples/models/gltf/RobotExpressive
- Retrieved 2026-11-05; original attribution preserved in
  `assets/avatars/placeholder/SOURCE.md`.
- Bundled `RobotExpressive.glb` SHA-256:
  `047f5e5fb3bb6d378bd1df16ca6137f2a596c99b3a1b5690b4020c05aaf6f319`.
- Full CC0 terms: `assets/animations/CC0-1.0.txt`.

`scripts/assets/avatar_placeholder.gd` normalizes the model to 1.75 m and applies
instance-owned status materials/indicators. Tangent generation is disabled because
the untextured source has no UVs. The binary is unmodified and bundled locally;
no runtime download is required. This replaces the original primitive box model.
It is not VRChat's robot asset and no VRChat assets are included.

## Quaternius Universal Animation Library — Standard-1.0

- **Creator:** Quaternius.
- **License:** CC0 1.0 Universal; free for personal, educational and commercial
  use, modification and redistribution. No paid Pro/Source assets are included.
- **Publisher:** https://quaternius.com/packs/universalanimationlibrary.html
- **Free Standard distribution:** https://store.godotengine.org/asset/quaternius/universal-animation-library/
- **Exact download:** https://store.godotengine.org/asset/quaternius/universal-animation-library/download/44/
- **Retrieved:** 2026-11-03.
- The archive's own `License.txt` is preserved as
  `assets/animations/Quaternius-License.txt`; full CC0 terms are in
  `assets/animations/CC0-1.0.txt`.

`assets/animations/manifest.json` records the archive, original GLB and converted
data SHA-256 hashes and the exact source clip assigned to each role. The bundled
data is extracted from `AnimationLibrary_Godot_Standard.glb`: Idle_Loop,
Walk_Loop, Jog_Fwd_Loop, Jump_Start, Jump_Loop, Jump_Land, Dance_Loop and Interact.

`tools/assets/convert_quaternius.py` reproduces the conversion from that free archive.
It preserves authored rotation samples and source T-pose bases, removes
translation/scale channels for in-place playback, maps the source rig to humanoid
bone names and includes finger motion. It does **not** synthesize new motion.
Target rigs may omit optional fingers/chest/shoulder bones. Legacy VRM 0.x forward
orientation is corrected during binding. Camera/collision root motion is disabled.

The previous original procedural recipes are no longer used or bundled as
defaults. Wave/Cheer placeholders are replaced by the pack's actual Dance and
Interact clips. Existing user shortcuts to removed placeholders show Unavailable
and can be reassigned in the wheel editor; user layouts are not overwritten.

Directional library revision `quaternius.directional.v2` removes Idle_Loop and
Jump_Land from bundled playback data and adds left/right reference-space
adaptations of Walk_Loop (+/-90 degrees). These use unchanged authored motion
samples, not new hand-keyed animation, but are **not dedicated authored strafe
clips**. A static first walk frame supplies the no-idle standing pose. The manifest
and converter record these adaptations explicitly.

Jump_Loop (falling) is also no longer bundled or played. Descending selects the
same static authored neutral pose used when standing still.

`quaternius.directional.v3` corrects neutral standing: it retains exactly the
first frame of **Idle_Loop**, rather than freezing a Walk_Loop frame. Idle motion
is not included or played. The manifest/converter record the standing source.

`quaternius.directional.v4` refines that static stance: hips/legs/feet use the
pack's A_TPose reference rotations while the upper body keeps the relaxed
Idle_Loop frame. No temporal idle motion or new hand-keyed motion is introduced.

User-imported assets retain their own licenses. A cache hash or successful import
does not grant permission to redistribute them.

## Interface font — Atkinson Hyperlegible Next

- **Creator:** Braille Institute, Applied Design Works, Elliott Scott, Megan
  Eiswerth, Letters From Sweden.
- **License:** SIL Open Font License 1.1; full text in `themes/fonts/OFL.txt`.
- **Source:** https://github.com/googlefonts/atkinson-hyperlegible-next
  (Google Fonts `ofl/atkinsonhyperlegiblenext`, upstream commit
  `7925f50f649b3813257faf2f4c0b381011f434f1`).
- **Retrieved:** 2026-11-05.
- Bundled `themes/fonts/AtkinsonHyperlegibleNext-Variable.ttf` is the unmodified
  upstream `AtkinsonHyperlegibleNext[wght].ttf` (weight axis 200–800, default
  400), renamed only to avoid brackets in resource paths. SHA-256:
  `5a455d1cfa099b601ab70751bb9673e8fe1854dc4500c80e1a220d0d75e31745`.
- `OFL.txt` SHA-256:
  `aca6a428580965d2297d1b718042dd427c2a9443ece3b0d02d758e161e0c4030`.

`scripts/GUI/theme/theme_builder.gd` uses the default instance (Regular, 400)
for body text and a weight-600 `FontVariation` for titles and primary buttons.
The font is not sold on its own and keeps its Reserved Font Name.

<!-- welcome-island-assets:start -->
## Welcome island asset inventory

Generated from `assets/welcome_island/manifest.json`; candidates not bundled are excluded.

### polyhaven.pine_sapling_small — Pine Sapling Small

- Author: Rob Tuytel; Rico Cilliers
- Source: https://polyhaven.com/a/pine_sapling_small
- License: CC0-1.0; terms: `assets/welcome_island/licenses/CC0-1.0.txt`
- Retrieved: 2026-11-05
- Attribution: Not required (CC0); voluntary acknowledgement above.
- Modifications: Publisher 1K glTF/buffer/textures preserved unchanged. Derived runtime scenes split individual variants, select Godot 4.7 meshoptimizer LOD topology up to 7000 triangles per surface, compact unused vertices and regenerate distance LODs. Rebuild: python3 tools/assets/optimize_island.py.
- Shipped: `assets/welcome_island/models/pine_sapling_small/pine_sapling_small_1k.gltf`; SHA-256 `f358c01926861dd082f32dba60f7c9fba232b585a985cf38c0d2229eecf4bc48`
  Original: `pine_sapling_small_1k.gltf`; SHA-256 `f358c01926861dd082f32dba60f7c9fba232b585a985cf38c0d2229eecf4bc48`; download: https://dl.polyhaven.org/file/ph-assets/Models/gltf/1k/pine_sapling_small/pine_sapling_small_1k.gltf
- Shipped: `assets/welcome_island/models/pine_sapling_small/textures/pine_sapling_small_twig_arm_1k.jpg`; SHA-256 `2eb0aa44124b5a4ae9401e00b23b3c916f4c3f421616ce1bb932f248fc061288`
  Original: `textures/pine_sapling_small_twig_arm_1k.jpg`; SHA-256 `2eb0aa44124b5a4ae9401e00b23b3c916f4c3f421616ce1bb932f248fc061288`; download: https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/pine_sapling_small/pine_sapling_small_twig_arm_1k.jpg
- Shipped: `assets/welcome_island/models/pine_sapling_small/textures/pine_sapling_small_twig_diff_1k.jpg`; SHA-256 `54af7d6fb664b5a38bcb118b557bc50e01e86ec54d6f1a573c3e32c649a53362`
  Original: `textures/pine_sapling_small_twig_diff_1k.jpg`; SHA-256 `54af7d6fb664b5a38bcb118b557bc50e01e86ec54d6f1a573c3e32c649a53362`; download: https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/pine_sapling_small/pine_sapling_small_twig_diff_1k.jpg
- Shipped: `assets/welcome_island/models/pine_sapling_small/textures/pine_sapling_small_bark_nor_gl_1k.jpg`; SHA-256 `05c46455531781b6cf18cae0648cf627f60ee942adaa8bcbfd1592fc2506a9e0`
  Original: `textures/pine_sapling_small_bark_nor_gl_1k.jpg`; SHA-256 `05c46455531781b6cf18cae0648cf627f60ee942adaa8bcbfd1592fc2506a9e0`; download: https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/pine_sapling_small/pine_sapling_small_bark_nor_gl_1k.jpg
- Shipped: `assets/welcome_island/models/pine_sapling_small/pine_sapling_small.bin`; SHA-256 `b4d2fc73d53f1d8717eb5ef9a2c66957d2a53152787e543aace88fcd6fca94ef`
  Original: `pine_sapling_small.bin`; SHA-256 `b4d2fc73d53f1d8717eb5ef9a2c66957d2a53152787e543aace88fcd6fca94ef`; download: https://dl.polyhaven.org/file/ph-assets/Models/gltf/8k/pine_sapling_small/pine_sapling_small.bin
- Shipped: `assets/welcome_island/models/pine_sapling_small/textures/pine_sapling_small_bark_diff_1k.jpg`; SHA-256 `5c76836b01c3536fa0e24207b67bf4f3315b53ebe2b4ecc6f08dfcf3f8d74929`
  Original: `textures/pine_sapling_small_bark_diff_1k.jpg`; SHA-256 `5c76836b01c3536fa0e24207b67bf4f3315b53ebe2b4ecc6f08dfcf3f8d74929`; download: https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/pine_sapling_small/pine_sapling_small_bark_diff_1k.jpg
- Shipped: `assets/welcome_island/models/pine_sapling_small/textures/pine_sapling_small_bark_arm_1k.jpg`; SHA-256 `336a4680cd571b6076b67afee2310b290b8900d9d126eb39ec1ae92e95be2ea9`
  Original: `textures/pine_sapling_small_bark_arm_1k.jpg`; SHA-256 `336a4680cd571b6076b67afee2310b290b8900d9d126eb39ec1ae92e95be2ea9`; download: https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/pine_sapling_small/pine_sapling_small_bark_arm_1k.jpg
- Shipped: `assets/welcome_island/models/pine_sapling_small/textures/pine_sapling_small_twig_nor_gl_1k.jpg`; SHA-256 `76af87821d7ff00e25768d5d97a449394fe64a21ae55d099da7f5ed46d9098c8`
  Original: `textures/pine_sapling_small_twig_nor_gl_1k.jpg`; SHA-256 `76af87821d7ff00e25768d5d97a449394fe64a21ae55d099da7f5ed46d9098c8`; download: https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/pine_sapling_small/pine_sapling_small_twig_nor_gl_1k.jpg
- Shipped: `assets/welcome_island/models/runtime/pine_sapling_small_a.scn`; SHA-256 `f1cbd09d0252462e9b624fcc9612c4d4e94ab320b0171b97e8217d70d70c2bb0`
  Original: `pine_sapling_small_1k.gltf`; SHA-256 `f358c01926861dd082f32dba60f7c9fba232b585a985cf38c0d2229eecf4bc48`; download: https://dl.polyhaven.org/file/ph-assets/Models/gltf/1k/pine_sapling_small/pine_sapling_small_1k.gltf
- Shipped: `assets/welcome_island/models/runtime/pine_sapling_small_b.scn`; SHA-256 `dd2bea2c31e511b5fe4cf65229f900900f3625a577ddb18d3cbd3fc166eb6940`
  Original: `pine_sapling_small_1k.gltf`; SHA-256 `f358c01926861dd082f32dba60f7c9fba232b585a985cf38c0d2229eecf4bc48`; download: https://dl.polyhaven.org/file/ph-assets/Models/gltf/1k/pine_sapling_small/pine_sapling_small_1k.gltf
- Shipped: `assets/welcome_island/models/runtime/pine_sapling_small_c.scn`; SHA-256 `0c59dcf5b6fc36ac5b8bda7966ec9d3e220545fc9ec192bbbcce45be340dd60b`
  Original: `pine_sapling_small_1k.gltf`; SHA-256 `f358c01926861dd082f32dba60f7c9fba232b585a985cf38c0d2229eecf4bc48`; download: https://dl.polyhaven.org/file/ph-assets/Models/gltf/1k/pine_sapling_small/pine_sapling_small_1k.gltf

### polyhaven.boulder_01 — Boulder 01

- Author: Rico Cilliers
- Source: https://polyhaven.com/a/boulder_01
- License: CC0-1.0; terms: `assets/welcome_island/licenses/CC0-1.0.txt`
- Retrieved: 2026-11-05
- Attribution: Not required (CC0); voluntary acknowledgement above.
- Modifications: Publisher 1K glTF/buffer/textures preserved unchanged. Derived runtime scenes split individual variants, select Godot 4.7 meshoptimizer LOD topology up to 7000 triangles per surface, compact unused vertices and regenerate distance LODs. Rebuild: python3 tools/assets/optimize_island.py.
- Shipped: `assets/welcome_island/models/boulder_01/boulder_01_1k.gltf`; SHA-256 `51487934db898b4c24072780a451e34eca5c02e3ada24a62bbc600bbc4019e92`
  Original: `boulder_01_1k.gltf`; SHA-256 `51487934db898b4c24072780a451e34eca5c02e3ada24a62bbc600bbc4019e92`; download: https://dl.polyhaven.org/file/ph-assets/Models/gltf/1k/boulder_01/boulder_01_1k.gltf
- Shipped: `assets/welcome_island/models/boulder_01/textures/boulder_01_arm_1k.jpg`; SHA-256 `c57187c5746b6be913fa53846cb44ff78743e7ca5000f131c9627b99563c2b87`
  Original: `textures/boulder_01_arm_1k.jpg`; SHA-256 `c57187c5746b6be913fa53846cb44ff78743e7ca5000f131c9627b99563c2b87`; download: https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/boulder_01/boulder_01_arm_1k.jpg
- Shipped: `assets/welcome_island/models/boulder_01/textures/boulder_01_diff_1k.jpg`; SHA-256 `c38f0e918f6dc16b8d386ba3cdd89805c78320c119a1ceec85856f82b09a65b8`
  Original: `textures/boulder_01_diff_1k.jpg`; SHA-256 `c38f0e918f6dc16b8d386ba3cdd89805c78320c119a1ceec85856f82b09a65b8`; download: https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/boulder_01/boulder_01_diff_1k.jpg
- Shipped: `assets/welcome_island/models/boulder_01/boulder_01.bin`; SHA-256 `7f5b06503d62bd95bfe9c6b8a354a5cc8ff04a4d271a8cf87a3e3125db4232d7`
  Original: `boulder_01.bin`; SHA-256 `7f5b06503d62bd95bfe9c6b8a354a5cc8ff04a4d271a8cf87a3e3125db4232d7`; download: https://dl.polyhaven.org/file/ph-assets/Models/gltf/8k/boulder_01/boulder_01.bin
- Shipped: `assets/welcome_island/models/boulder_01/textures/boulder_01_nor_gl_1k.jpg`; SHA-256 `0810cf6e89d89bb6eb065b4d2e2855288f5dcbd2c15c6e40ab90d462021b50aa`
  Original: `textures/boulder_01_nor_gl_1k.jpg`; SHA-256 `0810cf6e89d89bb6eb065b4d2e2855288f5dcbd2c15c6e40ab90d462021b50aa`; download: https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/boulder_01/boulder_01_nor_gl_1k.jpg
- Shipped: `assets/welcome_island/models/runtime/boulder_01.scn`; SHA-256 `333d61fa86fa6708671da74a986a8a68f88958adb56321d5b6c4a146b535a581`
  Original: `boulder_01_1k.gltf`; SHA-256 `51487934db898b4c24072780a451e34eca5c02e3ada24a62bbc600bbc4019e92`; download: https://dl.polyhaven.org/file/ph-assets/Models/gltf/1k/boulder_01/boulder_01_1k.gltf

### polyhaven.forest_floor — Forest Floor

- Author: eye-candy.xyz
- Source: https://polyhaven.com/a/forest_floor
- License: CC0-1.0; terms: `assets/welcome_island/licenses/CC0-1.0.txt`
- Retrieved: 2026-11-05
- Attribution: Not required (CC0); voluntary acknowledgement above.
- Modifications: Unmodified publisher 1K download; individual files retained, no scene preset or conversion.
- Shipped: `assets/welcome_island/textures/forest_floor/forest_floor_diff_1k.jpg`; SHA-256 `f12e5adea1741f9eb7a528bfc621f8267885b9530b74c3a8afdb823899bdbf0b`
  Original: `forest_floor_diff_1k.jpg`; SHA-256 `f12e5adea1741f9eb7a528bfc621f8267885b9530b74c3a8afdb823899bdbf0b`; download: https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/forest_floor/forest_floor_diff_1k.jpg
- Shipped: `assets/welcome_island/textures/forest_floor/forest_floor_nor_gl_1k.jpg`; SHA-256 `681f3de8c756c4d19bcda33039f953295498f38b1425ce9d56b37d6f97f6e518`
  Original: `forest_floor_nor_gl_1k.jpg`; SHA-256 `681f3de8c756c4d19bcda33039f953295498f38b1425ce9d56b37d6f97f6e518`; download: https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/forest_floor/forest_floor_nor_gl_1k.jpg
- Shipped: `assets/welcome_island/textures/forest_floor/forest_floor_rough_1k.jpg`; SHA-256 `ece0b331f08c03f3edcd8ab6815b74a5ae20768beef64cd4f96a5b2fa26e116e`
  Original: `forest_floor_rough_1k.jpg`; SHA-256 `ece0b331f08c03f3edcd8ab6815b74a5ae20768beef64cd4f96a5b2fa26e116e`; download: https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/forest_floor/forest_floor_rough_1k.jpg

### polyhaven.kloofendal_48d_partly_cloudy_puresky — Kloofendal 48d Partly Cloudy (Pure Sky)

- Author: Greg Zaal; Jarod Guest
- Source: https://polyhaven.com/a/kloofendal_48d_partly_cloudy_puresky
- License: CC0-1.0; terms: `assets/welcome_island/licenses/CC0-1.0.txt`
- Retrieved: 2026-11-05
- Attribution: Not required (CC0); voluntary acknowledgement above.
- Modifications: Unmodified publisher 1K download; individual files retained, no scene preset or conversion.
- Shipped: `assets/welcome_island/sky/kloofendal_48d_partly_cloudy_puresky/kloofendal_48d_partly_cloudy_puresky_1k.hdr`; SHA-256 `fd94c84997b8a3c353b62c2125a9b44e19509956986a126e472684432a02d798`
  Original: `kloofendal_48d_partly_cloudy_puresky_1k.hdr`; SHA-256 `fd94c84997b8a3c353b62c2125a9b44e19509956986a126e472684432a02d798`; download: https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/1k/kloofendal_48d_partly_cloudy_puresky_1k.hdr

### polyhaven.sparse_grass — Sparse Grass

- Author: Amal Kumar
- Source: https://polyhaven.com/a/sparse_grass
- License: CC0-1.0; terms: `assets/welcome_island/licenses/CC0-1.0.txt`
- Retrieved: 2026-11-05
- Attribution: Not required (CC0); voluntary acknowledgement above.
- Modifications: Unmodified publisher 1K JPEG diffuse, OpenGL normal and roughness maps; no displacement geometry.
- Shipped: `assets/welcome_island/textures/sparse_grass/sparse_grass_diff_1k.jpg`; SHA-256 `ae94f2b34597b9108eefd88217f55eccaec6d6b382e858a478ee92df90e66617`
  Original: `sparse_grass_diff_1k.jpg`; SHA-256 `ae94f2b34597b9108eefd88217f55eccaec6d6b382e858a478ee92df90e66617`; download: https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/sparse_grass/sparse_grass_diff_1k.jpg
- Shipped: `assets/welcome_island/textures/sparse_grass/sparse_grass_nor_gl_1k.jpg`; SHA-256 `1c840a24807346ddaaf94a5057aee4078fcec3a4cd84bfe45da7d3b480ef460b`
  Original: `sparse_grass_nor_gl_1k.jpg`; SHA-256 `1c840a24807346ddaaf94a5057aee4078fcec3a4cd84bfe45da7d3b480ef460b`; download: https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/sparse_grass/sparse_grass_nor_gl_1k.jpg
- Shipped: `assets/welcome_island/textures/sparse_grass/sparse_grass_rough_1k.jpg`; SHA-256 `9ebe6d03a9551c17d1802835c92c1442acb8f5d38d4874ee8c37770f11c4bed1`
  Original: `sparse_grass_rough_1k.jpg`; SHA-256 `9ebe6d03a9551c17d1802835c92c1442acb8f5d38d4874ee8c37770f11c4bed1`; download: https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/sparse_grass/sparse_grass_rough_1k.jpg

### polyhaven.rock_path — Rock Path

- Author: Amal Kumar
- Source: https://polyhaven.com/a/rock_path
- License: CC0-1.0; terms: `assets/welcome_island/licenses/CC0-1.0.txt`
- Retrieved: 2026-11-05
- Attribution: Not required (CC0); voluntary acknowledgement above.
- Modifications: Unmodified publisher 1K JPEG diffuse, OpenGL normal and roughness maps; no displacement geometry.
- Shipped: `assets/welcome_island/textures/rock_path/rock_path_diff_1k.jpg`; SHA-256 `6e5e805b8a40d49f516919a256be246fea2ed46707e3f9ff124140774508180e`
  Original: `rock_path_diff_1k.jpg`; SHA-256 `6e5e805b8a40d49f516919a256be246fea2ed46707e3f9ff124140774508180e`; download: https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/rock_path/rock_path_diff_1k.jpg
- Shipped: `assets/welcome_island/textures/rock_path/rock_path_nor_gl_1k.jpg`; SHA-256 `4a9b260df57d70b564a8f65a6584546f4bf6f439fd5863964b2226ed9d54a17c`
  Original: `rock_path_nor_gl_1k.jpg`; SHA-256 `4a9b260df57d70b564a8f65a6584546f4bf6f439fd5863964b2226ed9d54a17c`; download: https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/rock_path/rock_path_nor_gl_1k.jpg
- Shipped: `assets/welcome_island/textures/rock_path/rock_path_rough_1k.jpg`; SHA-256 `2155182f95da50dc6c3b065f46d6435968c7932b300b1764b1e5f0267908f6ab`
  Original: `rock_path_rough_1k.jpg`; SHA-256 `2155182f95da50dc6c3b065f46d6435968c7932b300b1764b1e5f0267908f6ab`; download: https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/rock_path/rock_path_rough_1k.jpg

### polyhaven.rock_01 — Rock 01

- Author: Rob Tuytel
- Source: https://polyhaven.com/a/rock_01
- License: CC0-1.0; terms: `assets/welcome_island/licenses/CC0-1.0.txt`
- Retrieved: 2026-11-05
- Attribution: Not required (CC0); voluntary acknowledgement above.
- Modifications: Unmodified publisher 1K JPEG diffuse, OpenGL normal and roughness maps; no displacement geometry.
- Shipped: `assets/welcome_island/textures/rock_01/rock_01_diff_1k.jpg`; SHA-256 `0b5f0418eb1e686190c5d33bb54c400b1f9ed58813b5e34aa5e573a5197302b5`
  Original: `rock_01_diff_1k.jpg`; SHA-256 `0b5f0418eb1e686190c5d33bb54c400b1f9ed58813b5e34aa5e573a5197302b5`; download: https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/rock_01/rock_01_diff_1k.jpg
- Shipped: `assets/welcome_island/textures/rock_01/rock_01_nor_gl_1k.jpg`; SHA-256 `7a7146f51159a7667233c2c14c34ff18a9f4374cc8869d53a1162648d0941023`
  Original: `rock_01_nor_gl_1k.jpg`; SHA-256 `7a7146f51159a7667233c2c14c34ff18a9f4374cc8869d53a1162648d0941023`; download: https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/rock_01/rock_01_nor_gl_1k.jpg
- Shipped: `assets/welcome_island/textures/rock_01/rock_01_rough_1k.jpg`; SHA-256 `e98b9c8ffb35513bd7b36a8730bf9745d05325376a85fae87ebf56a7c071a123`
  Original: `rock_01_rough_1k.jpg`; SHA-256 `e98b9c8ffb35513bd7b36a8730bf9745d05325376a85fae87ebf56a7c071a123`; download: https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/rock_01/rock_01_rough_1k.jpg

### polyhaven.weathered_planks — Weathered Planks

- Author: Dario Barresi; Dimitrios Savva
- Source: https://polyhaven.com/a/weathered_planks
- License: CC0-1.0; terms: `assets/welcome_island/licenses/CC0-1.0.txt`
- Retrieved: 2026-11-05
- Attribution: Not required (CC0); voluntary acknowledgement above.
- Modifications: Unmodified publisher 1K JPEG diffuse, OpenGL normal and roughness maps; no displacement geometry.
- Shipped: `assets/welcome_island/textures/weathered_planks/weathered_planks_diff_1k.jpg`; SHA-256 `01c9a372cfd7a7bf471b59c2458ed3ccecc93448aebf7ba0cc5b3b5b6ed24349`
  Original: `weathered_planks_diff_1k.jpg`; SHA-256 `01c9a372cfd7a7bf471b59c2458ed3ccecc93448aebf7ba0cc5b3b5b6ed24349`; download: https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/weathered_planks/weathered_planks_diff_1k.jpg
- Shipped: `assets/welcome_island/textures/weathered_planks/weathered_planks_nor_gl_1k.jpg`; SHA-256 `381d298f3194ec4961b04b4912b9b6efea4b2ff7b914dac57e24c8b6b0be6a25`
  Original: `weathered_planks_nor_gl_1k.jpg`; SHA-256 `381d298f3194ec4961b04b4912b9b6efea4b2ff7b914dac57e24c8b6b0be6a25`; download: https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/weathered_planks/weathered_planks_nor_gl_1k.jpg
- Shipped: `assets/welcome_island/textures/weathered_planks/weathered_planks_rough_1k.jpg`; SHA-256 `a017728183597417a350d1846a5a46db9702ee6d472a21c5da2f23015d606aa3`
  Original: `weathered_planks_rough_1k.jpg`; SHA-256 `a017728183597417a350d1846a5a46db9702ee6d472a21c5da2f23015d606aa3`; download: https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/weathered_planks/weathered_planks_rough_1k.jpg

### kenney.pond-boat — Watercraft Kit 2.1 — large rowing boat

- Author: Kenney
- Source: https://kenney.nl/assets/watercraft-kit
- License: CC0-1.0; terms: `assets/welcome_island/licenses/CC0-1.0.txt`
- Retrieved: 2026-11-05
- Attribution: Not required (CC0); voluntary acknowledgement above.
- Modifications: Unmodified boat-row-large.glb extracted from Watercraft Kit 2.1. Runtime hull uniformly scaled to pond size; independent collision/controls. Publisher notice: assets/welcome_island/licenses/Kenney-Watercraft.txt. Archive SHA-256 cd1470c1cf441c7f46d0944ae6d0d897242365dc97677c5079b3238965d659f3. Official download returned 403; same archive obtained via Asset Commons mirror. Runtime hull meshes use independent weathered-timber PBR overrides from the separately credited Poly Haven set; source geometry/texture bytes remain unchanged.
- Shipped: `assets/welcome_island/models/ship/boat-row-large.glb`; SHA-256 `25eed6585c7398654522d338ec575509615443887362ca8e598559b4eca142a3`
  Original: `Models/GLB format/boat-row-large.glb`; SHA-256 `25eed6585c7398654522d338ec575509615443887362ca8e598559b4eca142a3`; download: https://youraiagent.biz/api/assets/kenney-watercraft-kit/download
- Shipped: `assets/welcome_island/models/ship/Textures/colormap.png`; SHA-256 `311138350e74e35c5497a1bd8076a01740b7c302bed11027639fa553459a68de`
  Original: `Models/GLB format/Textures/colormap.png`; SHA-256 `311138350e74e35c5497a1bd8076a01740b7c302bed11027639fa553459a68de`; download: https://youraiagent.biz/api/assets/kenney-watercraft-kit/download

### kenney.home-furniture — Furniture Kit 2.0 — selected home furnishings

- Author: Kenney
- Source: https://kenney.nl/assets/furniture-kit
- License: CC0-1.0; terms: `assets/welcome_island/licenses/CC0-1.0.txt`
- Retrieved: 2026-11-05
- Attribution: Not required (CC0); voluntary acknowledgement above.
- Modifications: Unmodified individual GLBs extracted from Furniture Kit 2.0; assembled and scaled independently in our original house/layout. Included notice assets/welcome_island/licenses/Kenney-Furniture.txt. Mirror archive SHA-256 e67652d0932cee41683f74711c03d3e192a2af9979ef8e6b237711f5482d46b0. No furnished house preset included.
- Shipped: `assets/welcome_island/models/furniture/bedSingle.glb`; SHA-256 `ca00c63f9a12da3138d902b2f5f18e0360fb6e8a5ac42ccb4bc3f185724b65d1`
  Original: `Models/GLTF format/bedSingle.glb`; SHA-256 `ca00c63f9a12da3138d902b2f5f18e0360fb6e8a5ac42ccb4bc3f185724b65d1`; download: https://youraiagent.biz/api/assets/kenney-furniture-kit/download
- Shipped: `assets/welcome_island/models/furniture/loungeSofa.glb`; SHA-256 `1886b811c0d3ad0d8525a4fd43adf4112c497c8e0ed906f06877ca3517f4c7dd`
  Original: `Models/GLTF format/loungeSofa.glb`; SHA-256 `1886b811c0d3ad0d8525a4fd43adf4112c497c8e0ed906f06877ca3517f4c7dd`; download: https://youraiagent.biz/api/assets/kenney-furniture-kit/download
- Shipped: `assets/welcome_island/models/furniture/tableCoffee.glb`; SHA-256 `e38bea760fbd514efbb75528d09b4752c91af44677bbb97e6d4386c263525179`
  Original: `Models/GLTF format/tableCoffee.glb`; SHA-256 `e38bea760fbd514efbb75528d09b4752c91af44677bbb97e6d4386c263525179`; download: https://youraiagent.biz/api/assets/kenney-furniture-kit/download
- Shipped: `assets/welcome_island/models/furniture/bench.glb`; SHA-256 `ba05a6d23a5a5a44da016757632070e47ff7587ce10e2f6d6d52328b4cf5489b`
  Original: `Models/GLTF format/bench.glb`; SHA-256 `ba05a6d23a5a5a44da016757632070e47ff7587ce10e2f6d6d52328b4cf5489b`; download: https://youraiagent.biz/api/assets/kenney-furniture-kit/download
- Shipped: `assets/welcome_island/models/furniture/benchCushionLow.glb`; SHA-256 `d1fac209eae2ea7393beefa4932dacb54d500e8f9932a1b17d2a842527df1b2c`
  Original: `Models/GLTF format/benchCushionLow.glb`; SHA-256 `d1fac209eae2ea7393beefa4932dacb54d500e8f9932a1b17d2a842527df1b2c`; download: https://youraiagent.biz/api/assets/kenney-furniture-kit/download
- Shipped: `assets/welcome_island/models/furniture/pillow.glb`; SHA-256 `6fae7c190d0b676ef3efd35e5178cef21dffb5c80e1257d8b537ad424da0e5f6`
  Original: `Models/GLTF format/pillow.glb`; SHA-256 `6fae7c190d0b676ef3efd35e5178cef21dffb5c80e1257d8b537ad424da0e5f6`; download: https://youraiagent.biz/api/assets/kenney-furniture-kit/download
- Shipped: `assets/welcome_island/models/furniture/table.glb`; SHA-256 `ff1a94498d023957f4bc3ff6f55a7a82977d336dbf01a573b3364f03afe5ff61`
  Original: `Models/GLTF format/table.glb`; SHA-256 `ff1a94498d023957f4bc3ff6f55a7a82977d336dbf01a573b3364f03afe5ff61`; download: https://youraiagent.biz/api/assets/kenney-furniture-kit/download
- Shipped: `assets/welcome_island/models/furniture/plantSmall1.glb`; SHA-256 `2b9c022feb47be857b2c4fdc29f36522766ba9b70c578c31d7c05d71b4377d15`
  Original: `Models/GLTF format/plantSmall1.glb`; SHA-256 `2b9c022feb47be857b2c4fdc29f36522766ba9b70c578c31d7c05d71b4377d15`; download: https://youraiagent.biz/api/assets/kenney-furniture-kit/download
- Shipped: `assets/welcome_island/models/furniture/rugRectangle.glb`; SHA-256 `a989d2d59c04e3071e0c90388b113a9a8f339ce1814ef984c51cb6dcd7c8e0eb`
  Original: `Models/GLTF format/rugRectangle.glb`; SHA-256 `a989d2d59c04e3071e0c90388b113a9a8f339ce1814ef984c51cb6dcd7c8e0eb`; download: https://youraiagent.biz/api/assets/kenney-furniture-kit/download
- Shipped: `assets/welcome_island/models/furniture/lampRoundFloor.glb`; SHA-256 `50fe1b5b588edf15bfa9cc880f71a02a4fda6036350b24733d0ef4de5cc5e908`
  Original: `Models/GLTF format/lampRoundFloor.glb`; SHA-256 `50fe1b5b588edf15bfa9cc880f71a02a4fda6036350b24733d0ef4de5cc5e908`; download: https://youraiagent.biz/api/assets/kenney-furniture-kit/download
- Shipped: `assets/welcome_island/models/furniture/kitchenSink.glb`; SHA-256 `7b9610277d71f00dcf1bba49cf4d98d77ce5177e84bf76c7da2f8893e542f743`
  Original: `Models/GLTF format/kitchenSink.glb`; SHA-256 `7b9610277d71f00dcf1bba49cf4d98d77ce5177e84bf76c7da2f8893e542f743`; download: https://youraiagent.biz/api/assets/kenney-furniture-kit/download
- Shipped: `assets/welcome_island/models/furniture/kitchenStoveElectric.glb`; SHA-256 `cf646b960d7dfed1fac27898ff6de1f0671cfa33beecbed06ead7d0684517392`
  Original: `Models/GLTF format/kitchenStoveElectric.glb`; SHA-256 `cf646b960d7dfed1fac27898ff6de1f0671cfa33beecbed06ead7d0684517392`; download: https://youraiagent.biz/api/assets/kenney-furniture-kit/download
- Shipped: `assets/welcome_island/models/furniture/kitchenFridgeSmall.glb`; SHA-256 `35dab7f63711623be321bfd82072f4ab29fe8006aac9371c6e6b78df2e02f5ed`
  Original: `Models/GLTF format/kitchenFridgeSmall.glb`; SHA-256 `35dab7f63711623be321bfd82072f4ab29fe8006aac9371c6e6b78df2e02f5ed`; download: https://youraiagent.biz/api/assets/kenney-furniture-kit/download

### kenney.kitchenware — Food Kit — eight kitchen belongings

- Author: Kenney
- Source: https://kenney.nl/assets/food-kit
- License: CC0-1.0; terms: `assets/welcome_island/licenses/CC0-1.0.txt`
- Retrieved: 2026-11-05
- Attribution: Not required (CC0); voluntary acknowledgement above.
- Modifications: Unmodified individual GLBs plus colormap, normalized at runtime with simple collision proxies. No complete kitchen preset. Publisher notice assets/welcome_island/licenses/Kenney-Food.txt. Mirror archive SHA-256 cdad90853682499b94c9fda2f87678b24bfd8f3264e0ed323f6b6a27fd7c6f6f.
- Shipped: `assets/welcome_island/models/kitchenware/cup.glb`; SHA-256 `f9d6786fe9836f16ebb10cc1cb5a8ea8d512c7ae6cfa22394af653e5a5b05f09`
  Original: `Models/GLB format/cup.glb`; SHA-256 `f9d6786fe9836f16ebb10cc1cb5a8ea8d512c7ae6cfa22394af653e5a5b05f09`; download: https://youraiagent.biz/api/assets/kenney-food-kit/download
- Shipped: `assets/welcome_island/models/kitchenware/bowl.glb`; SHA-256 `92463570dced6e0898cdc11c218c477efa9b1693d6d3c0e661b67119f294ca7b`
  Original: `Models/GLB format/bowl.glb`; SHA-256 `92463570dced6e0898cdc11c218c477efa9b1693d6d3c0e661b67119f294ca7b`; download: https://youraiagent.biz/api/assets/kenney-food-kit/download
- Shipped: `assets/welcome_island/models/kitchenware/plate.glb`; SHA-256 `4c1de567b854264b2a9407ec221d33dfd13c7fc18563ea1f33cb8abe3a3d11be`
  Original: `Models/GLB format/plate.glb`; SHA-256 `4c1de567b854264b2a9407ec221d33dfd13c7fc18563ea1f33cb8abe3a3d11be`; download: https://youraiagent.biz/api/assets/kenney-food-kit/download
- Shipped: `assets/welcome_island/models/kitchenware/pot.glb`; SHA-256 `ba84c5ebd769849b7cb0365adf1f6044680e024ba29e0bc1bec93d54100f72b3`
  Original: `Models/GLB format/pot.glb`; SHA-256 `ba84c5ebd769849b7cb0365adf1f6044680e024ba29e0bc1bec93d54100f72b3`; download: https://youraiagent.biz/api/assets/kenney-food-kit/download
- Shipped: `assets/welcome_island/models/kitchenware/frying-pan.glb`; SHA-256 `66cd36e3361d47f068cd1fc06df422b550058adde2017f306ed93dad7c3d2b9f`
  Original: `Models/GLB format/frying-pan.glb`; SHA-256 `66cd36e3361d47f068cd1fc06df422b550058adde2017f306ed93dad7c3d2b9f`; download: https://youraiagent.biz/api/assets/kenney-food-kit/download
- Shipped: `assets/welcome_island/models/kitchenware/utensil-spoon.glb`; SHA-256 `dbb39cce42ceaad607f80a3ee0b25a6f7d8f5feec3688f0c66fb585f4621e5f5`
  Original: `Models/GLB format/utensil-spoon.glb`; SHA-256 `dbb39cce42ceaad607f80a3ee0b25a6f7d8f5feec3688f0c66fb585f4621e5f5`; download: https://youraiagent.biz/api/assets/kenney-food-kit/download
- Shipped: `assets/welcome_island/models/kitchenware/cutting-board.glb`; SHA-256 `067f8a9331d16c65487a748747de2cddab2a77826f23bd7379e4f5da186c78ea`
  Original: `Models/GLB format/cutting-board.glb`; SHA-256 `067f8a9331d16c65487a748747de2cddab2a77826f23bd7379e4f5da186c78ea`; download: https://youraiagent.biz/api/assets/kenney-food-kit/download
- Shipped: `assets/welcome_island/models/kitchenware/can.glb`; SHA-256 `f3ee6aad23adb6251adbc988652dff430abc781506759a53a8cc7aca6a87db48`
  Original: `Models/GLB format/can.glb`; SHA-256 `f3ee6aad23adb6251adbc988652dff430abc781506759a53a8cc7aca6a87db48`; download: https://youraiagent.biz/api/assets/kenney-food-kit/download
- Shipped: `assets/welcome_island/models/kitchenware/Textures/colormap.png`; SHA-256 `75baf74d9483a0fc56ac21ceba346fbe16fc24a2a1bf0524c53e6bbe802e1153`
  Original: `Models/GLB format/Textures/colormap.png`; SHA-256 `75baf74d9483a0fc56ac21ceba346fbe16fc24a2a1bf0524c53e6bbe802e1153`; download: https://youraiagent.biz/api/assets/kenney-food-kit/download

### innerscene.bungalow-house — Bungalow house — original architectural model

- Author: Innerscene Corp
- Source: https://www.innerscene.com/tools/library/3d-parts/bungalow-house-85d40048
- License: CC0-1.0; terms: `assets/welcome_island/licenses/CC0-1.0.txt`
- Retrieved: 2026-11-06
- Attribution: Not required (CC0); voluntary acknowledgement above.
- Modifications: Original GLB preserved. Verified embedded PNG images extracted by Godot and listed separately. Runtime adapts front facade/door/steps for broad accessible entry, retains roof/windows/porch details and uses separate proven collision/interior. Roof finish is subdued by per-instance material overrides. Embedded copyright dedicates model under CC0 1.0.
- Shipped: `assets/welcome_island/models/architecture/bungalow-house.glb`; SHA-256 `bf194d518767450bdc2bfa4d90948ec274bf07f23f5e3ae767c63e20bfd9e1cb`
  Original: `bungalow-house.glb`; SHA-256 `bf194d518767450bdc2bfa4d90948ec274bf07f23f5e3ae767c63e20bfd9e1cb`; download: https://www.innerscene.com/api/library/bungalow-house-85d40048/download
- Shipped: `assets/welcome_island/models/architecture/bungalow-house_black_iron_house_2k.png`; SHA-256 `d318402747c036331d5d2ec3cf0f68db840cb0e918f7630b973b8474761ffde6`
  Original: `bungalow-house.glb#black_iron_house_2k`; SHA-256 `d318402747c036331d5d2ec3cf0f68db840cb0e918f7630b973b8474761ffde6`; download: https://www.innerscene.com/api/library/bungalow-house-85d40048/download
- Shipped: `assets/welcome_island/models/architecture/bungalow-house_white_paint_house_2k.png`; SHA-256 `2d6a5a60d241cd8e95f8a5d2e0577c5aba5c72a299d0add462303cb74191dee0`
  Original: `bungalow-house.glb#white_paint_house_2k`; SHA-256 `2d6a5a60d241cd8e95f8a5d2e0577c5aba5c72a299d0add462303cb74191dee0`; download: https://www.innerscene.com/api/library/bungalow-house-85d40048/download
- Shipped: `assets/welcome_island/models/architecture/bungalow-house_stone_sandstone_house_2k.png`; SHA-256 `84379fe87bea9e9baf3fcdd3e5e79af6ab98b2f932841abdf8ded8daf4424ddb`
  Original: `bungalow-house.glb#stone_sandstone_house_2k`; SHA-256 `84379fe87bea9e9baf3fcdd3e5e79af6ab98b2f932841abdf8ded8daf4424ddb`; download: https://www.innerscene.com/api/library/bungalow-house-85d40048/download
- Shipped: `assets/welcome_island/models/architecture/bungalow-house_oak_house_2k.png`; SHA-256 `786bc83c956e98b793085e4772d78e32b1404abe105b56dbf5dc3cdf8d55c0ad`
  Original: `bungalow-house.glb#oak_house_2k`; SHA-256 `786bc83c956e98b793085e4772d78e32b1404abe105b56dbf5dc3cdf8d55c0ad`; download: https://www.innerscene.com/api/library/bungalow-house-85d40048/download
- Shipped: `assets/welcome_island/models/architecture/bungalow-house_brass_house_2k.png`; SHA-256 `a64f20e32da233823aa5841dc73b26bed5210ebe38a50fb034a078a8931b4424`
  Original: `bungalow-house.glb#brass_house_2k`; SHA-256 `a64f20e32da233823aa5841dc73b26bed5210ebe38a50fb034a078a8931b4424`; download: https://www.innerscene.com/api/library/bungalow-house-85d40048/download
- Shipped: `assets/welcome_island/models/architecture/bungalow-house_glass_house_2k.png`; SHA-256 `8161cfc07ecff3d81690e0b9290ac3e1e07fe388e33f96c511414119dc77f0cd`
  Original: `bungalow-house.glb#glass_house_2k`; SHA-256 `8161cfc07ecff3d81690e0b9290ac3e1e07fe388e33f96c511414119dc77f0cd`; download: https://www.innerscene.com/api/library/bungalow-house-85d40048/download
- Shipped: `assets/welcome_island/models/architecture/bungalow-house_render_cream_house_2k.png`; SHA-256 `95b3e5dd8187709d7e6dda21884e081fa0c63eb06e1f9f0140ace2aff20e5a8d`
  Original: `bungalow-house.glb#render_cream_house_2k`; SHA-256 `95b3e5dd8187709d7e6dda21884e081fa0c63eb06e1f9f0140ace2aff20e5a8d`; download: https://www.innerscene.com/api/library/bungalow-house-85d40048/download
- Shipped: `assets/welcome_island/models/architecture/bungalow-house_roof_tiles_red_house_2k.png`; SHA-256 `3555216a4ad939bd2d0685563cb863880f04e7a047ced4e8e255d8e90a54a770`
  Original: `bungalow-house.glb#roof_tiles_red_house_2k`; SHA-256 `3555216a4ad939bd2d0685563cb863880f04e7a047ced4e8e255d8e90a54a770`; download: https://www.innerscene.com/api/library/bungalow-house-85d40048/download

### polyhaven.sofa_02 — Sofa 02

- Author: Kirill Sannikov
- Source: https://polyhaven.com/a/sofa_02
- License: CC0-1.0; terms: `assets/welcome_island/licenses/CC0-1.0.txt`
- Retrieved: 2026-11-06
- Attribution: Not required (CC0); voluntary acknowledgement above.
- Modifications: Unmodified publisher 1K glTF/buffer/PBR maps. Runtime uniformly normalized for consistent home scale; no scene layout imported.
- Shipped: `assets/welcome_island/models/style/sofa_02/sofa_02_1k.gltf`; SHA-256 `5df114209f9b956ccd4831eaeef469a81339ab371d0056eb6d5d29eee08eb431`
  Original: `sofa_02_1k.gltf`; SHA-256 `5df114209f9b956ccd4831eaeef469a81339ab371d0056eb6d5d29eee08eb431`; download: https://dl.polyhaven.org/file/ph-assets/Models/gltf/1k/sofa_02/sofa_02_1k.gltf
- Shipped: `assets/welcome_island/models/style/sofa_02/textures/sofa_02_diff_1k.jpg`; SHA-256 `4ff65c782578b52eee89cb96cc4e258ce1b6848e1a7655019af1f7207c749840`
  Original: `textures/sofa_02_diff_1k.jpg`; SHA-256 `4ff65c782578b52eee89cb96cc4e258ce1b6848e1a7655019af1f7207c749840`; download: https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/sofa_02/sofa_02_diff_1k.jpg
- Shipped: `assets/welcome_island/models/style/sofa_02/textures/sofa_02_arm_1k.jpg`; SHA-256 `f2813f32cd9ec42a9080590d0953ac9e272d9baa0b22fdb5910bf325157393c6`
  Original: `textures/sofa_02_arm_1k.jpg`; SHA-256 `f2813f32cd9ec42a9080590d0953ac9e272d9baa0b22fdb5910bf325157393c6`; download: https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/sofa_02/sofa_02_arm_1k.jpg
- Shipped: `assets/welcome_island/models/style/sofa_02/textures/sofa_02_nor_gl_1k.jpg`; SHA-256 `c97a359703a8ce1cee62cbd9dc4013b611d821afb7769810983b464ebc5d0cfe`
  Original: `textures/sofa_02_nor_gl_1k.jpg`; SHA-256 `c97a359703a8ce1cee62cbd9dc4013b611d821afb7769810983b464ebc5d0cfe`; download: https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/sofa_02/sofa_02_nor_gl_1k.jpg
- Shipped: `assets/welcome_island/models/style/sofa_02/sofa_02.bin`; SHA-256 `cb337e03211be0309afa1ded2b6cbb2d402c0f794aaf8828fba559d27a42d3f5`
  Original: `sofa_02.bin`; SHA-256 `cb337e03211be0309afa1ded2b6cbb2d402c0f794aaf8828fba559d27a42d3f5`; download: https://dl.polyhaven.org/file/ph-assets/Models/gltf/4k/sofa_02/sofa_02.bin

### polyhaven.vintage_day_bed — Vintage Day Bed

- Author: Aron Łyczek
- Source: https://polyhaven.com/a/vintage_day_bed
- License: CC0-1.0; terms: `assets/welcome_island/licenses/CC0-1.0.txt`
- Retrieved: 2026-11-06
- Attribution: Not required (CC0); voluntary acknowledgement above.
- Modifications: Unmodified publisher 1K glTF/buffer/PBR maps. Runtime uniformly normalized for consistent home scale; no scene layout imported.
- Shipped: `assets/welcome_island/models/style/vintage_day_bed/vintage_day_bed_1k.gltf`; SHA-256 `fb255992b6e651de9709b17c083a14b405e99cbc26774b31bf252e38cf9287fb`
  Original: `vintage_day_bed_1k.gltf`; SHA-256 `fb255992b6e651de9709b17c083a14b405e99cbc26774b31bf252e38cf9287fb`; download: https://dl.polyhaven.org/file/ph-assets/Models/gltf/1k/vintage_day_bed/vintage_day_bed_1k.gltf
- Shipped: `assets/welcome_island/models/style/vintage_day_bed/textures/vintage_day_bed_nor_gl_1k.jpg`; SHA-256 `2902f47f4778fce0667c2a1dbff7e2e861a0aed475668ea3fce8a485487598eb`
  Original: `textures/vintage_day_bed_nor_gl_1k.jpg`; SHA-256 `2902f47f4778fce0667c2a1dbff7e2e861a0aed475668ea3fce8a485487598eb`; download: https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/vintage_day_bed/vintage_day_bed_nor_gl_1k.jpg
- Shipped: `assets/welcome_island/models/style/vintage_day_bed/textures/vintage_day_bed_diff_1k.jpg`; SHA-256 `78b7036a3254c780052b87ac962ac6ba212501821af03c56faa2d7a9ccb955ce`
  Original: `textures/vintage_day_bed_diff_1k.jpg`; SHA-256 `78b7036a3254c780052b87ac962ac6ba212501821af03c56faa2d7a9ccb955ce`; download: https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/vintage_day_bed/vintage_day_bed_diff_1k.jpg
- Shipped: `assets/welcome_island/models/style/vintage_day_bed/textures/vintage_day_bed_arm_1k.jpg`; SHA-256 `b60e71c345fc1d16396a94a133390b4cdde5c05a38ebaadf2f5dc96be2895b11`
  Original: `textures/vintage_day_bed_arm_1k.jpg`; SHA-256 `b60e71c345fc1d16396a94a133390b4cdde5c05a38ebaadf2f5dc96be2895b11`; download: https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/vintage_day_bed/vintage_day_bed_arm_1k.jpg
- Shipped: `assets/welcome_island/models/style/vintage_day_bed/vintage_day_bed.bin`; SHA-256 `08172858c3f9d4225780013e4e9afd01bb9db42e17001fc6c790a183227ecf07`
  Original: `vintage_day_bed.bin`; SHA-256 `08172858c3f9d4225780013e4e9afd01bb9db42e17001fc6c790a183227ecf07`; download: https://dl.polyhaven.org/file/ph-assets/Models/gltf/8k/vintage_day_bed/vintage_day_bed.bin

### polyhaven.coffee_table_round_01 — Coffee Table Round 01

- Author: Ulan Cabanilla
- Source: https://polyhaven.com/a/coffee_table_round_01
- License: CC0-1.0; terms: `assets/welcome_island/licenses/CC0-1.0.txt`
- Retrieved: 2026-11-06
- Attribution: Not required (CC0); voluntary acknowledgement above.
- Modifications: Unmodified publisher 1K glTF/buffer/PBR maps. Runtime uniformly normalized for consistent home scale; no scene layout imported.
- Shipped: `assets/welcome_island/models/style/coffee_table_round_01/coffee_table_round_01_1k.gltf`; SHA-256 `58fe785584f8999f760e590b04ce74f83962d42c9440ab9415910f63a31165dc`
  Original: `coffee_table_round_01_1k.gltf`; SHA-256 `58fe785584f8999f760e590b04ce74f83962d42c9440ab9415910f63a31165dc`; download: https://dl.polyhaven.org/file/ph-assets/Models/gltf/1k/coffee_table_round_01/coffee_table_round_01_1k.gltf
- Shipped: `assets/welcome_island/models/style/coffee_table_round_01/textures/coffee_table_round_01_diff_1k.jpg`; SHA-256 `422b4a24a4459e1fd6d121aae4f1097dd3e467c7a8036bb1d003f955302f1d28`
  Original: `textures/coffee_table_round_01_diff_1k.jpg`; SHA-256 `422b4a24a4459e1fd6d121aae4f1097dd3e467c7a8036bb1d003f955302f1d28`; download: https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/coffee_table_round_01/coffee_table_round_01_diff_1k.jpg
- Shipped: `assets/welcome_island/models/style/coffee_table_round_01/textures/coffee_table_round_01_arm_1k.jpg`; SHA-256 `7221b03af475555092abd650798facbb945bf4acf02e48f8697f012d8515bf52`
  Original: `textures/coffee_table_round_01_arm_1k.jpg`; SHA-256 `7221b03af475555092abd650798facbb945bf4acf02e48f8697f012d8515bf52`; download: https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/coffee_table_round_01/coffee_table_round_01_arm_1k.jpg
- Shipped: `assets/welcome_island/models/style/coffee_table_round_01/coffee_table_round_01.bin`; SHA-256 `9605a0c156bff4ec87e8717a79978d85d4e750d21b3193a3d08bed16e8666035`
  Original: `coffee_table_round_01.bin`; SHA-256 `9605a0c156bff4ec87e8717a79978d85d4e750d21b3193a3d08bed16e8666035`; download: https://dl.polyhaven.org/file/ph-assets/Models/gltf/8k/coffee_table_round_01/coffee_table_round_01.bin
- Shipped: `assets/welcome_island/models/style/coffee_table_round_01/textures/coffee_table_round_01_nor_gl_1k.jpg`; SHA-256 `a5912db1918b1ec925efb19179675cafc8832b082f80b2ea35c3a58b45e1aec4`
  Original: `textures/coffee_table_round_01_nor_gl_1k.jpg`; SHA-256 `a5912db1918b1ec925efb19179675cafc8832b082f80b2ea35c3a58b45e1aec4`; download: https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/coffee_table_round_01/coffee_table_round_01_nor_gl_1k.jpg

### polyhaven.wooden_picnic_table — Wooden Picnic Table

- Author: Ulan Cabanilla
- Source: https://polyhaven.com/a/wooden_picnic_table
- License: CC0-1.0; terms: `assets/welcome_island/licenses/CC0-1.0.txt`
- Retrieved: 2026-11-06
- Attribution: Not required (CC0); voluntary acknowledgement above.
- Modifications: Unmodified publisher 1K glTF/buffer/PBR maps. Runtime uniformly normalized for consistent home scale; no scene layout imported.
- Shipped: `assets/welcome_island/models/style/wooden_picnic_table/wooden_picnic_table_1k.gltf`; SHA-256 `6b0dd9916fd87dba2e5baad06e20c0badf68bc68a5761a13854fa9a215c6bd50`
  Original: `wooden_picnic_table_1k.gltf`; SHA-256 `6b0dd9916fd87dba2e5baad06e20c0badf68bc68a5761a13854fa9a215c6bd50`; download: https://dl.polyhaven.org/file/ph-assets/Models/gltf/1k/wooden_picnic_table/wooden_picnic_table_1k.gltf
- Shipped: `assets/welcome_island/models/style/wooden_picnic_table/textures/wooden_picnic_table_top_arm_1k.jpg`; SHA-256 `50d2b7a0b15c56bf82bc0c918e6eaa5f590a6fd61d32311c8da85c414ace297d`
  Original: `textures/wooden_picnic_table_top_arm_1k.jpg`; SHA-256 `50d2b7a0b15c56bf82bc0c918e6eaa5f590a6fd61d32311c8da85c414ace297d`; download: https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/wooden_picnic_table/wooden_picnic_table_top_arm_1k.jpg
- Shipped: `assets/welcome_island/models/style/wooden_picnic_table/textures/wooden_picnic_table_top_nor_gl_1k.jpg`; SHA-256 `1e65787457f9edfdd04f1ee3f777ac2d2a9d43bfbbd3cb40c1e086f939bba419`
  Original: `textures/wooden_picnic_table_top_nor_gl_1k.jpg`; SHA-256 `1e65787457f9edfdd04f1ee3f777ac2d2a9d43bfbbd3cb40c1e086f939bba419`; download: https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/wooden_picnic_table/wooden_picnic_table_top_nor_gl_1k.jpg
- Shipped: `assets/welcome_island/models/style/wooden_picnic_table/wooden_picnic_table.bin`; SHA-256 `1efd51c292843194fbd709452d56d06c9ddc770f43a013db57ca79bfc2731b01`
  Original: `wooden_picnic_table.bin`; SHA-256 `1efd51c292843194fbd709452d56d06c9ddc770f43a013db57ca79bfc2731b01`; download: https://dl.polyhaven.org/file/ph-assets/Models/gltf/4k/wooden_picnic_table/wooden_picnic_table.bin
- Shipped: `assets/welcome_island/models/style/wooden_picnic_table/textures/wooden_picnic_table_bottom_arm_1k.jpg`; SHA-256 `555226136c1d754d4aa5da42385a9152a146c5175382c77cced611a6880efd35`
  Original: `textures/wooden_picnic_table_bottom_arm_1k.jpg`; SHA-256 `555226136c1d754d4aa5da42385a9152a146c5175382c77cced611a6880efd35`; download: https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/wooden_picnic_table/wooden_picnic_table_bottom_arm_1k.jpg
- Shipped: `assets/welcome_island/models/style/wooden_picnic_table/textures/wooden_picnic_table_top_diff_1k.jpg`; SHA-256 `4aefdef35bf343410dbebd8577dfc968f1d6420ccddc601b19912e84b2accc0a`
  Original: `textures/wooden_picnic_table_top_diff_1k.jpg`; SHA-256 `4aefdef35bf343410dbebd8577dfc968f1d6420ccddc601b19912e84b2accc0a`; download: https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/wooden_picnic_table/wooden_picnic_table_top_diff_1k.jpg
- Shipped: `assets/welcome_island/models/style/wooden_picnic_table/textures/wooden_picnic_table_bottom_nor_gl_1k.jpg`; SHA-256 `c5d6eb388eceb6d98e92ff31d3f3346d411b1bbcb15c05dc9da71e4a7e398539`
  Original: `textures/wooden_picnic_table_bottom_nor_gl_1k.jpg`; SHA-256 `c5d6eb388eceb6d98e92ff31d3f3346d411b1bbcb15c05dc9da71e4a7e398539`; download: https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/wooden_picnic_table/wooden_picnic_table_bottom_nor_gl_1k.jpg
- Shipped: `assets/welcome_island/models/style/wooden_picnic_table/textures/wooden_picnic_table_bottom_diff_1k.jpg`; SHA-256 `887b9a57213f87196fb090419e14d00095af8fa56c93ca6cd7d0d70ef4e5fd27`
  Original: `textures/wooden_picnic_table_bottom_diff_1k.jpg`; SHA-256 `887b9a57213f87196fb090419e14d00095af8fa56c93ca6cd7d0d70ef4e5fd27`; download: https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/wooden_picnic_table/wooden_picnic_table_bottom_diff_1k.jpg

### polyhaven.fir_sapling — Fir Sapling

- Author: Rob Tuytel; Rico Cilliers
- Source: https://polyhaven.com/a/fir_sapling
- License: CC0-1.0; terms: `assets/welcome_island/licenses/CC0-1.0.txt`
- Retrieved: 2026-11-06
- Attribution: Not required (CC0); voluntary acknowledgement above.
- Modifications: Publisher 1K glTF/buffer/textures preserved unchanged. Derived runtime scenes split individual variants, select Godot 4.7 meshoptimizer LOD topology up to 7000 triangles per surface, compact unused vertices and regenerate distance LODs. Rebuild: python3 tools/assets/optimize_island.py.
- Shipped: `assets/welcome_island/models/nature/fir_sapling/fir_sapling_1k.gltf`; SHA-256 `a9466ca9d8c5b9b2eeeeafd3ce426f8912dcbd98a7281bad8c734833eb35b186`
  Original: `fir_sapling_1k.gltf`; SHA-256 `a9466ca9d8c5b9b2eeeeafd3ce426f8912dcbd98a7281bad8c734833eb35b186`; download: https://dl.polyhaven.org/file/ph-assets/Models/gltf/1k/fir_sapling/fir_sapling_1k.gltf
- Shipped: `assets/welcome_island/models/nature/fir_sapling/textures/fir_sapling_twigs_nor_gl_1k.jpg`; SHA-256 `34928b2a9d1f722d2f64a7da468c790ecaca9b89c00ac0878a9e0bad26748368`
  Original: `textures/fir_sapling_twigs_nor_gl_1k.jpg`; SHA-256 `34928b2a9d1f722d2f64a7da468c790ecaca9b89c00ac0878a9e0bad26748368`; download: https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/fir_sapling/fir_sapling_twigs_nor_gl_1k.jpg
- Shipped: `assets/welcome_island/models/nature/fir_sapling/textures/fir_sapling_branches_diff_1k.jpg`; SHA-256 `46d216526b6203dbd5dc3cfce5e49d7a4cc1770da2420faab45adf33671c7de4`
  Original: `textures/fir_sapling_branches_diff_1k.jpg`; SHA-256 `46d216526b6203dbd5dc3cfce5e49d7a4cc1770da2420faab45adf33671c7de4`; download: https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/fir_sapling/fir_sapling_branches_diff_1k.jpg
- Shipped: `assets/welcome_island/models/nature/fir_sapling/textures/fir_sapling_twigs_diff_1k.jpg`; SHA-256 `a9900fafad850deeb5f79b928fd7590bca9e8ec8734d2368d4c64bba8b0c5b22`
  Original: `textures/fir_sapling_twigs_diff_1k.jpg`; SHA-256 `a9900fafad850deeb5f79b928fd7590bca9e8ec8734d2368d4c64bba8b0c5b22`; download: https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/fir_sapling/fir_sapling_twigs_diff_1k.jpg
- Shipped: `assets/welcome_island/models/nature/fir_sapling/textures/fir_sapling_branches_nor_gl_1k.jpg`; SHA-256 `dbe474f6cd593d51a19fb92a627ad900b9ab47dabd1bf60117a2cf9d110f79ea`
  Original: `textures/fir_sapling_branches_nor_gl_1k.jpg`; SHA-256 `dbe474f6cd593d51a19fb92a627ad900b9ab47dabd1bf60117a2cf9d110f79ea`; download: https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/fir_sapling/fir_sapling_branches_nor_gl_1k.jpg
- Shipped: `assets/welcome_island/models/nature/fir_sapling/textures/fir_sapling_twigs_arm_1k.jpg`; SHA-256 `d1ec27a55bb67bfe5fa2c8a41a545dc71769934b142db56ad7c703d4146e1770`
  Original: `textures/fir_sapling_twigs_arm_1k.jpg`; SHA-256 `d1ec27a55bb67bfe5fa2c8a41a545dc71769934b142db56ad7c703d4146e1770`; download: https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/fir_sapling/fir_sapling_twigs_arm_1k.jpg
- Shipped: `assets/welcome_island/models/nature/fir_sapling/textures/fir_sapling_branches_arm_1k.jpg`; SHA-256 `44c32b056b78c1046aeeb44c973a1d1352ea12d0d7ef2425527555f1256a0964`
  Original: `textures/fir_sapling_branches_arm_1k.jpg`; SHA-256 `44c32b056b78c1046aeeb44c973a1d1352ea12d0d7ef2425527555f1256a0964`; download: https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/fir_sapling/fir_sapling_branches_arm_1k.jpg
- Shipped: `assets/welcome_island/models/nature/fir_sapling/fir_sapling.bin`; SHA-256 `efdebfae6ee4b3ea20c7a85eb9f798ff4953259a3616bcff0b7e580b00f34f40`
  Original: `fir_sapling.bin`; SHA-256 `efdebfae6ee4b3ea20c7a85eb9f798ff4953259a3616bcff0b7e580b00f34f40`; download: https://dl.polyhaven.org/file/ph-assets/Models/gltf/8k/fir_sapling/fir_sapling.bin
- Shipped: `assets/welcome_island/models/runtime/fir_sapling_a.scn`; SHA-256 `4b28984b540ff51233a6f0739ef2ac3edf728a33d08e72cc8407b2a86216f5db`
  Original: `fir_sapling_1k.gltf`; SHA-256 `a9466ca9d8c5b9b2eeeeafd3ce426f8912dcbd98a7281bad8c734833eb35b186`; download: https://dl.polyhaven.org/file/ph-assets/Models/gltf/1k/fir_sapling/fir_sapling_1k.gltf
- Shipped: `assets/welcome_island/models/runtime/fir_sapling_b.scn`; SHA-256 `3cce609097e5683ad0d6d6cd5e496883814bd5c21911f4774347fdef3757f8af`
  Original: `fir_sapling_1k.gltf`; SHA-256 `a9466ca9d8c5b9b2eeeeafd3ce426f8912dcbd98a7281bad8c734833eb35b186`; download: https://dl.polyhaven.org/file/ph-assets/Models/gltf/1k/fir_sapling/fir_sapling_1k.gltf
- Shipped: `assets/welcome_island/models/runtime/fir_sapling_c.scn`; SHA-256 `7a457178a3e5f3d60fe0f8ad43d407eeb945a60bac1bbd73f906906d9fc9206e`
  Original: `fir_sapling_1k.gltf`; SHA-256 `a9466ca9d8c5b9b2eeeeafd3ce426f8912dcbd98a7281bad8c734833eb35b186`; download: https://dl.polyhaven.org/file/ph-assets/Models/gltf/1k/fir_sapling/fir_sapling_1k.gltf

### polyhaven.fern_02 — Fern 02

- Author: Rob Tuytel; Rico Cilliers
- Source: https://polyhaven.com/a/fern_02
- License: CC0-1.0; terms: `assets/welcome_island/licenses/CC0-1.0.txt`
- Retrieved: 2026-11-06
- Attribution: Not required (CC0); voluntary acknowledgement above.
- Modifications: Unmodified publisher 1K glTF/buffer/PBR files; individually placed in our original island composition. Runtime simplification/LOD uses local Godot authoring tool where recorded.
- Shipped: `assets/welcome_island/models/nature/fern_02/fern_02_1k.gltf`; SHA-256 `33974295ee19670af4877705fc7d91f33f42d6302f0d44a625e072271223031f`
  Original: `fern_02_1k.gltf`; SHA-256 `33974295ee19670af4877705fc7d91f33f42d6302f0d44a625e072271223031f`; download: https://dl.polyhaven.org/file/ph-assets/Models/gltf/1k/fern_02/fern_02_1k.gltf
- Shipped: `assets/welcome_island/models/nature/fern_02/textures/fern_02_arm_1k.jpg`; SHA-256 `ebfb5d76ce9cbdaec20bcd22dce9b755f0b1b8650ef29ca13555e3e6961025d7`
  Original: `textures/fern_02_arm_1k.jpg`; SHA-256 `ebfb5d76ce9cbdaec20bcd22dce9b755f0b1b8650ef29ca13555e3e6961025d7`; download: https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/fern_02/fern_02_arm_1k.jpg
- Shipped: `assets/welcome_island/models/nature/fern_02/textures/fern_02_diff_1k.jpg`; SHA-256 `a828a6e7b4c01c826911e2eac4b3afc7457dab7b3b392a31c681ed88b7d50029`
  Original: `textures/fern_02_diff_1k.jpg`; SHA-256 `a828a6e7b4c01c826911e2eac4b3afc7457dab7b3b392a31c681ed88b7d50029`; download: https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/fern_02/fern_02_diff_1k.jpg
- Shipped: `assets/welcome_island/models/nature/fern_02/textures/fern_02_nor_gl_1k.jpg`; SHA-256 `45bce132c6e96a0864bc89ab5da51361ab3f4afa83a6669ae499ab5ca811f621`
  Original: `textures/fern_02_nor_gl_1k.jpg`; SHA-256 `45bce132c6e96a0864bc89ab5da51361ab3f4afa83a6669ae499ab5ca811f621`; download: https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/fern_02/fern_02_nor_gl_1k.jpg
- Shipped: `assets/welcome_island/models/nature/fern_02/fern_02.bin`; SHA-256 `fe1abb762bcbbc7ad9e86925c8080437a62add257d9280e9142fdc85c226e64c`
  Original: `fern_02.bin`; SHA-256 `fe1abb762bcbbc7ad9e86925c8080437a62add257d9280e9142fdc85c226e64c`; download: https://dl.polyhaven.org/file/ph-assets/Models/gltf/8k/fern_02/fern_02.bin

### polyhaven.tree_stump_01 — Tree Stump 01

- Author: Rob Tuytel
- Source: https://polyhaven.com/a/tree_stump_01
- License: CC0-1.0; terms: `assets/welcome_island/licenses/CC0-1.0.txt`
- Retrieved: 2026-11-06
- Attribution: Not required (CC0); voluntary acknowledgement above.
- Modifications: Unmodified publisher 1K glTF/buffer/PBR files; individually placed in our original island composition. Runtime simplification/LOD uses local Godot authoring tool where recorded.
- Shipped: `assets/welcome_island/models/nature/tree_stump_01/tree_stump_01_1k.gltf`; SHA-256 `9c66ba87d693f35eb404acaa96e0eeff831c295b61a0a903795584cbcc3527c9`
  Original: `tree_stump_01_1k.gltf`; SHA-256 `9c66ba87d693f35eb404acaa96e0eeff831c295b61a0a903795584cbcc3527c9`; download: https://dl.polyhaven.org/file/ph-assets/Models/gltf/1k/tree_stump_01/tree_stump_01_1k.gltf
- Shipped: `assets/welcome_island/models/nature/tree_stump_01/tree_stump_01.bin`; SHA-256 `b4d9ca70b3c908c4a638fbd6a23ed96c84055bbbf14cf44b89e31ad59fa21e0a`
  Original: `tree_stump_01.bin`; SHA-256 `b4d9ca70b3c908c4a638fbd6a23ed96c84055bbbf14cf44b89e31ad59fa21e0a`; download: https://dl.polyhaven.org/file/ph-assets/Models/gltf/8k/tree_stump_01/tree_stump_01.bin
- Shipped: `assets/welcome_island/models/nature/tree_stump_01/textures/tree_stump_01_diff_1k.jpg`; SHA-256 `781ebe420ac4d84f2e44b9e9937a596e3d5d90711d978a1392f8bf3771b5bf31`
  Original: `textures/tree_stump_01_diff_1k.jpg`; SHA-256 `781ebe420ac4d84f2e44b9e9937a596e3d5d90711d978a1392f8bf3771b5bf31`; download: https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/tree_stump_01/tree_stump_01_diff_1k.jpg
- Shipped: `assets/welcome_island/models/nature/tree_stump_01/textures/tree_stump_01_nor_gl_1k.jpg`; SHA-256 `425117514b0386bb6df41cb64a61a624d2596472e05777483d4021b3285e3ceb`
  Original: `textures/tree_stump_01_nor_gl_1k.jpg`; SHA-256 `425117514b0386bb6df41cb64a61a624d2596472e05777483d4021b3285e3ceb`; download: https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/tree_stump_01/tree_stump_01_nor_gl_1k.jpg
- Shipped: `assets/welcome_island/models/nature/tree_stump_01/textures/tree_stump_01_arm_1k.jpg`; SHA-256 `d845cd6ab45288c546267d059ebe1f8a737e174330fe9375e5f99e753f2f95d8`
  Original: `textures/tree_stump_01_arm_1k.jpg`; SHA-256 `d845cd6ab45288c546267d059ebe1f8a737e174330fe9375e5f99e753f2f95d8`; download: https://dl.polyhaven.org/file/ph-assets/Models/jpg/1k/tree_stump_01/tree_stump_01_arm_1k.jpg

<!-- welcome-island-assets:end -->
