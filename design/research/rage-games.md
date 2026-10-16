# Research: what makes a good rage game

Written for T7 on 2026-10-16. A reference note, not design: the decisions it led to are in `design/decisions.md`, and the current design in `design/gdd.md`. Sources are web reviews, interviews and one dissertation; the games' own designers are quoted where a primary source was found.

## The reference games

| Game | Input | What loses progress | How far back | Why it reads as fair | Where the comedy is |
|---|---|---|---|---|---|
| **Getting Over It** (Foddy, 2017) | Mouse moves the hammer; the body follows | Any fall; no checkpoints, aggressive autosave so there is no save-scumming | Anywhere from a ledge to the very start | Deterministic physics: the hammer only goes where the player put it. "You always put it there." | The body, the pot, the narrator's calm commentary on your failure; a streaming hit because the failure is the show |
| **A Difficult Game About Climbing** (Pontypants, 2024) | Mouse, two hands | Falling | To the body of water at the start of the current area, never to the start of the game | Simple controls, "hard but fair" in most reviews; the one complaint is jumps that need one exact mouse motion | Flailing hands, the splash |
| **Jump King** (Nexile, 2019) | Hold to charge, release to jump; no meter; no mid-air control | A missed jump | Two or three screens, sometimes near the start; progress and setbacks are both saved | One verb "in one of its truest forms" (Felix Wahlström); the charge is learnable by feel, and the fall is the player's own jump | The stoic knight's long fall |
| **Pogostuck: Rage With Your Friends** (2019) | Rotate and jump only | Falling; no checkpoints; hours can go in one slip | As far as you fall | Two inputs, consistent physics; mastery is possible | Co-op tethers players together, so a friend's mistake is yours too |
| **QWOP** (Foddy, 2008) | One key per thigh and calf, four keys for one runner | Falling over | Back to the start of the 100 m | Nothing is random; the body does exactly what the keys say | Bad controls on purpose: slapstick from doing something familiar (running) the hard way |

Two adjacent games matter for PKSEI's "four bodies" and "funnier" pillars:

- **Octodad: Dadliest Catch** (Young Horses, 2014). The design post-mortem is the best primary source on awkward-but-funny control. Lessons it states: keep the *input* tight and responsive and let the *body* produce the chaos; add invisible help so physics never traps the player; warn before the penalty, because punishment the player could not see coming feels unfair; "the real issue was punishment, not difficulty": time pressure and loss states removed the humour, and the fixes replaced them with slapstick; do not let the designers' own skill set the difficulty, test with fresh players and act on it.
- **Heave Ho** (Le Cartel, 2019). Co-op physics with hands only. Falls are instant respawns, so reviewers report laughter rather than rage; the fun is the chain of friends who fail together. Shows that setback *size* is the dial between comedy and rage.

## What the sources agree on

1. **Frustration is designed, not tolerated.** Foddy treats frustration as a legitimate emotional register, and "griefing the player" as the point. A 2026 University of Porto dissertation on rage games ("No Pain, No Game", Hugo Ramos) names three patterns: Emotional Contradiction, Hostile Layout, Cathartic Payoff.
2. **Fairness is the dividing line.** Every praised rage game has deterministic physics and few inputs; every complaint is about an input that didn't do what it said or a penalty the player couldn't see coming. Minimal randomness, consistent controls, masterable levels.
3. **Lost progress is the penalty, never a game over.** None of the five has a death or a timer. Progress and setbacks both persist, which is what makes the sunk cost bite.
4. **Setback size is tuned per game.** From "all of it" (Getting Over It, Pogostuck) through "two or three screens" (Jump King) to "start of the area" (A Difficult Game About Climbing). The softer floor is the newer design and still reads as a rage game.
5. **One verb, distilled.** Jump King is a charge-and-release; QWOP is four keys; Pogostuck is rotate-and-jump. Depth comes from physics and the level, not from more inputs.
6. **The failure is the entertainment.** All five are streaming games. The failure has to be legible from across the room, with a body that reacts.
7. **Comedy dies with time pressure and loss states** (Octodad). Pacing should come from the mechanic itself.

