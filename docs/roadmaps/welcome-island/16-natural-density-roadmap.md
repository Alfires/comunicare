# Natural landscape density and stone poses

Status: implemented and focused verification passed; final human art/XR review open.

Keep the streamed entry and existing hero trees. Add bounded, uneven low planting
and stone clusters rather than another expensive canopy layer. Protect spawn,
route shoulders, house, pond, dock and social-space circulation. Vary stone yaw,
tilt, proportions and burial without changing the proven edge safety collision.
Verify deterministic placement/clearance and mixed poses before inspecting
Forward Plus spawn, grove and overview renders; rerun routes and streaming.

## Result

Added sheltered fern/small-stone pockets, bounded shared grass-blade instances and
young reduced pines between the existing hero trees. Exclusion tests protect the
central clearing, route margins, house, pond and social spaces. Stone poses now
vary in all three axes, proportions and burial; edge safety proxies are unchanged.
Meadow shading retains photographic detail without darkening the whole island to
brown soil. Narrower visual paths and meadow-matched shoulders preserve physics.

The initial pose/density checks failed before implementation. Final Forward Plus
landscape checks: 25 passed; routes: 30 passed; streaming: 11 passed. Combined-home
lifecycle also passed. Screenshot feedback caught broad triangular grass shapes
and mismatched brown shoulders, both corrected before the final renders.

GTX 1070 fixed views: ~2.4–5.5 million reported primitives, ~480 MB video memory;
render-loop p95 ~8.8–8.9 ms (potentially vsync-limited, not GPU or stereo timing).
Headless entry 178 ms; forced all-content completion 3.32 s. Largest scheduler
callback 15.7 ms includes grass construction: this is not a hard XR frame budget.
One rendered attempt timed out at ~1 s/frame; the retry and final rendered run
passed. Do not infer sustained performance or finished art from these captures.
