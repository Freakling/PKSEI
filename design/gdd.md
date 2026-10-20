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
PKSEI is *Paddla Kanot Som En Idiot*, Swedish for "paddle a canoe like an idiot". It is a rage game and a tech demo for Godot Director (page copy: `design/itch-page.md`).

Four drunk guys have lashed two aluminium canoes into a catamaran and need to reach an island on the far side of the lake. You control all four at once. The lake throws random hazards at them, and they keep drinking, so the boat gets harder to control the longer the crossing takes. Nobody dies: a bad stretch drifts the boat back into water already crossed. A top-down, bright pixel-art rage game in the spirit of Getting Over It and A Difficult Game About Climbing, played for the comedy of watching four idiots fail together.

Genre: action/arcade. Feelings to hit: rage and mastery, with comedy throughout. Reference research: `design/research/rage-games.md`.

## Design Pillars
1. **Hard but fair.** Failure is always the player's fault and readable in hindsight. Rage comes from near-misses, never from randomness the player couldn't see coming.
2. **Four bodies, one brain.** The difficulty is coordination: controlling four guys at once is the game. No single guy is ever the hero.
3. **Drunker is funnier.** Every control-degrading effect must also be funny to watch. Comedy comes from physics and the guys, not cutscenes.
4. **No death, only setbacks.** There is no game over and no restart. A bad stretch drifts the boat back into water already crossed, and the guys keep drinking. Progress is the only thing at stake.

## Core Loop
### Moment to moment
Charge-and-release paddling against a constant current. Each guy has two keys, forward and reverse: hold to wind up, release to stroke, with no on-screen meter; the power of the stroke comes from how long the key was held. The boat gains speed, turns and wobbles from the mix of who strokes when and how hard. Strong strokes burn a guy's stamina, so the player balances power against stamina for each guy. The player juggles four wind-ups at once while drunkenness makes each guy less reliable, and the current pulls the boat back toward the shore whenever the strokes stop.

### Session
A sitting is one continuous attempt at the crossing, since there is no restart: the player pushes forward, gets set back, pushes forward again until they reach the island or quit. A clean crossing with no incidents at a steady pace takes about two minutes; with incidents a real crossing is far longer. The lake length is a tunable (it was three times longer at first, and cut to a third after play).

### Run / campaign
One lake, one crossing, from the launch shore to the island on the far side. The lake is long; hazards are randomised per attempt along a guaranteed path.

### Starting conditions
Four guys, mildly tipsy, on a calm stretch of water at the shore, with a crate of beer aboard. Drunkenness climbs with time, faster while a guy is on a break or floating in the water, so the first stretch teaches control before it degrades.

## Systems
### Catamaran and paddling
Two aluminium canoes lashed side by side, two guys per hull: a front and a back seat on each. A stroke on the left turns the boat to the right and a stroke on the right turns it left, as with an outboard at the stern; strokes on both sides together go straight. Stroke power grows with how long the guy's key was held, up to a cap; a tap is a weak stroke, a long hold a strong one, and the turn scales with the power as the push does. A strong stroke burns more stamina (see Stamina). A reverse stroke is the forward stroke mirrored, with weaker push.

**Seats matter.** All four seats give the same forward push, but steering comes mostly from the back: a back-seat stroke turns the boat about four times as much as a front-seat stroke (the shares are tunables, meant to feel like 80/20). The front seats are the engine and the back seats the rudder, so which drunk guy sits where matters. The catamaran never capsizes: a wobble is cosmetic. A constant headwind blows from the island toward the shore: a boat nobody paddles loses a little water, slowly, while loose things on the water, beers and swimmers, are carried back noticeably faster. The lake itself is a big static place the boat moves through; the shore and the island are fixed. The physics stays readable: the same strokes give the same boat when the guys are sober (pillar "Hard but fair").

