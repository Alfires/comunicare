# Roadmaps and design history

Current behavior starts at the [documentation home](../README.md). Plans below
mix implemented milestones, superseded proposals and manual release gates.

| Roadmap | Status / authority |
| --- | --- |
| [Client-only per-player avatar visibility](client-avatar-visibility-roadmap.md) | Planned: Hide/Show avatar beside each remote participant; local session/fingerprint scope, unaffected same-asset players, avatar-change enforcement and no relay/global block |
| [Desktop and VR sprinting](sprinting-roadmap.md) | Implemented with manual gates: hold left joystick click in VR or Ctrl on desktop for 1.5× horizontal speed; rebindable Ctrl, suppression/rearming and relative walk/run selection; hardware comfort and visual two-client validation remain open |
| [Documentation system](documentation-system-roadmap.md) | Documentation/tooling delivered with explicit operating limits; current guides, function/schema reference and local Git release checks linked from docs home |
| [Real UI multiplayer investigation/testing](real-ui-multiplayer-validation-roadmap.md) | Investigated with full production autoloads and rendered UI: unrelated Add relay disconnects active federated play; offline startup delays menu; legacy port edits do not change effective list; planned hit-tested/two-client UI gates supersede service-only stability claims |
| [Multi-relay federation and LAN discovery](multi-relay-federation-roadmap.md) | Ordered preferences/failover plus live trusted TLS peering, signed public directories, concurrent clients, IPv4 LAN hints and routed gameplay implemented; per-actor ingress policy, automatic trust/bootstrap, IPv6/mDNS and WAN/VR/security gates remain open |
| [Safe world system rewrite](safe-world-system-roadmap.md) | Initial safe ZIP/text scene loader and pure script/lease/state/role services implemented and tested; complete native authoring/custom-node/Terrain3D, transport/player interactions, texture parity and script frontend remain pending; see current authoring limits |
| [Multiplayer and discovery reliability](multiplayer-and-public-discovery-reliability-roadmap.md) | Planned after current-code inspection: appearance/session correlation, bounded decoding, retryable discovery and responsibility-based module extraction |
| [VR controls, menus, IK and FBT](vr-controls-menus-ik-fbt-roadmap.md) | Planned: planar head-relative movement, either-hand A/X main menu, snap/smooth turning, comfort settings, calibrated rig/IK and optional tracker support |
| [Conventional Commits](conventional-commit-roadmap.md) | Historical assembly plan; current [contribution rules](../../CONTRIBUTING.md) supersede old no-push/two-type assumptions |
| [Settings and microphone](microphone-and-settings-roadmap.md) | Implemented with hardware limitations; see tests/microphone_settings |
| [Profiles and settings](profile-and-expanded-settings-roadmap.md) | Implemented with limitations; ownership is profile-service controlled |
| [Profile layout](profile-layout-roadmap.md) | Implemented layout history; see tests/profile |
| [Discovery](public-world-discovery-roadmap.md) | Implemented with limitations; staged acknowledged transitions remain authoritative |
| [Active Instance](active-instance-roadmap.md) | Implemented; old retained-ban policy superseded by [relay lifecycle](../relay-data-lifecycle.md) |
| [Friends](friend-system-roadmap.md) | Implemented with limitations; client-local consent and active relay edges |
| [Cache/original animation plan](avatar-cache-and-animation-roadmap.md) | Partly superseded by automatic animation plan and current usage |
| [Automatic avatar/emote plan](automatic-avatar-animation-roadmap.md) | Implemented incrementally with unverified XR/visual gates; [current usage](../asset-cache-and-animation-usage.md) supersedes historical poses/masks |

Dependency order: settings/account ownership → authenticated relay/acknowledged
instances → profiles/social/access → cache/import → avatar animation/rendering.
The [relay privacy contract](../relay-data-lifecycle.md) governs every subsystem.
Asset provenance remains in [THIRD_PARTY_ASSETS](../../THIRD_PARTY_ASSETS.md), not
in a roadmap's old licensing proposal.
