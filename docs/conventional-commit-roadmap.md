# Roadmap: small Conventional Commits

## Goal and current status

Split the existing working changes into small, reviewable **`feat`** and **`fix`** commits instead of one large commit. This document is a plan only: it does not stage files, create commits, rewrite history or push anything.

The working tree contains both modified tracked files and substantial untracked code, scenes, tests and documentation. `git diff --stat` alone misses the untracked work. Several systems share the same files, especially `relay.gd`, `network_handler.gd`, `relay_peer.gd`, `packet_info.gd`, `save_data.gd`, `project.godot` and the menu scenes. Do not assign an entire shared file to the first feature and accidentally include every later feature.

## Commit rules

Use:

```text
feat(scope): add a new capability
fix(scope): correct existing broken behavior
```

- **`feat`**: settings registry, profile editing, friendship, presence, new menu/navigation or access modes.
- **`fix`**: blocking avatar import, incorrect relay membership, stale state, data retention contrary to the privacy contract, invalid input, broken copying or an existing layout bug.
- One behavioral purpose per commit; include its necessary protocol/client/relay wiring, scenes, tests and documentation. A feature that needs three cooperating layers can still be one focused commit.
- Do not split merely by file type (`all scripts`, `all scenes`, `all tests`) if that leaves intermediate commits broken. Do not create one commit per arbitrary function either.
- Keep each committed revision importable and its applicable checks green. Tests must accompany the behavior they verify; do not add the full future suite before its dependencies unless explicitly creating a separate red-test branch.
- Keep relevant `.gd.uid` files with their scripts and preserve existing resource UIDs, packet IDs and compatibility spellings. Allocate only the new IDs introduced by that step; never temporarily renumber wire values to make a split easier.
- Every commit is a coherent change, not necessarily a standalone release. Document coordinated client/relay upgrades. Add `!`/a `BREAKING CHANGE:` footer only where an actual compatibility break warrants it; do not guess compatibility from the title.
- Suggested bodies: why the change is needed, important policy/compatibility notes, and the exact checks run. Do not claim hardware verification or historical pass counts as current results.

## Proposed commit sequence

This order follows dependencies. File lists are **areas/hunks**, not instructions to stage the full current files. The titles are proposed commit messages, not claims that these commits already exist.

