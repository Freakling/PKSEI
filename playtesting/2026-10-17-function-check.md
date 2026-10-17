# Function check 2026-10-17
**Build:** 53eef3b · **Covers:** T6, T8, T9, T10, T11, T13, T15, T16, T17, T18, T20, T21, T22, T23, T24, T25, T26, T28, T31, T34, T38, T39, T41, T44, T45, T48, T50, T53, B3
Tick one box per item; leave both empty if you didn't check it. Say what went wrong in Notes.

First round: nothing built so far has been played by a human, so this covers every `(play)` outcome in TASKS.md, plus the art and audio sign-offs the two milestones are waiting for. Expect a long session; a clean crossing alone takes five minutes or more. Do the sections in order: the early ones only need the launch shore, the later ones need a crossing.

## Before you start
- **Run a debug build:** open the project in Godot 4.7 and press F5 (Run Project). The itch.io build is a release build and has no debug tools.
- **Keys:** hold to charge, release to stroke. Left hull: Q (front forward), A (front reverse), W (back forward), S (back reverse). Right hull: I (front forward), K (front reverse), O (back forward), L (back reverse). A left-side stroke turns the boat right, a right-side stroke turns it left; back seats steer about four times as much as front seats.
- **Debug keys:** F5 knocks a beer overboard on the left hull, F6 on the right hull (no hazard needed). F7 shows or hides the guaranteed-path overlay (a translucent strip) together with a magenta diamond at every event trigger point.
- **Seed:** the Output panel prints `lake seed <number>` at launch and after every shore reset. Quote it in Notes when a hazard misbehaves, so the same lake can be built again. There is no way to enter a seed yet.
- **Timings to expect** (placeholder values): the first antic winds up roughly a minute in, the second at about a minute and a half, the third at about two and a half minutes, and the timing bar at about three minutes. A guy on a break drinks three times as fast and a guy in the water five times as fast, so knocking a guy in with F5 brings his antics forward. A break's warning lasts a second and a half and the break itself three seconds. A beer bobs loose for two and a half seconds before the guy jumps.
- **The lake:** rocks can appear from the first band, logs, geese, fishing lines, cross-current stripes, motorboat wakes and gusts from the second (about 400 px out), headwind stretches and the jet-ski from the third. The beast rises when you steer within about 120 px of the lake's left or right edge (the lake is 1600 px wide) or go past the island's far side.

## Catamaran and paddling
- **T6** Holding and releasing each of the eight keys gives a stroke from that seat: a tap is weak, a long hold strong; Q/W/I/O push forward, A/S/K/L push back weaker. Left strokes turn the boat right, right strokes turn it left, back seats turn more than front seats, and with no strokes the boat drifts back toward the shore. *How:* at the launch shore, try each key alone, then pairs, then stop paddling and watch the drift.
  - [ ] Works   - [ ] Broken / missing
  - Notes:
- **T8** The camera stays centred on the boat and leads a little toward the direction of travel, so water ahead shows early. *How:* paddle away from the shore, turn, and watch where the boat sits on screen. (B3: the camera never followed the boat in the first play; this is also its fix.)
  - [ ] Works   - [ ] Broken / missing
  - Notes:
- **T38** The crossing feels huge: with everyone paddling hard and nothing going wrong, the island takes about five minutes to reach, and the water looks endless on the way. *How:* note the clock on the win title when you get there.
  - [ ] Works   - [ ] Broken / missing
  - Notes:

## Drunkenness
- **T13** Each antic reads at a glance on the guy, with a visible wind-up before it fires and a recovery after: he stands up (the boat rocks), drops his paddle and fishes for it (his seat is dead until he has it), nods off (dead weight), or pees over the side (his seat is dead while he goes). *How:* paddle for about a minute and keep an eye on the guys; each guy does one antic per threshold, so there are up to three per guy per attempt. Note which antic you saw and whether you could tell it was coming.
  - [ ] Works   - [ ] Broken / missing
  - Notes:
- **T13** A hard knock during a pee puts the peeing guy in the water without a beer. *How:* when a guy is peeing, bump a log or let a gust or wake hit; he should fall in. A shove too gentle to knock him in is fine.
  - [ ] Works   - [ ] Broken / missing
  - Notes:
- **T31** At the top tier a wind-up announces the timing bar; after it, a bar sweeps back and forth next to the guy while his key is held, and only a release in the green zone gives the stroke you meant; a miss paddles the other way. *How:* keep a guy aboard for about three minutes, or knock him in with F5/F6 and leave him floating to speed it up, then hold and release his key and watch the bar.
  - [ ] Works   - [ ] Broken / missing
  - Notes:
- **T23** Every drunkenness and stamina telegraph has its own animation on the guy that starts at the warning and ends at the effect: the break warning, each antic wind-up and the timing-bar tell. *How:* watch for this throughout the session; note any warning that was only readable from the HUD.
  - [ ] Works   - [ ] Broken / missing
  - Notes:
