# 0003: Separate avatar visuals from camera and tracking authority

**Accepted with visual/hardware limitations.** Runtime head cutting and parenting
cameras to animated bones caused fragile geometry/view coupling. Detached import
prepares a separate first-person derivative; original third-person resources stay
intact, with camera masks selecting representations and shared skeleton/expression
state. Current local view excludes interior torso as a deliberate visibility tradeoff.

Animation owns only its bone channels. Camera is player/headset-owned; a final local
head/arm modifier makes the avatar follow external tracker targets, not the reverse.
Sideways locomotion uses adapted CC0 walk legs plus forward upper-body samples;
standing is a static composition, not a dedicated captured neutral animation.

Consequence: unusual rigs/annotations/controller orientation require calibration;
this is not a complete full-body or remote tracker system. Pose/geometry tests do
not certify headset comfort, mirror/shadow appearance or all humanoid models.

Evidence: [function contracts](../reference/functions.md),
[asset provenance](../../THIRD_PARTY_ASSETS.md), optional real-VRM and animation
lifecycle tests. Future changes should document new evidence, not call the current
compromises universal visual correctness.
