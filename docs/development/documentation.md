# Documentation conventions

Offline local file/heading checks: `python3 tools/docs/check.py` (or `--changed`
for changed tracked Markdown relative to HEAD).
Checker fixtures: `python3 tools/docs/test_check.py`. Only tracked Markdown is
scanned, excluding vendored add-on manuals. External URLs are not fetched. This
does not validate behavioral reference-page coverage. Production declarations are
indexed with `python3 tools/docs/inventory.py`; run with `--check` to reject drift.
The scanner's fixture test is `python3 tools/docs/test_inventory.py`. Inventory
entries are exact source declarations, not automatically reviewed explanations.

The reviewed [function contracts](../reference/functions.md) cover every named
public function and every production module, with private algorithm/callback
groups. Run `python3 tools/docs/contracts.py` and
`python3 tools/docs/test_contracts.py` for missing/stale section/name checks.
This checks coverage only, not semantic truth: reviewers must still compare
behavior with code/tests. Add a contract entry with any new public function.

Current guides explain supported behavior, prerequisites, errors/recovery,
security and limitations. Architecture pages explain ownership/data flow and
teardown. Reference pages name exact source functions, signatures, outputs,
await/thread requirements, side effects and authorization. Link evidence/tests;
do not infer behavior from a roadmap title.

Roadmaps belong in `docs/roadmaps/`. Mark planned, implemented-with-limitations and
superseded sections explicitly. Keep old plans as history and link current
reference instead of repeatedly appending contradictory amendments.

Function inventories can be generated; explanations cannot be certified from
function names alone. Review public contracts and important private algorithms.
Preserve compatibility spellings in examples. Keep local links relative to the
document; check file and anchor targets before committing.

For verification notes, record command, revision, warnings/skips and hardware
scope. Separate implemented, automated-tested and manual-tested claims. Never copy
historical pass counts as a current baseline or call executable worlds sandboxed.
