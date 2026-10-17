# itch.io page copy for PKSEI

Paste these into the project's Edit page on itch.io. Kept here so the page and the game stay in step. Rewritten 2026-10-17 for the build with Swedish bubbles, names, touch by press height and the obstacle-crowded path; the cover images are in `design/itch/` (upload `thumbnail@2x.png`).

## Title
PKSEI

## Short description or tagline
Four drunk guys, two canoes, one lake. Paddle like an idiot.

## Genre
Action

## Tags (10)
rage-game, difficult, pixel-art, comedy, physics, boat, drunk, swedish, godot, tech-demo

## Custom noun
tech demo

## Embed options
Mobile friendly: on. Automatically start on page load: on. Fullscreen button: on. Viewport 1280×720.

## Community
Comments. The page is a tech demo collecting feedback, so a comment thread at the bottom is enough; a discussion board can come if people show up.

## Description

**PKSEI** is *Paddla Kanot Som En Idiot*, Swedish for "paddle a canoe like an idiot". It is a rage game about four drunk friends, and it is also a tech demo.

### Fyra idioter. Två kanoter. En ö.

Vajking, Tåååny!!, Ryggen, Danne!, Danne?, Göras!, Matte, Bibbe, NakenOlsson, Skrattet, Alkisen and Meh-lajnen: four of them turn up each attempt, lash two aluminium canoes into a catamaran, and set off for an island on the far side of a very long lake. You paddle for all four at once. They drink the whole way, so the boat gets harder to steer the longer the crossing takes, and they never stop talking.

The lake does not help. Logs and rocks crowd the only safe line, geese charge from their nests, motorboat wakes roll in sideways, gusts shove you off course, a jet-ski idiot cuts across your bow, and if you stray toward the edges the Loch-Brez beast comes up and swallows whoever is nearest, spitting him out far behind you. A guy who gets too drunk stands up, drops his paddle, nods off, pees over the side or, at the top of the meter, pukes. A beer knocked overboard means someone jumps in after it, drinks it where he lands ("Ska bara dricka sen kommer jag") and then nags you to come and get him.

Nobody dies. A bad stretch drifts you back toward the shore, drunker than before, and if the boat empties completely it drifts home at five times the speed. The shore is the bottom of the mountain, not a game over. Think *Getting Over It*, on water, with three friends who are no help at all.

### Controls

Each guy has two keys. Hold to wind up, release to stroke. The up key strokes forward and the down key in reverse.

- Left hull: **Q / A** back seat, **W / S** front seat
- Right hull: **O / L** back seat, **I / K** front seat
- **R** restarts the attempt

The outer keys steer, the inner keys propel: the back seats carry most of the turning, so a stroke on the left back seat swings the bow right. The scheme is written in the sand at the launch.

**On a phone** (landscape, please): the screen is split into four pads laid out like the keys, the outer pads for the back seats and the inner pads for the front seats. Press and hold to wind up, release to stroke. A press on or above the line on a pad strokes forward; a press below it, on the down arrow, strokes in reverse. Hold the corner button to restart.

### The tech demo

PKSEI is built with [Godot Director](https://github.com/Freakling/Godot-Director), a workflow where a human directs the game design and an AI agent builds it. Every design call comes to the designer as a question with options, every change has to pass one project check (unit tests, scene loads, screen-script rules), and the records (design document, decisions log, task list) stay the single source of truth. The whole game, code, generated pixel art, generated sound and the Swedish lines, was built this way in a few days of conversation. The source is on [GitHub](https://github.com/Freakling/PKSEI), and the recipe is written up as a [devlog](https://freakling.github.io/Director-Driven-Development/).

Everything you see is being tuned: the numbers, the art, the sounds, the lines. Comments on what feels unfair, funny or broken are exactly what this page is for.

### Where it comes from

Every year the author and a few friends go out camping the way the game does: canoes, a lake, an island, too much beer. The game is the trip with the physics turned up and the nicknames kept.

### Status

Early playable build, keyboard and touch. Known gaps: no settings screen, no sound volume control, no local co-op yet. Mobile layout checked on a browser emulator, not yet on many real phones: say which one you played on.
