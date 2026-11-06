# Rock hull fit

Status: implemented; landscape physics, routes and streaming checks passed.

Replace bounding-box corner proxies with convex hull vertices derived from the
actual mesh. Cache local hulls per shared mesh, then bake each placement's world
transform. Regression: a sloped tetrahedron must not gain empty box corners.
Verify landscape physics, dry routes and streaming before publication. Convex
hulls still bridge concavities; they are not exact triangle collision.

The sloped-mesh regression failed with the old box-corner proxy and passes with
cached unsimplified convex hull points. Mesh resources themselves are cache keys
so a released instance ID cannot alias another mesh. Each hull is transformed
into the identity physics body's world space, preserving tilted/nonuniformly
scaled rock alignment. No source assets or visible rock poses changed.
