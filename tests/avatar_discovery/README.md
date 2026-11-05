# Public avatar discovery acceptance tests

Follow-up coverage includes advanced filters, bounded PNG decoding, texture TTL,
catalog TTL revalidation, actual thumbnail-card controls and result restoration,
PKCE S256/state/port/replay/expiry checks, and custom-vs-built-in OAuth policy.
`--display` runs these contracts in a real window (not a headset).
`KEYRING_TEST=1` is an explicit nonisolated synthetic Secret Service round-trip;
the development environment failed its store because no Secret Service is active.
Normal tests never read/write the user's OS keyring. Real login/animation-preview
visual behavior and headset usability remain separate manual gates.

**Implementation update:** core contracts now run against production components,
not guarded missing APIs. Optional `ANIMATION_FIXTURE=/path/to/permitted.vrma`
checks explicit in-place adaptation through the production importer. Live network
checks are **opt-in only**: `LIVE_DISCOVERY=1 python3 tests/avatar_discovery/run.py`.
Normal invocation remains isolated loopback-only with no real account/credentials.
The original RED baseline and interfaces below are retained as history; they are
not the current implementation status. Additional roadmap tests remain outstanding.

Current verification (2026-11-05): **46 passed**, zero failed/skipped in normal
loopback mode. Real VRMA fixture adds one assertion. Explicit live verification
plus real fixture: **52 passed**, zero failed/skipped, checking both anonymous
catalogs/downloads and in-place motion conversion. Live checks are evidence at
that time, not a guarantee of provider availability or complete asset compatibility.

Run `python3 tests/avatar_discovery/run.py` (override executable with `GODOT`).
These tests target the [roadmap](../../docs/roadmaps/public-avatar-discovery-roadmap.md)
and its initial production implementation. Missing production modules/scenes fail explicitly;
dependent checks are reported as not run, never counted as passing coverage.
Exit 1 means acceptance failures; exit 2 means missing Godot, timeout or Godot
`ERROR:` infrastructure failure. The original intentionally red suite is now green
for implemented core contracts, not every roadmap/manual gate.

Initial baseline (2026-11-05): **1 passed, 6 failed, 5 dependent groups not run**,
exit 1, no Godot errors. Only preservation of the existing Home entries currently
passes; missing components do not count as exercised provider/auth/UI behavior.

The runner creates a disposable Compatibility project under `/tmp/opencode` and
an ephemeral loopback HTTP server. It does not load real accounts/autoloads,
contact external providers, read secrets, import models or implement the feature
in fixtures. HTTP is allowed only through an explicit test-only loopback override.
All credentials are literal synthetic strings. Provider responses are a proposed
schema-1 catalog, **not recorded evidence of a qualifying real public API**.

## Production interfaces

Modules under `scripts/discovery/avatars/`:

- `source_registry.gd`: `add_source(dict) -> bool`,
  `set_credentials(id, dict) -> bool`, `get_credentials(id) -> Dictionary`,
  `remove_source(id)`, `export_configuration()`. Anonymous built-ins reject every
  auth mode; custom sources may hold scoped memory-only secrets; exports omit them.
- `request_policy.gd`: `prepare_request(source, target_url, credentials) -> Dictionary`
  with `headers`, or `{}` on rejection. Built-ins ignore foreign credentials;
  custom credentials require exact origin; token-bearing built-in URLs are rejected.
- `discovery_service.gd`: `configure(source, transport_options)`, await
  `search({query, type, cursor}) -> Dictionary`. Fixture responses have `schema`,
  `items`, `next_cursor`; preserve fixture `request_received` diagnostics for
  transport assertions (or replace with an explicit test-observer seam when
  implementing). Failures return nonempty `error`, not thrown Godot errors.
  `/bad`, `/rate-limit` and `/login-required` are base paths in failure scenarios.
- `import_policy.gd`: `evaluate(record) -> {can_import, can_equip, ...}`. Unknown
  importer compatibility and missing redistribution rights cannot grant equip;
  unsupported FBX cannot import through the current GLB/VRM pipeline.
- `scenes/GUI/avatar_browser.tscn`: `submit_home_search(query)`,
  `select_category(id)`, `get_search_state() -> {tab, query, category, cursor}`.
  State access is an acceptance seam, not a substitute for later rendered tests.

Production implementations may refine these contracts with equivalent behavioral
tests; do not remove assertions or replace services with successful test doubles.
Update runner copies when real components gain dependencies; do not enable the
real game's startup or real settings to satisfy them.

## Coverage and remaining gates

Guarded checks cover Home tile preservation, anonymous built-ins, optional custom
login, secret-free source exports, removal, endpoint syntax, credential-origin
isolation, real loopback type filtering/pagination/error handling, import gates,
and Home search/category navigation state. Until components exist, these are
future conditional checks—not executed behavioral coverage.

Not yet covered by automated assertions: request-generation races, cancellation/debounce, provider merging,
bounded decode limits, retries/backoff timing, thumbnail decoding/cache lifetime,
redirect wire behavior, source-management rendered controls, credential-store
failure, OAuth PKCE/state/callbacks, logout/account-switch in-flight cancellation,
actual draft/Apply isolation and licensing provenance persistence. These need
additional tests alongside the corresponding implementation slices. No headset,
visual layout, live provider terms/availability or real credential-store/OAuth
integration is certified by this suite.
