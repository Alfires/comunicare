# 0001: Git-only explicit release publication

**Accepted.** Owner requested no hosting-specific tooling and small verified
Conventional Commits/pushes. Hosted bots/workflows and automatic tag-on-commit were
rejected: they add provider coupling or publish before review.

Local Python/Git calculates versions from an explicit reachable baseline, prepares
reviewable metadata and verifies the recorded plan before annotated tagging.
Optional hooks validate messages/docs; they do not push/install themselves.
Stable release publication is explicit ordinary Git, preferably atomic branch/tag.

Consequence: local hooks are bypassable, not server policy; no version baseline
can be inferred safely from historical nonconventional commits. Signing and actual
test execution remain operator responsibilities. Recovery journal handles bounded
metadata failure, not every filesystem/power-loss scenario.

Evidence and recovery: [release guide](../development/releases.md) and temporary
Git fixture tests. No production tag/version/hook installation is implied.