- **T23** A late or missed stroke shows as a fumble on the guy. *How:* once a guy is drunk (a few minutes in), release his key and watch him; some strokes land late or not at all, and each of those should look like a fumble.
  - [ ] Works   - [ ] Broken / missing
  - Notes:
- **T44** A floating guy drinks from a beer at his mouth only while he has one; a guy knocked in during a pee floats without a beer. *How:* compare an F5 swimmer (has a beer once he reaches it) with a pee victim or a guy spat out by the beast (no beer).
  - [ ] Works   - [ ] Broken / missing
  - Notes:

## Stamina
- **T6** A guy's break warning and his break read at a glance on him, and the HUD row says "break soon" then "on a break". *How:* hold one guy's key for long strokes over and over until he burns out; a warning shows for a second or two, then he sits out for three seconds and his seat gives no strokes.
  - [ ] Works   - [ ] Broken / missing
  - Notes:

## Hazards
- **T10** A log sits still on the water (it never drifts), is visible well before the boat reaches it, and a bump knocks a beer overboard on the hull that hit it and shoves the boat. *How:* press F7 to see the path, then steer off it into a log. (The original item said logs drift; T36 fixed them in place.)
  - [ ] Works   - [ ] Broken / missing
  - Notes:
- **T24** Each hazard telegraph in the GDD table is an animation that plays before the effect: the geese hiss with raised wings, the motorboat crosses before its wave, ripples race ahead of a gust, whitecaps mark a headwind stretch, arrows run along the cross-current stripe, the beast's fin and ripples circle first. *How:* tick this after the hazard items below; note any hazard whose effect came with no animation first.
  - [ ] Works   - [ ] Broken / missing
  - Notes:
- **T26** Each audio telegraph sounds before its hazard is visible, or at its wind-up: a motorboat engine before the wake, the jet-ski heard from off-screen, the geese hissing, wind rising before a gust and before a headwind stretch. *How:* play with sound on and, for each event, note whether you heard it before you saw it.
  - [ ] Works   - [ ] Broken / missing
  - Notes:
- **T15** Geese: nearing the nesting flock makes it hiss with raised wings; the charge always follows, the geese peck at the boat (each peck a beer overboard, at most one every couple of seconds), then give up and return. Both the warning and the attack read at a glance. *How:* steer toward a flock (it sits beside the path); see whether backing off after the hiss still gets you charged (it should).
  - [ ] Works   - [ ] Broken / missing
  - Notes:
- **T16** Motorboat wake: the motorboat is seen crossing ahead before its wave rolls toward you. Head-on the wave does nothing; broadside it knocks a beer overboard on the high hull, shoves the boat sideways and puts water aboard, so that hull's guy bails instead of paddling until it is out. *How:* wake triggers are magenta diamonds on the path (F7). Pass one head-on, then another turned sideways.
  - [ ] Works   - [ ] Broken / missing
  - Notes:
- **T17** Gust: ripples race across the water about a second ahead, then the boat is shoved sideways for a few seconds. *How:* a gust trigger is a magenta diamond on the path (F7); watch the water as you reach it.
  - [ ] Works   - [ ] Broken / missing
  - Notes:
- **T17** Harsh wind: a stretch of whitecaps is visible before the boat reaches it; inside it only strong strokes gain water. *How:* headwind triggers are magenta diamonds on the path (F7), from the third band on.
  - [ ] Works   - [ ] Broken / missing
  - Notes:
- **T18** Cross-current stripe: a band of visibly faster water across the lake; inside it the boat is pushed sideways. *How:* the stripe spans the lake, so the path runs straight through it; watch the boat's drift inside.
  - [ ] Works   - [ ] Broken / missing
  - Notes:
- **T20** Fishing line: the fisherman's dinghy and the line across the water are visible before the boat reaches them; crossing the line snags the paddle on that side for a few seconds. *How:* steer off the path across a line.
  - [ ] Works   - [ ] Broken / missing
  - Notes:
- **T21** Jet-ski: the warning is loud enough to react to; it is heard from off-screen a second or two before the jet-ski crosses your path on a diagonal from the lake edge, and the sprite faces along its course (T24). A hit shoves the boat hard and knocks a beer overboard. *How:* jet-ski triggers are magenta diamonds on the path (F7), from the third band on. Try to dodge one on the warning alone.
  - [ ] Works   - [ ] Broken / missing
  - Notes:
