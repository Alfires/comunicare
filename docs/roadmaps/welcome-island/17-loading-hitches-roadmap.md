# Smaller streaming work slices

Status: implemented; focused tests and exported-pack check passed.

Keep the landscape intact. Split the 3,200-candidate grass build into bounded
scheduler jobs, with progressive visible instance counts and cancellation owned
by the scene. Cache distance ordering until jobs or player position change.
Test progressive construction and unchanged final grass population, then measure
streaming callbacks and rerun landscape/home lifecycle checks. These bounds do
not certify GPU upload or individual imported-model attachment times.

## Evidence

Progressive-grass assertions failed before implementation. Grass now starts with
zero visible instances and evaluates at most 96 candidates per queued callback.
All 3,200 deterministic candidates still finish, using the same blade mesh and
placement exclusions. Priority sorting is cached until jobs change or the player
moves at least half a metre; activation distances still use the live position.

Headless observation: entry 167 ms, full forced completion 3.49 s, maximum scheduler
callback 1.87 ms (previous density pass: 15.66 ms). These are observations, not a
hard timing assertion. House stages and GPU uploads are excluded from callback
timing. Repeated-home lifecycle and exported resource-pack checks passed.
Final expanded streaming run: 15 assertions passed, entry 147 ms, completion
4.13 s and maximum callback 6.65 ms, demonstrating timing variability.

Forward Plus landscape checks passed on retry (25 assertions). The first rendered
run hit the 30 s content deadline; the retry completed around that limit. Thus
full rendered loading remains variable, not fixed by grass batching alone. Fixed
post-load view p95 intervals were 9.2–10.6 ms on GTX 1070; they do not measure
loading-frame stalls or certify XR performance. Do not raise the test deadline
merely to disguise slow loading.
