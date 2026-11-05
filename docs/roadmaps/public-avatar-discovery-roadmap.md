# Public avatar and animation discovery roadmap

## Status and scope

**Planned — 2026-11-05.** Add an **Avatar Browser** tile to the Home menu,
listing avatars and animations from documented public provider APIs. This is a
discovery/import interface, not another animation playback or synchronization
system. No API integration or browser UI is delivered by this document.

**Built-in provider requirement: no login or tokens.** Every built-in provider must support
anonymous catalog/search, metadata, thumbnails and asset downloads without user
accounts, OAuth, API keys, bearer tokens, session cookies or token-bearing signed
download links. No developer credential, authentication proxy or login-required
source-page handoff may be used to work around this requirement.

**Explicit exception: user-added custom APIs may require login.** Users can add
their own provider endpoint and optionally authenticate to that provider. This
does not permit shipped/built-in integrations to require credentials. Custom
sources are opt-in, clearly labeled and disabled until explicitly configured;
credentials and account state are isolated per custom provider.

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
│ Home         │ [Search avatars and animations…       ] [Go] │
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
| [Sketchfab Data API](https://sketchfab.com/developers/data-api/v3) | Some metadata/search endpoints are public, but the associated download flow requires authentication | Excluded from the browser: anonymous metadata alone does not satisfy anonymous asset acquisition |
| [Sketchfab Download API](https://sketchfab.com/developers/download-api) / [guidelines](https://sketchfab.com/developers/download-api/guidelines) | Downloads require end-user authentication unless a separate arrangement is approved | Excluded; no authenticated integration or special credentialed arrangement |
| [VRoid Hub API](https://developer.vroid.com/en/api/) / [model loading](https://developer.vroid.com/en/api/load-character.html) | OAuth and model download/use licensing | Excluded; no login/token API integration |

Before implementation, identify alternative documented **anonymous** APIs or
public machine-readable catalogs with direct, credential-free asset URLs. Record
terms, anonymous rate limits, content ratings, licensing, download formats and
actual humanoid/animation coverage. Public JSON catalogs may be searched locally
with explicit fetched-catalog scope; do not misrepresent them as server-side APIs.
No qualifying provider is verified by this roadmap yet. Select at least one
usable anonymous source and demonstrate real avatar **and animation** queries
and downloads without credentials.
If no provider supplies compatible standalone animations, report that blocker;
do not present a static web download pack as a public animation search API.

No scraping protected sites, unofficial VRChat avatar indexes, private endpoints,
embedded developer secrets or bypassing login/download restrictions. A public
API is not automatically anonymous: anything needing a credential at any stage
is excluded from the built-in catalog. Do not add an authentication backend to
the relay. Custom-source authentication is the explicit user-configured exception
defined below, not a workaround for built-in provider selection. If qualifying sources cannot be found,
report the provider-availability blocker instead of relaxing this requirement.

## 3. Client-side discovery architecture

Suggested modules under `scripts/discovery/avatars/`:

- **Provider adapters:** explicit IDs/capabilities and `categories`, `search`,
  `details`, anonymous `resolve_download` for built-ins; normalize provider responses.
- **Discovery service:** bounded concurrency, request generations/cancellation,
  query/filter routing, partial success, pagination and deduplication.
- **Catalog record:** provider ID + stable provider asset ID, type, title, author,
  source-page URL, thumbnail, formats, license/use metadata, ratings and timestamps.
- **Browser UI:** renders records/state; does not own avatar configuration
  persistence or animation playback. Optional custom-source authentication is
  isolated from anonymous built-in adapters.

Deduplicate pages by provider+asset ID; identical names/URLs across providers are
not proof of identical content. Track download revisions by existing content hash
only after validated acquisition. Persist canonical provider IDs, public URLs and
provenance. Reject embedded credentials in URLs. Built-ins never acquire/store
provider tokens; custom credentials use the separate scoped mechanism below.

On Search submit/filter change, increment generation and discard stale results,
thumbnail callbacks and cursor completions. Cancel/debounce text requests if live
search is enabled (explicit submit is sufficient initially). Bound page size,
JSON bytes/depth, metadata lengths, thumbnail dimensions/bytes and cache lifetime.
Do not download models for a scrolling card list. Retry/backoff per provider,
honor Retry-After and distinguish offline, empty and rate-limited states. If an
endpoint starts requiring authentication, mark the source unavailable/unsupported;
never prompt for login or retry with credentials for a built-in source. One unavailable provider must
not erase successful results from another.

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
configuration contrary to its policy. A provider requiring authenticated or
token-based multiplayer licensing is excluded from built-ins, even if its listing
is public. Custom-source login does not itself grant multiplayer redistribution:
restricted content remains unequippable until the existing sharing policy can be
satisfied lawfully and technically.

The existing asset fetcher rejects redirects. Anonymous provider/CDN downloads
may require them: implement a bounded redirect flow with per-hop HTTPS checks,
no credential forwarding and URL/destination policy tests, or resolve
a direct URL through the adapter. Do not globally allow arbitrary redirects or
accept token-bearing download flows for built-ins. Custom download credentials
are origin-scoped and never forwarded automatically across redirects.
No domain approval list for user avatar
URLs is introduced by this browser; API adapters still have explicit endpoints.

## 6. Privacy, persistence and lifecycle

Discovery runs on the client, never through relay-owned durable catalogs or
search history. Providers learn the client's network address and search terms;
explain this before enabling a source. Opening the Home menu alone does not
contact third parties; opening the browser contacts only enabled providers.

Never send account keys, contact lists, fingerprints or current-session roster
to provider APIs. Do not send Authorization headers, API-key query parameters,
login cookies or tokens for built-ins. Tests must
verify requests remain anonymous across search, details, thumbnails, downloads
and redirects. An application account switch discards pending account-owned
imports. Custom-source account changes additionally cancel authenticated jobs
and clear or switch their isolated credential context.

### User-added custom API sources (optional authentication)

Add **Manage sources → Add custom API** inside the browser, distinct from its
Home/Search navigation. The form accepts a display name, HTTPS API base URL,
supported content types and an authentication mode: **None**, **API key/bearer
token**, or a documented supported **OAuth public-client flow**. Authentication
is optional, never required to use the browser's built-in sources.

- Define a versioned JSON catalog/search/details/download contract and publish an
  example response plus a connection-test action. Arbitrary APIs do not share a
  schema: support this contract initially, or a bounded declarative field mapping
  after separate design. A URL alone cannot integrate every API. Do not load
  executable adapters, downloaded scripts or provider-supplied web content.
- No arbitrary password-form automation, HTTP Basic over plaintext, bundled
  OAuth secrets or embedded login webviews. OAuth uses the external system browser
  with PKCE/state and a validated callback where supported. Unsupported auth
  schemes show an explanation rather than weakening verification. Never ask for
  the user's Comunicare account key/password to access a custom provider.
- Require confirmation before contacting the added endpoint, explaining that it
  receives the user's IP, queries and any provider credential they supply. Show
  the exact origin before login/test. New sources cannot impersonate built-ins
  or become automatically enabled from remote search results or relay messages.
- Bind credentials to the custom source ID, exact HTTPS origin and local account.
  Change of origin invalidates stored authorization. Never send credentials to
  thumbnails/CDNs/redirect destinations without separate explicit origin consent;
  default to denying authenticated cross-origin fetches.
- Store secrets using a supported OS credential store; if unavailable, offer
  memory-only credentials with clear feedback, not plaintext fallback. Normal
  source configuration contains only a credential-store reference, never tokens.
  Do not persist signed/private download URLs in cache keys, public profiles,
  applied-source descriptors or logs. If the existing asset-cache interface
  cannot keep credentials/private URLs out of persistent source records, add a
  scoped acquisition path before enabling authenticated custom downloads.
- Include Test connection, Enable/Disable, Edit, Sign out/Clear credentials and
  Remove. Disabling/removing/logging out cancels pending provider work, frees
  previews and drops in-memory secrets. Persisted preferences are account-scoped;
  removal deletes its credential-store entry without deleting unrelated assets.
- Display provider identity and anonymous/authenticated status in source controls
  and Details. A custom API still undergoes the same bounds, format, content,
  license, preview/import and explicit Apply checks; login does not mean trust.

Custom-source tests cover schema mismatch, bounded decoding, invalid HTTPS URLs,
wrong-origin credential isolation, redirect denial, PKCE/state/callback failures,
secure-store unavailability, logout/removal cancellation, account switching and
secret redaction. Built-in request tests must remain fully credential-free even
when authenticated custom sources are enabled simultaneously. Real provider
OAuth/platform credential-store behavior remains a separate manual release gate.

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
   filter capabilities, malformed responses, rate limits and normalization;
   built-ins reject authentication-required endpoints and credential-bearing URLs.
2. **Discovery service:** generations, cancellation, mixed-provider partial failure,
   deduplication, cursor bounds and metadata/thumbnail cache expiry.
3. **Home tile/browser:** actual Home/Search/sidebar layout; Home search switches
   to Search with exact query; categories install visible filters; Back restores
   focus/results/scroll; no HTTP before opening the browser.
4. **Details/preview/import draft:** licensing/format gates, unavailable downloads,
   unsupported assets, cancellation, no-store behavior and no automatic Apply.
5. **Anonymous end-to-end downloads:** verify credential-free acquisition,
   redirects and source unavailability when a provider starts requiring login.
6. **User-added custom APIs:** versioned catalog contract, source-management UI,
   optional scoped credentials/public-client login and secure acquisition path;
   verify mixed anonymous/custom requests never share authentication state.

Add a disposable `tests/avatar_discovery/run.py` with synthetic HTTP providers
and sanitized recorded responses; keep credentials and external networking out
of automated fixtures. Extend existing microphone/settings, profile, asset-cache,
animation-sync and real-UI runners as relevant. Independent tests must establish
that browsing/importing does not change avatars, emote playback, instance
membership or local per-player avatar visibility until the appropriate Apply.

Manual gates: current real anonymous API behavior/terms and credential-free downloads,
keyboard/small-window and real-headset sidebar/search/scroll usability, thumbnail
performance, permitted real model import and compliant multiplayer sharing. Do
not report live integrations complete based solely on fake-server tests.

Document enabled providers and limitations in current user guides, source/import
contracts in the function reference, new settings/storage schemas and provenance
handling. Update this roadmap/index with actual delivered slices, test results,
skips and remaining gates. No runtime implementation or completed verification
is claimed by this planning document.
