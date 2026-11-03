# Client storage, configuration and recovery

`user://` is Godot's application user-data directory, not a repository-relative
folder. Account stores can contain personal information even when no private key
is present. Back them up privately; never commit runtime directories.

| Path | Owner/format | Version and recovery |
| --- | --- | --- |
| `user://user.key` | SaveData / CryptoKey private account key | Existing corrupt keys are preserved; do not regenerate silently |
| `user://user.cfg` | SettingsStore / ConfigFile | `[meta] version=1`, typed `[settings]`; legacy migration reads UserSettings; corrupt/future format blocks writes |
| `user://profiles/<fingerprint>.cfg` | ProfileService / ConfigFile `[profile]` | Owner key, revision, four profile fields, signature; reject wrong key/signature before adopting/overwriting |
| `user://friends/<fingerprint>.cfg` | FriendService / signed JSON despite `.cfg` suffix | Envelope `data` + signature; data version 1, owner public key, revision, preference, contacts/relationships/outbox |
| `user://moderation/<fingerprint>.cfg` | RelayPeer client policy / ConfigFile | `[policy] owner` and `instances` maps; corrupt/wrong-account state prevents automatic approval |
| `user://avatars/<fingerprint>.json` | AvatarConfiguration / JSON | schema 1, owner fingerprint, revision, model/source references; failed validation preserves prior selection |
| avatar path plus `.wheel.json` | EmoteLayout / JSON | schema 1, root/group graph; corrupt data preserved with read-only default fallback |
| `user://asset_cache/index.json` | AssetCache / JSON | schema 1 and source records; corrupt index preserved, writes disabled |
| `user://asset_cache/blobs/sha256/<hash>` | Immutable original bytes | Hash/length verified; integrity is not publisher trust or redistribution permission |
| `user://asset_cache/derived/worlds/<hash>-1/content/` | Versioned extraction | Active leases pin bytes; `.ready` marks successful extraction |
| `user://asset_cache/staging/` | Incomplete/transient content | Only managed unreferenced staging is disposable; no-store bytes owned by temporary lease |

Test adapters can override paths; do not infer production filenames from fixtures.
The relay/dedicated-server branch must not initialize these client stores.

## Settings example

```ini
[meta]
version=1
[settings]
audio.microphone_muted=true
input.toggle_microphone=86
input.toggle_animation_menu=66
```

The registry owns defaults/type/range/category/description. Values above illustrate
physical V/B keycodes; use Controls UI for validation/conflict handling. Store
changes emit immediately and debounce save by 400 ms; save uses a temporary file
and rename. Unknown/unregistered settings are not public extension storage.
Unrelated legacy sections are preserved. Failed writes report errors without
claiming persistence; failed read/future-version state blocks replacement.

## Signed profiles and contacts

Profile fields: `profile.username` (trimmed, 1..128), description (0..1024, newline
permitted), icon URL (may be empty), avatar URL (required). Media URLs are bounded
HTTP(S) addresses without credentials/control characters. Profile revision is an
integer 0..2^53−1. Sign fixed canonical bytes, not raw ConfigFile formatting.
`get_profile()` returns copies; remote snapshots are session-scoped and replaced.

Friends signing canonicalizes integer-valued JSON numbers and prefixes
`comunicare/friends-store/v1\n`. Stores are at most 8 MiB on read; commits enforce
roughly 7 MiB JSON, at most 128 contacts and bounded 2,048-entry maps. A relationship
contains signed request, optional accept/terminal and confirmed delivery state;
outbox events must belong to the local actor. Do not manually edit signatures or
restore a stale backup expecting revoked friendship to reappear. Persisted contact
profiles are independent of live instance-only profile state.

## Avatar and wheel examples

```json
{"schema":1,"owner":"<account fingerprint>","revision":1,"model":{},"sources":[]}
```

This is a shape example, not a valid signed identity or a replacement file.
Applied sources use managed hash, display name, optional URL and explicit share
permission. Absolute source paths stay local; configuration is not signed public
profile data. No-store sources cannot become persistent applied configuration.
Wheel entries reference stable emote/group IDs, not just labels; stale references
show unavailable rather than pointing to a new identically named clip.

Wheel constraints: 32 groups, four levels below root, 1,024 total entries. Every
visible page has eight sectors; above eight entries the group paginates five
content entries plus in-wheel Previous/Page/Next. Graph validation rejects cycles
and dangling groups. Layout edits persist independently of source Apply/Cancel.

## Cache example and invariants

```json
{"schema":1,"sources":{}}
```

Source key is SHA-256 of `kind + "\n" + source` (query parameters significant).
Records carry kind/hash/size/check/access times, HTTP validators, pinned and
no-cache flags. Four concurrent jobs and 32 waiters bound acquisition; source
limits are 64 MiB avatars, 128 MiB worlds, 16 MiB animations. World extraction
limits are 4,096 entries and 256 MiB. Default disk budget is 4 GiB. Leases protect
active revisions independently of persistent pinned user originals.

Conditional GET reuses verified bytes on 304; failed updates retain known-good
content with stale status/backoff. no-store uses temporary bytes, not an indexed
durable record. Clear-unused refuses active jobs and preserves leases/import pins.
Index atomic rename is not a database-wide crash transaction. Source validation,
trust opt-in and schema checks are not a sandbox for executable Godot scenes.

## Safe recovery procedure

Stop the client, copy the affected original files privately, inspect actual errors
and restore a known-good owner-matching backup. Do not delete account keys or
replace stores just to suppress errors. Cache removal is separate from account
recovery; imported originals need explicit deletion. Relay restart always begins
empty and cannot restore a lost client key/contact store.

Sources: [settings store](../../scripts/settings/settings_store.gd),
[profiles](../../scripts/profile/profile_service.gd),
[friends](../../scripts/profile/friend_service.gd),
[avatar config](../../scripts/assets/avatar_configuration.gd),
[cache](../../scripts/assets/asset_cache.gd). Verification:
[isolated runners](../development/testing.md). Release metadata/journal is a
repository development format, described separately in [releases](../development/releases.md).
