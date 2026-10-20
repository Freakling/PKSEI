# Splash
**Opens:** res://scenes/splash.tscn (over the lake in res://scenes/main.tscn) · **Catalog:** splash
**Drawing:** none yet; built from the GDD · **GDD:** Presentation and Platforms

## Purpose
The first thing a player sees: the crew in their catamaran, the title, and a prompt. Any key or a tap fades it away to the launch shore, where play starts. Chiptune music plays while it is up.

## Layout (at 1920x1080)
| # | Element | Name | Where (x, y, w, h %) | Shows | Does | Size |
|---|---|---|---|---|---|---|
| 1 | Backdrop | %Backdrop | 0, 0, 100, 100 | the lake's water, the island small at the top, the catamaran with the four guys a little below the middle, bobbing | - | fills the screen |
| 2 | Title | %Title | 10, 12, 80, 18 | PKSEI, large, cream with a dark outline | - | centred, fit |
| 3 | Subtitle | %Subtitle | 15, 30, 70, 8 | Paddla Kanot Som En Idiot | - | centred, fit |
| 4 | Prompt | %Prompt | 25, 82, 50, 7 | "Press any key" on keyboards, "Tap to start" on touchscreens, blinking | any key, a click or a tap: fade out | centred, fit |

## Navigation
No focusable controls: the whole screen is the button. Any key, mouse button, pad button or touch starts the fade, after a short input guard (a constant, about half a second) so the key that launched the page doesn't skip it. Input during the fade is ignored; nothing reaches the lake until the splash is gone.

## Other sizes
The title, subtitle and prompt stay centred on the canvas; the backdrop fills it. Phones in landscape show the same layout scaled.

## States
- **Up:** music playing, prompt blinking.
- **Fading:** the screen and the music fade out together over about a second, then the splash frees itself.

## Open
None.
