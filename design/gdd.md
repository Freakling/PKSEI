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

Genre: action/arcade. Feelings to hit: rage and mastery, with comedy throughout. Reference research: `design/research/rage-games.md`.

## Design Pillars
1. **Hard but fair.** Failure is always the player's fault and readable in hindsight. Rage comes from near-misses, never from randomness the player couldn't see coming.
2. **Four bodies, one brain.** The difficulty is coordination: controlling four guys at once is the game. No single guy is ever the hero.
3. **Drunker is funnier.** Every control-degrading effect must also be funny to watch. Comedy comes from physics and the guys, not cutscenes.
4. **No death, only setbacks.** There is no game over and no restart. A bad stretch drifts the boat back into water already crossed, and the guys keep drinking. Progress is the only thing at stake.

## Core Loop
### Moment to moment
Charge-and-release paddling against a constant current. Each guy has one key: hold to wind up, release to stroke, with no on-screen meter; the power of the stroke comes from how long the key was held. The boat gains speed, turns and wobbles from the mix of who strokes when and how hard. Strong strokes burn a guy's stamina, so the player balances power against stamina for each guy. The player juggles four wind-ups at once while drunkenness makes each guy less reliable, and the current pulls the boat back toward the shore whenever the strokes stop.

### Session
A sitting is one continuous attempt at the crossing, since there is no restart: the player pushes forward, gets set back, pushes forward again until they reach the island or quit. Target crossing time for the first version: a few minutes for a competent player. The number is a tunable.

### Run / campaign
One lake, one crossing, from the launch shore to the island in the middle. Hazards are randomised per attempt. The first version is a short lake; it grows longer once the loop is proven.

### Starting conditions
Four guys, mildly tipsy, on a calm stretch of water at the shore, with a crate of beer aboard. Drunkenness climbs with time, faster while a guy is on a break or floating in the water, so the first stretch teaches control before it degrades.

## Systems
### Catamaran and paddling
Two aluminium canoes lashed side by side, two guys per hull: a front and a back seat on each. A stroke on the left turns the boat to the right and a stroke on the right turns it left, as with an outboard at the stern; strokes on both sides together go straight. Stroke power grows with how long the guy's key was held, up to a cap; a tap is a weak stroke, a long hold a strong one. A strong stroke burns more stamina (see Stamina).

**Seats matter.** All four seats give the same forward push, but steering comes mostly from the back: a back-seat stroke turns the boat about four times as much as a front-seat stroke (the shares are tunables, meant to feel like 80/20). The front seats are the engine and the back seats the rudder, so which drunk guy sits where matters. The catamaran never capsizes: a wobble is cosmetic. A constant current runs from the island toward the shore, so a boat nobody paddles loses water. The physics stays readable: the same strokes give the same boat when the guys are sober (pillar "Hard but fair").

### Drunkenness
Each guy has his own drunkenness level. It rises with time, as the guys drink from the crate, faster while a guy is on a stamina break, and faster still while a guy floats in the water drinking the beer he went in after. Rising drunkenness degrades that guy's control in three tiers, each visible on the guy himself (pillar "Drunker is funnier"):
- **Lag and misses.** A drunker guy's stroke lands later after the release, and sometimes not at all; the fumble shows in his animation. Delay and miss chance rise with the level.
- **Antics.** At drunkenness thresholds a guy does something stupid, always with a visible wind-up and a recovery: he stands up and rocks the boat, drops his paddle and has to fish for it, or nods off as dead weight.
- **Scrambled keys.** Only at the top tier, a guy's key stops being his: announced with a wind-up, shown on screen next to him, and steady until he sobers up or the boat is set back. The player can see it and adapt, so the pillar "Hard but fair" holds.
Input is always honoured instantly in the animation; what the drunk body then does with it is the comedy.

### Stamina
Each guy has his own stamina. Every stroke burns some, more for a stronger stroke, and it recovers while he rests between strokes. When a guy is burnt out he takes a **break**: he stops paddling for a few seconds, his seat gives no strokes, his stamina recovers quickly, and he cracks open beers faster, so his drunkenness climbs. He may also take a break before he is burnt out: the chance rises with how much stamina he has burnt. Every break, forced or random, is telegraphed on the guy a second or two in advance, so the player can see it coming and compensate with the other three (pillar "Hard but fair"). The player's trade-off is power now against a break later, four times over.

### Hazards
Random hazards along the crossing. Every hazard is visible, or audibly announced, before it matters, so the player can react (pillar "Hard but fair"). Hazards combine: a wake or a gust can push the boat into a log or a flock, and that is intended.

**Effects** a hazard can have, alone or combined:
- *Beer overboard* on the side hit, which starts a Rescue (see Setbacks).
- *Shove*: a push to the boat's position or heading. Costs water and steering, no guy lost.
- *Snag a paddle*: one seat gives no strokes for a few seconds, the same shape as a stamina break.
- *Stop the boat*: speed to zero on a hard hit, harsh against the current.
- *Force a stamina break*: the hit guy takes a break on the spot and drinks. Available to hazards; none uses it yet.
- *Water aboard*: the boat takes on water, and the guy on the side it came in stops paddling to bail until it is out. More water, longer bailing.

