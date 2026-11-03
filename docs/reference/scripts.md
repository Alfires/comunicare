# Production declarations

The [machine-readable symbol inventory](symbols.json) records each production
GDScript module's function/class/signal names, source line, visibility convention
and declaration text. Generate/check it locally:

```sh
python3 tools/docs/test_inventory.py
python3 tools/docs/inventory.py
python3 tools/docs/inventory.py --check
```

Scope is `scripts/` and `relay_protocol/`, including nested declarations. The
scanner ignores strings/comments and supports multiline bracketed signatures.
It is not a full GDScript compiler, type resolver or call graph, and line numbers
change with source edits. Godot's isolated import remains the compilation check.
Anonymous functions are not named API entries. Third-party add-on APIs remain
upstream-owned and are excluded from inventory drift checks.

Use [function contracts](functions.md) for all named public production functions,
ownership, threads, errors and side effects; private callbacks/algorithms are
grouped by module lifecycle. `python3 tools/docs/contracts.py` checks module/public
function entry coverage. Inventory presence alone is not an explanation, and a
name-coverage check cannot prove prose correctness. Godot/runtime review remains
required when behavior changes.
