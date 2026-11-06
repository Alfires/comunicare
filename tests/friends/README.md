# Friends, local contacts and presence tests

Run from the repository root:

```sh
python3 tests/friends/run.py
# Requires a real desktop display; uses Dummy audio, not the microphone:
python3 tests/friends/run.py --display
GODOT=/path/to/godot python3 tests/friends/run.py
```

Requires Python 3, Godot 4 and ephemeral loopback networking. Production friend service, signed-event validation, relay router, RelayPeer, Friends page and profile view run in a disposable Compatibility project under `/tmp/opencode`. Keys are generated in memory; signed client stores use disposable `res://` paths. No real user account/contact files, external HTTP, physical microphone, headset, production relay port or normal startup are used.

Exit 0 means all assertions passed, 1 means assertions failed, and 2 indicates Godot import/runtime errors. There are no unconditional red-test placeholders or skipped prerequisite groups. Display runs execute the same contracts plus GPU/layout/screenshot checks. Screenshots: `/tmp/opencode/friends-visual/`.

## Verified result

**Presence optimization follow-up — 2026-11-06:** 97 headless / 101 windowed
checks pass. Identical sequenced heartbeats update receive time without emitting
UI rebuild signals; location/status changes and stale recovery still emit them.
Unsolicited delivery IDs are ignored and durable receipts remove delivery hints.
Account-switch assertions verify absence of old identities instead of relying
on a fixed number of empty-state UI children. No frame-rate benchmark is claimed.

**Expanded verification — 2026-11-06:** **93 passed** headlessly and **97 passed**
windowed, exit 0 without Godot errors. Related profile **120** and Active Instance
**138** assertions passed in the current working tree. Older counts below are
historical, not the current baseline.

Added checks exercise real authenticated ENet joining using a friend's public
session descriptor; actual Friends Join button → coordinator arguments (fixture
coordinator, not full world activation); Same instance disabling; busy-transition
suppression; admission rejection feedback; click-time expiry checks; invalid URL
clearing; descriptor-copy isolation; block and viewer/subject disconnect cleanup.
Network request/acceptance/presence still uses production relay/services; UI join
failure paths use an explicit recording fixture so no game startup or real account
files are touched. This does not certify full multi-client world downloads,
cross-relay friend location, invitation delivery or real headset interaction.

Godot 4.7.2: **72 passed, 0 failed** headlessly; **76 passed, 0 failed** with real X11/Intel OpenGL Compatibility display rendering. All commands exited 0 without Godot runtime/import errors. Display startup logged failed NVIDIA driver probes before successfully selecting Intel. Regression checks passed: Active Instance **128**, Active Instance display **27**, profile **110**, discovery **51 + 24 startup**, microphone/settings **92**, avatar loading **10**. The profile suite emitted its ObjectDB leak warning; these results do not certify full-game leak freedom or XR hardware behavior.

## Verified coverage

- Canonical public-key contacts, duplicates, self/private-key rejection, private nicknames and signed account-scoped reload.
- Wrong-owner/corrupt/tampered stores are preserved; failed writes do not mutate the previous usable contacts; no private keys in stored data.
- Explicit request/acceptance, durable receipt, forged/altered events, crossed requests, cancellation/decline/revocation/block and no resurrection by delayed acceptance or unblock.
- Three real authenticated ENet clients, distinct instances of the same relay, capability negotiation, real event/receipt packets, sender-identity enforcement and malformed packet rejection.
- Mutually authorized Online/DND/appear-offline, unrelated/proof-replaying account isolation, connection-generation/sequence filtering, expiry and recovery.
- Client-local offline revocation retry on reconnect, relay cleanup of social publications/subscriptions/pending receipts/rates, preservation of client friendship history.
- Real Friends scene: lists while offline, status selector, add-by-key fingerprint review and Save contact, correct read-only profile/Back, account-switch clearing, and main-menu tab order.
- Display-backed 640×480 GPU layout, usable scrolling, in-bounds status controls and screenshots without loading remote avatar media.

## Implementation and limits

`SaveData.friends` is an account-scoped service stored at `user://friends/<fingerprint>.cfg`. Its signed JSON envelope holds contacts, owner-signed relationship events, terminal tombstones, durable outbox and self-status preference. Files are atomically replaced; corrupt/unsupported/wrong-account files block writes and are not silently replaced. Remote presence is volatile. Signatures detect modification, not rollback of a valid old backup; multi-device synchronization and key rotation are not provided.

Wire ID **24** carries bounded social messages; authentication advertises `social_version: 1`. Both clients and relay should be updated. Legacy relays leave Friends transport/status unavailable without changing saved contacts. Requests retry in rotating batches; the initial service supports 128 contacts and up to 2,048 relationship/outbox records, with an 8 MiB load limit and bounded message/routing rates. There is no history compaction/export UI yet.

The relay keeps only active-connection publications, pairwise authorizations and short-lived pending delivery IDs. It stores no offline events, profiles for friends, complete contact lists or social history on disk; disconnect removes both sides' references. Presence requires both live accounts to authorize the same signed request/acceptance proof after reconnect. Each side's local revocation/block state governs its authorization. Offline is scoped to the connected relay; it does not establish global offline status. Appear-offline changes presence only, not game membership or transport reachability, and is not anonymity against timing/co-presence inference.

No unsolicited social popups or notification sounds are introduced: incoming requests remain in the inbox, including during DND. `notifications_allowed()` exposes the policy for future invitation/notification features. DND never changes microphone, voice playback, or instance membership. Friend profiles are separate cached views; they never populate the instance-only remote-profile cache or grant editing rights.

## Instance access contracts

UI refinement verification: Friends is now the second tab (Home, Friends, World Explorer, Active Instance, Settings). The user overview exposes Send friend request near its identity details, targets the displayed account, and changes to disabled Friend request sent state. Verified Friends suite: **75 passed** headlessly and **79 passed** display-backed. Profile **110**, Active Instance **128**, microphone/settings **92** also passed; profile/microphone runs emitted ObjectDB leak warnings without runtime/import errors.

Friends, Friends+ and Request now use current mutual relay authorizations. Direct friends of any current admin qualify for Friends and Request; Friends+ additionally allows a two-edge chain through another connected user. Request waits for explicit admin approval in Active Instance, while preserving the prior membership; decline, 60-second expiry or changed type/admin/friendship reject admission. Client-owned ban approval is still required for moderated instances. Non-public types stay out of discovery; authenticated code lookup (ID 25) supplies the world only to eligible candidates. IDs 26/27 carry pending-request notifications and admin decisions.

Real relay tests cover unrelated denial, direct automatic join, two-hop Friends+ versus Friends denial, Request direct-only eligibility, pending/decline/allow, non-admin decision forgery, expiry, type-change revalidation, code lookup without premature membership transition and closed Private. This is active-user/same-relay graph authorization, not offline or cross-relay friend lookup. Promotion/departure changes whose friendships authorize new entrants; existing members are not automatically evicted.

Remaining release work: manual headset/controller interaction, full startup/XR rendering, comprehensive resource-exhaustion/load testing, OS-level filesystem auditing, multi-device/rollback recovery, invitation/session access and presence across relays. Headless/display tests are not proof of these. The main VR player still depends on the repository's existing menu presentation/input wiring; this change supplies the shared Friends page, not a new XR menu framework.
