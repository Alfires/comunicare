# Friends, invites and profile synchronization usability

## Status — 2026-11-06

Current-code investigation, with an initial roster/Quick Invite implementation.
This extends [Friends](friend-system-roadmap.md) and
[Active Instance](active-instance-roadmap.md), not a new parallel social system.

Delivered in this slice: Add friend / Accept friend beside remote roster entries,
pending/friends/blocked states, and Quick Invite focusing the current copyable
instance code with joining instructions. Direct in-app friend invitations and
ongoing cached-friend description refresh are **planned**, not implemented claims.

## Findings from the existing system

- `friend_service.gd` owns signed client-local contacts, requests, receipts,
  tombstones and outbox. Mutual acceptance—not a contact row—establishes friendship.
- `friends_menue.gd` already groups Friends, Incoming, Outgoing and Saved contacts,
  but normally requires opening a profile or pasting a public key to add someone.
- `share_session_menue.gd` has verified fingerprint-keyed session members, so it
  can provide direct social actions without asking users to copy keys manually.
- Quick Invite in `tablet_shell.gd` previously looked for a missing `focus_invite`
  method. The working immediate sharing path is the existing instance code.
- No invite operation exists in the current friend wire service. An Invite label
  must not imply that an invitation was sent when only a page was opened.
- Friend cached profiles update with signed friendship events. Routine presence
  publish/authorize traffic does not refresh descriptions after those events end.
- In-instance profiles and cached friend profiles are distinct stores. A newer
  in-instance description must not be overwritten by an older cached social copy.

## 1. Roster-first friendship

Every remote row shows Add friend, Request sent, Accept friend, Accepting…,
Friends or Blocked. Enable only actions valid for the current relationship and
verified profile. Disable stale/busy-session rows. Recheck session and fingerprint
on click; reused peer IDs cannot redirect social consent to a different account.
Show rejection/queued/delivery feedback inline without discarding existing state.

Preserve name/profile, avatar visibility, badges and moderator controls. Use flow
layout or compact grouping on narrow/VR menus; long names cannot push social
actions offscreen. Add keyboard/pointer hit tests and rendered crowded-roster tests.

## 2. Friends page clarity

Primary actions: Find in this instance, Requests (with count), Friends, and an
advanced Add public key option. Explain Saved contact versus mutual friend in
plain language. Add search, stable sorting, preserved scroll/focus and clear
offline/queued/unsupported states. Accept/Decline/Cancel should update the row
without rebuilding unrelated controls or losing focus.

Show public name, presence and short signed description, with timestamp/stale
indication where cached. Local nicknames remain private and never overwrite
another player's signed profile. Block/remove require appropriate confirmation;
do not bury Accept behind a destructive-action menu.

## 3. Actual in-app invitations

Introduce a capability-negotiated invite message, separate from durable friendship
consent events. Only accepted unblocked friends can send/receive it; rate limit,
bound metadata, derive sender identity from authentication and reject replay/expiry.
The relay holds only active-connection delivery state—no invitation mailbox,
disconnected-target history or durable user/session data.

Invite includes exact session ID, content/world revision and a validated relay
route reference as needed for federation. Never join by world URL alone. Recipient
sees sender, instance and Join/Decline; Join uses ordinary staged world download,
revision validation and acknowledged admission. Friendship or invite receipt never
bypasses Private/Friends/Request/bans/admin approval. Unsupported peers offer Copy
instance code honestly; offline targets show unavailable, not “sent.”

Provide Invite next to eligible friends and Quick Invite recipient picker. Keep
copy-code sharing available independently. Do not invent a durable invite protocol
before capability/codec/service/relay lifecycle tests and documentation exist.

## 4. Signed descriptions that stay synchronized

On local profile save, publish signed profile revision to connected authorized
friends through a negotiated social profile-update/request path. Presence alone
is not a signed profile and cannot update descriptions. Reuse ProfileIdentity
verification, fingerprint ownership, monotonic revision/replay checks and existing
profile byte/field limits. Reject old/conflicting updates and wrong identities.

On reconnect, exchange revision summaries and request missing/newer profiles in
bounded batches rather than resending every full profile each presence tick.
Persist only permitted verified client-local cached friend profiles; emit profile
and UI change signals only for actual updates. Never merge instance membership,
roles or remote editing rights into friend caches. Offline/DND/block privacy must
be explicit; blocked/revoked pairs stop updates and relay references are cleared.

Test description edits in an open profile, Friends row and Active Instance;
same-instance and separate-instance accepted friends; reconnect/offline refresh;
stale signature/revision; account switch; revoked/blocked target and unsupported
capability. Show cached/stale content honestly rather than claiming live sync.

## 5. Delivery gates

Use failing tests first, small passing Conventional Commits and ordinary Git push.
Extend isolated friends/profile/active_instance suites and add real two-client
invite/description tests. Validate federation and exact-instance admission where
applicable, but no external relay or real accounts in default automated tests.
Record warnings, skips and actual rendered/headset scope.

Initial roster tests pass their social/invite assertions. The full Active Instance
runner currently fails its loopback voice-delivery assertion (zero packets in two
runs); this is an unresolved verification blocker, not a passing suite claim.

Model-loading investigation is separate: a current anonymous R1 sample downloads,
validates, imports through cache, applies and reloads successfully with production
code in an isolated project. This does not reproduce every user's failing model.
Capture the exact remaining UI error/source and add a browser Apply integration
fixture before claiming the reported loading failure resolved. Preserve original
accounts/cache and never replace unrelated data as a troubleshooting shortcut.
