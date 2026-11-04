# Real UI multiplayer investigation and acceptance roadmap

**Status: investigated and planned, 2026-11-04. No production fixes in this change.**
The user's report that the system does not work is not disproved by service-test
passes. This roadmap establishes a user-visible acceptance gate for the existing
desktop UI, startup, relay settings, LAN discovery, world browser and federation.
It supersedes claims that repeated isolated runner passes demonstrate a working
end-user experience. Existing suites remain useful regression evidence, not a
replacement for this gate.

## 1. Investigation performed

Used the Godot console and scene skills, inspected production scripts/scenes and
ran **Godot 4.7.2** against a disposable copy of tracked project files. Production
`DataLoader`, `SaveData`, `NetworkHandler`, main menu, settings and World Explorer
were used, not fixture autoloads. Godot imports, account generation, settings and
profile writes occurred only under temporary XDG directories in `/tmp/opencode`.
No real account store was opened; no network configuration was changed.

Experiments included:

1. Normal production startup with no reachable relay, recording scene/player/menu
   availability at 1, 5, 16 and 20 seconds.
2. A real **X11/OpenGL Compatibility window**, loading the full production menu,
   selecting Network and saving a rendered screenshot. This is actual rendering,
   not a headless screenshot claim. Forward Plus/OpenXR was not validated.
3. Production World Explorer + real TLS service + real local ENet origin and host
   account. Invoked the actual rendered Join button's `pressed` signal; recorded
   actual coordinator/transport membership and relay members afterward.
4. After a successful federated join, configured the actual relay-preferences panel
   and invoked its Add relay button with an unrelated fallback endpoint.
5. Modified the actual Network UDP SpinBox and compared the settings value with
   the persistent ordered relay store.
6. Attempted viewport mouse/key event injection. The first pointer attempt did not
   select Network (it remained Assets), so this is **not** a successful physical
   click automation test. This failure itself requires coordinate/focus diagnostics.
   It cannot be hidden by replacing pointer events with `pressed.emit()`.

Temporary evidence from this run:

```text
/tmp/opencode/real-ui-investigation-81fzh0ga/
  startup-ui.log
  visible.log
  remote-join-ui.log
  remote-join-policy-ui.log
  pointer-ui.log
  data/godot/app_userdata/comunicare/network-settings.png
  data/godot/app_userdata/comunicare/network-pointer-test.png
```

Artifacts are local/temporary, not committed fixtures or permanent CI evidence.
The directory also contains **disposable private account keys**: do not upload it
wholesale. Sanitize diagnostic excerpts/screenshots before sharing. A repeatable
checked-in UI runner is a deliverable below, not something these scratch probes
already provide. Changes to probes corrected a SceneTree `_process` return-type
parse error before measurements; that was a probe defect, not an application defect.

## 2. Findings with confidence and evidence

### F1 — Adding an unrelated relay disconnects active federated play (P0, reproduced)

The real Join button path successfully authenticated a second user and joined the
same origin session. Both transport and coordinator agreed; relay membership was
two and World Explorer displayed `Joined instance`. It remained joined six seconds
later. Then the actual Add relay button added a different localhost endpoint:

```text
before: coordinator_session=<live code>, relay_members=2, busy=false
after Add: current_session="", connected=false, tunnel_exists=false
panel_status="Relay preferences saved. Reload World Explorer when offline to connect."
```

Cause: `relay_preferences.gd` emits the same `changed` signal for add/reorder/remove/
block. `NetworkHandler._relay_policy_changed()` closes any active gameplay tunnel
whenever `directory_browser` exists, before checking whether active policy changed.
The panel's own explanation promises that list changes apply on the next connection.
The implementation violates that promise. Reorder and unrelated remove use the same
handler; these are code-path predictions until separately reproduced.

Fix contract: distinguish preference/order changes from identity/endpoint block and
trust-revocation changes. Add/reorder/unrelated remove must preserve membership,
voice and leases. Relevant blocks/revocation must stop the affected route immediately.
Do not "fix" this by making blocks delayed or reconnecting with old authorization.

### F2 — Startup has no usable player/menu during failed initial relay attempt (P1, reproduced)

Production startup probes reported:

