# Documentation conventions

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
