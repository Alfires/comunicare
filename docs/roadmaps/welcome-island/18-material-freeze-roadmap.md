# Runtime material compilation freezes

Status: implemented; focused verification passed with remaining hitch caveats.

Test rendered loading heartbeats, not only scheduler callback duration. A failing
Forward Plus run reproduced 2,683 ms and 1,498 ms frames despite callbacks under
7 ms. Dynamic triplanar materials were not covered by imported-asset precompilation.
Prepare those exact variants and imported material pipelines on an isolated worker
before publishing resources. Stream custom shaders and grass materials as well.
Keep resources immutable after publication; no worker may touch the SceneTree.

The first successful rendered run observed a 324 ms worst loading frame. This
removes the reproduced multi-second freeze, not every perceptible hitch. Repeat
rendered verification, headless lifecycle and exported-pack checks before shipping.

## Verification

Successful Forward Plus loading-heartbeat runs: worst frames 324 ms and 162 ms,
versus the reproduced 2,683 ms baseline. Sixteen assertions passed, including a
500 ms loading-frame ceiling. Headless streaming, landscape, three-cycle home
lifecycle and exported-pack checks passed. One intervening rendered run failed
with repeated approximately 1,000 ms intervals while pipeline counters remained
unchanged; this remains recorded as a failure, not attributed conclusively to
asset loading or ignored by raising the threshold. Further hardware validation
is needed; this fix is not a promise of stutter-free frames.

Runtime triplanar variants are prepared on one low-priority worker, including a
small surface whose material is assigned before RenderingServer mesh creation.
That invokes the engine's load-time pipeline preparation before publishing the
resource. Imported materials are visited without instantiating scene nodes.
Custom shaders and the grass material now go through background loading too.
Worker-owned variants are retained until world removal and never mutated after
publication. Teardown joins an in-flight worker before releasing its resources;
switching away during compilation can still wait for that worker.
