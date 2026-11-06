# Gentle terrain relief

Status: implemented; focused landscape/render, routes, house, pond and streaming checks passed.

Add low rolling landforms outside the central clearing, routes, house, pond and
social spaces. Use the same height function for visible terrain and collision,
and place streamed vegetation/rock hulls on the resulting surface. Preserve the
flat dock and sealed basin. Check relief, grounded objects and dry traversal;
inspect spawn/grove/overview renders. Do not add external assets or costly canopy.

Added smooth grove/meadow rises, protected flat circulation and the pond quadrant.
Vegetation/grass/ground details use triangle-interpolated terrain height, cached
per grid sample. Visible terrain and collision share the same mesh. The relief
regression failed before implementation; Forward Plus views were inspected.
The pond bank test initially hit newly collidable rocks instead of ground; it now
excludes rock bodies for its terrain-only ray while landscape tests retain real
rock collision/ray checks. Final art and XR review remain open. No new assets.
