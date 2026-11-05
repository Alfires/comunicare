# Bundled animation provenance

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
