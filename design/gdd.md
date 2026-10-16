# PKSEI · Game Design Document

<!-- How this document works
- It states the current design only. History is in git, the reason for each decision is in
  design/decisions.md, and anything undecided is under Open Questions. Agents write down only what
  the human decided.
- Refer to sections by heading ("GDD › Combat"), never by number. Add a subsection rather than
  growing a long one, and delete sections this game doesn't need.
- Say what a number is for and how it should feel; the values themselves live in data/*.tres.
- Engineering conventions live in .godot-director/rules.md, and project-specific ones in AGENTS.md ›
  Project rules, not here.
-->

## Pitch
Four drunk guys have lashed two aluminium canoes into a catamaran and need to reach an island in the middle of the lake. You control all four at once. The lake throws random hazards at them, and they keep drinking, so the boat gets harder to control the longer the crossing takes. Nobody dies: a bad stretch drifts the boat back into water already crossed. A top-down, bright pixel-art rage game in the spirit of Getting Over It and A Difficult Game About Climbing, played for the comedy of watching four idiots fail together.

Genre: action/arcade. Feelings to hit: rage and mastery, with comedy throughout.

## Design Pillars
1. **Hard but fair.** Failure is always the player's fault and readable in hindsight. Rage comes from near-misses, never from randomness the player couldn't see coming.
2. **Four bodies, one brain.** The difficulty is coordination: controlling four guys at once is the game. No single guy is ever the hero.
3. **Drunker is funnier.** Every control-degrading effect must also be funny to watch. Comedy comes from physics and the guys, not cutscenes.
4. **No death, only setbacks.** There is no game over and no restart. A bad stretch drifts the boat back into water already crossed, and the guys keep drinking. Progress is the only thing at stake.

## Core Loop
### Moment to moment
Paddle-timing balance. Each guy paddles or leans on input; the catamaran gains speed, turns and tips from the mix of who paddles when. The player juggles four guys at once while drunkenness makes each one less reliable. Exact inputs: see Open Questions (Q1).

### Session
A sitting is one continuous attempt at the crossing, since there is no restart: the player pushes forward, gets set back, pushes forward again until they reach the island or quit. Target crossing time for the first version: a few minutes for a competent player. The number is a tunable.

### Run / campaign
One lake, one crossing, from the launch shore to the island in the middle. Hazards are randomised per attempt. The first version is a short lake; it grows longer once the loop is proven.

### Starting conditions
Four guys, mildly tipsy, on a calm stretch of water at the shore. Drunkenness climbs with time and beers, so the first stretch teaches control before it degrades.

## Systems
### Catamaran and paddling
Two aluminium canoes lashed side by side, two guys per hull. Paddle strokes on one side push that side forward and turn the boat toward the other; paddling both sides together goes straight. Leaning shifts weight and tips the boat. The physics must stay readable: the same inputs give the same result when the guys are sober (pillar "Hard but fair").

### Drunkenness
Each guy has his own drunkenness level that rises with time and with beers. Higher levels degrade that guy's control and must look funny doing it (pillar "Drunker is funnier"). What the degradation is exactly, and where beers come from, is open (Q4).

### Hazards
Random hazards along the crossing: which ones, and how they are randomised so they stay readable, is open (Q3). Every hazard is visible before it matters, so the player can react (pillar "Hard but fair").

### Setbacks
Nobody dies. A bad stretch sends the boat back into water already crossed, where the player has to re-cross it, drunker than before. What triggers a setback and how far it sends the boat is open (Q2).

### Lake and island
The lake is the level: a launch shore, open water with hazards, and the island at the end. The first version is a single short lake.

## Characters and Units
Four guys. They are the comedy: the bodies the player drives and the thing that goes wrong. Whether they differ from one another (weight, tolerance, personality) is undecided and can wait until the loop is playable.

## Progression and Meta
None planned for the first version. The crossing is the whole game.

## World and Narrative
A lake, four drunk guys, a catamaran made of two canoes, and an island they have decided to reach. No further story.

## Difficulty and Scaling
Difficulty comes from drunkenness, which only rises over the attempt, and from the hazards getting denser toward the island. Numbers for both are tunables.

## Win and Loss
- **Win:** the catamaran reaches the island with all four guys aboard.
- **Loss:** none. Setbacks replace losing (see Setbacks).

## Presentation and Platforms
- Platforms: Web (HTML5, itch.io). Desktop builds for development.
- Target aspect ratios: 16:9 at a 640×360 canvas, integer-scaled (720p, 1080p, 1440p).
- Input: keyboard first (scheme: Q1). Local co-op with one guy per player is a planned mode (Q5).
- Camera: top-down, follows the catamaran, biased toward the direction of travel so hazards show early.
- Art direction: top-down, bright pixel art, a bit retro, lots of comedy. Godot primitives and flat colours until pixel art replaces them.
- Audio: undecided; the comedy will want sound, so plan for stroke, splash and guy noises once the loop is playable.
- Player settings: volume and a fullscreen toggle at least; settings are JSON in `user://`.

## Glossary
| Term | Meaning |
|---|---|
| Guy | One of the four drunk men the player controls at once. |
| Catamaran | The two aluminium canoes lashed together; the boat. |
| Crossing | The run: shore to island on one lake. |
| Setback | Being drifted back into water already crossed. The game's only penalty. |
| Hazard | A random obstacle or event on the lake that pushes, blocks or tips the boat. |

## Open Questions
<!-- Numbered Q<n>, never reused. When one is answered: write the rule into its section, add a line
to design/decisions.md, and delete the question here. -->
- **Q1 · Control scheme.** How do four guys map onto one keyboard, so that it is difficult but learnable? Options to weigh: one key per guy per side; a stroke rhythm; mirrored halves. Gamepads later. Gates the input part of T6.
- **Q2 · Setbacks.** What sends the boat back (capsizing, a guy overboard, drifting into a current) and how far (to the previous area, a fixed distance, or until the boat is righted)? Gates T9.
- **Q3 · Hazards.** Which hazards (logs, wakes, swimmers, geese, currents, wind…) and how they are randomised so they stay readable. Gates T10.
- **Q4 · Drunkenness effects.** What a drunker guy does: input lag, missed strokes, mirrored inputs, wobble, passing out? And whether beers are picked up on the lake or simply drunk over time. Gates the effect mapping in T5.
- **Q5 · Local co-op.** One guy per player: in the first version, or a later mode once single-player is proven?

**Next:** Q6
