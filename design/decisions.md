# Design decisions

Why the design is the way it is: one line per decision, newest last, never edited. The GDD states the current design; this file says how it got there. A decision that replaces an earlier one says so.

Format: `- YYYY-MM-DD · <decision> · why: <reason> · from: <Q<n> | conversation | playtest file>`

- 2026-10-16 · PKSEI is a rage game: four drunk guys cross a lake to an island on a catamaran made of two aluminium canoes, and the player controls all four at once · why: the human's concept · from: conversation
- 2026-10-16 · Genre is action/arcade; the feelings to hit are rage and mastery, with comedy throughout · why: the human's concept · from: conversation
- 2026-10-16 · Design pillars: Hard but fair; Four bodies, one brain; Drunker is funnier; No death, only setbacks · why: the human picked three from the proposed set and added the fourth, pointing at Getting Over It and A Difficult Game About Climbing · from: conversation
- 2026-10-16 · Nobody dies and there is no game over: a bad stretch drifts the boat back into water already crossed · why: Getting-Over-It-style loss of progress is the rage, not restarting · from: conversation
- 2026-10-16 · Moment to moment is paddle-timing balance: each guy paddles or leans on input and the boat turns and tips from the mix · why: makes coordinating four bodies the control problem itself · from: conversation
- 2026-10-16 · A run is one lake, one crossing from shore to island; the first version is short and the lake grows later · why: start small, lengthen once the loop is proven · from: conversation
- 2026-10-16 · Win: reach the island with all four guys aboard · why: part of the chosen run option; confirm if a guy overboard should be allowed to count · from: conversation
- 2026-10-16 · An attempt starts sober-ish at the shore on calm water; drunkenness climbs with time and beers · why: the first stretch teaches control before it degrades · from: conversation
- 2026-10-16 · Platform: web (HTML5 on itch.io), GL Compatibility renderer · why: easy to share playtest builds · from: conversation
- 2026-10-16 · Input: keyboard first; local co-op with one guy per player is a planned mode (exact scheme open, Q1 and Q5) · why: cheapest to build; co-op turns the coordination problem into party chaos · from: conversation
- 2026-10-16 · Canvas 640×360, 16:9, integer scaling, nearest filtering · why: scales cleanly to 720p/1080p/1440p with room for a boat, four guys and hazards ahead · from: conversation
- 2026-10-16 · Camera follows the boat, biased toward the direction of travel · why: hazards visible early serves Hard but fair · from: conversation
- 2026-10-16 · Art direction: top-down, bright pixel art, a bit retro, lots of comedy · why: the human's concept · from: conversation
- 2026-10-16 · Controls: four keys, one per guy, hold to charge and release to stroke, no on-screen meter; local co-op later gives each player two keys, stroke and lean · why: more expressive than a tap and gives drunkenness a second thing to corrupt; the human reserved the two-key scheme for co-op · from: Q1
- 2026-10-16 · The catamaran never capsizes; a wobble is cosmetic · why: it is a catamaran · from: Q2
- 2026-10-16 · The setback is the Rescue: a hazard knocks a beer overboard, a guy jumps in after it, the boat drifts with three paddlers until it reaches him; no calm areas stop the drift (replaces the earlier "drifts back into water already crossed" wording, which it makes concrete) · why: the loss is proportional to the recovery with fewer paddlers, and the rescue is the comedy · from: Q2
- 2026-10-16 · A constant current runs from the island toward the shore at all times · why: the game's gravity; keeps the pressure on without timers · from: Q2
- 2026-10-16 · A rescued guy drinks the saved beer on the spot · why: every setback makes the next stretch harder, the sunk-cost loop in beer form · from: Q2
- 2026-10-16 · Drunkenness degrades control as lag and missed strokes rising with the level, plus telegraphed antics at thresholds (stand up, drop the paddle, nod off); drinking is time-based plus rescued beers, no pickups in the first version · why: chaos in the bodies, not in the input; wind-ups keep it fair · from: Q4
- 2026-10-16 · Scrambled keys only at the top drunkenness tier, announced with a wind-up, shown next to the guy and steady until he sobers or is set back · why: the human wanted scrambling; the announced, steady form keeps the pillar Hard but fair · from: Q4
- 2026-10-16 · Seats matter: all four seats give the same forward push, back seats do most of the steering (meant to feel like 80/20 back/front); a left stroke turns the boat right and a right stroke left, like an outboard at the stern · why: the human's call; makes who sits where part of the coordination problem · from: conversation
- 2026-10-16 · Keys: Q left front, A left back, I right front, K right back; left hand drives the left hull, right hand the right · why: the human's call; one hand per hull · from: conversation