| Elapsed | Current scene | Player count | Connection attempt |
| --- | --- | --- | --- |
| 1 s | startup | 0 | pending |
| 5 s | startup | 0 | pending |
| 16 s | world (`wold` node) | 1 | failed, endpoint error available |
| 20 s | same world | 1 | offline |

`scripts/startup/main.gd::_ready` awaits `create_peer()` before loading the initial
world/player. The timeout and each fallback can prolong a startup screen with no
usable settings/retry UI. The app eventually entered offline play in this run;
this is not evidence of an infinite hang or the user's exact machine's cause.

Fix contract: present a responsive local shell immediately, with bounded visible
connection progress/cancel/retry. Do not start duplicate players or join sessions
twice when authentication finishes after the shell appears.

### F3 — Visible UDP-port control is disconnected from effective preference after migration (P1, reproduced)

The real SpinBox saved `network.relay_port=17888`, while the effective main relay
entry remained port `7374`. The address field is labelled migration-only, but the
UDP port still looks operational. Runtime now chooses the ordered store, not those
scalar fields. This makes a plausible user repair attempt have no effect.

Fix contract: hide/read-only both legacy migration fields after migration, or
provide a clearly scoped editor of the selected row with transport/port labels.
Show effective current ingress and saved next-connect target, separately. Do not
silently synchronize unrelated stores in a way that overwrites user order.

### F4 — LAN discovery is a hint/trust workflow, not automatic usable local worlds (P1, inspected)

`lan_relay_transport` ingests advertisements into candidate state.
`get_remote_instances()` returns only the certificate-trusted directory client's
instances, not LAN candidates. The settings panel offers a raw certificate-path/ID
import. Thus an unknown local relay can be detected without any worlds appearing.
The empty internet presets intentionally contribute no trusted relay either.

This is a real product gap, not justification to disable TLS verification. Provide
an explicit local onboarding flow: discovered relay → inspect identity → approve
trust through a defined security model → query verified public instances. Explain
"detected, not trusted", "trusted, unreachable", "no public instances", and
"blocked" as distinct states. Any certificate transfer/fingerprint confirmation
design must be reviewed; do not auto-trust a certificate sent by an attacker.

### F5 — Real visible Network page is lengthy and mixes incompatible operations (P1, rendered)

The screenshot shows legacy address/UDP controls, a LAN toggle, saved-relay actions,
hostname/port inputs, Add relay, identity/certificate paths and directory trust in
one scrollable form. TLS import and legacy UDP share the same port input; the
distinction is explanatory prose. There is no selected-row endpoint editor.
Full fingerprint labels and horizontal action rows need small-window/DPI checks.

The rendered screenshot confirms the form exists, not that every control is usable
with mouse/keyboard at every resolution. The initial pointer-injection attempt
missed its target. Coordinate conversion, hover/focus ownership, clipping and
scroll visibility must be instrumented before drawing input conclusions.

### F6 — Remote Join works in one controlled UI/coordinator scenario (positive, limited)

Production browser + coordinator + autoloads + actual TLS/ENet origin successfully
joined built-in `default_wold` by activating the real Join button signal. This
narrows the investigation: remote Join is not universally broken. It does **not**
establish real pointer clicking, external world HTTP staging, two complete client
windows, safe rollback, or reliable error handling during connection races.

### F7 — Offline Reload timer/null-peer race (P0 candidate, inspected; needs reproduction)

`world_explorer.gd::_on_reload_pressed` sets `refreshing=true` before awaiting a
connection. `_process` has a 10-second discovery timeout that dereferences
`discovery_peer.directory_supported`; relay connection/auth can take 15 seconds
per candidate. With no current peer or a replaced peer, directory timing and
connection timing can overlap. Existing tests inject expiry with a connected peer.
Reproduce with the real full UI and slow/absent relay; don't label this confirmed
until the runtime branch is exercised.

### F8 — Same-origin reauthentication and policy/endpoint races (P0 candidates, inspected)

Remote Join closes old transport immediately before authenticating a new account
connection to the origin. The origin refuses duplicate live account connections
and may not yet have processed old disconnect. Lower-level tests use separate
accounts or no previous membership. Test same origin, another origin, same instance,
policy edit while staging/authenticating and rapid repeated clicks. Record old/new
generation, not just the final label. No silent ban bypass or stale admission.

### F9 — Runtime warnings and scope of previous evidence (P2, observed)

