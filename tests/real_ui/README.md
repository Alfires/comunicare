# Production UI acceptance — initial roadmap execution

## Avatar preview and Apply integration

Failure-path regressions cover one-click digest rejection (busy state released,
equipped model preserved), results whose provider has been removed, and invalid
animation-source Apply errors. Removed-provider preview/import must return an
actionable error before indexing the registry.

Avatar details now provide a single **Apply avatar** action. The modal reports
download progress over 0–70% when Content-Length is available (otherwise byte
count), then validation at 75%, commit at 90%, and completion at 100%. These are
overall workflow stages, not a precise importer percentage. Failure keeps the
current model and shows the error with a dismiss button. Animation imports still
open the source editor. Integration tests assert one-click Apply completes without
opening the editor in headless and rendered modes.

Browser usability regressions assert collapsed advanced filters, typed search,
digest mismatch rejection during preview, visible review/Apply controls and a
missing-cache error that preserves the current model. The browser has a direct
My avatar entry; review/import controls distinguish supported preview from licensed
equipping. File/URL import is an expandable advanced editor section.

```sh
AVATAR_FIXTURE=/path/to/permitted/avatar.vrm python3 tests/real_ui/run.py --plugins --suite avatar
AVATAR_FIXTURE=/path/to/permitted/avatar.vrm python3 tests/real_ui/run.py --plugins --rendered --suite avatar
```

Explicit fixture only; the runner serves it on loopback and never downloads an
external model implicitly. Production browser download/preview/import, editor Apply,
cache-backed model reload and temporary-identity memory-only Apply are exercised.
Preview must accept only the exact bundled first-person BlendShapeSync helper,
disable its processing, and continue rejecting arbitrary script-bearing content.
Search reads the typed field even without Enter. Temporary accounts do not create
durable avatar configuration/wheel files; validated asset bytes use the shared cache.

## Expanded movement and world-switch checks

The VR emulator additionally invokes the production frame and physics methods on
a synthetic collision floor: tracked-rig walking, braking and transition blocking.
Head tracking uses the XRServer head tracker's default pose; XRCamera3D does not
provide XRController3D's `get_is_active`. Rendered automation explicitly supplies
emulated application focus while driving locomotion. This is not OpenXR validation.

The two-client runner now alternates four times between two loopback HTTP packages
with distinct world IDs/content revisions, creating a new instance each time. Both
clients verify acknowledged activation, loaded scene, stable authenticated transport,
cleared transition busy state and convergence on exactly two members. The packages
share courtyard geometry; this does not test every world's collision layout.
The initial Create/Join is pointer-driven; subsequent hops call production coordinator
methods. Shutdown clears the client transport state before disconnecting ENet so
periodic friend ticks cannot send after teardown.

Desktop movement is covered separately by `tests/vr_controls` production-physics
checks. An attempted two-window body-input extension was not retained: headless
mouse capture is unavailable and simultaneous rendered players contend for X11's
mouse grab. Do not claim a continuous PC/VR mixed-client gameplay journey from
these separate passing groups.

## Duplicate-window identity fallback

The UI relay host now deliberately uses the same saved key as the production client.
The coordinator must handle the relay's explicit duplicate-account response with
one temporary memory-only identity, while the first account stays admitted. Tests
verify distinct fingerprints, unchanged original key bytes, fresh memory-only
profile/contacts, absence of durable temporary account stores and no repeated key
rotation. Low-level RelayPeer still rejects duplicate accounts; only the application
coordinator applies this narrowly scoped second-window behavior.

## VR emulator gate

```sh
python3 tests/real_ui/run.py --plugins --suite vr
python3 tests/real_ui/run.py --plugins --rendered --suite vr
```

The new engine-level emulator registers head/left_hand/right_hand XR trackers,
instantiates the **actual production VR player scene**, and drives controller
poses, joystick, analog grip and button edges. Sixteen assertions pass headlessly
and/or rendered as recorded in logs: actual tracked-hand motion, locomotion input,
production 3D shared menu/Network settings, controller-ray geometry/pixel mapping,
real SubViewport button hit testing, menu suppression, face-button edges, focus
loss and grip/release latches. Normal player processing/physics is disabled while
these specific production input paths are called deterministically; this is not
a complete continuously running locomotion/physics or networked VR-play journey.

No Monado service/OpenXR runtime manifest is configured on this host. `hello_xr`
alone is not a runtime. The runner therefore uses Godot XR tracker emulation with
OpenXR disabled; no system-wide runtime/package installation is performed. Do not
report an OpenXR compositor, action-profile, stereo rendering, headset comfort or
physical controller pass from this test. Hardware/runtime validation stays open.

The original-world rendered teardown gate still reproduces leaked VR-panel render
targets. Additional material/viewport cleanup did not remove that failure and was
not retained as a speculative fix. It remains a blocker, not an emulator limitation
to be silently ignored.

## Expanded fault and layout coverage

The current UI suite passes **39 assertions** in headless and rendered X11 modes:
same-origin rejoin and instance switching reuse the authenticated transport; menu
close/recreate while joining remains recoverable; injected route loss clears busy/
membership, origin liveness removes the old account and a fresh join works. Real
form certificate import/invalid submission, E/V/B text-input safety, preference
reload and preflight content-hash failure are covered. Viewport-local pointer
injection passes 640×480/1000×700 at 1× and 1440×900 at 1.5× scale. This is Godot
hit testing, not OS-level keyboard/mouse automation. Certificate submission is
signal-driven; native file-picker/confirmation pointer coverage remains open.

`--original-world` removes the trusted shell fixture. It reproduced original-world
VR-panel render-target leaks on shutdown despite its 38 then-current assertions
passing; this mode **fails infrastructure validation** and remains an explicit
release blocker. Do not hide it or treat passing example-world rendering as proof
that built-in-world teardown is clean.

`--two-clients --rendered --soak-seconds 1200` now supports a real two-process,
two-window sustained carrying soak. The 1,200-second rendered run completed:
host 10/guest 11 assertions passed, approximately 2,491/2,490 motion samples,
membership/lease preserved, remote movement observed, physics restored on drop,
and both processes exited 0. Local evidence: `/tmp/opencode/ui-two-window-20-minute.log`.
This closes the example-world carry soak gate, not original-world teardown or
native certificate-dialog pointer acceptance.

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