**The set** for the first lake:
| Hazard | Telegraph | What it does |
|---|---|---|
| Floating log | Drifts toward you with the current | Bump: beer overboard on the side hit, and a shove that kills speed |
| Angry geese | A flock guarding goslings; hissing and raised wings as you near them | They charge the boat and peck: beer overboard. They give up and return after a few seconds |
| Rock or buoy | Fixed, visible from far off | Hit: stop the boat, beer overboard |
| Fishing line | A fisherman in a dinghy, the line visible across the water | Crossing it snags the paddle on that side for a few seconds |
| Motorboat wake | The motorboat crosses ahead first, then its wave rolls toward you | Head-on: nothing. Broadside: beer overboard on the high side, a sideways shove, often into something else, and water aboard, so a guy bails |
| Wind gust | Ripples race across the water a second ahead | A sideways shove for a few seconds, compounding with the current |
| Harsh wind | A stretch of whitecaps ahead | A sustained headwind where only strong strokes make progress: a stamina-management test, too hard a push and the breaks come |
| Cross-current stripe | A visible band of faster water | Pushes sideways or backward while the boat is in it |
| Jet-ski idiot | Loud from offscreen, then crosses your path on a straight line at speed | Hit: a hard shove and a beer overboard |

**Placement.** The lake is a series of bands from shore to island. Each band draws its hazards from a weighted list, with a density that rises toward the island, from one seed per attempt: reproducible for testing, different between attempts. The density curve and the weights are tunables.

### Setbacks
Nobody dies and the boat never capsizes. The setback is the **Rescue**: a hazard knocks a beer overboard, and a guy jumps in after it. The beer drifts with the current; he swims to it, and once he has it he floats, drifting with the current and drinking it. He never swims back on his own. Every guy in the water is one paddler fewer, so the boat is slower and harder to steer while the current drifts it back toward the shore. The player has to paddle to each swimmer and pick him up; there are no calm areas that stop the drift, so the water lost is however much the recovery cost, and the longer he floats the drunker he comes back.

There is no limit on how many guys can be in the water. The cascade is the point: one guy gone makes the crossing much harder, two makes it close to impossible, and with all four in the water nobody paddles and the boat drifts home. **Shore reset:** when the boat drifts all the way back to the shore, with or without anyone aboard, the attempt returns to its Starting conditions: everyone aboard, mildly tipsy, stamina full, progress zero. It is the bottom of the mountain, not a game over.

### Lake and island
The lake is the level: a launch shore, open water with hazards and the current, and the island at the end. The first version is a single short lake.

## Characters and Units
Four guys. They are the comedy: the bodies the player drives and the thing that goes wrong. Whether they differ from one another (weight, tolerance, personality) is undecided and can wait until the loop is playable.

## Progression and Meta
None planned for the first version. The crossing is the whole game.

## World and Narrative
A lake, four drunk guys, a catamaran made of two canoes, a crate of beer, and an island they have decided to reach. No further story.

## Difficulty and Scaling
Difficulty comes from drunkenness, which only rises over the attempt, from the constant current, from stamina breaks that get likelier the harder the player pushes, from the rescue cascade (each swimmer makes the next rescue harder), and from the hazards getting denser toward the island. Numbers for all of these are tunables.

## Win and Loss
- **Win:** the catamaran reaches the island with all four guys aboard. A cutscene follows: the boys step onto the island, make camp and drink more. The crossing ends there.
- **Loss:** none. Setbacks replace losing (see Setbacks).

## Presentation and Platforms
- Platforms: Web (HTML5, itch.io). Desktop builds for development.
- Target aspect ratios: 16:9 at a 640×360 canvas, integer-scaled (720p, 1080p, 1440p).
- Input: keyboard, four keys, one per seat, hold to charge and release to stroke: Q left front, A left back, I right front, K right back. The left hand drives the left hull and the right hand the right hull. Local co-op with one guy per player is a planned mode (Q5); there each player gets two keys, stroke and lean.
- Camera: top-down, follows the catamaran, biased toward the direction of travel so hazards show early.
- Art direction: top-down, bright pixel art, a bit retro, lots of comedy. Godot primitives and flat colours until pixel art replaces them. Telegraphs come first: every wind-up and hazard warning gets its pixel animation before any decorative art.
- Audio: telegraphs first. Sound announces hazards before they are visible: a motorboat engine before its wake, a jet-ski heard from offscreen, geese hissing, wind rising before a gust or a headwind stretch. Then stroke, splash and guy noises for the comedy. Silent until the audio stage.
- Player settings: not decided yet; when they come, they are JSON in `user://`.

## Glossary
| Term | Meaning |
|---|---|
| Guy | One of the four drunk men the player controls at once. |
| Seat | A guy's place on the boat: left or right hull, front (engine) or back (rudder). |
| Catamaran | The two aluminium canoes lashed together; the boat. It never capsizes. |
| Crossing | The run: shore to island on one lake. |
| Current | The constant pull from the island toward the shore. The game's gravity. |
| Rescue | The setback: a guy in the water after a drifting beer, one paddler fewer, the boat drifting until he is picked up. |
| Shore reset | The boat drifting all the way back to the shore: everyone aboard, sober-ish, full stamina, start over. |
| Hazard | A random obstacle or event on the lake, always telegraphed; most knock a beer overboard. |
| Band | A stretch of the lake, shore to island; hazards are drawn per band with rising density. |
| Bailing | A guy scooping water out of the boat instead of paddling, after a hazard put it there. |
| Antic | A telegraphed stupid thing a drunk guy does: stands up, drops his paddle, nods off. |
| Stamina | A guy's reserve for strong strokes. Burnt by paddling, recovered by resting. |
| Break | A guy's telegraphed pause of a few seconds: no strokes, fast stamina recovery, faster drinking. |

## Open Questions
<!-- Numbered Q<n>, never reused. When one is answered: write the rule into its section, add a line
to design/decisions.md, and delete the question here. -->
- **Q5 · Local co-op.** One guy per player with stroke and lean keys: in the first version, or a later mode once single-player is proven?

**Next:** Q7
