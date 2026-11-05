# Avatar Browser

Open **Home → Avatar Browser**. The left sidebar offers **Home**, **Search** and
**Sources**. Home search opens Search with the entered text; category buttons
select avatar/animation filters. Search also has provider, format and ordering
filters, with explicit Load more. Search is over fetched public catalogs, not a
global server-side index or popularity ranking.

Result cards now have bounded PNG/JPEG thumbnails, license/compatibility/sharing/
loop filters and tag search. Advanced filters for custom APIs apply only to each
fetched page. Built-in catalogs and thumbnail caches expire after five minutes.
Back from Details restores fetched cards, scroll and selected-card focus without
another catalog request. Unknown compatibility is never presented as verified.

Opening the browser makes no external requests. Submit a search/category or
select **Load category recommendations** to contact enabled sources. Providers
receive your IP and search terms. Built-in providers never receive credentials:

- **100Avatars R1:** Polygonal Mind's 100 CC0 VRM avatars via Open Source Avatars'
  public JSON catalog. Model downloads are hosted on Arweave.
- **Public CC0 VRMA manifest:** VoxAvatar's public manifest of 13 CC0 animations,
  with creator/source links and expected SHA-256 digests. This is an animations-only
  source; select it or the Animation type filter to add motions to your library.

These endpoints were live-tested on 2026-11-05 without authentication. Catalogs
can change or go offline. Listing compatibility remains unknown until actual import.

## Download and add animations or avatars

Select a result to view its author, license, format and source link. For anonymous
avatars, **Preview model** downloads a separate model without equipping it.
**Download, validate and review** imports into a separate Avatar source-editor
draft. Nothing changes in your equipped avatar or animation library until **Apply**.
Cancel discards the draft. Added compatible non-basic animation clips become
available in the existing emote wheel after Apply; recognized locomotion roles
use the existing automatic resolver. The source limit remains 32.

The current animation importer supports humanoid rotations, not root translations.
The public VRMA clips contain hip translation. Use **Import animation in-place
(remove translation tracks)** for those clips: the explicit worker conversion
preserves rotations, validates the result and records the adaptation in provenance.
It does not change the original online file or relax the standard importer.

**Preview animation on a separate copy of my avatar (in-place)** downloads the
motion and plays it on an independent avatar in the preview viewport. Conversion
removes translation only for this explicit in-place action. The equipped model,
configuration and instance animation stream are untouched. A compatible local
avatar must be available. Close Details to dispose the preview.

Import supports self-contained VRM/GLB avatars up to 64 MiB and compatible GLB/VRMA
animations up to 16 MiB. FBX/Unity packages/ZIPs are not supported. Built-in licenses
were checked as CC0; custom source claims remain your responsibility. Currently
only CC0 redistribution is accepted by this browser's import action. Downloads
with no-store policy or digest mismatches are not saved into applied configuration.

## Add a custom API

In **Sources**, enter a name, HTTPS endpoint and optional **Bearer** or
**X-API-Key** credential, then confirm the endpoint. Anonymous use remains available.
The API must implement the schema below; a URL alone does not integrate arbitrary
websites. Sources can be enabled/disabled, tested, edited or removed. Updating an
endpoint clears its credential. **Sign out / clear credential** removes the secret.

Credentials default to **memory-only** and clear on browser close/account change.
On Linux, `secret-tool` with an unlocked Secret Service enables explicit **Remember
credential in OS keyring** and **Restore from OS keyring** actions. Secrets use the
helper's standard input, not command-line arguments. Failure/other platforms keep
memory-only behavior; there is no plaintext fallback. Sign out, Remove and changing
endpoint request deletion of the old keyring entry. Locked/unavailable keyrings
may prevent deletion; remove stale entries in the OS keyring manager if needed.
Source endpoints/preferences are saved separately
per local account at `user://avatars/<fingerprint>.discovery.json`. Authenticated
requests are restricted to the exact endpoint origin; cross-origin redirects and
credential-bearing download URLs are rejected. Private asset URLs/headers are not
written to the ordinary asset cache or applied source descriptors: validated bytes
are imported through a temporary local file. The relay never handles discovery.

Custom sources can select **OAuth** and specify HTTPS authorization/token URLs,
public client ID and scopes. **OAuth sign in** opens the system browser with PKCE
S256/random state and a temporary localhost callback. Callback Host, port/path,
state, three-minute expiry and one-use codes are checked; HTTPS code exchange
uses no redirects or client secret. Providers must support public native clients
and dynamic loopback ports. No embedded login pages, refresh-token storage or
automatic token refresh is provided; sign in again when a token expires.

Requests use GET with `query`, `type` (`all`, `avatar`, `animation`) and `cursor`.
Example response:

```json
{
  "schema": 1,
  "items": [{
    "id": "wave-1",
    "title": "Wave",
    "type": "animation",
    "format": "vrma",
    "author": "Creator",
    "license": "CC0-1.0",
    "redistribution": true,
    "page_url": "https://example.org/wave",
    "download_url": "https://example.org/files/wave.vrma"
  }],
  "next_cursor": ""
}
```

Maximum metadata response is 4 MiB, nesting 32, page 200 records; fields and cursors
are bounded. Errors/rate limits appear inline. At most three HTTPS redirects are
followed, never forwarding custom credentials to a different origin.

## Current limitations

Category feeds require explicit loading. PNG/JPEG thumbnails are bounded to 2 MiB
and 2048×2048 before decode, then resized to 256px; GIF/WebP thumbnails use an empty
slot. Metadata refresh failure does not yet retain expired stale catalogs.
Authenticated model preview is disabled (animation previews use scoped downloads).
Real OAuth-provider registration/login, keyring behavior on each desktop, headset
keyboard/layout, visual animation previews and independent-client sharing still
need manual verification. Windowed automated contracts do not certify XR hardware.

Verification: `python3 tests/avatar_discovery/run.py` and the windowed
`--display` mode run synthetic contracts without external providers. Explicit
`KEYRING_TEST=1` enables a synthetic OS-keyring store/lookup/delete test; it is not
part of the isolated default suite. On this development desktop the store failed
because Secret Service is unavailable (`The name is not activatable`), so no
successful keyring round-trip is claimed. Real OAuth login also remains unverified.
