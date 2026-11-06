# Offline welcome home: implemented features and limits

The bundled `default_wold` is one continuous floating home island. Startup enters
it without waiting for a relay. Spawn is in the middle; exploring never requires
finishing Help, connecting or enabling a microphone.

## Things to do

- Walk between the house, left deck, picnic space, grove and pond; no required order.
- Open Settings → Controls for optional Help/current bindings. Help and reachable
  highlights can be hidden for the session without disabling interactions.
- Use the existing saved pickup action (default E on desktop, grip in VR) for
  reachable kitchenware. Held objects use collision checks; drop has no throw impulse.
- Adjust lounge/bedroom/kitchen lighting separately through Controls: on/off,
  brightness and warm/neutral palettes. Home reload restores defaults.
- Use the kitchen faucet, hob, storage/fridge and reset controls. Eight individually
  bundled premade belongings replace the earlier primitive placeholders. Heat is
  visual only; there is no fire, damage, recipe objective or food simulation.
- Near the dock, request boarding and explicitly confirm. Movement drives the
  local boat. Stop, exit at dock or return via Controls. Menu/focus loss stops it
  and requires neutral controls before resuming. Returning home clears the rider.
- View local licenses and authors in Settings → Credits without internet.

The house now uses a textured CC0 bungalow exterior adapted around the original
accessible layout, with realistic Poly Haven lounge/daybed/table assets. Source
credits and modification notices are bundled. This replaces the first bright
low-poly lounge/box-wall presentation; the island remains our own composition.

Home objects/lights/appliances/boat are **local-only**, including inside an online
instance using the same content. They do not claim synchronized ownership. Existing
online instance admission and downloaded-world script restrictions remain unchanged.
Lost registered items return to their own homes; players recover from water to a
clear bank or center fallback. Controls provides explicit nearby bed/sofa rest and
leave actions. Rest pauses synthetic walking without rotating the tracked headset;
leave restores movement at a clear exit or center fallback. There is no automatic
sleep, forced lying-down view or time skip. Real-headset rest comfort remains unverified.

## Verification and release limitations

Run `python3 tests/welcome_island/run_acceptance.py` for the local matrix. Optional
`--template /path/to/matching/linux_debug.x86_64` checks a standalone Linux debug
export; without it, the exported resource pack is hosted by the installed editor.
Run `python3 tools/assets/build_home_revision.py` and `--check` before export.
Detailed fixture/hardware scope is in [test notes](../../tests/welcome_island/README.md).

The landscape is an **initial composition**, not finished environment art: sparse
saplings, geometric terrain edge/underside, simple house/appliance-door shapes and
limited blending remain. Optimized tree/rock variants have LODs/visibility limits,
but this does not establish whole-map XR frame budgets. There is no cleared ambient
audio yet; none is downloaded or played automatically.

Desktop Compatibility and an initial Forward Plus render have been exercised;
real-headset two-eye water/reflections, seated reach, controller UI, motion comfort,
WAN/multi-client visual checks and named-device GPU/VRAM budgets remain open.
Do not interpret green isolated assertions or screenshots as complete release
certification. The [roadmap index](../roadmaps/welcome-island/README.md) records
partial delivery and required manual gates.