| # | Conventional Commit title | Small, coherent scope | Verification at that revision |
| --- | --- | --- | --- |
| 1 | `feat(settings): add typed registry and persistent settings store` | `settings_registry.gd`, `settings_store.gd`, relevant `save_data.gd` initialization/migration, registry-backed settings UI and required scene wiring. Preserve corrupt files and legacy settings. | Settings/store/UI portions of `tests/microphone_settings/`; include a runnable focused suite with this step. |
| 2 | `feat(voice): share persistent microphone controls across desktop and VR` | `voice_controller.gd`, capture integration, Home mute button/icons, input-binding registry additions and input map. Persist mute before capture begins. | Microphone/settings runner including mute, fresh-buffer, binding and capture tests. |
| 3 | `feat(profile): add key-owned signed account profiles` | `profile_identity.gd`, `profile_service.gd`, profile initialization/storage and migration in SaveData. Keep profile ownership separate from general settings. | Profile service, signatures, corruption and account-key tests. |
| 4 | `feat(network): authenticate accounts and exchange scoped profiles` | Authenticator, account packets, explicit auth/profile IDs, RelayPeer and relay handlers, coordinator publication and same-instance profile replacement. Include all minimum wire dependencies together. | Real loopback auth/profile checks and relevant discovery regressions. |
| 5 | `feat(profile): add account overview and field-specific editing` | Profile scene/script, edit popup, media helper, error popup, profile icon/Home entry and necessary settings-field removal. A working avatar-preview dependency must be included here or extracted as a prerequisite, never referenced before it exists. | Profile UI/service tests plus microphone/settings regression. |
| 6 | `feat(profile): add independent avatar preview controls` | Preview framing, rotation/zoom, local-file preview and cleanup refinements not required by step 5. If step 5 requires the entire preview already, fold this step into step 5 rather than manufacture a broken boundary. | Profile preview/layout tests. |
| 7 | `fix(network): preserve instance membership until join acknowledgement` | Session result/address packets, explicit create/join identity and URL validation, relay membership lifecycle, staged loader/coordinator transitions and rollback/disconnect behavior. Include required protocol hunk dependencies. | Transition/relay portions of public discovery runner; profile networking regression. |
| 8 | `feat(discovery): browse public instances grouped by world URL` | Public summary encoding, catalog/snapshot separation, browser scene/script, refresh/startup wiring and own-instance filtering. Must use acknowledged joins from step 7, never implicit hosting. | Complete public discovery + startup runner. |
| 9 | `feat(instance): add authoritative active-instance roster and metadata` | `instance_state.gd`, snapshot/request/result protocol, relay roles/revisions, coordinator state, code copying, complete roster/self and profile navigation, metadata Save/Cancel/conflict UI. | Relevant Active Instance state/UI/metadata tests; profile and discovery regressions. |
| 10 | `feat(instance): add kick ban and admin promotion` | Target-bound relay checks, confirmations, eviction cleanup, client-owned moderation policy and admission protocol needed for reconnect bans. **Do not introduce relay-retained disconnected-account bans even temporarily.** | Moderation/admission/voice isolation tests in Active Instance runner. |
| 11 | `fix(relay): erase disconnected-user data across all active state` | Idempotent cleanup, cross-user caches, pending admissions, authored metadata, auth challenge cleanup, relay-mode client-persistence guard, logging cleanup and bounded disconnect detection. Any cleanup necessary to make step 10 safe belongs in step 10; keep only independent hardening here. Include `docs/relay-data-lifecycle.md`. | Lifecycle scans, candidate/moderator disconnect, timeout, fresh-relay/no-write checks and all networking regressions. |
| 12 | `feat(friends): persist public-key contacts and mutual consent locally` | `friend_event.gd`, `friend_service.gd`, signed account-scoped contacts/store/outbox/tombstones, explicit accept/decline/cancel/revoke/block and SaveData initialization. Initially no presence or transport claims. | Local storage/signature/consent portions of friends suite. |
| 13 | `feat(friends): route authenticated friend events between active accounts` | FriendRouter event/receipt routing, capability negotiation and social wire ID 24, RelayPeer transport, client retries and disconnect cleanup. No offline relay mailbox. | Real friend delivery, forgery, reconnect/revocation and relay-cleanup tests. |
| 14 | `feat(presence): share privacy-controlled friend status` | Persistent self preference, live pairwise authorization, Online/Offline/DND, generation/sequence/expiry, subscription cleanup and no retained offline identities. | Presence authorization, hidden/offline/DND, stale updates, disconnect/reconnect tests. |
| 15 | `feat(friends): add Friends tab and profile request actions` | Friends scene/script, local lists and key review, status selectors, user-overview Send friend request, disabled sent/blocked states, profile Back navigation and final tab placement. Keep Friends second. | Complete friends runner and display mode; profile/microphone regressions. |
| 16 | `feat(instance): enforce Friends Friends+ and Request access modes` | Fresh active friendship-edge authorization relative to current admins, one extra hop for Friends+, authenticated code lookup, explicit Allow/Decline with expiry/revalidation, join coordinator and mode selector. Existing bans still apply. | Real mode-specific friend/access tests, Active Instance request rows, discovery regressions. |
| 17 | `fix(avatar): move model import off the frame thread` | Worker import/queue/join ownership in DataLoader, awaited URL/local-preview callers, generation guards, keeping old remote avatar on failure and URL-change guards. Include profile refresh avoidance if treated as part of the same blocking-load bug. | Avatar loading runner and profile/voice/network regressions. |
| 18 | `feat(home): add dashboard grid and shared World Explorer navigation` | Final layout only: Home/Friends/World Explorer/Settings tabs; expanding Home 2×2 grid below status; Explorer tile selects shared tab, Active Instance opens lazy Home subpage, two empty placeholders; Back/focus/reset/subscription cleanup and desktop override removal. Do not commit obsolete intermediate tab layouts. | Home/profile layout/navigation tests at both sizes; friends tab-order tests; discovery startup; display checks. |

