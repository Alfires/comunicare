# Public avatar and animation discovery roadmap

## Status and scope

**Planned — 2026-11-05.** Add an **Avatar Browser** tile to the Home menu,
listing avatars and animations from documented public provider APIs. This is a
discovery/import interface, not another animation playback or synchronization
system. No API integration or browser UI is delivered by this document.

Required experience:

- Persistent **left sidebar** with **Home** and **Search**.
- **Home:** search bar at the top, followed by multiple category sections with
  asset cards. Submitting that search switches to Search and runs the query.
- **Search:** searches avatars and animations together or separately, with filters,
  sorting and pagination. Category selection also opens a filtered Search view.
- Details show preview, author, source, format, license, compatibility and actions.
- Intentional import integrates with existing User → Avatar configuration;
  browsing, previewing or downloading must not silently equip an avatar.

## 1. Navigation and layout

Replace the unused `Empty4` Home grid cell in
`scenes/GUI/home_menue.tscn` with **Avatar Browser**. Preserve the existing 2×2
layout, World Explorer, Active Instance, Emotes, profile and microphone controls.
Extend `scripts/GUI/home_menue.gd::open_home_menu()` with a lazy browser route
and correct return-focus mapping. Do not start discovery requests at game startup.

```text
Home menu → Avatar Browser
┌──────────────┬──────────────────────────────────────────────┐
│ Home         │ [Search avatars and animations…       ] [Go]│
│ Search       │ Humanoid avatars              [See all]      │
│              │ [card] [card] [card]                         │
│              │ Robots / stylized / low-poly  [See all]      │
│              │ [card] [card] [card]                         │
│              │ Animations and emotes         [See all]      │
└──────────────┴──────────────────────────────────────────────┘
```

Home categories are explicit curated/provider-backed queries, not invented
popularity or personalized recommendations. Suggested initial sections: humanoid
avatars, robots, stylized/low-poly avatars, locomotion animations and emotes.
Show only categories supported by enabled providers, with clear empty states.

Search owns query, selected filters, sort and per-provider cursors. Home search
submission selects Search, transfers the exact query, resets old pagination and
runs one request generation. Merely focusing the bar must not navigate. Category
clicks clear incompatible prior filters and install the selected category; make
these changes visible. Preserve query/scroll when returning from Details, and
keep separate Home/Search navigation state while the browser is open.

Use responsive scrolling content, a left sidebar that stays usable at small
desktop sizes, keyboard submit/focus navigation, adequate VR pointer hit targets
and the existing VR text keyboard. Back from Details restores the originating
card; Back from the browser returns focus to the Home tile. Search typing must
not trigger movement, sprint, microphone shortcuts or emote selection.

## 2. Provider feasibility and first integration gate

Research checked on 2026-11-05:

