# Profile layout and popup editor roadmap

Scope: original roadmap, now implemented for the display layout, popup URL/text editor and isolated preview. Key-based ownership, same-instance visibility, signatures and popup errors remain intact.

## Implementation status

Preview loading refinement: opening either your own or another same-instance user's profile automatically loads the avatar URL into the isolated preview. No click-to-load step is required. This makes an external media request for visitor avatars; existing download limits and preview isolation still apply.

Latest refinement: avatar column is about **24% of profile width**, transparent viewport/background, with only left/right rotation controls (no visible load/zoom/reset menu). Own previews load automatically; visitor previews load on click/rotation interaction to preserve explicit external-request consent. Name, description, picture and avatar each have their own owner-only Edit button, opening a popup limited to that field. Single-field saves preserve the other profile fields. **95 profile checks pass**.

- Persistent left details / right 3D preview layout, arrow-only Back, picture/name row, description, collapsed full public key and Copy. Owner-only Edit opens one embedded draft popup; visitor view has no inline editing.
- Popup supports name/description/URLs, character count, image/model URL preview, reset picture, Save/Cancel, discard confirmation, revision conflicts and popup errors without draft loss.
- Right-side preview has its own World3D, separate generated model, lighting/camera, bounded resolution, mesh-bounds framing, drag/button rotation, zoom/reset, explicit network load and stale-result suppression. Hiding/closing clears model and stops rendering. Script-bearing/physics/audio trees are refused before entering the preview tree; this is not a full importer sandbox.
- File picker supports **local preview only** for raster pictures and VRM files; selected files are never written to public URL fields or uploaded. Persisted managed local-media overrides/imports remain a follow-up, clearly labeled in the UI. Saved/shared media continues to use URLs.
- Verified: **89 profile checks**, **92 microphone/settings checks**, **75 discovery/startup checks** pass. Layout tested at 640×480 and 1000×700; fake model/image boundaries avoid external downloads and real VRM imports. Full real-model rendering, file-picker behavior in VR and hostile-model/image hardening still require verification; existing VRM addon import errors remain unrelated blockers.

## Target layout

The **3D avatar preview is on the right**, beside all profile details. The left column contains the back arrow, picture/name, description and public-key information.

```text
┌─────────────────────────────────────┬─────────────────────────┐
│ ←                          [Edit]   │                         │
│                                     │                         │
│ [Profile picture]   Display name    │                         │
│                                     │   3D avatar preview     │
│ Description                         │                         │
│ Multiline profile description…      │   [drag to rotate]      │
│                                     │   [zoom] [reset view]   │
│ Public-key fingerprint              │                         │
│ [Show public key] [Copy public key]  │                         │
└─────────────────────────────────────┴─────────────────────────┘
```

- **Back:** simple icon-only left arrow in the top-left; tooltip `Back`, keyboard focus and minimum 48×48 hit area.
- **Picture/name:** picture beneath Back, name immediately to its right. Keep a bundled picture fallback and square image crop.
- **Description:** below the entire picture/name row, with wrapping and multiline support. Show a neutral empty-state label when absent.
- **Avatar:** independent right-hand panel spanning the height of the left content, not underneath it. Use a roughly 55% details / 45% preview starting split, adjustable to actual menu dimensions.
- **Edit:** one button on the left column's top row, opposite Back. Visible/enabled only for the private-key owner. No inline editable fields in the display layout, even for the owner.
- **Public key:** preserve an accessible fingerprint, expandable full read-only key and Copy. Do not let a long key push the avatar off-screen. Never display private key material.
- Keep the Home profile button top-left and microphone top-right; this redesign concerns the profile menu opened by that button.

## Existing code and changes required

| File / component | Current behavior | Planned change |
| --- | --- | --- |
| `scenes/GUI/profile_menue.tscn` | VBox with Back, status and dynamically generated Fields | Persistent two-column scene, left details and right preview. |
| `scripts/GUI/profile_menue.gd` | Renders name/description/URL editors directly on the page | Render a read-only profile snapshot; delegate drafts and editing to a popup. |
| `scripts/profile/profile_service.gd` | Owner checks, atomic validation/persistence, revisions and remote cache | Retain authority; add explicit managed-media support if local imports ship. Never weaken owner checks for file selection. |
| `scripts/profile/profile_media.gd` | HTTPS icon loader, default fallback, stale-request suppression | Reuse for picture display/preview; add safe local-source handling separately. |
| `scripts/startup/data_loader.gd` | Per-request VRM loader used for player avatars | Supply bounded preview requests; preview model must not be the live player's node. |
| `scripts/GUI/error_popup.gd` | Shared error overlay | Reuse above the editor; errors must not dismiss or erase the draft. |

## Phase 1 — Persistent read-only view

