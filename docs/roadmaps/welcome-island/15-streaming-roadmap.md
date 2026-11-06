# Home streaming

Status: implemented; focused headless and exported-pack verification passed.

Test first: terrain before scenery, proximity priority, bounded threaded requests,
and removal while loading. Keep continuous terrain and pond recovery at entry.
Load resources on loader threads and attach visual objects incrementally. Retain
interactive objects once built to preserve pickup/rest/boat state. Complete-scene
tests explicitly request all content. Downloaded-world admission is unchanged.

## Evidence and boundaries

The entry test failed before implementation: 1,682 ms headless scene construction,
with house and all vegetation already constructed. Follow-up observations were
150–242 ms. Forced all-content runs completed in approximately 2.3–2.6 seconds while
yielding frames. These exclude import, account/player loading and networking, and
are not cold-cache or rendered-frame guarantees.

One threaded request at a time; one scheduler attachment per frame; a 38 m radius
with continuously reprioritized distance ordering. Terrain, basin recovery, dock
and edge proxies remain resident. House assembly yields between major models.
Interactive content remains resident after creation to preserve state. Distant
scenery is deferred, not unloaded after visiting; individual mip levels are not
streamed. One model attachment/GPU upload can still exceed a frame budget.
Rendered/XR hitch profiling remains required.

The final 11-assertion streaming run measured 242 ms entry and a 2.05 ms largest
scheduler callback; callback timing excludes yielded house stages and GPU uploads.
Overlapping model/dependency requests triggered an intermittent dummy-renderer RID
error. Serialize top-level requests and let models own their texture dependencies.
The follow-up streaming, house, combined-home and landscape runs passed without
engine errors; routes/kitchen/lighting/pond/ship/recovery also passed.
