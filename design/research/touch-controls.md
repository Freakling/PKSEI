# Research: touch controls

Written for the touch design session on 2026-10-17. A reference note; the decision is in `design/decisions.md` and the current design in `design/gdd.md` › Presentation and Platforms.

## What the engine and the host allow

- **Godot multitouch.** `TouchScreenButton` supports several simultaneous presses out of the box; ordinary `Button` nodes only react to touch with the project's touch-to-mouse emulation on. Raw `InputEventScreenTouch` / `InputEventScreenDrag` carry a finger `index`, so a screen script can track each thumb itself, which is what a pad with hold, release and flick needs. `TouchScreenButton` is a Node2D (no Control anchors), so pads are laid out from the viewport size in code.
- **itch.io on phones.** A mobile visitor always gets "click to launch in fullscreen", whatever the desktop embed settings. iOS Safari has no fullscreen API, so itch.io falls back to a maximised view with the browser bar still visible; iPad does have it, and swipes can leave fullscreen. Android reports of the canvas being cropped or double-scaled are common; keeping the canvas stretch to the viewport (`canvas_items`, aspect keep) and testing on real devices is the known answer.
- **PKSEI's export** already runs without threads, so no SharedArrayBuffer headers are needed on mobile browsers.

## How others put many limbs on a touchscreen

- **QWOP (mobile):** the four limbs are driven by two thumbs moving inside on-screen diamonds; the quadrant picks the limb. Expressive, hard to read.
- **Octodad (iOS / Windows touch):** one thumb per side drives one leg; a two-finger tap switches to the arms; built for a tablet held in two hands. Reviewers found it workable but less confident than a pad.
- The common thread: two thumbs, one side of the screen each, with the position inside the side choosing what the thumb drives.

## The tension for PKSEI

The keyboard lets the player hold four charges at once. Two thumbs cannot. Touch therefore makes "four bodies, one brain" a different problem: which two guys to work right now, and how fast to alternate. That is a legitimate difficulty of its own and keeps the pillar, as long as the mapping is readable.

## Options considered

1. **Hull pads, seat by height, flick to reverse** (chosen). The left half of the screen is the left hull, the right half the right hull. A touch in the upper part of a half charges that hull's front seat, in the lower part its back seat; release strokes forward; a short flick down before release strokes in reverse. One screen script over `RunState.stroke()`; the keyboard stays.
2. **Eight on-screen buttons.** A faithful copy of the keys with multitouch `TouchScreenButton`s. Needs four fingers; fine on tablets, cramped on phones.
3. **QWOP-style diamonds.** Quadrant picks seat and direction. Hard to read.
4. **One pad per hull, both guys stroke.** Simplest, but it strains the pillar.

## Sources
- [TouchScreenButton, Godot 4.4 docs](https://docs.godotengine.org/en/4.4/classes/class_touchscreenbutton.html)
- [How to properly use InputEventScreenTouch for mobile, Godot forum](https://forum.godotengine.org/t/how-to-properly-use-inputeventscreentouch-for-mobile/17278)
- [Uploading HTML5 games, itch.io docs](https://itch.io/docs/creators/html5)
- [HTML5 iPad full-screen issues, itch.io support](https://itch.io/t/4307329/html5-ipad-full-screen-issues)
- [HTML5 game cut off in fullscreen on Android, itch.io support](https://itch.io/t/6707019/html5-game-is-cut-off-in-fullscreen-on-android-but-only-when-launched-from-the-itchio-page)
- [QWOP, Wikipedia (mobile controls)](https://en.wikipedia.org/wiki/QWOP)
- [Octodad: Dadliest Catch review, TouchArcade](https://toucharcade.com/2015/11/09/octodad-dadliest-catch-review/)
- [Octodad touch controls, developer reply on Steam](https://steamcommunity.com/app/224480/discussions/0/540732889613126053)
