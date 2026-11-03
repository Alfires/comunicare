# Documentation system and Git-only versioning roadmap

## Status and scope

**Implementation in progress.** Documentation navigation, contribution/architecture/testing guides and link-safe relocation of the nine existing roadmaps are implemented. A local Conventional Commit parser and deterministic explicit-baseline release planner, metadata preparation/checking and annotated-tag commands are available with temporary-Git tests. No real application baseline/version, release tag or hooks have been installed. Exhaustive function references, symbol/link tooling, opt-in hooks, prereleases and release fault/recovery coverage remain incomplete; the requirements below remain the target, not a completion claim. See [release usage](../development/releases.md).

Additional implemented slice: offline tracked-Markdown file/anchor checking with
fixtures, a service-contract reference, and opt-in commit-msg/pre-push scripts plus
an existing-policy-preserving installer. Hooks remain uninstalled. Pre-push
currently refuses new remote branches without a baseline instead of handling all
new-branch histories automatically. Full symbol inventory and hook integration/
mutation-failure tests remain pending. Preparation is sequential multi-file writing,
not transactional; this limitation is explicit in the release guide.

Requirements:

- Explain how the application works, how features behave, and how its important classes/functions cooperate—not merely list files or future ideas.
- Put roadmaps in **`docs/roadmaps/`**, separate from current user/developer/reference documentation.
- Keep design history without presenting superseded behavior as current functionality.
- Validate documentation against production code and executable tests, with explicit hardware/security limitations.
- Use **Git only for repository integration**: no GitHub Actions/workflows, CLI, APIs, release PR bots or hosting-specific tools.
- Automate Conventional Commit validation, SemVer calculation and changelog generation with local Python scripts and opt-in Git hooks. Creating/pushing a release remains an explicit, reviewable operation.
- Commit and push each small completed, verified part to the configured upstream. Never push broken test-first intermediate snapshots or unrelated changes.

## 1. Findings from the existing documents

The source material is valuable but not a reliable current reference without reconciliation:

| Existing roadmap | Information to extract and verify | Destination |
| --- | --- | --- |
| `microphone-and-settings-roadmap.md` | Typed registry/store, migration, shared mute ownership, capture order, key rebinding and settings UI | User settings/voice guide; settings and voice reference |
| `profile-and-expanded-settings-roadmap.md` | Account key ownership, signed profiles, local versus remote fields, media loading and authentication | Account/profile guide; identity/storage/protocol reference |
| `profile-layout-roadmap.md` | Field-specific editing, previews, navigation, focus, desktop/small viewport behavior | UI guide and profile UI reference |
| `public-world-discovery-roadmap.md` | Catalog versus live discovery, URL versus instance identity, staged acknowledged joins, public summaries | Worlds guide; transition and discovery architecture |
| `active-instance-roadmap.md` | Roster, roles, metadata revisions, kick/ban/promotion, admission | Instance guide; authorization/state reference |
| `friend-system-roadmap.md` | Signed local contacts, mutual consent, retries/tombstones, privacy-controlled presence, Friends/Friends+/Request access | Social guide; consent and access state machines |
| `avatar-cache-and-animation-roadmap.md` | Content-addressed storage, HTTP validation, leases, quota, import security, original animation design | Cache/import reference; retain historical playback proposals only as history |
| `automatic-avatar-animation-roadmap.md` | Applied sources, automatic/emote authority, radial groups/paging, XR interaction, rendering/tracking changes | Avatar/emote guides; configuration, renderer and tracking reference |
| `conventional-commit-roadmap.md` | Coherent changes, staging, verification and small commit boundaries | Contribution guide; supersede its old no-push/two-type assumptions with current owner instructions |

`docs/relay-data-lifecycle.md` remains a governing security/privacy contract, not a roadmap. Its no-durable-relay-data rule supersedes old disconnected-user ban retention proposals. `docs/asset-cache-and-animation-usage.md` and `THIRD_PARTY_ASSETS.md` remain current-reference inputs, but their accumulated amendments must be consolidated against code.

