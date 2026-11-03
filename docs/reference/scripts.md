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

Use [service contracts](services.md) to understand ownership, threads, errors and
flows. Inventory presence alone does not mean a function has a reviewed behavioral
explanation; exhaustive per-function contract review remains separate work.