### Optional smaller fixes

Use separate commits only if they remain independently reproducible and useful after the feature split:

- `fix(instance): keep confirmation dialogs within small viewports` — wrapping fingerprints, bounded dialogs and long-name clipping with display tests.
- `fix(profile): avoid reloading unchanged avatar previews` — isolate from step 17 only if its synchronous/asynchronous loader boundaries remain valid.
- `fix(protocol): reject malformed account JSON without runtime errors` — bounded quiet parsing and hostile-input tests; place before the first dependent social tests.

Do not duplicate these same hunks in both the parent feature and a follow-up fix. Combine overlapping items when extracting them would make a meaningless commit.

## How to assemble the commits safely

### 1. Inventory before staging

```sh
git status --short
git diff --stat
git diff --name-only
git ls-files --others --exclude-standard
```

Review untracked directories individually, including `docs/`, `tests/`, icons and UID companions. Existing unrelated work is not cleanup material. Confirm which changes belong in this series before committing them.

### 2. Build coherent boundaries

- For a file that belongs entirely to one commit, stage that explicit path only.
- For a tracked shared file, use `git add -p -- <path>` to select only the relevant hunks. Closely interleaved hunks may need deliberate staged-content construction; do not use broad adds as a shortcut.
- New/untracked shared files cannot safely be treated as ordinary whole-file additions if they already contain later features. Prepare and verify the appropriate earlier version in an isolated assembly workspace, or combine dependent steps into a slightly larger coherent feature commit. Do not overwrite the user's current working file or use reset/checkout to discard it.
- `project.godot` translation inputs, enum additions, autoload hooks, fixtures and scene references must follow the feature that first needs them. Settings/profile/friend and instance-related code in SaveData must be staged separately.
- No blanket `git add .`, broad reset, automatic file deletion or mass rewriting to force the plan.

### 3. Verify the candidate snapshot, not just the full working tree

```sh
git diff --cached --stat
git diff --cached --name-status
git diff --cached --check
git diff --cached
```

Tests passing in the complete current working tree do **not** prove an earlier partial commit works: unstaged dependencies may hide mistakes. Export the staged index into a new disposable directory (for example a unique directory under `/tmp/opencode` using `git checkout-index --prefix=<directory>/ -a`) and run that snapshot's applicable isolated runners there. This export writes a separate copy, not a checkout/reset of current work. Do not reuse a directory containing unrelated files. Test fixtures must contain only the behavior/dependencies available in that snapshot.

Only after explicit authorization to create commits, commit the verified staged unit using its `feat` or `fix` title. Repeat in dependency order, checking the remaining unstaged/untracked diff each time. If a boundary cannot be tested without the next change, adjust the boundary instead of recording a knowingly broken revision.

### 4. Final verification and publication

At the final assembled revision, run:

```sh
python3 tests/microphone_settings/run.py
python3 tests/profile/run.py
python3 tests/public_discovery/run.py
python3 tests/active_instance/run.py
python3 tests/friends/run.py
python3 tests/avatar_loading/run.py
python3 tests/active_instance/run.py --display
python3 tests/friends/run.py --display
```

Display commands require a real desktop display. These runners do not prove headset/controller behavior, physical microphone/listening quality, production-size avatar GPU performance or the full XR stack. Record errors, warnings and skipped groups rather than copying old pass counts.

Inspect the final commit sequence and remaining diff, confirm no account keys/settings/generated screenshots or real user data are included, and confirm the combined commit content matches the intended changes. Creating local commits is separate from publishing: **do not push unless requested**, and never force-push/rewrite existing published history merely to match this roadmap.

## Documentation and tests policy

Attach each roadmap's implementation updates, its tests, fixtures and runner changes to the corresponding feature/fix. Add this planning document and applicable `AGENTS.md` guidance alongside the first relevant authorized unit, or use the repository's normal documentation commit type if the user later permits types beyond `feat`/`fix`. Do not mislabel a documentation-only change as a code fix just to satisfy a rigid two-type rule.

The aim is readable, working increments—not a prescribed number of commits. Merge tightly coupled steps or split independent fixes when evidence supports it, while keeping feature behavior, safety invariants and tests intact.