Known drift examples to resolve: animation defaults moved from procedural recipes to licensed Quaternius data; standing is now a static combined pose; idle/fall/landing playback changed; strafe composition changed multiple times; first-person rendering moved from runtime splitting to detached derivatives; XR tracking gained a final modifier pass. Verify current function behavior rather than copying a historical paragraph or pass count. The root README's early feature checklist also needs a current-status audit.

## 2. Proposed documentation tree

```text
README.md                         # Concise introduction, status and docs entry
CONTRIBUTING.md                   # Setup, test-first development, small commits/pushes
CHANGELOG.md                      # Generated release history, not roadmap progress
VERSION                           # Single proposed application SemVer source
THIRD_PARTY_ASSETS.md              # License/provenance entry point
docs/
  README.md                       # Documentation home and audience navigation
  getting-started/
    installation.md               # Supported Godot/build setup and limitations
    desktop.md
    vr.md
    relay.md                      # Client vs dedicated-server flags/presets
  guides/
    accounts-and-profiles.md
    settings-and-voice.md
    worlds-and-instances.md
    friends-and-presence.md
    avatars-and-emotes.md
    troubleshooting.md
  architecture/
    overview.md                   # Ownership and dependency diagram
    startup-and-lifecycle.md
    network-and-admission.md
    persistence-and-security.md
    assets-animation-and-tracking.md
  reference/
    scripts.md                    # Index of documented production modules
    startup.md
    settings-and-voice.md
    identity-and-profiles.md
    friends.md
    client-and-relay.md
    protocol.md
    assets-and-animation.md
    ui-and-scenes.md
    storage-formats.md
    configuration.md
  development/
    testing.md
    documentation.md
    git-and-versioning.md
    releases.md
  roadmaps/
    README.md                     # Status/dependencies/supersession index
    documentation-system-roadmap.md
    ...existing *roadmap.md        # Moved in a dedicated link-safe change
  decisions/
    README.md
    NNNN-short-title.md            # Accepted decision, reason and consequences
```

Start with repository-rendered Markdown; a hosted site is not necessary. Optional local static rendering can be considered later, but must not introduce provider-specific deployment automation. Keep diagrams understandable as text; if rendered diagrams are added, provide an accessible textual explanation.

### Link-safe roadmap migration

1. Inventory every local path/link/anchor pointing at existing roadmaps, including README, AGENTS, docs, tests and source comments.
2. Use `git mv` for root `docs/*roadmap.md` into `docs/roadmaps/` without rewriting their historical content in the same commit.
3. Repair relative links from moved documents, links between roadmaps and external references within the repository. Update glob/path references in guidance; do not move the relay lifecycle contract into roadmaps.
4. Add a roadmap index with status (`planned`, `in progress`, `implemented with limitations`, `superseded`), dependencies, current-reference link and superseding decisions. Completed roadmaps remain historical records, not duplicate manuals.
5. Keep old-path pointer pages only where a known external link needs compatibility; otherwise use the new canonical path. Pointer pages contain no duplicate specification. Check that glob inventories distinguish pointers from actual plans.
6. Run local path/anchor validation before committing and pushing. No broken intermediate migration commits.

## 3. Explain the full runtime, not just individual features

Every architecture page must show ownership, control/data flow, errors and teardown:

- **Startup:** UID main scene resolution; autoload ordering; account/settings/voice initialization; desktop/VR/server selection; relay authentication; surviving local player and world swaps. Warn that normal startup can create real user files; use isolated tests for automation.
- **Client/relay:** custom ENet flow, authenticated connection identity, instance-scoped routing, acknowledged transitions, snapshots/revisions, timeout recovery and disconnected-user erasure. A world URL is not a session ID.
- **Account/social:** key-scoped signed profile and contact stores, verification, ownership checks, local outbox/consent/tombstones, presence versus permission, same-instance profiles versus cached contacts.
- **Settings/voice:** registry → store → UI/application flow; saved mute before capture; input suppression; gain/threshold/buffering; incoming voice isolation; ownership across desktop/VR.
- **Assets:** URL/import → conditional fetch → validation/staging → content hash → index → lease → import → attach. Document no-store, failure fallback, quotas, exact revisions, cache trust and cleanup limits.
- **Avatar/animation:** applied model/source selection, role resolution, static standing, strafe composition, emote interruption, one resolved-state protocol, requested content delivery, generation guards and blend ownership.
- **Rendering/tracking:** full original versus local first-person derivative, VRM annotations/fallback filtering, camera masks, independent camera pose, final head/arm modifier and tracking-loss behavior. Explicitly distinguish local tracker solving from remote tracker synchronization; do not imply full-body IK or validated VRChat parity.
- **UI:** scene ownership, lazily created pages, self versus visitor controls, mouse/focus/shortcut lifetimes, eight-sector paging/group navigation and XR action modes.
- **Security/storage:** exact client-owned files, schema/migration/corruption handling, no relay persistence, executable-world trust, untrusted importer limits, source URL privacy and third-party redistribution rights.

