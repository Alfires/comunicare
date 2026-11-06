# Streamed material reuse

Status: implemented and focused verification passed; shorter rendering hitches remain.

Avoid recreating identical ground/dock/path materials for every mesh. Upgrade
existing surfaces one per scheduler callback instead of replacing all at once.
Deduplicate immutable imported-material pipeline preparation across asset loads.
Check shared material identity, queued upgrades, rendered loading heartbeats,
landscape and home lifecycle. Do not hide stalls by extending test deadlines.

The material-identity regression failed before the cache was added. Identical
surface type/scale/readiness now shares a resource; different texture scales stay
distinct. Imported material preparation retains a reference and avoids repeating
pipeline warmup for the same immutable resource. Headless rendering skips the
GPU-only warmup (a dummy-renderer RID leak was observed without this guard).

Forward Plus retry: 18 assertions passed, worst loading frame 160 ms, maximum
scheduler callback 1.72 ms. Full forced content completion 27.3 s; no deadline was
extended. The preceding rendered run failed with repeated ~1 s intervals and
unchanged compilation counters; the cause remains unresolved. No claim of smooth
60/90 Hz loading is made. Home lifecycle, landscape and exported-pack checks passed.
