# Cold built-in script diagnostics

Run `python3 tests/welcome_island/check_scripts.py` to parse all shipped island
scripts in a disposable project without normal startup, account access, OpenXR,
editor plugins or cached imports. Dependency scripts are checked before layout,
so their own errors are visible instead of only a parent preload error.

The reported `layout.gd:22` landscape-resolution failure was reproduced during
concurrent island edits; the later snapshot passed both direct cold parsing and
`python3 tests/welcome_island/run_layout.py --landscape`. No stable production
parser defect was established, so no speculative fallback/dynamic-load replacement
was added. A failed/missing script must remain an error, not a silently bare map.

This checks parsing only, not asset availability or successful streaming callbacks.
Use the layout/landscape runner for those integration checks. Godot is selected
with `GODOT`; each parse has a timeout. Source project and generated caches are not
modified. Exit 1 reports parser failures; exit 2 reports missing executable/timeout.
