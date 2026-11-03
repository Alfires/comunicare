# Troubleshooting and evidence collection

## Startup or menu failure

Capture the exact Godot error, script/function/line, steps, desktop versus headset,
and current commit (`git rev-parse --short HEAD`). Do not paste private keys,
signed private URLs or complete user stores. Reproduce in isolated runners first;
factory/lifecycle tests cover detached/retiring animation controllers and input
ownership, not every renderer/device path.

## Avatar is stuck, clipped or differently animated

Check applied source validation and role names, share permission, importer errors,
and whether the peer supports the same animation capability/library. Unsupported
VRMA tracks are an explicit importer limit; a `.glb` extension alone does not prove
humanoid metadata. Local tracker targets can override head/hands; synthetic pose
tests are not visual headset calibration.

For clipping provide screenshots from first/third person and avatar format/version,
not private model bytes. First-person intentionally hides interior torso/head;
original third-person model remains intact. A source update can change hashes;
failed updates should retain the last valid selection. Do not clear account keys
to fix rendering. See [usage](../asset-cache-and-animation-usage.md).

## Join or presence unavailable

Check relay connection/authentication, exact session identity, negotiated world
revision, trust/format errors and admin admission expiry. Friendship/presence alone
does not bypass bans or Private mode. Offline/DND preference and mic mute are
independent. Missing cached pinned world bytes cannot be replaced silently by newer
URL content for an already pinned instance.

## Storage and release failures

Back up originals before recovery; wrong-owner/signature/future-version errors
must not be suppressed through destructive reset. Cache cleanup is separate from
account recovery. Release journal recovery is separate again: inspect repository
metadata diff and follow [releases](../development/releases.md); never force-push
or delete remote tags after a failed atomic push without understanding remote state.

## Verification claims

Run applicable [isolated suites](../development/testing.md), record failures plus
reruns/skips/warnings and attach a minimal reproduction. Internet latency, physical
voice, renderer/shadows and headset comfort require manual tests. “Tests pass” is
not a substitute for describing the actual observed visual/device failure.
