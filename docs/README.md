# Comunicare documentation

Current documentation describes shipped code; [roadmaps](roadmaps/README.md)
describe intentions and history. A passing headless test is not a claim of
headset, renderer, microphone or production-network verification.

## Players and operators

- [Run desktop/VR clients and relays](getting-started/runtime.md)
- [VR controls and tracking status](guides/vr-controls.md)
- [Accounts, profiles and social access](guides/accounts-and-social.md)
- [World transitions, settings and voice](guides/worlds-settings-and-voice.md)
- [Offline home island: features and release limits](guides/welcome-home.md)
- [Avatar sources, animation and emotes](asset-cache-and-animation-usage.md)
- [Public avatar/animation browser and custom APIs](guides/avatar-browser.md)
- [Relay privacy and lifecycle contract](relay-data-lifecycle.md)
- [Third-party asset licenses](../THIRD_PARTY_ASSETS.md)

## Contributors

- [Contribution workflow](../CONTRIBUTING.md)
- [Runtime architecture](architecture/overview.md)
- [Lifecycle sequences and decision boundaries](architecture/lifecycle-flows.md)
- [Service contracts and data flows](reference/services.md)
- [Production function/class/signal inventory](reference/scripts.md)
- [Function behavior, ownership and side effects](reference/functions.md)
- [Wire packets and capability schemas](reference/protocol.md)
- [Storage formats and recovery](reference/storage-formats.md)
- [Configuration and scene wiring](reference/configuration.md)
- [Troubleshooting](guides/troubleshooting.md)
- [Verification](development/testing.md)
- [VR validation status and hardware gates](development/vr-validation.md)
- [Welcome home human release gates](development/welcome-home-release-gates.md)
- [Documentation conventions](development/documentation.md)
- [Local Git-only releases](development/releases.md)
- [Roadmaps and remaining work](roadmaps/README.md)
- [Accepted architecture decisions](decisions/README.md)

## Status

Godot 4.7 desktop/VR social application, in early development. Client and relay
must be upgraded together for negotiated protocol features. The Linux export
preset is a dedicated server, not a desktop client. Normal startup writes account
data; automated checks must use disposable test projects.
