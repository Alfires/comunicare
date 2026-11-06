# World loading: current behavior and limits

## Download and preparation

URL/local package gameplay paths await bounded worker jobs for validation and
detached world construction, keeping the main loop responsive. A completed worker
is joined before attachment. The old world remains active while download/validation
runs; acknowledged instance/revision checks still decide when activation is allowed.
Synchronous preparation remains available for authoring/isolated tooling.

## Activation and nearby visuals

Scene attachment installs collision before movement resumes. A scene-owned reveal
scheduler restores nearby mesh render layers in batches of at most eight, with an
approximately 1.5 ms CPU scheduling budget per frame. Activation does not wait for
every visual batch; runtime/pickup initialization and spawn reset complete before
the transition releases controls. Script-visible flags are never rewritten by reveal.

Unrevealed meshes outside 38 m wait for the player to approach. Pending work uses
world-space mesh bounds, so a large floor does not disappear merely because its
origin is distant. Priority updates at 10 Hz after at least 0.5 m of player movement;
pending mesh bounds are refreshed so moving props can enter range too. Deleted
meshes are discarded and removing the scheduler restores remaining render layers.
The scheduler stops processing after all pending visuals have been revealed.

Revealed resources stay resident. This is **not** spatial resource unloading,
progressive collision attachment or a promise of zero loading time. PackedScene
instantiation, tree attachment, collision registration and GPU uploads can still
cause work. The trusted built-in home additionally uses its own asset/attachment
scheduler; downloaded worlds never inherit unrestricted resource-loading callbacks.

`DataLoader.world_loading_progress(stage, fraction)` exposes loading stages; it is
not an exact measurement of GPU work or proof that all distant regions are visible.

## Verification

`tests/world_system` covers reveal budgets, range, moved bounds, authored visibility
and cleanup. `tests/avatar_loading` checks worker heartbeat/queue release.
`tests/real_ui --two-clients` exercises actual loopback packages, Create/Join,
world/instance switches and local-file activation. These checks do not certify
large-map Forward Plus frame times or physical-headset loading comfort.
