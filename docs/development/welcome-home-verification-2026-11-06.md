# Welcome home verification — 2026-11-06

## Source and scope

Committed source **ec810c368d20ae74930f396e94b6bd9078487e80** was archived into an
isolated directory before testing. Its own Git index lists only that archive's
files, so concurrent working-tree edits cannot change the matrix inputs. No real
account, capture device or external relay is used by the isolated runners.

The full local matrix is run with the matching official Godot 4.7.2 Linux debug
template. See the completion summary for individual group results; a local passing
matrix is not release approval. Temporary logs are not durable evidence unless
retained separately. Do not publish private test-account artifacts wholesale.

### Stable-matrix completion

The exact-source matrix completed at `/tmp/opencode/welcome-release-results-aotzvrjv`:
**23/24 selected groups passed**. The only failure was a stale committed
`house_spaces.gd` hash in the built-in dependency JSON. Active Instance, all other
home suites and official Linux debug standalone export passed on this stable source.
Commit `b1df226` regenerates that single hash from staged/committed bytes; a fresh
archive of the fix passes the manifest checker. The earlier matrix remains recorded
as failed; it is not relabeled a 24/24 run. No behavioral source change was needed
for the manifest repair. The archive Git index had no HEAD commit, so the runner
reported source-snapshot scope; the exact original revision is recorded above.

## Completed checks

- Local Markdown path/anchor checks passed on the isolated source.
- Forward Plus rendered landscape checks passed: **18 assertions**.
- Device: NVIDIA GTX 1070, Vulkan 1.4.312, Godot 4.7.2.
- 60 event-loop frame samples per fixed view after warmup:

| View | Median ms | p95 ms | Reported video memory |
| --- | ---: | ---: | ---: |
| Spawn | 7.945 | 11.708 | 386,358,768 bytes |
| Overview | 8.128 | 10.001 | 386,358,768 bytes |
| Grove | 8.297 | 8.667 | 386,358,768 bytes |
| Underside | 8.275 | 8.683 | 386,358,768 bytes |

These are small-window, potentially vsync-limited **render-loop intervals**, not
GPU-only timings, sustained thermal measurements or stereo headset performance.
The spawn p95 exceeds an 11.1 ms 90 Hz budget even before stereo rendering; no
90 Hz XR claim is made. Named-device sustained XR profiling remains required.

## Failed or unavailable acceptance

- Function-contract coverage checker fails for several current UI/editor/avatar
  modules and public functions, and a stale scene module marker. Local link checks
  do not imply function-reference completeness. This pre-existing drift is not
  corrected by inventing boilerplate behavioral contracts.
- Final visual review is **not approved**: screenshots still show sparse saplings,
  broad bare terrain, obvious path strips and limited naturalistic ground/sky
  composition. Root/shore details and a better house do not finish the art pass.
- No configured OpenXR runtime (`XR_RUNTIME_JSON` unset; system/user active runtime
  files absent). Physical-controller reach, stereo artifacts and motion comfort
  cannot be tested here.
- No human multi-network listening participants are available. Loopback voice
  routing fixtures do not establish intelligible WAN playback or subjective quality.

## Required next evidence

Use the [human gate matrix](welcome-home-release-gates.md) with named testers,
hardware, renderer, network conditions and explicit pass/fail results. Provide
final-art changes and rendered comparisons rather than ticking a checklist from
asset counts. Release remains **BLOCKED** while these requirements are unmet.
