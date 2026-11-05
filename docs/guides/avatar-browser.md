# Avatar Browser

Open **Home → Avatar Browser**. The left sidebar offers **Home**, **Search** and
**Sources**. Home search opens Search with the entered text; category buttons
select avatar/animation filters. Search also has provider, format and ordering
filters, with explicit Load more. Search is over fetched public catalogs, not a
global server-side index or popularity ranking.

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

Credentials are **memory-only** and are cleared on browser close/account change;
there is no plaintext token persistence, OAuth, password-form automation or OS
credential-store integration. Source endpoints/preferences are saved separately
per local account at `user://avatars/<fingerprint>.discovery.json`. Authenticated
requests are restricted to the exact endpoint origin; cross-origin redirects and
credential-bearing download URLs are rejected. Private asset URLs/headers are not
written to the ordinary asset cache or applied source descriptors: validated bytes
are imported through a temporary local file. The relay never handles discovery.

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

This is the first browser slice: text result cards (no downloaded thumbnails),
explicit category-feed loading, type/format/provider/title filters only. Advanced
license/tag/compatibility filters, automatic TTL/revalidation, persisted scroll/
focus restoration, animation preview playback and OAuth remain roadmap work.
Authenticated assets can be validated/imported, but direct authenticated preview
is disabled. Real headset layout/keyboard usability, full renderer previews and
independent-client sharing still need manual validation.
