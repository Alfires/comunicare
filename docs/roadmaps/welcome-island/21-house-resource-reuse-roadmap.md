# House resource reuse

Status: implemented and focused house/lifecycle/export verification passed.

Reuse unchanged timber materials and furniture source bounds within one house.
Keep tinted floor/shelf/art materials separate so shared-state changes cannot
recolor unrelated geometry. Hoist wall-coordinate transforms out of triangle
loops. Verify reuse, tint isolation, clearance/rest, lifecycle and loading frames.

Reuse assertions failed before implementation. Shared timber, isolated floor tint
and cached furniture bounds now pass alongside house rest/clearance, repeated
entry and exported-pack checks. Rendered streaming passed with a 413 ms worst
frame; this does not demonstrate smoother overall rendering than prior results.