Full startup/join scratch runs reported renderer RID/ObjectDB shutdown leaks and
a Jolt solver-bias warning. These differ from cleanly passing narrow headless
services; isolate graceful test teardown vs application-owned leaks before fixes.
Earlier federation runs also showed Unicode/NUL diagnostics; retain as a tracked
investigation item. The visible X11 run used Intel/Mesa after NVIDIA-driver probe
messages; it succeeded. Do not call that Forward Plus/GPU portability verification.

## 3. Why previous green tests missed user-facing failures

- `tests/public_discovery/startup_suite.gd` uses the real coordinator, but fixture
  SaveData/DataLoader and a replacement browser script; it does not execute normal
  account startup, the whole menu or pointer routing.
- Federation transport tests directly configure certificates/services, connect
  RelayPeers and send intents. They bypass settings trust import, saved preference
  migration, `join_remote_instance` and visible status transitions.
- The preferences panel tests emit button signals and inspect pure store state;
  they do not keep real federated membership alive during an unrelated edit.
- Example worlds use real scene/physics copies, but automated hand poses; this is
  not proof of the full client input/UI path or hardware behavior.
- Repeated short tests establish repeatability only for those paths. They are not
  a long-running GUI soak, a release build check or a proof of user usability.

## 4. Required real-UI test harness

Create an opt-in `tests/real_ui/run.py` with evidence levels, no existing green
runner weakened or replaced. No permanent production test shortcuts.

### Isolation, topology and artifacts

- Copy tracked project content into a disposable directory; use production
  autoload initialization order and scenes. Separate XDG/user roots and ephemeral
  keys for each client/relay. Never use real user credentials or overwrite settings.
- Use two actual Godot client processes/windows and two or three relay processes;
  a loopback HTTP server serves the checked-in example `.cworld` and a controlled
  catalog. Prefer configurable URLs over replacing production UI scripts; document
  any test-only dependency substitution precisely.
- Create/certify throwaway infrastructure with the local provisioning tool. All
  networking stays on loopback except explicitly permitted LAN multicast tests.
  Empty shipped internet presets remain empty. No global discovery/scanning.
- Start the real startup scene, not just instantiate Settings in a handcrafted tree.
  Provide healthy-relay, no-relay and delayed-relay launches with hard watchdogs.
- Evidence: sanitized JSON timeline, logs, screenshots before/after each action,
  control path/rectangle/focus, window/logical viewport scaling, request ID, active
  ingress/origin, instance/revision and relay-observed membership. Redact account
  keys, private paths/cert secrets and payloads. Keep failure artifacts, not just totals.
- Stop processes gracefully, verify no live ports/processes remain, and separate
  shutdown artifacts from test assertion failures. Missing display is an explicit
  skipped rendered group, not a rendered pass.

### Input hierarchy: do not conflate levels

| Level | Mechanism | What it proves |
| --- | --- | --- |
| Service | Direct helper calls | Data/policy logic only |
| UI wiring | Button `pressed.emit()` / signals | Production callback/service binding, not hit testing |
| Scene input | `Viewport.push_input`/Input events at measured coordinates | Godot hit testing, focus, modal interception and routing |
| Rendered window | Actual display, screenshots and matching input coordinates | Layout, clipping, scaling and scene-input behavior on a renderer |
| OS automation/manual | Window-targeted pointer/keyboard through available desktop tooling | OS focus/window integration; record backend/tool and permission limits |

No xdotool/Xvfb was available in this investigation. An actual X11 window did run;
do not install extra system packages or take over the user's desktop implicitly.
Use a dedicated test window, do not move/click arbitrary user applications. For
the first missed pointer probe, reconcile root viewport coordinates with stretch,
physical window dimensions and Control transforms before accepting injected actions.

## 5. Acceptance journeys and exact checks

