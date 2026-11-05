# Bundled animation provenance

## Original offline avatar placeholder

`scripts/assets/avatar_placeholder.gd` is an original block humanoid constructed
from Godot BoxMesh primitives, with a local loading/blocked indicator. No external
model, texture, font file or downloaded asset is bundled for this placeholder.
The implementation is shipped with the game and follows the repository license.

Research considered Kenney's CC0 Blocky Characters:
https://kenney.nl/assets/blocky-characters . Its download endpoint returned HTTP
403 in the development environment, so no Kenney asset is included or claimed as
the source of this original placeholder.

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
