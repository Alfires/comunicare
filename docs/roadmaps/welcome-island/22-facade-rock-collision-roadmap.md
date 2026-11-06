# Front facade and rock collision

Status: implementation verified with focused house/landscape/route checks.

Front-window regression failed before implementation. Restore glazing in the
app-owned front wall plane, matching the sill/lintel opening and leaving the
four-metre central doorway unobstructed. Each glazing pane has a matching thin
box collider; decorative mullions stay within its footprint.

Rim, underside, shore and meadow rocks gain simple convex proxies fitted to the
transformed source mesh bounds. Bake world-space points into identity-transform
bodies rather than applying nonuniform visual scale to physics bodies. Proxies
are conservative bounding hulls, not exact rock surfaces. Rock removal releases
its collision; scene changes clear all bodies with the island. Existing edge
safety barriers remain unchanged. Route traversal and house entrance/rest tests
must pass with the new physics enabled. Hardware/XR testing remains open.