## Principles for PKSEI, checked against the pillars

1. **The player always put it there.** Physics is deterministic; the same strokes give the same boat. Drunkenness changes *when* and *whether* a guy's stroke lands, in ways the player can see coming, and never randomises the outcome of a stroke that did land. (Hard but fair)
2. **One verb: the stroke.** Each guy has one input. Depth comes from timing four of them against the boat's physics. No extra verbs until the stroke is mastered. (Four bodies, one brain)
3. **Setbacks are spatial and persistent.** The only penalty is water re-crossed. Position is saved continuously; there is no restart and no timer. (No death, only setbacks)
4. **Areas with soft floors.** The lake is a chain of stretches. A setback costs the current stretch, never the whole crossing. The stretch length is the rage dial and a tunable. (No death, only setbacks; Hard but fair)
5. **Warn before the penalty.** Every hazard and every tip-over is telegraphed before it costs anything: a visible hazard ahead, a wobble before a capsize, a stagger before a guy does something stupid. (Hard but fair)
6. **Tight input, chaotic bodies.** The key press is always honoured instantly in the animation; what the drunk body then does with it is the comedy. Chaos lives in the follow-through, not in the input. (Drunker is funnier; Hard but fair)
7. **Failure is the show.** Every setback has a visible, physical cause that reads at a glance, for the player and for anyone watching a stream. (Drunker is funnier)
8. **Fresh players set the difficulty.** The team's own skill is never the yardstick; the playtest template's scores are. (process rule, serves Hard but fair)

## Proposals for the open questions

The human decides; these are options with one recommendation each. Numbers are tunables, not values.

### Q1 · Control scheme (four guys on one keyboard)
- **A. One key per guy, tap to stroke.** Four keys, one per seat (two per hull). A tap is one stroke at fixed power; each guy has a short recovery before his next stroke. Equal strokes on both hulls go straight, uneven strokes turn, bursts tip. No leaning in the first version; tipping emerges from imbalance. *Build:* Paddling (T4) as designed. *Serves* Four bodies, one brain (coordination is the whole skill) and principle 2. *Co-op:* trivially one key per player (Q5).
- **B. Charge and release per guy.** Same four keys, but hold to wind up and release to stroke; power from hold time, no meter (Jump King). Harder to learn, more expressive, and drunkenness has a second thing to corrupt (a guy who holds too long). *Build:* T4 plus a charge model. *Strains* readability: four invisible charges at once is a lot to track.
- **C. Stroke and lean, two keys per guy.** Eight keys. The most control and the most difficulty, but 8 keys on one keyboard is a hand-position problem before it is a game problem; better suited to co-op. 
- **D. Mouse drags strokes.** One pointer, drag on a guy to stroke him. Getting Over It lineage, but one pointer for four guys serialises the coordination and loses the "all at once" feel.

**Recommendation: A.** One verb distilled; the boat's physics and drunkenness supply the depth; it is the scheme that most directly makes four-at-once the game, and it maps onto co-op without change. B can be a later escalation if A proves too easy.

### Q2 · Setbacks (what sends the boat back, and how far)
- **A. Stretch reset.** The lake is a chain of stretches marked by buoys or landmarks. Capsizing (or losing a guy overboard beyond a recovery time) returns the boat, upright and with everyone aboard, to the start of the current stretch. Clean, fair, a fixed cost. *Build:* Setbacks + RunState.
- **B. Continuous drift.** No stretches. A capsized boat drifts backward with the current until the player rights it by coordinated strokes, so the cost is however long recovery takes, sometimes the whole crossing. Purest Getting Over It, maximum rage, hardest to keep fair when drunk.
- **C. Drift with soft floors.** B's drift, but the lake has calm areas where a drifting boat stops. The cost is proportional to how fast you recover, capped at the previous calm area. This matches "reset to previous areas" and keeps rage within tolerable bounds. *Build:* Setbacks + lake areas + a righting interaction.