Include sequence diagrams for startup/authentication, admitted world join, source apply/import, automatic motion/emote replication, friendship acceptance and disconnect cleanup. Link each flow to concrete modules/functions and the tests that exercise it.

## 4. Function and class reference standard

Build a machine-readable production-symbol inventory, then review its explanations manually. Scope: `scripts/**/*.gd`, `relay_protocol/**/*.gd` and relevant scenes/configuration; index third-party add-ons as dependencies rather than rewriting their upstream manuals. Exclude generated `.godot`, disposable fixtures, keys and user data. Document test infrastructure separately.

Each module entry includes:

- Path, node/class/base type, owner/lifetime and its collaborators.
- Purpose, state machine, signals, externally meaningful properties and scene node dependencies.
- Every public function's exact signature/defaults, inputs/outputs, sync versus awaited completion, side effects, storage/network writes and expected errors.
- Thread/SceneTree requirements, detached-node ownership, cancellation/generation behavior and cleanup obligations.
- Preconditions and authorization/trust boundaries; examples should not bypass service ownership checks.
- Private functions grouped under the public flow they implement. Explain important algorithms and invariants rather than merely repeating names; retain an inventory link for all private symbols.
- Links to relevant tests and known limitations. A claim of behavior needs implementation/test evidence, not only a roadmap link.

Example entry to fill from verified code:

```text
Module: scripts/startup/data_loader.gd
Function: _build_avatar(buffer: PackedByteArray, path: String) -> Node3D
Purpose: parse/import a detached avatar tree on the worker.
Inputs: bytes or bounded source file, as selected by its awaited import wrapper.
Output/ownership: detached model or failure; caller attaches/releases on main thread.
Side effects: imported mesh/resources and first-person derivatives; no active SceneTree access.
Related: import queue/waiters, generation guards, first-person preparation.
Evidence: tests/avatar_loading; optional real-avatar animation checks.
```

Do not promise exhaustive auto-generated explanations. Inventory/signatures can be generated; behavioral descriptions require review. A lightweight lexer/parser must handle multiline declarations, decorators, nested classes and signals without mistaking comments/strings for functions. Test the inventory generator with fixtures before using its coverage report as a gate.

## 5. Page templates and status rules

**Current guide/reference:** purpose and audience; supported/current behavior; prerequisites; walkthrough or API contract; errors/recovery; security; limitations; source/tests; verified revision/date.

**Roadmap:** status and scope; verified baseline; goal/non-goals; decisions/compatibility; dependent small increments; failing tests and acceptance gates; manual release gates; links to current docs. When implemented, link the reference instead of appending repeated corrections indefinitely.

**Decision record:** context; considered approaches; chosen decision; tradeoffs; compatibility/migration; evidence and supersession. Decisions must record known compromises, such as adapted rather than independently authored strafe motion.

Separate `implemented`, `automated-tested`, `manual-tested` and `planned` claims. Do not promote a synthetic headless pose test into a headset visual guarantee. Treat old recorded pass counts as historical; record exact commands, revision, warnings and skipped groups for new verification notes.

## 6. Local documentation checks

Proposed Python-only commands (not implemented yet):

```sh
python3 tools/docs/check.py
python3 tools/docs/inventory.py --check
python3 tools/versioning/check_commits.py --range <base>..HEAD
```

