# RED bone mapping, calibration and optional FBT acceptance

**Implementation update:** current suite passes **39 assertions**, exit 0. The
red baseline below is historical. Validation/calibration/sample-provider/optional
leg-solving primitives exist; player loads owner/avatar calibration and modifier
accepts optional target subsets. Runtime tracker discovery/assignment UI, full-body
calibration workflow, foot planting and smooth per-chain loss fades remain outside
this green suite and are not certified hardware FBT support.

**Intentionally failing roadmap suite.** Run
`python3 tests/avatar_tracking/run.py`; assertion failure exits 1, Godot errors exit
2. No implementation, headset, account, network, real calibration store or tracker
serial is used. Generated poses and temporary device labels are synthetic. Existing
green animation tests are separate and remain unchanged.

Expanded baseline: **11 passed, 7 failed**, exit 1, no Godot errors. As guarded
components are implemented, their detailed assertions will run and the total
assertion count will grow. The two baseline solver checks are not proof of FBT.

The current head/arm solver is exercised for camera independence and reachable
targets. Missing calibration/validity APIs and roadmap components fail explicitly.
Guarded future behavioral checks cover duplicate/missing/zero-length maps,
owner/avatar-scoped calibration persistence and invalid scale, tracker assignment/
expiry/clear, and optional pelvis/feet reach. Missing components cannot silently
turn their dependent assertions green.

Proposed interfaces, chosen for testability (not existing-code claims):

- `humanoid_rig_adapter.gd`: `validate_mapping(skeleton, role_to_bone_name)` returns
  a report with boolean `valid` and diagnostic details.
- `tracking_calibration.gd`: `configure(path, account, avatar_hash)`,
  `save_calibration(dictionary)` returns bool, `load_calibration()` returns validated
  dictionary or empty on incompatible/corrupt owner/avatar state.
- `tracker_role_provider.gd`: `update_sample(ephemeral_id, transform, valid, msec)`,
  `assign(role, id)` bool, `targets(now)` dictionary (samples older than one second
  unavailable), `clear()`; never infer support from an absent tracker.
- `full_body_solver.gd`: `configure(skeleton, mapping)`, `solve(role_transform_map,
  delta)` updates valid subset chains without invalid poses on missing roles.
- Existing AvatarTracking gains `set_calibration` and `set_tracking_validity`;
  `tracking_weights()` returns role → current blend weight for observable fallback.
  Current-code tests now exercise zero-distance, unreachable, vertical and forward
  arm targets, reach bounds, missing opposite-side mutation and finite poses.

Guarded additions also reject wrong arm hierarchy, verify that rejected/invalid
calibration preserves previous bytes/values, prevent duplicate device-role use,
expire invalid samples immediately and permit valid tracker reacquisition. These
do not execute until their components exist; initial baseline counts report only
executed assertions, not future conditional cases.

This is not hardware FBT certification, a finger/face/room-mesh system or a remote
pose replication test. Foot planting/sliding, joint limits, torso fitting, actual
runtime discovery/calibration UI and comfort remain later tests/manual gates.