- **T50** The beast: a fin and ripples circle the boat with a low rumble (T26), then it rams the boat (a hard shove back toward the lake's middle) and grabs the guy on the hull it hit; he is spat out in the water a long way back toward the shore, and the grab has its own sound. It leaves once the boat is back inside. The fin, the circling and the grab all read at a glance. *How:* steer to the left or right edge of the lake and keep going until the fin appears; then paddle back toward the middle and check it dives.
  - [ ] Works   - [ ] Broken / missing
  - Notes:

## Setbacks
- **T34** When a beer goes over it is visible bobbing away for a couple of seconds, and the guy who will go after it winds up visibly in his seat (his seat still paddles) before he jumps. *How:* F5 at the shore and watch the left hull.
  - [ ] Works   - [ ] Broken / missing
  - Notes:
- **T9** The guy visibly jumps in, swims to the beer, floats drinking it, drifts back toward the shore faster than the boat does, and climbs back in when the boat reaches him. With all four in the water the empty boat drifts home quickly, and touching the shore resets the attempt: everyone aboard, mildly tipsy, progress zero, the same lake again. *How:* F5 and F6 a few times away from the shore; pick one guy up, then let the rest drift and wait for the shore reset.
  - [ ] Works   - [ ] Broken / missing
  - Notes:
- **T45** For every swimmer off-screen an arrow in his shirt colour sits at the edge of the screen pointing at him, and disappears when he is on screen or picked up. *How:* F5, then paddle on until the swimmer is out of view; turn around and come back.
  - [ ] Works   - [ ] Broken / missing
  - Notes:

## Win and Loss
- **T6 / T28** Reaching the island with all four aboard ends the attempt and the win cutscene plays: the camera eases onto the island, the boys hop off onto the beach, walk up to the clearing, the tent pops up, the fire lights and they sit round it drinking; a title shows the crossing time and "Press any key to go again". Any key starts a new attempt on a fresh lake. *How:* complete a crossing (five minutes or more; there is no shortcut). Also check that nothing hits the boat or the guys during the cutscene even if a gust, wake, jet-ski or geese charge was active at the island (B4).
  - [ ] Works   - [ ] Broken / missing
  - Notes:

## Presentation and Platforms
- **T48 / T53** At the launch shore the control scheme is scratched into the sand beside the boat's start, showing all eight keys at their seats (Q/A, W/S left; I/K, O/L right; hold to charge, release to stroke), and none of it is on screen once the boat has left.
  - [ ] Works   - [ ] Broken / missing
  - Notes:
- **T6 / T53** The HUD shows the progress bar and, per guy, his seat and keys (LF Q/A, LB W/S, RF I/K, RB O/L) with a drunkenness bar and a stamina bar, hidden once the attempt is won.
  - [ ] Works   - [ ] Broken / missing
  - Notes:
- **T22** Everything on screen is pixel art drawn for the 640×360 canvas and nearest-filtered: the catamaran, the four guys, the water, the shore and the island; no flat-colour primitives remain, and pixels stay crisp at window sizes that are a whole multiple of 640×360.
  - [ ] Works   - [ ] Broken / missing
  - Notes:
- **T25** Strokes, splashes, jumps and pick-ups each have a sound. The master volume follows the player setting: there is no settings screen yet, so only check that the default volume is sensible against the hazards' loops.
  - [ ] Works   - [ ] Broken / missing
  - Notes:
- **T39** With F7 on, the translucent strip follows the planned path: it winds from the launch to the island, bending from band to band, and no log, rock, flock or fishing line reaches into it (only cross-current stripes cross it). After a shore reset the same strip comes back. *How:* paddle along the strip for a few bands and look at what sits beside it.
  - [ ] Works   - [ ] Broken / missing
  - Notes:
- **T41** With F7 on, a small magenta diamond marks each event trigger point, and every diamond sits inside the strip. Reaching a diamond fires its event (wake, gust, headwind stretch or jet-ski).
  - [ ] Works   - [ ] Broken / missing
  - Notes:
- **T11** The game runs at freakling.itch.io/pksei in the browser, with the last shipped build. *How:* open the page in a browser; the web build has no debug keys, so just paddle off the shore.
  - [ ] Works   - [ ] Broken / missing
  - Notes:

## Sign-offs
The two milestones below are marked done but wait on your call. Tick Works to sign off, or Broken with what should change; a note that says what you want different becomes a task, not a bug.
- **Pixel art (T22–T24)** The look is signed off: the boat, the guys, the water, shore and island, the hazards and their telegraph animations, the win cutscene art. Say what jars, if anything: palette, readability at 1× and 2×, any sprite that doesn't read top-down.
  - [ ] Works   - [ ] Broken / missing
  - Notes:
- **Audio (T25–T26)** The sounds are signed off: strokes, splashes, jumps, pick-ups, the cheer, and the hazard loops (engine, jet-ski, geese, wind, beast rumble, grab). Say which sound is wrong, too loud, too quiet or missing.
  - [ ] Works   - [ ] Broken / missing
  - Notes:

## Not in this round
- **T33** (respawned hazards appear outside the camera's look-ahead): superseded by T36, which fixed every object in place and removed the refill; nothing to check.
- **B1, B2, B4**: fixed bugs with regression tests; the check proves them. B4's cutscene part is folded into the Win and Loss item above.