Suggested scene structure:

```text
ProfileMenu (Control)
  Content (HBoxContainer)
    Details (VBoxContainer)
      Header (HBoxContainer)
        Back (Button, arrow icon)
        Spacer (Control, expand)
        Edit (Button, owner only)
      DetailsScroll (ScrollContainer)
        DetailsBody (VBoxContainer)
          IdentityRow (HBoxContainer)
            Picture (TextureRect)
            Name (Label)
          Description (Label, wrapping)
          Fingerprint (Label, wrapping)
          KeyActions (HBoxContainer)
          FullPublicKey (TextEdit, read-only, collapsed initially)
    AvatarPanel (PanelContainer)
      AvatarPreview (reusable preview scene)
  EditorOverlay (created once/reused, hidden initially)
```

Use container stretch ratios and minimum sizes, not fixed screen coordinates. The left details scroll independently; long descriptions/keys must not grow the page beyond its bounds. Set shrink/clip/wrapping rules so names and URLs cannot force unbounded widths.

At small supported resolutions, retain the preview **on the right**. Reduce picture/preview minimum widths and use scrolling; do not silently stack the preview below the details. Define a minimum usable menu size and test it on the desktop and VR viewport. Accessibility scaling must not hide Back/Edit.

`open_profile(service, fingerprint)` continues to resolve the view through ProfileService. Missing/departed profiles show unavailable state and a popup error, clear old picture/model/key data and offer Back. Switching from an owner to a visitor must immediately remove Edit and cancel any active owner editor.

## Phase 2 — Isolated 3D avatar preview

Suggested reusable scene: `scenes/GUI/avatar_preview.tscn`, script `scripts/GUI/avatar_preview.gd`.

- Use a `SubViewportContainer` with a `SubViewport`, **own World3D**, preview root, Camera3D, neutral lighting and background. Never insert the live player/avatar into the preview or share its physics world.
- Build a separate VRM instance without microphone, network, movement or player scripts. Preview-only nodes never join player groups, publish profile updates, or change the equipped avatar.
- Calculate finite world-space visual bounds from nested/transformed meshes. Center the model and fit camera distance/near/far planes to the bounds; use safe fallback framing for missing/invalid geometry. Do not assume every avatar has the same height or origin.
- Drag rotates the preview; wheel/buttons zoom within bounds; Reset view restores framing. Input only affects the preview under the pointer/focus, never player camera movement. Include visible controls for VR users rather than relying on a mouse wheel.
- Show loading/empty state in the preview panel. Fetching another user's avatar is an **explicit Load preview** action initially because it accesses an external URL; label this clearly. Owner loading can reuse a validated cached source, but must still produce an independent model instance.
- Preserve byte/time limits and add model complexity limits before treating arbitrary avatars as safe. Loading a Godot/VRM resource is not a sandbox: avoid world scene/script execution and document remaining importer risks.
- Each open/source change increments a request generation. Cancel requests where possible and discard/free stale model results. Closing, leaving the instance, switching profile or destroying the view releases the model, request and viewport resources.
- Suspend viewport rendering while hidden; use update-when-visible/explicit updates rather than continuously rendering a closed menu. Limit preview resolution to its displayed size and a sensible cap.
- Failure keeps a neutral placeholder, offers Retry, and opens the shared error popup once per failed user request. Do not repeatedly raise popups each frame.

## Phase 3 — Owner-only Edit popup

Suggested scene/script: `scenes/GUI/profile_edit_popup.tscn`, `scripts/GUI/profile_edit_popup.gd`.

Clicking **Edit** opens one centered modal overlay, prefilled from the latest saved owner snapshot. The display behind it remains read-only.

```text
Edit profile                                      [×]
Name                 [text........................]
Description          [multiline text..............]
                     [character count.............]
Profile picture      [HTTPS URL...................]
                     [Choose file] [Preview] [Default]
Avatar               [VRM URL.....................]
                     [Choose file] [Preview]
[validation / loading status]
                                  [Cancel] [Save]
```

- Text controls edit name/description; URL fields and Choose file supply image/avatar sources. A picker only appears when the player explicitly requests a file.
- Keep one draft for all fields. Typing, selecting files and previewing never modifies the stored profile or live player.
- Save rechecks private-key ownership and base revision, validates all fields, and calls ProfileService once. Publish/update Home/refresh the visible profile only after a successful durable commit. If saving fails, keep the popup and draft open and report through the error popup.
- Cancel discards draft/temporary previews without touching saved profile, active avatar or network state. Escape first closes the active error/picker, then offers draft discard; it must not also close the underlying profile/menu in the same event.
- A dirty close asks for discard confirmation. Avoid multiple modal layers capturing focus independently; restore focus to Edit when finished.
- Repeated Edit clicks reuse/focus the popup. A visitor has no Edit button; calling popup methods or service saves directly must still reject unauthorized changes.
- If the profile changes remotely/elsewhere during editing, show a revision conflict and offer Reload or Cancel rather than overwriting. Leaving the instance invalidates visitor views; key/account changes close an owner draft and require reopening under the new identity.
- Block microphone/game shortcuts while any modal/picker is active, while text has focus, and during IME entry. Support desktop and existing VR SubViewport input routing; use an embedded overlay rather than relying solely on OS-native windows that cannot render inside VR.

