# Roadmaps and design history

Current behavior starts at the [documentation home](../README.md). Plans below
mix implemented milestones, superseded proposals and manual release gates.

| Roadmap | Status / authority |
| --- | --- |
| [Documentation system](documentation-system-roadmap.md) | Documentation/tooling delivered with explicit operating limits; current guides, function/schema reference and local Git release checks linked from docs home |
| [Safe world system rewrite](safe-world-system-roadmap.md) | Proposed: native Godot authoring with custom-node/addon support (Terrain3D via baking or reviewed integration), full standard-material textures, metadata/manual ZIP packaging, safe parsing, restricted scripts and shared VR/desktop pickup; existing relay/URL delivery and kick/ban-only admin target retained |
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