Checks should cover local files/anchors, source/test references, duplicate navigation IDs, required page metadata and public API inventory coverage. Provide `--changed` for fast author feedback and a full scan for release. Keep external URL checking optional/network-dependent; do not contact arbitrary remote URLs in the default check.

Verify examples against disposable fixtures where practical: configuration formats, packet examples, quoted signatures and CLI flags. Never execute remote world scripts or launch the production account-writing startup merely to validate docs. Add privacy scanning for committed keys/user data with explicit fixtures/allowlists; no automatic deletion.

## 7. Automatic Conventional Commit versioning — local Git only

### Version policy

- Single proposed source: root `VERSION`, strict SemVer. Agree the first baseline explicitly; do not infer a release number from Godot engine version, library revision or old commit history.
- `feat` → minor; `fix` → patch; `!` or a valid `BREAKING CHANGE:`/`BREAKING-CHANGE:` footer → major. Other types alone produce no release. Multiple commits choose the highest impact. Document and test this policy also for `0.x`; do not silently adopt different pre-1.0 rules from a package tool.
- Conventional syntax: `type(scope)!: summary`, optional scope/break marker, body/footers. Validate documented allowed types. Do not classify `docs` as a feature just to bump a version.
- App version and protocol/cache/asset schema versions are different contracts. Never automatically bump packet IDs, capability versions or content hashes when app SemVer changes.
- Final tag format `vX.Y.Z`; optional preview format `vX.Y.Z-dev.N` calculated from a declared base. Preview builds do not move the stable baseline or invent stable tags.
- Branches are not releases: the current `new` upstream may accept incremental work, but release branch eligibility must be explicitly configured. No assumption that `master` or the current feature branch should publish automatically.

### Local commands and Git integration

Proposed standard-library Python tool `tools/versioning/release.py` uses subprocess Git, no network SDK or GitHub tools:

1. `plan --base <tag-or-commit>` resolves an explicit reachable release baseline (or configured initial baseline), reads UTF-8 commit messages from Git, parses Conventional Commits and reports next version and changelog. Default behavior is read-only.
2. `check` validates VERSION/Godot app version consistency, generated changelog and required docs/testing evidence. Read `project.godot`'s application `config/version`; do not modify `config/features`' Godot engine version.
3. `prepare --base ...` requires a clean working tree, computes the same plan deterministically, updates VERSION, app `config/version` and CHANGELOG atomically, then stops for review/testing. No automatic commit/push or tag in a hook.
4. After review and required tests, create a small `chore(release): X.Y.Z` commit with ordinary `git commit`; the bump calculation excludes release-only commits.
5. `tag --version X.Y.Z` checks clean committed state, matching metadata, baseline and duplicate tag, then creates an annotated tag at that exact commit. It must never overwrite tags; signing may be an explicitly configured option.
6. Push the release commit and exact tag with ordinary Git. Prefer `git push --atomic <remote> <branch-ref> <tag-ref>` when supported. On unsupported atomic push or remote rejection, stop and explain recovery; never force or delete remote tags automatically. Normal non-release parts continue to use `git push` to the configured upstream.

Use `git log`'s topological reachable range once; merge commits should not count as extra features merely because their prose resembles a commit title. Validate actual constituent commits where appropriate. Reverts, squash merges, malformed history, shallow clones, missing/ambiguous tags and initial releases need tested explicit policies: do not silently guess a baseline or cancel a reverted feature without tracing its exact commit. An already released commit must not be counted twice.

### Opt-in hooks, not provider automation

- Version hooks live in tracked `.githooks/`; install only through an explicit command setting repository-local `core.hooksPath`. Detect and respect existing hooks/configuration; offer instructions instead of overwriting them.
- `commit-msg` validates the Conventional Commit message and gives a useful correction. It must not amend the message or create commits.
- `pre-push` runs the appropriate local message/docs/version checks for the actual proposed refs. It must handle new branches and tag-only pushes without assuming a remote tracking ref exists. Skip expensive Godot suites only under a documented explicit developer choice, not an invisible bypass.
- Do not auto-increment versions on every commit, run hooks recursively, create tags in post-commit, push from a hook or invoke hosting tools. Deterministic version calculation is automatic; stable release publication is deliberately explicit.
- Local hooks are bypassable and are not a server-enforced guarantee. Document this honestly. Optional ordinary Git server hooks can enforce policy only on servers the owner controls, with separate approval.