## Phase 4 — URL/text/file source handling

The current signed profile schema supports remote URLs, **not arbitrary local file paths**. File support needs an explicit schema/runtime change rather than storing `file://` in public profile fields.

### Profile picture files

- Allow PNG/JPEG/WebP through an explicit file picker; restrict filters but still validate content, file size and decoded dimensions. Do not accept a file merely because its suffix matches.
- Import a copy into application-managed storage and store a bounded managed reference in a **local media override**, not an absolute OS path. Never delete/modify the user's original file.
- Make local-only status obvious: other players see the default/public URL until a hosting/upload mechanism provides a shareable reference. Do not automatically upload a selected file without consent.

### Avatar files

- Initially support validated `.vrm`, copying to managed storage or loading explicitly selected data through a bounded loader. No arbitrary `.tscn`, `.gd`, executable world archive or untrusted resource-path loading.
- Separate local equipped/preview source from the signed `profile.avatar_url` used by peers. Choosing a local-only avatar must not leak the OS path, publish a bogus URL or silently reset the public avatar. Show `Local only; not shared` and let the owner retain/change their public URL separately.
- If local avatar loading cannot be safely integrated in the first implementation, keep Choose file visibly unavailable with an explanation. Do not add a working-looking button that does nothing or calls the URL loader with a filesystem path.

### Commit and cleanup rules

- Draft imports live in a staging area. Cancel/failure removes only owned temporary files; successful saves move to managed media and update local metadata. Preserve files still referenced by other profile/preview operations.
- Bound cache/staging usage, handle missing files after restart, and fall back safely. Keep local paths and import metadata out of signed public packets and general Settings.
- Local media changes do not alter the account key, profile ownership or same-instance authorization.

## Phase 5 — Integration and tests

Update existing profile tests only where the layout intentionally changes: owner mode now means **Edit is available**, not that inline fields are editable. Preserve service-level ownership, signature, same-instance key visibility and persistence assertions.

Automated tests should use actual scene `_ready()`/input paths with fake media/model boundaries:

1. Back is an icon-only top-left arrow; picture is below it; name is beside picture; description is below both; avatar panel is to the right of the whole details column at supported sizes.
2. Long names/descriptions/full keys do not overlap or displace preview; details scroll and Back/Edit remain reachable. Home mic/profile button placement remains unchanged.
3. Both owners and visitors see a read-only main view. Only owner sees Edit. Direct unauthorized popup/service calls fail; changing viewed account cancels prior draft and removes Edit immediately.
4. Clicking Edit twice creates one popup. Draft prefill, Save, Cancel, dirty discard, revision conflict and write failure preserve the expected stored/live/network state.
5. Invalid URLs/text/files produce the existing error popup above the editor without losing the draft. Success closes/refreshes as designed, not an error popup.
6. Popup/picker/error focus, Escape/Enter, microphone shortcut suppression, IME and VR viewport input do not leak to underlying controls.
7. Preview uses a separate World3D/model instance; framing handles transformed/empty/extreme bounds; rotation/zoom stay local; hidden preview stops rendering.
8. Stale request A cannot replace newer B; closing/leaving clears preview; retries do not duplicate models/signals; failed preview never changes equipped avatar.
9. File picker validation, managed copies, Cancel cleanup, missing-file fallback and no local paths/private keys in public profile packets.
10. All existing authentication, session scoping, departure cleanup, microphone and discovery regressions continue passing.

Manual acceptance: owner/visitor profile, small/large desktop windows, actual VR pointer controls, very tall/small VRM models, malformed/slow media, file-selection cancellation, editing while reconnecting and leaving while a preview loads. Existing VRM addon import errors must be resolved before claiming real model/VR verification.

## Delivery order

1. Persistent two-column read-only layout and positioning tests.
2. Owner Edit popup with text/URL drafts, ownership/revision/error handling and tests.
3. Isolated right-side 3D preview with loading/cancellation/input tests.
4. Managed local file selection and explicit local-vs-shared semantics.
5. Regression, resize/accessibility and desktop/VR verification.

Do not put Profile back into Settings, change account keys, auto-fetch untrusted visitor models without consent, or weaken current privacy/authentication rules during the redesign.
