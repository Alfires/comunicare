# Production UI acceptance — initial roadmap execution

```sh
python3 tests/real_ui/run.py
python3 tests/real_ui/run.py --rendered
```

Copies source into a disposable project with real production autoloads, menu,
Settings, World Explorer, TLS service and ENet origin. All account/settings/trust
data is isolated under `/tmp/opencode`. Artifacts contain **disposable private
keys**; never publish the whole directory. Logs, timelines and screenshots should
be individually reviewed/redacted.

Initial regression: adding/reordering/removing an unrelated relay while joined
through TLS disconnected the actual account. Tests failed before the selective
policy fix and pass afterward; blocking still disconnects immediately. The suite
also uses Input.parse_input_event with viewport final-transform coordinate mapping
to hit-test the real Network category at 640×480 and 1000×700. Join and membership
edit actions currently use real button signals: they do not claim pointer-level
join or two-window gameplay acceptance.

Explicit isolation boundaries:

- Editor plugins disabled **only in the disposable copy**. The vendored VRM plugin
  currently fails clean Godot 4.7.2 import with missing callback return values.
  Production scripts/autoloads are not replaced by fixtures.
- Built-in world scene cache is replaced with a trusted empty packed shell while
  retaining production file hash checks. This avoids the original world's viewport/
  Jolt teardown leaks masking membership/UI assertions. Full world visuals/physics
  are separately covered by world_system, not by this fixture.
- The production catalog HTTP request is cancelled once the full menu is mounted;
  tests depend only on loopback networking. It may have been initiated during
  `_ready`; a fully hermetic catalog dependency seam is still required.
- Headless uses Compatibility and real scene input. `--rendered` opens a dedicated
  X11 window; this combined rendered suite **has timed out in current verification**
  and is not a passing gate. Timeout output/artifacts are retained, not swallowed.

Exit 1 means assertion failures; exit 2 means engine errors, missing prerequisites
or timeout. A passing headless run does not mark the whole UI roadmap complete.
Offline startup responsiveness, selected-row editing, trust onboarding, two complete
client windows, renderer cleanup and 20–30 minute soak remain subsequent work.
