# Bundled animation provenance

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

User-imported assets retain their own licenses. A cache hash or successful import
does not grant permission to redistribute them.
