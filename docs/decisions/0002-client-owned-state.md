# 0002: Durable user state belongs to clients

**Accepted.** Relay-retained offline accounts, bans and social history would violate
the project privacy contract. Keep only connected-user routing/authorization state
and erase indirect references on disconnect. Client keys/profiles/consent/outboxes/
moderation policy remain locally persisted and owner-scoped.

Consequence: relay restart starts empty; reconnect requires fresh authentication,
grants and moderator approval. Missing policy fails closed, not by restoring an old
relay ban cache. Persistent offline delivery would require a separately approved
architecture, not a hidden queue extension.

Authoritative contract: [relay lifecycle](../relay-data-lifecycle.md). Evidence:
profile/friends/active-instance cleanup and no-relay-write tests. This is application
state deletion, not forensic OS/log erasure.
