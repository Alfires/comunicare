# Responsive world preparation

URL/local package runtime loading now schedules package validation and detached
world construction on a bounded worker queue. Awaiting callers keep the main loop
running; only a completed worker is joined. The synchronous builder/prepare API
remains available to authoring and isolated tooling, not the gameplay URL/file path.

After validated instance acknowledgment, scene attachment installs collision, then
previously visible MeshInstance3D nodes reveal nearest the spawn first in batches
of eight per frame. Hidden authored meshes remain hidden. Script start/pickup setup
happens after reveal, so scripted visibility changes are not overwritten. Progress
is available via `DataLoader.world_loading_progress(stage, fraction)`; this change
does not add a new loading overlay.

This is not full spatial streaming. PackedScene instantiation, initial tree attachment,
collision registration and GPU uploads can still incur work. Movement remains blocked
until activation finishes, and the old world stays active during download/validation.
No unvalidated package is activated or shared-instance revision check bypassed.
Built-in trusted scenes use their existing loading path. Do not infer guaranteed
frame times or instantaneous spawn from these changes.

Tests: actual loopback two-client package Create/Join/world switches and local file
activation; production worker scheduling heartbeat with a deterministic slow job;
world package and avatar import regressions. Forward Plus and headset frame-time
profiling against a large converted map remain open.
