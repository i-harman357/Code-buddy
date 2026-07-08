# Deadpool chibi overlay + speech bubbles

## Goal
Redesign the existing Deadpool desktop-pet character into a chibi-style SwiftUI
drawing (no image assets) and add a speech-bubble system that reacts to
`CheckInEngine` state changes with sarcastic, fourth-wall-aware lines.

## Scope
- `DeadpoolCharacterView.swift` — full visual rewrite to chibi style.
- New `DeadpoolSpeechBubble.swift` — comic bubble shape + pop animation.
- New `DeadpoolLines.swift` — line pools per state + no-repeat picker.
- `PetWindowController.swift` — NSPanel switch, transition detection, drag
  handling, position persistence.
- `PetMovementEngine.swift` — pause/resume around manual drags.
- `ContentView.swift` — toggle label rename only.

Out of scope: Dock-tile rendering path (`DockCharacterController`) keeps
working unchanged — it renders the same `DeadpoolCharacterView`, just smaller
and without the speech bubble (bubble only makes sense on the roaming panel,
which already has a chat window affordance the Dock tile doesn't).

## Visual design
Chibi build, SwiftUI shapes/paths only, palette `#D42B2B` (red) /
`#1A1A1A` (black) / white:
- Big circle head, ~60% of total character height, black outline stroke.
- Two black oval eyes (mask look), white highlight dot in each.
- Tiny body below: red torso capsule, black belt bar, tiny legs, small
  red/black boots.
- One arm raised in a "talking" pose (fixed bent capsule, not toggled).
- Black outline stroke (~1.5–2pt) on every filled shape for the cartoon look.

State still drives motion, not color (unlike Robot/Buddy):
- FLOW: slow idle bob.
- ACTIVE: raised-arm gives a small periodic wave/bounce.
- STALLING: fast side-to-side jitter/shake.
- AWAY: head droops, eyes narrow to slits, "z" drifts up periodically.
- STOPPED: static idle pose, no motion.

Total character height target ~180pt (matches roaming panel's character
region). Dock-tile usage passes a smaller `GeometryReader`-driven size as it
does today — the view is proportional, not fixed-pixel.

## Speech bubble
- Classic bubble: rounded-rect body + small triangular tail (custom `Path`),
  white fill, black stroke (~1.5pt).
- Bold system-font text, dark/black, centered, wraps within a max width.
- Rendered above the character inside the same panel content view (panel
  grows to reserve bubble space; character is bottom-anchored).
- Appears with a pop: scale 0.1 → 1.0 + fade in, spring animation, anchored
  near the tail so it reads as growing out of the character.
- `allowsHitTesting(false)` — never intercepts the character's tap/drag.
- Disappears after 6 seconds. A new line arriving resets the 6s timer rather
  than stacking.

## Lines
Exact pools from the request (FLOW/ACTIVE/STALLING/AWAY, 3–4 lines each) live
in `DeadpoolLines.swift` as `[CheckInState: [String]]`. A `pick(for:excluding:)`
helper avoids repeating the immediately-previous line (falls back to the same
line only if the pool has exactly one entry). AWAY lines containing `[X]` get
that token replaced with the elapsed-away minutes as an `Int`.

Launch greeting ("Wade Wilson reporting for duty...") fires once on panel
install, bypassing the repeat-check (there's no previous line yet).

## Trigger logic
`engine.$state` currently republishes on every 5s poll tick even when the
value hasn't changed. `PetWindowController` will track a local
`lastKnownState` and only fire a new line when the incoming state actually
differs from it — this is the "on state change" trigger the spec describes.
STOPPED has no line pool (silent, as today).

For AWAY, the elapsed-minutes value is read from `engine.idleSeconds` at the
moment of the STOPPED/FLOW/ACTIVE/STALLING → AWAY transition and does not
keep updating live (matches "on state change → pick a line," not a ticking
timer).

## Window, drag, persistence
- `PetOverlayWindow` becomes an `NSPanel` (`styleMask: [.borderless,
  .nonactivatingPanel]`, `isFloatingPanel = true`, `canBecomeKey/canBecomeMain
  = false` override) instead of a plain `NSWindow`, matching "floating
  NSPanel, always on top, no title bar."
- Auto-walk behavior (`PetMovementEngine`) is unchanged and stays on by
  default.
- A `DragGesture` on the character (separate from the existing tap-to-open-chat
  gesture) live-repositions the panel and sets `PetMovementEngine.isPaused =
  true` for the duration of the drag and after it ends.
- The pause clears on the next real state transition (same "state changed"
  check as the line trigger), at which point the walker resumes from wherever
  the character was dropped.
- The dropped position is written to `UserDefaults` (`petManualPosition`) only
  while `isPaused` is true. On next launch, if a saved position exists, spawn
  there (still paused, waiting for a state change to resume walking); if not,
  default spawn is bottom-right of the screen (changed from today's
  bottom-center) as the spec requests.

## Menubar toggle
Rename the `ContentView` toggle label from "Let him roam your desktop" to
"Show Deadpool." Same `state.enableDesktopPet` binding — `PetWindowController`
is already Deadpool-only, so no new state/property is needed.

## Testing
No unit test target in this project (`FatigueConfig`-style logic is tuned by
hand, not tested). Verification is manual: build via Xcode/`xcodebuild`,
launch, confirm greeting fires, confirm each state transition (forced via
debug signals or waiting) shows the correct bubble pool, confirm drag pins
position and auto-walk resumes after a state change, confirm position
persists across relaunch.

## Commit
"Phase 4 — Deadpool chibi overlay with speech bubbles"
