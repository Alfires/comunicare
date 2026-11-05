# Accounts, profiles, friends and presence

## Hide one player's avatar locally

In **Active Instance**, use **Hide avatar** beside another player's entry. Only
your client hides that player's model; voice, nameplates, profiles, collision and
instance access are unchanged. Other players using the same model remain visible.
Avatar changes stay hidden; **Show avatar** reveals the latest model. Downloads
and animation processing are not blocked.

The choice lasts for the current session, including that player's reconnect.
Leaving/switching sessions, relay disconnect or account change clears it. This is
not a persistent user block, mute or admin action.

## Account identity and recovery

The private account key is the identity owner, not the display name or relay peer
number. Client startup loads `user://user.key`; a new account can create it, but a
corrupt existing key is preserved and reported rather than silently replaced.
Back it up privately. Never paste a private key into a contact field or commit
user storage. Relay authentication proves possession through a challenge/signature;
it does not send the private key to the relay.

Profiles are signed and key-scoped under `user://profiles/`. Self-profile editing
uses ownership checks; other users are read-only even if you administer their
instance. An instance roster is authoritative membership, not merely a list of
avatars that finished downloading. Profile images/avatars may contact external
hosts; a signature establishes the profile owner, not the safety of that content.

## Contacts and mutual friendship

Saving a public key creates a local contact, not friendship. Sending a request
does not unilaterally grant consent. The other account must explicitly accept;
delivery/receipt state, cancellations, declines, revocations and tombstones prevent
late messages from restoring an old relationship. Contacts/outbox/policy persist
locally under `user://friends/`, not in an offline relay mailbox.

Online, Offline and Do Not Disturb are privacy-controlled presence preferences.
Appearing offline does not disconnect the game or change microphone mute.
Presence alone never grants instance admission, moderation rights or profile
editing. Cached contact profiles are distinct from live same-instance profiles.

## Access modes

Public permits ordinary eligible joins; Private remains closed. Friends requires
fresh mutual friendship with a current admin. Friends+ permits one additional
connected mutual-friend hop. Request requires direct admin friendship and explicit
approval. Bans/moderation policy still apply; missing moderator support fails closed.
Disconnect removes relay friendship/admission references; clients retain their own
signed consent and moderation policy. See [relay contract](../relay-data-lifecycle.md).

Implementation: [profile service](../../scripts/profile/profile_service.gd),
[friend service](../../scripts/profile/friend_service.gd),
[router](../../relay_protocol/friend_router.gd),
[relay](../../scripts/multiplayer/relay.gd).
Verification: profile/friends/active-instance [runners](../development/testing.md).
