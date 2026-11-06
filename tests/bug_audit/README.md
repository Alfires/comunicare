# Thirty regression reproductions — 2026-11-06

Run `python3 tests/bug_audit/run.py` (`GODOT` overrides the executable).
The runner copies production helpers to a disposable Compatibility project under
`/tmp/opencode`. No real accounts, network, startup, keyring or model files are used.
Exit 1 means assertions failed; exit 2 means prerequisites/Godot errors. The initial
baseline reproduced all 30 failures, including native singular-transform errors;
the fixed suite passes 30/30 without Godot errors.

## Numbered issues (matches suite IDs)

1. Custom source inventory had no bound, allowing growing preferences/request work.
2. Unknown built-in adapter identifiers were accepted and produced empty catalogs.
3. Whitespace-only source identifiers were accepted.
4. Authentication tokens allowed control characters other than CR/LF.
5. Long OAuth client IDs were silently truncated into another client identity.
6. Malformed DNS labels were accepted before HTTPRequest.
7. Signed/non-digit URL port syntax was accepted.
8. Numeric credentials were coerced into bearer strings.
9. Explicit default HTTPS port was treated as a different origin, breaking valid auth.
10. OAuth loopback callback without a path was accepted.
11. Configured OAuth URLs could duplicate reserved state/challenge/client parameters.
12. Whitespace-only authorization codes were accepted after form decoding.
13. Nonfinite initial dial values poisoned draw/state calculations.
14. Relative float epsilon suppressed legitimate dial steps at large baselines.
15. Negative tracker timestamps entered runtime sample state.
16. Singular tracker bases appeared as available valid tracking devices.
17. Tracker device churn accumulated unbounded historical samples.
18. Singular calibration samples reached matrix inversion and emitted native errors.
19. Unsupported tracker roles could be captured into calibration output.
20. Singular calibrated targets could reach downstream solvers.
21. Blank emote shortcut titles created invisible wheel actions.
22. Persisted duplicate shortcuts bypassed add/move duplicate validation.
23. Unsupported glTF minimum-version requirements were ignored.
24. An empty first JSON chunk allowed a second JSON chunk in a GLB.
25. Undeclared BIN chunks were accepted.
26. Embedded image entries without a valid bufferView were accepted.
27. Invalid declared humanoid nodes silently vanished, leaving partial mappings.
28. Overflowing quaternion magnitude could produce invalid normalization results.
29. Missing bufferView buffer references silently defaulted to zero.
30. Nonunit rotation values were silently normalized rather than rejected.

## Bounds and compatibility

Source count is capped at 64; tracker inventory at 256, evicting the oldest
unassigned sample first. Credentials remain origin-scoped; default port
normalization does not merge different nondefault ports. Unicode domain names must
use their ASCII/punycode representation. Supported CC0/animation/model formats and
explicit sharing policy are unchanged. Quaternion length-squared tolerance is 0.02
to permit exporter rounding, not arbitrary scaling. Legal BIN alignment padding
remains supported by the earlier regression suite.

Existing discovery, animation, tracking, loading and VR suites must also run.
Synthetic validation does not certify real OAuth providers, every model exporter,
renderer or headset. Optional real-avatar verification requires an existing
permitted `AVATAR_FIXTURE`; the previous temporary sample was absent during this
audit and that optional run could not start.