### Drunkenness
Each guy has his own drunkenness level. It rises with time, as the guys drink from the crate, faster while a guy is on a stamina break, and faster still while a guy floats in the water drinking the beer he went in after. Rising drunkenness degrades that guy's control in three tiers, each visible on the guy himself (pillar "Drunker is funnier"):
- **Lag and misses.** A drunker guy's stroke lands later after the release, and sometimes not at all; the fumble shows in his animation. Delay and miss chance rise with the level.
- **Antics.** At drunkenness thresholds a guy does something stupid, always with a visible wind-up and a recovery: he stands up and rocks the boat, drops his paddle and has to fish for it, nods off as dead weight, or needs to pee. While he pees at the edge his seat gives no strokes, and if a hazard rocks the boat hard enough he loses his balance and falls in: a swimmer to rescue like any other, but with no beer in hand, so he doesn't drink while he floats.
- **Seeing double.** Only at the top tier, a guy's controls reverse: while it lasts his forward key paddles in reverse (the weaker reverse stroke) and his reverse key paddles forward, every stroke, no minigame. Announced with a wind-up ("Vilket håll är fram?"), shown on him (he sways) and on the HUD ("seeing double"), and it lasts ten to fifteen seconds at most, then he is back to plain lag and misses and another antic can come; it can return after a while if he is still that drunk. The player can see it and adapt by pressing the other key, so the pillar "Hard but fair" holds. A missed stroke, from lag or a fumble, still burns stamina: he swung.
Drunkenness also comes down. A guy who reaches the top of the meter pukes overboard: a wind-up, then his seat is out for a moment while he leans over the side, and his level drops by a good chunk. Peeing lowers it a little too. So the meter is a cycle, not a ramp: the worst guy sorts himself out, loudly. Puking has a small chance, about one in fifty, of drawing the Loch-Brez beast.

Input is always honoured instantly in the animation; what the drunk body then does with it is the comedy.

### Stamina
Each guy has his own stamina. Every stroke burns some, more for a stronger stroke, and it recovers while he rests between strokes. When a guy is burnt out he takes a **break**: he stops paddling for a few seconds, his seat gives no strokes, his stamina recovers quickly, and he cracks open beers faster, so his drunkenness climbs. He may also take a break before he is burnt out: the chance rises with how much stamina he has burnt. Every break, forced or random, is telegraphed on the guy a second or two in advance, so the player can see it coming and compensate with the other three (pillar "Hard but fair"). The player's trade-off is power now against a break later, four times over.

### Hazards
Random hazards along the crossing, of two kinds. **Objects** are fixed on the map: logs, rocks and buoys, the geese's nesting flock, the fisherman's dinghy and line, cross-current stripes; the path winds around them and they never drift. **Events** happen as the boat passes: a motorboat's wake, a gust, a harsh-wind stretch, the jet-ski, the geese's charge. Only beers and swimmers drift. Every hazard is visible, or audibly announced, before it matters, so the player can react (pillar "Hard but fair"). Hazards combine: a wake or a gust can push the boat into a log or a flock, and that is intended.

**Effects** a hazard can have, alone or combined:
- *Beer overboard* on the side hit, which starts a Rescue (see Setbacks). At most one beer goes over every couple of seconds: hits inside that window still shove or stop the boat but knock no beer over, so a cluster of hits can't wipe the crew out at once. The window is a tunable.
- *Shove*: a push to the boat's position or heading. Costs water and steering, no guy lost, unless a guy is peeing: a hard enough shove knocks him in.
- *Snag a paddle*: one seat gives no strokes for a few seconds, the same shape as a stamina break.
- *Stop the boat*: speed to zero on a hard hit, harsh against the current.
- *Force a stamina break*: the hit guy takes a break on the spot and drinks. Available to hazards; none uses it yet.
- *Water aboard*: the boat takes on water, and the guy on the side it came in stops paddling to bail until it is out. More water, longer bailing.

