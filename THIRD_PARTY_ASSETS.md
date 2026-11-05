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

`tools/convert_quaternius.py` reproduces the conversion from that free archive.
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

<!-- welcome-island-assets:end -->