| Candidate | Documented capability / limitation | Proposed treatment |
| --- | --- | --- |
| [Sketchfab Data API](https://sketchfab.com/developers/data-api/v3) | Some metadata/search endpoints are public; downloads have separate authorization and format constraints | Candidate metadata/search adapter; verify current terms, pagination, limits and required attribution before enabling |
| [Sketchfab Download API](https://sketchfab.com/developers/download-api) / [guidelines](https://sketchfab.com/developers/download-api/guidelines) | Downloads require end-user Sketchfab authentication unless a separate arrangement is approved | Optional authenticated import only after compliant desktop OAuth feasibility; otherwise show Open source page, not a fake Download button |
| [VRoid Hub API](https://developer.vroid.com/en/api/) / [model loading](https://developer.vroid.com/en/api/load-character.html) | Developer registration, OAuth and model download/use licensing; multiplayer use has explicit licensing mechanisms | Deferred adapter pending approved native-client/auth flow and a compatible multiplayer-use policy; not anonymous public downloading |

Before implementation, record each provider's current API terms, app registration,
rate limits, desktop/VR authentication options, content ratings, licensing,
download formats and actual humanoid/animation coverage. Select at least one
usable documented provider and demonstrate real avatar **and animation** queries.
If no provider supplies compatible standalone animations, report that blocker;
do not present a static web download pack as a public animation search API.

No scraping protected sites, unofficial VRChat avatar indexes, private endpoints,
embedded developer secrets or bypassing login/download restrictions. A public
API need not be anonymous. Never publish an OAuth client secret in the game;
use an officially supported public-client flow, or defer that integration. Do not
add an authentication backend to the relay implicitly. Provider onboarding is a
release prerequisite, not something mocked tests can certify.

## 3. Client-side discovery architecture

Suggested modules under `scripts/discovery/avatars/`:

- **Provider adapters:** explicit IDs/capabilities and `categories`, `search`,
  `details`, optional authorized `resolve_download`; normalize provider responses.
- **Discovery service:** bounded concurrency, request generations/cancellation,
  query/filter routing, partial success, pagination and deduplication.
- **Catalog record:** provider ID + stable provider asset ID, type, title, author,
  source-page URL, thumbnail, formats, license/use metadata, ratings and timestamps.
- **Browser UI:** renders records/state; does not own download credentials,
  avatar configuration persistence or animation playback.

Deduplicate pages by provider+asset ID; identical names/URLs across providers are
not proof of identical content. Track download revisions by existing content hash
only after validated acquisition. Keep signed download URLs/tokens ephemeral;
persist canonical provider IDs and provenance rather than expiring private URLs.

On Search submit/filter change, increment generation and discard stale results,
thumbnail callbacks and cursor completions. Cancel/debounce text requests if live
search is enabled (explicit submit is sufficient initially). Bound page size,
JSON bytes/depth, metadata lengths, thumbnail dimensions/bytes and cache lifetime.
Do not download models for a scrolling card list. Retry/backoff per provider,
honor Retry-After and distinguish offline, empty, rate-limited and auth-required
states. One unavailable provider must not erase successful results from another.

Use explicit Load more and provider-specific cursors initially. Do not invent a
globally exact relevance/popularity order across incompatible ranking systems:
explain merged ordering, or group by provider. Keep old results labeled stale on
network failure. Search history is not persisted by default.

## 4. Search filters and cards

Initial filters:

- Type: **All / Avatars / Animations**.
- Provider and category/tags.
- Format: VRM, compatible GLB, VRMA, other (browse-only).
- Compatibility: verified compatible / unknown / incompatible; metadata-only
  candidates must never be labeled verified before importer validation.
- Usage/license: CC0, attribution-required, other/unknown; separately show
  downloadable and multiplayer-redistribution eligibility.
- Animation-specific: standalone/embedded, locomotion/emote, loop if known.
- Sort: provider-supported relevance/newest/popularity, with unsupported options
  disabled or explicitly marked local-to-fetched-results.

Unsupported filters cannot silently broaden a query; apply bounded client-side
filtering with an honest fetched-results scope or disable them for that provider.
Default to provider-supported safe content; do not fetch disallowed thumbnails
first and only hide them afterward. Treat unknown ratings conservatively.

Cards show thumbnail/fallback, title, author, **Avatar/Animation** badge, provider
and compatibility/download status. Details show author/source links, license and
attribution, provider use restrictions, known size/format, validation results and
clear failure reasons. Render remote text as plain bounded text, not executable
markup, scripts or embedded provider web pages.

## 5. Preview, import and equip boundaries

Current constraints: `DataLoader`, `asset_cache.gd` and `avatar_configuration.gd`
accept bounded self-contained binary glTF/VRM avatars with humanoid mapping.
Animation import is a rotation-only humanoid GLB/VRMA subset with a 16 MiB budget;
avatar budget is 64 MiB. Generic animated GLB, FBX, BVH, Unity packages and ZIP
archives are not automatically compatible. Embedded unsupported animation may
also reject a model under current validation; surface this honestly.

Actions:

1. **Open source page** for every valid provider record.
2. **Preview** only after explicit external-request consent and permitted model
   acquisition; use an isolated detached preview. It cannot change equipped state
   or transmit an instance animation/model descriptor.
3. **Add to Avatar configuration** imports a validated avatar or animation into a
   draft using the existing cache/service, preserving license provenance.
4. Review in User → Avatar and **Apply** explicitly through its ownership checks;
   Cancel retains the current equipped avatar and configuration.

Public/downloadable is not redistribution permission. Current multiplayer custom
models require explicit sharing permission and distribute cached bytes to peers.
Some provider licenses cannot support that design. For restricted/unknown rights,
disable equip/share and explain why, even if personal preview is permitted.
Do not forge `share_allowed=true` from a search result or checkbox alone; retain
license evidence and required attribution, and check compatibility with existing
sharing semantics. No-store/expiring-use content must not enter persistent applied
configuration contrary to its policy. Provider-specific multiplayer licensing
requires a separate compliant design before enabling equip from that provider.

The existing asset fetcher rejects redirects. Authorized provider/CDN downloads
may require them: implement a bounded redirect flow with per-hop HTTPS checks,
credential stripping across origins and URL/destination policy tests, or resolve
a direct URL through the adapter. Do not globally allow arbitrary redirects or
send provider tokens to thumbnails/CDNs. No domain approval list for user avatar
URLs is introduced by this browser; API adapters still have explicit endpoints.

## 6. Privacy, persistence and lifecycle

Discovery runs on the client, never through relay-owned durable catalogs or
search history. Providers learn the client's network address and search terms;
explain this before enabling a source. Opening the Home menu alone does not
contact third parties; opening the browser contacts only enabled providers.

Never send account keys, contact lists, fingerprints or current-session roster
to provider APIs. External account tokens use an OS credential store where
available; absent secure supported storage, use memory-only login. Tokens and
signed URLs must not enter logs, general settings, profiles, cache source keys,
Git, relay state or ordinary metadata exports. Logout cancels credentialed work
and clears token state; an account switch discards pending account-owned imports.

Use a separate bounded metadata/thumbnail cache, honoring cache policy and
provider terms. Do not store search listings as immutable model originals.
Existing asset quota/pinning/corruption recovery still governs imported bytes.
Closing the browser cancels UI work and frees previews; no busy loops, background
catalog crawling or automatic equipping. Imported explicit user-owned selections
may remain according to existing cache and license rules.

## 7. Test-first delivery and release gates

Implement small independently verified slices, each with failing tests first,
then a passing Conventional Commit pushed to the configured upstream:

1. **Provider feasibility + schema/adapters:** recorded public fixtures, pagination,
   filter capabilities, malformed responses, rate/auth failures and normalization.
2. **Discovery service:** generations, cancellation, mixed-provider partial failure,
   deduplication, cursor bounds and metadata/thumbnail cache expiry.
3. **Home tile/browser:** actual Home/Search/sidebar layout; Home search switches
   to Search with exact query; categories install visible filters; Back restores
   focus/results/scroll; no HTTP before opening the browser.
4. **Details/preview/import draft:** licensing/format gates, authorization expiry,
   unsupported assets, cancellation, no-store behavior and no automatic Apply.
5. **Optional authentication/download adapters:** only after provider approval and
   supported native auth; verify credential isolation, redirects and logout.

Add a disposable `tests/avatar_discovery/run.py` with synthetic HTTP providers
and sanitized recorded responses; keep credentials and external networking out
of automated fixtures. Extend existing microphone/settings, profile, asset-cache,
animation-sync and real-UI runners as relevant. Independent tests must establish
that browsing/importing does not change avatars, emote playback, instance
membership or local per-player avatar visibility until the appropriate Apply.

Manual gates: current real API behavior/terms, desktop OAuth where applicable,
keyboard/small-window and real-headset sidebar/search/scroll usability, thumbnail
performance, permitted real model import and compliant multiplayer sharing. Do
not report live integrations complete based solely on fake-server tests.

Document enabled providers and limitations in current user guides, source/import
contracts in the function reference, new settings/storage schemas and provenance
handling. Update this roadmap/index with actual delivered slices, test results,
skips and remaining gates. No runtime implementation or completed verification
is claimed by this planning document.