### Versioning tests before implementation

Use temporary Git repositories under `/tmp/opencode`: patch/minor/major precedence; breaking footers; scopes/multiline bodies; release-only and docs-only ranges; merges/reverts; prereleases; no initial tag; unreachable tags; shallow clone refusal; duplicate tags; dirty tree; missing upstream; competing remote advance; hook installation with existing configuration; failed checks; tag-only pushes; atomic push rejection; deterministic repeated dry runs. Assert no mutation during plan/check and no secret/account access. Do not test against the real release history or push experimental tags to the project remote.

## 8. Small delivery units and push gates

These are proposed future commits. Commit/push each passing part rather than accumulating one documentation overhaul:

| Part / Conventional Commit | Deliverable | Verification before push |
| --- | --- | --- |
| `docs(navigation): add documentation home and audience map` | docs index, root README links, template/status conventions | Local path/manual content checks |
| `docs(roadmaps): relocate planning documents and repair links` | `git mv` all roadmaps, status/supersession index, repaired references | Link inventory and full local links scan |
| `docs(architecture): explain startup ownership and teardown` | Runtime graph, client/server modes, state/storage/security boundaries | Trace named functions and fixtures against code |
| `docs(guides): document account social and instance workflows` | Small feature-by-feature guide commits, not one giant guide dump | Corresponding isolated suites and examples |
| `docs(avatar): document import rendering tracking and emote flows` | Current asset/animation/reference behavior and limitations | Avatar/animation/cache suites; record optional real-rig/hardware gaps |
| `test(docs): add source inventory and local link fixtures` | Failing test cases for links/symbol parsing/coverage | Disposable fixtures, no real startup |
| `feat(docs): validate links and index production function contracts` | Generator/checker plus reviewed per-module API pages in subsequent small commits | Red-to-green checker tests and repository scan |
| `test(versioning): cover Conventional Commit release planning` | Tests delivered with the minimal working planner in a coherent unit, not a pushed broken suite | Temporary Git repository cases |
| `feat(versioning): calculate SemVer and changelog from local Git history` | Read-only plan, agreed baseline/version policy | All dry-run/no-mutation tests |
| `build(release): prepare version metadata and annotated tags locally` | Prepare/check/tag commands, safeguards, release guide | Dirty/tag/race/recovery fixtures; no real release tag |
| `build(git): add opt-in commit and push checks` | Explicit local hook installer, message/pre-push checks | Existing-hook protection and actual ref-case tests |
| `docs(reference): complete function and release documentation coverage` | Close inventoried gaps, review pages/examples and limitations | Full docs checks, applicable suites; no invented hardware claims |

If a checker and its red tests cannot form independently runnable commits, implement and verify locally before committing the coherent test+fix unit. Never push knowingly failing snapshots to satisfy the “small parts” rule.

## 9. Definition of done

- `docs/README.md` provides clear routes for players, relay operators, contributors and API readers.
- All roadmap plans live under `docs/roadmaps/`, with repaired links and clear history/status; current docs do not require reading a roadmap to understand shipped behavior.
- Every production subsystem and public function has reviewed contracts, side effects, lifecycle/thread/authorization notes and test links. Private flows are indexed and their important invariants explained.
- Protocol IDs/capabilities, storage schemas, settings, scenes and known security/XR limits are discoverable and verified against code.
- Local checks catch broken links, stale symbol inventory and malformed commit/version metadata.
- A clean temporary Git history proves deterministic Conventional Commit → version/changelog calculation and safe prepare/tag behavior, without any GitHub tooling.
- The contribution/release instructions consistently require small verified Conventional Commits and ordinary Git pushes; no force-push, hidden auto-release or unrelated-file staging.
- Installed/implemented functionality is distinguished from this plan. No release workflow, hooks or complete API reference is claimed complete merely because this roadmap exists.