| Journey | Action through real UI | Required result |
| --- | --- | --- |
| Fresh offline launch | Start app with no server | Responsive shell/settings promptly; visible connection state; no 15-second invisible configuration lockout. |
| Legacy migration | Open Network with old scalar endpoint | One main row, effective endpoint explicit; legacy edits cannot deceptively appear operational. |
| Add/reorder while playing | Join via TLS, Add fallback/Make main/Down/unrelated Remove | Existing membership, held item and voice route preserved; changes affect future selection only. |
| Relevant block | Block active endpoint/origin/transit | Route ends promptly with explicit reason, current session clears; no silent reconnect through blocked route. |
| Remove vs block | Remove row, then rediscover; block/unblock separately | Removal preserves blocks but does not invent a block; unblock doesn't silently restore membership/order. |
| Trusted setup | Import valid/invalid/revoked certificate using controls | Clear validation; no silent key replacement; active trust revocation ends route; failure preserves original files. |
| LAN | Local advertiser appears in Network | Candidate state explains trust; approved directory public worlds appear in Explorer; expired/blocked candidate disappears. |
| Presets | Open with shipped empty list | Clear empty state; no internet probes, no implicit fallback insertion. |
| Reconnect | Absent relay → start relay → Reload | One coalesced attempt, progress and retry; no null-peer timer error, duplicate sessions or stale statuses. |
| Public discovery | Two instances same URL on separate relays | Distinct rows/scoped identities; own instance deduplicated; no hidden/private summaries leaked. |
| Real remote Join | Click a federated instance with main ingress reachable/unreachable | Bounded route selection with alternatives; exact hash staged; acknowledged instance and visible scene agree. |
| Same-origin switch | Join a second instance through same origin/account | No duplicate-account race, no stale old membership; failure states honest. |
| Browser lifetime | Close/reopen menu or switch tabs while awaiting | No callback on freed node; current operation isn't hijacked by stale UI; no duplicate subscriptions/popups. |
| Failure mid-join | Kill middle/origin, cancel or change blocks | No stuck busy state; old/new membership outcome explicit; input stays available and cache doesn't bypass admission. |
| Gameplay | Two real client windows load example via HTTP, pick/move/drop | Other client's rendered cube follows, holders agree, disconnect releases; don't assert mere packet receipt equals rendering. |
| Input safety | Type relay fields with E/V/B/Escape, tab/scroll/click | No unintended grab/mute/menu dismissal; focus and keyboard accessible; dialogs consume clicks exactly once. |
| Relaunch | Quit/save/reopen same isolated client data | Order/blocks/trust correct; no silent reset/reapproval; no dead startup due to stale health/session cache. |

Run pointer journeys at 640×480, 1000×700, wide window and at least two UI scale
factors; verify all controls reachable by scrolling/keyboard. Preserve the existing
VR menu interface but defer physical headset guarantees to a separate explicit gate.

## 6. Implementation order and release gates

1. **P0 repro harness:** check in a faithful full-autoload test for F1; assert failure
   before any production fix. Add offline Reload race and preference-change-during-
   join cases. Name evidence level in every test report.
2. **P0 lifecycle repairs:** selective block/trust invalidation, route generation
   guards, separate connect/directory timers and safe UI teardown. Commit only
   passing fixes with their reproductions; no unrelated multiplayer rewrite.
3. **P1 usable connection shell:** offline-first responsive startup, visible endpoint/
   stage/cancel/retry state and bounded sequential fallback. No auto-ban bypass.
4. **P1 Network UI:** separate Legacy UDP, Trusted TLS and Directory discovery
   sections, editable rows, effective ingress label, certificate picker and explicit
   trust confirmation. Make legacy migration fields nondeceptive.
5. **P1 LAN onboarding/Explorer:** explain trust boundary, query approved local
   directories, handle catalog failure nonmodally and show per-source status. A
   catalog outage must not block otherwise working local instance selection.
6. **Rendered input acceptance:** fix coordinate automation, use actual hit-tested
   controls and screenshots; run real two-window HTTP-world/join/carry flows.
   Signal-only tests remain useful but cannot satisfy this phase.
7. **Soak/failure matrix:** repeated real UI journeys, rapid edits/reconnects and
   20–30-minute two-client idle/carry sessions, deterministic fault injection and
   state/queue growth measurements. Report latency/cleanup bounds and flakes.
8. **Release decision:** all P0/P1 journeys green with artifacts, current limitations
   visible, no unexplained errors/leaks or mocked groups counted as completed.
   Run existing regressions too; don't change their assertions merely to hide errors.

Definition of done: a fresh user can launch, identify/select a working relay,
discover an approved local instance, join and interact through visible controls,
then manage unrelated preferences without being disconnected. Failure states are
recoverable and tell the truth. The user's actual reported failure remains open
until its setup/reproduction matches a passing journey; this investigation does
not establish which of the findings is the cause on their machine.