**The set** for the first lake:
| Hazard | Telegraph | What it does |
|---|---|---|
| Log | Fixed on the water, visible from far off | Bump: beer overboard on the side hit, and a shove that kills speed |
| Angry geese | A flock guarding goslings; hissing and raised wings as you near them | Once they hiss the charge always comes: they charge the boat and peck: beer overboard. They give up and return after a few seconds |
| Rock or buoy | Fixed, visible from far off | Hit: stop the boat, beer overboard |
| Fishing line | A fisherman in a dinghy, the line visible across the water | Crossing the line snags the paddle on that side for a few seconds. Ramming the dinghy itself is a bump: beer overboard on the side that hit it, and a shove away |
| Motorboat wake | The motorboat crosses ahead first, trailing a V of two wake fronts, one either side of its course at about 30°, that keep spreading after it | Each front is a wave: head-on into it, within the head-on angle of its normal, nothing, so the boat can cross from one side of the V to the other at an angle. Broadside: beer overboard on the high side, a sideways shove, often into something else, and water aboard, so a guy bails. At most one wave hit per motorboat. Getting in the motorboat's way is worse: its hull rams the boat, a beer goes over on the side it came from and the boat is shoved along its course, once per motorboat |
| Wind gust | Ripples race across the water a second ahead | A sideways shove for a few seconds, compounding with the current |
| Harsh wind | A stretch of whitecaps ahead | A sustained headwind where only strong strokes make progress: a stamina-management test, too hard a push and the breaks come |
| Cross-current stripe | A visible band of faster water | Pushes sideways or backward while the boat is in it |
| Jet-ski idiot | Loud from offscreen, then crosses your path on a diagonal from the lake edge at speed | Hit: a hard shove and a beer overboard |
| The Loch-Brez beast | A fin and ripples circle the boat first; a low rumble | Rises when the boat strays near a lake edge or past the island's far side (the guaranteed path never leads there, nor into the warning band before it), and never on its own in open water: in the deep middle only a puke can call it, with a small chance. Before the boat reaches that zone, while it is still a stretch away, one guy warns in Swedish ("Inte för långt ut!"), once per approach, so the player knows where the beast's water begins. It rams the boat (a hard shove back toward the lake's middle) and grabs a guy: swallowed, dived with, and spat out in the water a stretch back toward the shore (the distance is a tunable), a rescue setback. It leaves once the boat is back inside, when a puke-called visit's one grab is done, or when a ram can't catch the boat |

**Placement.** The lake is a series of bands from shore to island. Each band draws its hazards from a weighted list, with a density that rises toward the island, from one seed per attempt: reproducible for testing, different between attempts. A guaranteed path winds through every band: a corridor no object reaches into (the lake-wide cross-current stripe is the one object the path runs straight through), whose position wanders from band to band so the crossing is never a straight line. Objects are placed within a spread either side of the corridor, not anywhere across the lake, so the obstacles crowd the route the boat actually takes; logs and rocks are the commonest. The density curve, the weights, the corridor's width, how far it wanders and the spread are tunables.

### Setbacks
Nobody dies and the boat never capsizes. The setback is the **Rescue**: a hazard knocks a beer overboard; it bobs away for two or three seconds while a guy winds up, visibly, and then he jumps in after it. If he ends up in the water some other way before he jumps, he swims for that beer anyway. The beer drifts with the wind; he swims to it, and once he has it he floats, drifting with the current and drinking it. After a few seconds adrift he starts swimming slowly back toward the boat, slower than the boat can come for him, so the rescue is still the player's job but a patient one can meet him halfway. He talks the whole time, in Swedish: while he swims for the beer, while he drinks it ("Ska bara dricka sen kommer jag"), and once he is swimming back he complains and nags to be fetched ("Kom och hämta mig dåååå!"), a line every few seconds. Every guy in the water is one paddler fewer, so the boat is slower and harder to steer while the current drifts it back toward the shore. The player has to paddle to each swimmer and pick him up; a swimmer who is off-screen is pointed at by an arrow at the edge of the view, so he can always be found; there are no calm areas that stop the drift, so the water lost is however much the recovery cost, and the longer he floats the drunker he comes back.

There is no limit on how many guys can be in the water. The cascade is the point: one guy gone makes the crossing much harder, two makes it close to impossible, and with all four in the water nobody paddles: the boat is uncontrollable, so its drift home speeds up to about five times the headwind's pull, so the player isn't kept waiting for the shore reset. The multiplier is a tunable. **Shore reset:** when the boat touches the shore again after leaving it, with or without anyone aboard (never at the launch itself), the attempt returns to its Starting conditions: everyone aboard, mildly tipsy, stamina full, progress zero, on the same lake: the layout is kept, so the lake is learnable; only a new attempt draws a new one. It is the bottom of the mountain, not a game over.

### Lake and island
The lake is the level: a launch shore, a huge stretch of open water with hazards and the headwind, and the island on the far side. One lake.

## Characters and Units
Four guys. They are the comedy: the bodies the player drives and the thing that goes wrong. Each attempt gives them four distinct names drawn from the crew's list of nicknames (Vajking, Tåååny!!, Ryggen, Danne!, Danne?, Göras!, Matte, Bibbe, NakenOlsson, Skrattet, Alkisen, Meh-lajnen, P-Erik; the list is data the human edits). The HUD shows the names, not the keys: the keys are taught by the sand text. Under each name it says what the guy is doing whenever he can't paddle (in the water, taking a piss, puking, asleep, on a break, snagged, bailing, seeing double), so a guy who doesn't respond is explained, never a mystery. Whether they differ from one another in weight, tolerance or personality is undecided.

## Progression and Meta
None planned for the first version. The crossing is the whole game.

## World and Narrative
A lake, four drunk guys, a catamaran made of two canoes, a crate of beer, and an island they have decided to reach. No further story. The setting is the author's annual camping trip with friends: canoes, a lake, an island, too much beer.

The guys speak Swedish. Every telegraph gets a speech bubble: a guy says what he is about to do ("Jag måste pissa", "Fyfan va trött jag är!"), and when a hazard announces itself one guy calls it out ("Nu jävlar blåser det!" for the wind, "Se upp för fåglarna!" for the geese), so the warning is also the joke. A guy in the water keeps talking too (see Setbacks), and a guy whose paddle the fishing line snags gets angry and yells about it ("Fan, linan!"). The lines are data the human edits.

## Difficulty and Scaling
Difficulty comes from drunkenness, which only rises over the attempt, from the constant current, from stamina breaks that get likelier the harder the player pushes, from the rescue cascade (each swimmer makes the next rescue harder), and from the hazards getting denser toward the island. Numbers for all of these are tunables.

## Win and Loss
- **Win:** the catamaran reaches the island with all four guys aboard. A cutscene follows: the boys step onto the island, make camp and drink more. The crossing ends there, and the title shows the crossing's stats: time taken, shore resets, strokes (and fumbles and reverse ones), beers drunk (estimated from the drunkenness gained, a beer per `level_per_beer`), beers overboard and rescued, times in the water (jumps, falls, beast grabs), pukes, pisses, naps, stand-ups, paddles dropped, breaks, snags, water bailed, hazard hits and the drunkest moment: everything the run counted, so the crew can argue about it.
- **Loss:** none. Setbacks replace losing (see Setbacks).

## Presentation and Platforms
- Platforms: Web (HTML5, itch.io), on desktop browsers and on phones and tablets through itch.io's mobile fullscreen. Development runs the project from the editor and the command line; the Web preset is the only export.
- Target aspect ratios: 16:9 at a 640×360 canvas, scaled to fit the window (fractional: whole multiples left phones with a 1× canvas, B6), crisp at 720p, 1080p and 1440p.
- Input: keyboard, eight keys, two per seat (forward and reverse), hold to charge and release to stroke: the outer columns are the back seats and the inner columns the front seats: left hull Q/A back, W/S front; right hull I/K front, O/L back; up is forward, down is reverse. The left hand drives the left hull and the right hand the right hull. A reverse stroke pushes less than a forward one (a tunable fraction) but turns the same and burns the same stamina.
- Touch: on a touchscreen the pads appear by themselves (hidden on keyboard play). The layout follows the keys: outer steers, inner propels. The left half of the screen is the left hull, the right half the right hull; within a half, a touch in the outer part (toward the screen edge) charges that hull's back seat and a touch in the inner part (toward the middle) its front seat; the press's height picks the direction: on or above the line drawn low across each pad (anywhere up the screen) strokes forward, below it, on the down arrow, strokes in reverse; forward is the main direction, so it gets most of the pad; the pads sit low, where thumbs rest; there is no flick. Two thumbs mean two guys at a time: choosing which two and alternating fast is the touch version of four bodies, one brain. Research: `design/research/touch-controls.md`. The scheme is shown once, written large in the sand on the launch shore (twice the sprite scale), so it is there at the start, gone once the boat has left, and back whenever the boat is at the launch shore again. Local co-op with one guy per player is a planned mode (Q5); there each player gets two keys, stroke and lean.
- Camera: top-down, follows the catamaran, biased toward the direction of travel so hazards show early.
- Art direction: top-down, bright pixel art, a bit retro, lots of comedy. The pixel art is generated by a script (`tools/gen_sprites.gd`), so it is reproducible and edited in code. Telegraphs came first: every wind-up and hazard warning has its pixel animation. Other boats (the motorboat, the jet-ski, the fisherman's dinghy) are drawn at least as large as the catamaran, so they are recognised at a glance.
- Audio: telegraphs first. Sound announces hazards before they are visible: a motorboat engine before its wake, a jet-ski heard from offscreen, geese hissing, wind rising before a gust or a headwind stretch. Then stroke, splash and guy noises for the comedy. The sounds are synthesised by a script (`tools/gen_audio.gd`). Music: the splash plays a looping theme in a MIDI-like chiptune style. The theme in the game is a placeholder generated by the same script; the human's own track (an mp3) replaces it later by swapping one file.
- Splash: the game opens on a splash screen over the launch shore: the crew in their catamaran on the water with the island behind, the title "Paddla Kanot Som En Idiot" and a blinking "Press any key" ("Tap to start" on touch). Any key, click or tap fades it away to the shore, where play starts; nothing reaches the boat until it is gone. It shows once per launch, not after a reset or the win. Chiptune music plays while it is up and fades out with it. Layout: `design/ui/splash.md`.
- Reset: R on the keyboard starts a new attempt at once (a fresh lake); the sand text at the launch shore says so. On touch, a small corner button that must be held for a moment while a ring fills, so a stray tap can't reset.
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
| Antic | A telegraphed stupid thing a drunk guy does: stands up, drops his paddle, nods off, needs to pee. |
| Seeing double | The top drunkenness tier: the guy's two keys swap for ten to fifteen seconds; forward paddles backwards and the other way round. |
| Stamina | A guy's reserve for strong strokes. Burnt by paddling, recovered by resting. |
| Break | A guy's telegraphed pause of a few seconds: no strokes, fast stamina recovery, faster drinking. |

## Open Questions
<!-- Numbered Q<n>, never reused. When one is answered: write the rule into its section, add a line
to design/decisions.md, and delete the question here. -->
- **Q5 · Local co-op.** One guy per player with stroke and lean keys: in the first version, or a later mode once single-player is proven?

- **Q7** · Release: what command uploads each export preset's build to UAT and to production, and which CI secrets does it need? Answering it sets up release: /design Q7 runs the "Set up release" step. Until then `tools/ship.sh` pushes straight to the itch.io html5 channel.

**Next:** Q8
