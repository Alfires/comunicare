# Menu, VR tablet and color schemes

The main menu is the same tablet-style layout on PC and in VR. Its exact sizes,
colors and texts are fixed in the
[GUI tablet specification](../roadmaps/gui-tablet-specification.md).

## Layout

- **Status bar** (top): your profile picture, friend presence (Online, Do not
  disturb, Appear offline), the current instance with its access mode and
  number of people, the microphone button, the clock and Close. In VR it also
  has a pin button.
- **Navigation rail** (left): Quick, Friends, Worlds, Avatars, Instance and
  Settings.
- **Quick page**: Mute, Emotes, Change avatar, Invite, Respawn and Mirror, plus
  the friends who are online right now.

Nested pages such as a profile get a Back button in the page header. Short
confirmations ("Avatar changed.", "Instance code copied.") appear as
notifications at the bottom and disappear on their own.

## PC

- **Esc** opens the menu on the Quick page. Inside a nested page Esc goes back
  first; on a top-level page it closes the menu. Clicking the dimmed game
  around the menu also closes it.
- **1–6** switch between the rail pages while no text field is focused.
- The menu is a fixed 2D panel in the middle of the window. On small windows
  it fills the window height and the rail shows icons only.

## VR tablet

- Press the menu button (A/X by default, see
  [VR controls](vr-controls.md)) to open or close the tablet. It appears about
  55 cm in front of you, slightly below eye height and tilted toward you.
- **Hold** the menu button for 0.6 s to bring the tablet back in front of you.
  A short press still opens or closes it; an open tablet only closes when you
  release the button.
- **Move it:** hold **grip** with a hand on the tablet's frame, or while your
  pointer is on the status bar, and move the hand. Release grip to leave it
  floating. Grip with both hands and move them apart or together to resize it
  (0.6× to 1.6×). Near the tablet frame, grip moves the tablet instead of
  picking up world items.
- Next time you open it, the tablet appears where you left it, relative to your
  position and facing direction.
- **Pin button:** pinned (default) keeps the tablet where you put it; unpinned
  lets it follow your view when you turn more than 45° away.
- Point with either controller and pull the trigger to press buttons, or turn on
  **Touch the tablet with the controller tip** to press by touching the screen.
- Settings → VR Menu: Tablet placement, Tablet size, touch input and Tablet
  side (left, right or centered). Tracker setup and the comfort preset are in
  Settings → VR Comfort.

## Color schemes and size

Settings → Interface:

- **Color scheme:** Graphite (default), Paper, Forest, Sand, Night and High
  contrast. Every scheme keeps body text at a contrast of at least 4.5:1
  (7:1 for High contrast).
- **Accent color:** Teal, Blue, Amber, Green, Rose, Violet, or Match 3D
  highlight, which follows "Selectable item highlight color".
- **Corner roundness:** Square, Subtle (default), Rounded or Round. Applies to
  buttons, panels, cards and the tablet frame; round chips stay round unless you
  choose Square.
- **Interface size:** 0.75× to 1.5×, for desktop menus and the VR tablet.
- **Reduce motion:** turns off easing for the tablet, menus and the avatar
  preview.

Changes apply immediately without a restart.

## Friends page

- **Search** finds contacts by name or fingerprint.
- **All / Online / Requests** filters the list. Requests shows how many incoming
  requests are waiting.
- Contacts are grouped (Friends, Incoming requests, Outgoing requests, Saved
  contacts) with a count per group; online friends come first.
- Each contact has one main button (Join friend, Accept, Cancel request, Send
  friend request or Unblock) and a **…** menu for View profile, Remove friend,
  Delete contact and Block. Removing, deleting and blocking ask for confirmation.
- **Add public key** opens a form: paste their public key, check the fingerprint,
  then send a request or just save the contact.

## Avatar preview

Drag to turn the avatar, right-drag to move the view, scroll to zoom and
double-click to reset. The toolbar (on hover on PC, always in VR) opens a local
VRM file for preview only, cycles full body / upper body / face framing,
resets the view and shows a relaxed pose instead of a T-pose.
