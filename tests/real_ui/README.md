# Production UI acceptance — initial roadmap execution

## Verified extended gates (supersedes historical limitations below)

```sh
python3 tests/real_ui/run.py --plugins
python3 tests/real_ui/run.py --plugins --rendered --suite ui
python3 tests/real_ui/run.py --plugins --two-clients --rendered
python3 tests/real_ui/run.py --plugins --suite ui --soak-seconds 1200
```

- Production editor-plugin import now passes on Godot 4.7.2 after explicit Error
  returns were added to four VRM extension callbacks. `--plugins` keeps real editor
  plugins enabled; without it the earlier isolated mode remains available.
- Rendered X11 Network suite completes with zero engine errors. The earlier GL
  leaks came from unnecessarily loading the original VR-panel world into the test
  resource cache before overriding it. That test-only load has been removed.
- `--two-clients` starts a separate real relay process, loopback HTTP example-world
  server and two client processes with independent user data. Each mounts production
  autoloads/menu; Create and Join are hit-tested pointer actions. Actual downloaded
  scene cube transforms/freeze state verify carrying and drop. The guest captures
  `two-clients/remote-held-cube.png` in rendered mode. Results: host 9/guest 10 passed.
- Gameplay hand poses remain automated through the production pickup adapter, not
  a claim of physical mouse/key pickup or headset validation. These clients load
  the actual example world without the built-in world shell replacement.
- A completed 1,200-second actual UI/TLS soak ran 1,199 add/reorder/remove cycles,
  preserving membership and bounded route/session counts. It is a single-client
  UI membership soak with a second transport host, **not a 20-minute two-window
  carry soak**. Long runs are opt-in and have bounded watchdogs.
- Screenshot/frame capture no longer waits indefinitely for a draw signal. Pointer
  clicks allow two layout frames and inject motion before press/release. The first
  rendered two-client attempt missed Join; the corrected automation subsequently
  passed. No failed attempt is counted as a pass.

The two-client harness uses loopback-only avatar URLs so default remote-avatar
downloads cannot keep shutdown threads alive. Its Python coordinator always stops
clients, relay and HTTP server, including failures. Certificates/account keys and
source copies stay in artifacts; never publish those wholesale.

Open roadmap gates remain explicit: same-origin reauthentication and mid-join
fault/UI lifetime matrix, all window/DPI combinations, full trust onboarding via
pointer/dialog confirmation, per-source status UX, graceful original-world renderer
teardown and long two-window carry stress. These successful checks do not imply
all roadmap journeys or hostile-network security are complete.

**Next-phase update:** startup now mounts the production player/menu independently
of relay selection, with cancellation. Legacy scalar fields are hidden, saved rows
can be edited, TLS import has a separate port/file picker and catalog errors are
nonmodal. Headless results: 5 startup and 22 UI assertions pass. Rendered actions
finish but GL texture leak errors still make that runner exit 2; rendering remains
an open gate. The disposable override disables catalog HTTP before UI startup;
avatar acquisition is disabled explicitly to prevent external download threads
from obscuring lifecycle tests. No avatar/asset visual guarantee is claimed.

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
