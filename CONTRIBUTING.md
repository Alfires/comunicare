# Contributing

Use Godot 4.7 and Python 3. Read [repository guidance](AGENTS.md) and the
[documentation home](docs/README.md) before editing. Preserve resource UIDs,
explicit packet IDs, compatibility spellings and client-owned privacy policy.

## Small verified changes

1. Inspect `git status --short`; do not discard or stage unrelated work.
2. For a bug, reproduce it with a failing isolated test before changing code.
3. Fix one coherent behavior with its tests and current documentation.
4. Run applicable [isolated suites](docs/development/testing.md). Record warnings,
   skipped prerequisite groups and manual limitations, not just exit status.
5. Stage explicit paths; review `git diff --cached` and
   `git diff --cached --check`.
6. Commit using `type(scope): summary`, then `git push` to the configured
   upstream for each completed verified part. Do not publish red intermediate
   commits, force-push or rewrite another contributor's work.

Use `feat` for a new capability, `fix` for a correction, `docs` for documentation,
`test` for tests, `refactor` for behavior-preserving restructuring, and `build`,
`chore`, `perf`, `style` or `revert` where appropriate. Real breaking changes use
`!` and an explanatory `BREAKING CHANGE:` footer. Application release numbers
are distinct from protocol, asset-library and storage-schema versions.

Use ordinary Git only for repository integration. No GitHub-specific CLI, API,
workflows or release bots. Hooks must be opt-in, never silently installed.

Never commit account keys, user profiles, caches or downloaded private avatars.
Third-party motion assets require redistribution rights and provenance.
