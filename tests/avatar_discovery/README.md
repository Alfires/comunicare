# Public avatar discovery — opt-in RED acceptance tests

Run `python3 tests/avatar_discovery/run.py` (override executable with `GODOT`).
These tests target the [roadmap](../../docs/roadmaps/public-avatar-discovery-roadmap.md),
not existing implemented APIs. Missing production modules/scenes fail explicitly;
dependent checks are reported as not run, never counted as passing coverage.
Exit 1 means acceptance failures; exit 2 means missing Godot, timeout or Godot
`ERROR:` infrastructure failure. Do not add this intentionally red suite to green
repository/release checks until implementation satisfies it.

Initial baseline (2026-11-05): **1 passed, 6 failed, 5 dependent groups not run**,
exit 1, no Godot errors. Only preservation of the existing Home entries currently
passes; missing components do not count as exercised provider/auth/UI behavior.

The runner creates a disposable Compatibility project under `/tmp/opencode` and
an ephemeral loopback HTTP server. It does not load real accounts/autoloads,
contact external providers, read secrets, import models or implement the feature
in fixtures. HTTP is allowed only through an explicit test-only loopback override.
All credentials are literal synthetic strings. Provider responses are a proposed
schema-1 catalog, **not recorded evidence of a qualifying real public API**.

## Proposed production interfaces

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

Not yet covered: request-generation races, cancellation/debounce, provider merging,
bounded decode limits, retries/backoff timing, thumbnail decoding/cache lifetime,
redirect wire behavior, source-management rendered controls, credential-store
failure, OAuth PKCE/state/callbacks, logout/account-switch in-flight cancellation,
actual draft/Apply isolation and licensing provenance persistence. These need
additional tests alongside the corresponding implementation slices. No headset,
visual layout, live provider terms/availability or real credential-store/OAuth
integration is certified by this suite.
