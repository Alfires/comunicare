# Asset cache and animation usage

## Cache

Loaded URL avatars and world archives use `user://asset_cache/`. Open it from
**Settings → Assets**. The default budget is 4 GiB; active objects and imported
animation originals are protected. The same page controls automatic checks,
offers an immediate loaded-assets check and confirms removal of unused downloads.
Failed refreshes retain validated known-good bytes. Source updates never replace
the active world scene in place.

HTTPS is required unless the development-only HTTP setting is enabled. Redirects
are currently refused. Remote world scenes are executable Godot content, not a
sandbox: enable the explicit trusted-publisher setting only for URLs you trust.
New clients/relays pin world hashes during create/resolve/join. Older unpinned
sessions cannot provide this consistency guarantee.

## Animations

Open **Home → Animations** (header button). Eight simple original CC0 motions work
offline. Desktop avatars use idle/walk/run/jump/fall automatically; choose a clip
and Play to override this, or return to automatic locomotion using its button.
Pause, Resume, Stop, Loop and speed controls affect the selected motion.

Import a local `.vrma`/`.glb` or add an HTTPS link. Supported files must be
self-contained binary glTF with declared VRM/VRMA humanoid mapping, rotation-only
channels, LINEAR/STEP interpolation and at most 16 MiB. Unsupported expression,
translation, sparse/CUBICSPLINE or external-reference data produces an error.
This is not full VRMA conformance. Imported originals are stored in the managed
library; source files are never deleted. Reopening restores pinned imports.

Defaults synchronize automatically when the relay supports animation version 1.
For imports, explicitly enable **Share imported motion** only if you have the
right to redistribute it. Other current instance players request validated bytes
from the connected owner. Neither a local path nor a private link is advertised;
the relay forwards bounded chunks without keeping files or offline history.
No-store links cannot be shared. Missing/unsafe/incompatible motion falls back
rather than executing imported code. Remote playback/downloads can be disabled
in the same page. That opt-out currently lasts only for this client process.

Full-body VR motion requires its separate opt-in. Motion never drives collision
body/root motion or the real camera; actual avatar/IK appearance and headset
comfort still require manual verification. Change the avatar through the existing
profile controls; local VRM selection remains preview-only.

## Compatibility and limits

Update client and relay together for wire ID 28, animation hello negotiation and
world revision metadata. Old relays do not synchronize motion. Headless tests
exercise synthetic rigs and real loopback transport, not real-world visual sync
quality. The 100 ms drift goal, full-renderer/XR behavior, large-transfer voice
fairness and export notices remain release checks. See the roadmap's current
implementation section for the full remaining-work list.