**Recommendation: C.** The size of the loss stays the player's own (how fast they recover) while the floor stops a drunk late-game capsize from erasing the crossing, which is principle 4.

### Q4 · Drunkenness effects (what a drunk guy does to control)
- **A. Timing only.** A drunker guy's stroke lands later, and sometimes not at all, with the delay and miss chance rising by level. The fumble is visible in the animation. Drinking is time-based only. Fair and simple; the comedy is quieter.
- **B. Timing plus telegraphed antics.** A's lag ramp, and at drunkenness thresholds a guy does something stupid, each with a visible wind-up and a recovery: stands up and tips the boat, drops his paddle and has to fish for it, nods off as dead weight. The antics are the comedy, and the wind-up keeps them fair. Drinking time-based in the first version; beer pickups can come later as a hazard the player steers around (Q3).
- **C. Input scrambling.** Drunk guys respond to the wrong key or paddle the wrong side. Funny for a second, but it breaks principle 1 and strains Hard but fair, because the input no longer does what it says. Not recommended.

**Recommendation: B.** Chaos in the bodies, not in the input (principle 6); each antic is a telegraphed event the player can see coming (principle 5); and it gives the playtest loop "Getting drunker" something to laugh at.

## Sources
- [Bennett Foddy interview, Google Design Notes (2018)](https://design.google/library/bennett-foddy-getting-over-it-interview)
- [Pain, difficulty and Getting Over It, Lars Doucet, Game Developer](https://www.gamedeveloper.com/design/pain-difficulty-and-getting-over-it)
- [Thoughts on Getting Over It, Game Developer](https://www.gamedeveloper.com/design/thoughts-on-getting-over-it)
- [Here's why the designer of QWOP likes making people mad, Waypoint](https://waypoint.vice.com/en/article/yw357j/heres-why-the-designer-of-qwop-likes-making-people-mad)
- [Getting Over It with Bennett Foddy, Wikipedia](https://en.wikipedia.org/wiki/Getting_Over_It_with_Bennett_Foddy)
- [A Difficult Game About Climbing, Wikipedia](https://en.wikipedia.org/wiki/A_Difficult_Game_About_Climbing)
- [A Difficult Game About Climbing reviews, OpenCritic](https://opencritic.com/game/16618/a-difficult-game-about-climbing/reviews)
- [Jump King review, TheSixthAxis](https://www.thesixthaxis.com/2020/07/31/jump-king-review/)
- [Jump King console announcement with Nexile quotes, Gematsu](https://gematsu.com/2020/02/comically-vicious-vertical-platformer-jump-king-coming-to-ps4-xbox-one-and-switch-in-2020)
- [Pogostuck: Rage With Your Friends, Giant Bomb](https://giantbomb.com/wiki/Games/Pogostuck_Rage_With_Your_Friends)
- [Pogostuck reviews, RAWG](https://rawg.io/games/pogostuck-rage-with-your-friends/reviews)
- [QWOP was proof that games can be slapstick comedy, PC Gamer](https://www.pcgamer.com/uk/qwop-was-proof-that-games-can-be-slapstick-comedy)
- [Octodad: Dadliest Catch post-mortem, part 3: design, Game Developer](https://gamedeveloper.com/design/octodad-dadliest-catch-post-mortem-pt-3-design)
- [Heave Ho review, Nintendo World Report](https://nintendoworldreport.com/review/76603)
- [No Pain, No Game: A Study on Rage Game Design Patterns, Hugo Ramos, U. Porto (2026)](https://repositorio-aberto.up.pt/handle/10216/176239)
- [Rage quit remedy, Wayline](https://www.wayline.io/blog/rage-quit-remedy-designing-games-that-keep-players-hooked)
- [Modern rage game "rules" thread, itch.io forums](https://itch.io/post/6419629)
