# Tasks

Milestones, the work queue and bugs: the only place work is tracked. Item format: `.godot-director/tasks.md`. Queue order is priority; reorder by moving items. Pruning moves done items to `TASKS-archive.md`.

**Next IDs:** T98 · B9 · R1

## Milestones
| Milestone | Status |
|---|---|
| Design: pitch, pillars and core loop decided | ✅ done (Q5, co-op timing, still open) |
| Foundation: project settings, first system with a test, check passing | ✅ done |
| Core loop playable (grey-box): T6, T8, T9, T13, T28 | ✅ done |
| Hazards complete: T10, T15–T21 | ✅ done |
| Pixel art and animation, telegraphs first: T22–T24 | ✅ done (awaiting the human's sign-off on the look) |
| Audio, telegraphs first: T25–T26 | ✅ done (sounds await the human's ear) |
| Content & balance: no `## PLACEHOLDER` left (human) | ⬜ (134 placeholders) |

✅ done · 🟨 in progress · ⬜ not started

## Queue

### T1 · The check passes on a clean clone · done · S · agent
- Depends on: (none)
- Touches: project.godot, tools/check.cfg
- Done when: `bash tools/check.sh` exits 0 after deleting `.godot/` (check)
- GDD: (none)

### T2 · Create the folder layout · done · S · agent
- Depends on: (none)
- Touches: scripts/autoload/.gitkeep (new), scripts/systems/.gitkeep (new), scripts/resources/.gitkeep (new), scripts/ui/.gitkeep (new), scenes/.gitkeep (new), data/.gitkeep (new), tests/.gitkeep (new)
- Done when: every folder in AGENTS.md › Layout exists in git (check) · the check still passes (check)
- GDD: (none)

### T7 · Research: what makes a good rage game · done · S · agent
- Depends on: (none)
- Touches: design/research/rage-games.md (new)
- Done when: a note compares Getting Over It, A Difficult Game About Climbing, Jump King, Pogostuck and QWOP on setbacks, control, fairness and comedy, and ends with 5–8 principles plus a proposal for Q1, Q2 and Q4 for the human to decide in a design session (check)
- GDD: Design Pillars

### T3 · RunState autoload: the current attempt · done · M · agent
- Depends on: T2
- Touches: scripts/autoload/run_state.gd (new), project.godot (autoload)
- Done when: `reset()` restores the starting conditions: four guys, mildly tipsy, all aboard, zero progress, phase `launch` (test) · the check runs the autoload without errors (check)
- GDD: Core Loop › Starting conditions

### T4 · Paddling rule class: four charged strokes to thrust and turn, against the current · done · M · agent
- Depends on: T2
- Touches: scripts/systems/paddling.gd (new), scripts/resources/boat_tuning.gd (new, +stroke_force_min, +stroke_force_max, +charge_time, +turn_torque, +steer_share_front, +steer_share_back, +current_speed), data/boat_tuning.tres (new), tests/test_paddling.gd (new)
- Done when: stroke power grows with hold time from stroke_force_min to stroke_force_max over charge_time (test) · equal strokes on both sides give forward thrust and no turn (test) · a left-side stroke turns the boat right and a right-side stroke left (test) · a back-seat stroke turns the boat by steer_share_back and a front-seat stroke by steer_share_front, with the same forward push (test) · with no strokes the boat moves toward the shore at current_speed (test)
- GDD: Systems › Catamaran and paddling

### T5 · Drunkenness rule class: level, lag, misses and scrambled keys · done · M · agent
- Depends on: T2
- Touches: scripts/systems/drunkenness.gd (new), scripts/resources/drink_tuning.gd (new, +drink_rate, +break_drink_multiplier, +water_drink_multiplier, +start_level, +lag_curve, +miss_curve, +scramble_level), data/drink_tuning.tres (new), tests/test_drunkenness.gd (new)
- Done when: each guy's level rises by drink_rate per second from start_level, times break_drink_multiplier while he is on a break, and times water_drink_multiplier while he floats in the water (test) · stroke delay and miss chance rise with the level per lag_curve and miss_curve (test) · at scramble_level and above, the guy's key maps to another guy's seat, steady until his level drops below it (test)
- GDD: Systems › Drunkenness

### T14 · Stamina rule class: strokes burn it, breaks recover it, telegraphed · done · M · agent
- Depends on: T2
- Touches: scripts/systems/stamina.gd (new), scripts/resources/stamina_tuning.gd (new, +burn_per_power, +recover_rate, +break_recover_rate, +break_duration, +break_warning, +random_break_curve), data/stamina_tuning.tres (new), tests/test_stamina.gd (new)
- Done when: a stroke burns stamina in proportion to its power, and stamina recovers at recover_rate between strokes (test) · a burnt-out guy gets a warning of break_warning, then a break of break_duration during which his seat gives no strokes and stamina recovers at break_recover_rate (test) · the chance of a random break per second rises with burnt stamina per random_break_curve, from a seeded random, and gets the same warning (test)
- GDD: Systems › Stamina

### T6 · Grey-box lake: catamaran, four guys and the island, set as main scene · done · L · agent
- Depends on: T3, T4, T14
- Touches: scenes/lake.tscn (new), scripts/lake.gd (new), scenes/catamaran.tscn (new), scripts/catamaran.gd (new), scripts/ui/hud.gd (new), scenes/main.tscn (replaced), project.godot (main scene, input actions), scripts/autoload/run_state.gd (reset() reads DrinkTuning.start_level and drops STARTING_DRUNKENNESS; wires Paddling, Drunkenness and Stamina), tests/test_run_state.gd, scripts/resources/boat_tuning.gd (+thrust_scale, +turn_scale, +linear_damping, +angular_damping), data/boat_tuning.tres, scripts/resources/lake_tuning.gd (new, +island_distance), data/lake_tuning.tres (new)
- Done when: the check loads the main scene without errors (check) · Q, A, I and K (left front, left back, right front, right back), hold to charge and release to stroke, paddle the boat from the shore against the current to the island, and reaching it with all four aboard ends the attempt (play) · a guy's break warning and break read at a glance on him (play) · the HUD shows progress and each guy's drunkenness and stamina (play)
- GDD: Systems › Lake and island · Win and Loss

### T31 · Timing-bar strokes at the top drunkenness tier replace the scrambled keys · done · M · agent
- Depends on: T6
- Touches: scripts/systems/drunkenness.gd (replace scrambled/key_target/scramble_target with the timing bar), scripts/resources/drink_tuning.gd (+bar_period, +green_width; scramble_level renamed bar_level), data/drink_tuning.tres, scripts/autoload/run_state.gd (stroke: outside the green zone the stroke is backwards), scripts/catamaran.gd (the bar next to the guy while his key is held), scripts/systems/paddling.gd (Stroke.backwards), tests/test_drunkenness.gd, tests/test_run_state.gd
- Done when: at bar_level and above, the bar position for a hold time sweeps back and forth with bar_period, and a release inside green_width of the centre counts as a hit (test) · a hit gives the normal stroke, a miss a backwards stroke of the same power, and both burn stamina (test) · the bar is visible next to the guy while his key is held, and the tier is announced with a wind-up (play) · nothing references the old scrambled-key mapping (check)
- GDD: Systems › Drunkenness

### T8 · Camera follows the boat with look-ahead · done · S · agent
- Depends on: T6
- Touches: scenes/lake.tscn, scenes/catamaran.tscn (camera moved out), scripts/lake_camera.gd (new), scripts/resources/boat_tuning.gd (+camera_lead), data/boat_tuning.tres
- Done when: the camera stays centred on the boat and leads toward its direction of travel by camera_lead (play)
- GDD: Presentation and Platforms

### T9 · Rescue: beers overboard, guys after them, fewer paddlers until each is picked up, shore reset · done · L · agent
- Depends on: T6, T5
- Touches: scripts/systems/rescue.gd (new), scripts/resources/boat_tuning.gd (+swim_speed, +beer_toss, +pickup_radius), data/boat_tuning.tres, scripts/autoload/run_state.gd, scripts/catamaran.gd, scripts/lake.gd, scenes/lake.tscn, project.godot (debug_beer_left F5, debug_beer_right F6, debug builds only), scripts/systems/drunkenness.gd (drinking flag), tests/test_rescue.gd (new), tests/test_run_state.gd
- Done when: each beer overboard puts one more guy in the water (the one on the side the hazard hit), with no limit, and strokes from his seat do nothing until he is back (test) · the beer drifts at current_speed, the swimmer swims to it at swim_speed, then drifts with it (test) · the boat reaching a swimmer puts him aboard (test) · with nobody aboard the boat drifts at current_speed, and reaching the shore resets the attempt to the starting conditions (test) · the guy visibly jumps, swims, floats drinking, and climbs back in (play)
- GDD: Systems › Setbacks

### T32 · Stamina pauses for a guy in the water · done · S · agent
- Depends on: T9
- Touches: scripts/autoload/run_state.gd, tests/test_run_state.gd
- Done when: a guy in the water neither recovers stamina nor rolls random breaks, and comes back in the state he left (test)
- GDD: Systems › Stamina

### B1 · A stroke released just before the guy jumps still lands · done · S · agent · low
- Depends on: T9
- Touches: scripts/autoload/run_state.gd, tests/test_run_state.gd
- Repro: release a key, then knock that guy's beer over (F5/F6 in a debug build) before the pending stroke lands (same physics frame, or within a drunk guy's lag) → expected: no stroke / actual: the stroke lands from the water
- Found in: T9
- GDD: Systems › Setbacks

### T10 · Hazard framework: seeded bands, effects palette, and the floating log · done · M · agent
- Depends on: T6, T9
- Touches: scripts/systems/hazards.gd (new), scripts/resources/hazard.gd (new, +weight, +first_band, +shove_strength, +hit_cooldown), data/hazards/log.tres (new), scripts/resources/lake_tuning.gd (+lake_width, +band_length, +density_curve, +hazards, +launch_margin, +island_radius), data/lake_tuning.tres, scripts/resources/boat_tuning.gd (+bail_rate), data/boat_tuning.tres, scripts/autoload/run_state.gd (effects palette, lake_seed), scripts/lake.gd, scenes/lake.tscn, scripts/catamaran.gd, scripts/hazards/log.gd (new), scenes/hazards/log.tscn (new), tests/test_hazards.gd (new)
- Done when: each band draws hazards from the weighted list with density per density_curve, from one seed, so the same seed gives the same lake (test) · the effects beer overboard, shove, snag, stop, forced break and water aboard exist as calls on the boat and the guys (test) · a floating log drifts at current_speed, is visible before it reaches the boat, and a bump knocks a beer overboard on the side hit and shoves the boat (play)
- GDD: Systems › Hazards

### T33 · Hazards respawn: a lake that has drifted its hazards past the shore refills ahead of the boat · done · M · agent
- Depends on: T10
- Touches: scripts/systems/hazards.gd, scripts/lake.gd, tests/test_hazards.gd
- Done when: a band whose hazards have all drifted past the shore is re-planned from the attempt's seed and a band counter, so a long crossing never meets an empty lake (test) · respawned hazards appear outside the camera's look-ahead (play)
- GDD: Systems › Hazards

### B2 · A swimmer who drifts past the shoreline can't be picked up · done · M · agent · med
- Depends on: T10
- Touches: scripts/systems/rescue.gd, scripts/autoload/run_state.gd, scripts/resources/boat_tuning.gd (+shore_margin), data/boat_tuning.tres, tests/test_rescue.gd, tests/test_run_state.gd
- Repro: knock a beer over while the boat rests at the launch shore (a band-1 log drifting into it, or F5) → the swimmer drifts down through the shoreline where the boat can't reach him; shore_touched() does nothing in LAUNCH → expected: he washes up and climbs back aboard, or the shore stops him within reach / actual: stuck until the player paddles off and comes back for a shore reset
- Found in: T10 review
- GDD: Systems › Setbacks

### B3 · The camera never followed the boat · done · S · agent · high
- Depends on: T8
- Touches: scenes/lake.tscn
- Repro: paddle away from the shore → expected: the view follows the boat / actual: the view stays on the launch shore. The camera's exported `boat` node was null because the hand-written scene lacked the `node_paths` marker Godot needs to resolve an exported node.
- Found in: ad hoc (the human's first play)
- GDD: Presentation and Platforms

### T34 · A beer bobs away for a moment before a guy winds up and jumps · done · M · agent
- Depends on: T9
- Touches: scripts/systems/rescue.gd, scripts/resources/boat_tuning.gd (+jump_delay), data/boat_tuning.tres, scripts/autoload/run_state.gd, scripts/lake.gd, scripts/catamaran.gd, tests/test_rescue.gd, tests/test_run_state.gd, tests/test_hazards.gd
- Done when: a beer overboard floats loose for jump_delay seconds before the chosen guy leaves the boat; his seat still paddles until he jumps (test) · the wind-up reads on the guy and the beer is visible drifting during the delay (play)
- GDD: Systems › Setbacks

### T35 · Loose things drift faster than the boat · done · S · agent
- Depends on: T9
- Touches: scripts/resources/boat_tuning.gd (+loose_drift_speed), data/boat_tuning.tres, scripts/autoload/run_state.gd, tests/test_run_state.gd
- Done when: beers and swimmers drift at loose_drift_speed while the boat drifts at current_speed, with loose_drift_speed the larger placeholder (test)
- GDD: Systems › Catamaran and paddling · Systems › Setbacks

### T36 · Objects are fixed: the log stops drifting, the band refill goes · done · S · agent
- Depends on: T33
- Touches: scripts/hazards/log.gd, scripts/lake.gd, scripts/systems/hazards.gd, tests/test_hazards.gd
- Done when: a log stays where it was planned (test) · no band refill code remains; plan_band stays for the path and future events (check) · the check passes (check)
- GDD: Systems › Hazards

### T37 · A guaranteed path winds through every band · done · M · agent
- Depends on: T36
- Touches: scripts/systems/hazards.gd, scripts/resources/lake_tuning.gd (+path_width, +path_wander), data/lake_tuning.tres, tests/test_hazards.gd
- Done when: no object is placed inside the corridor, whose centre moves by at most path_wander between neighbouring bands and stays inside the lake (test) · the corridor is continuous from the launch to the island (test)
- GDD: Systems › Hazards

### T38 · Size the lake for a five-minute clean crossing · done · S · agent
- Depends on: T37
- Touches: data/lake_tuning.tres, scripts/lake.gd, scripts/resources/lake_tuning.gd
- Done when: island_distance, lake_width and band_length are set so a steady full-power crossing with no incidents takes about five minutes at the current boat speed, and the water polygon covers the whole lake (check: the arithmetic quoted) · the crossing feels huge (play)
- GDD: Core Loop › Session

### T39 · Debug overlay draws the guaranteed path · done · S · agent
- Depends on: T37
- Touches: scripts/lake.gd, scenes/lake.tscn, project.godot (debug_toggle_path F7)
- Done when: in debug builds (`OS.is_debug_build() or OS.has_feature("dev_tools")`) a translucent strip shows the corridor from `Hazards.corridor_x` so path_width and path_wander can be tuned by eye, toggled with a debug key (check: the gate is quoted) · the strip follows the planned path (play)
- GDD: (none)

### T44 · A swimmer without a beer looks different from one drinking · done · S · agent
- Depends on: T13, T22
- Touches: scripts/lake.gd
- Done when: a floating swimmer shows a beer at his mouth only while `has_beer` is true, so the pee-antic victim reads as beerless (play)
- GDD: Systems › Drunkenness

### T45 · Off-screen arrows point at guys in the water · done · M · agent
- Depends on: T9, T22
- Touches: scripts/ui/offscreen_arrows.gd (new), scenes/lake.tscn (HUD), tools/gen_sprites.gd, assets/sprites/arrow.png (new), tests/test_offscreen_arrows.gd (new)
- Done when: for every swimmer outside the camera's view an arrow sits at the edge of the screen pointing at him, in his seat colour, and disappears when he is on screen or picked up (play) · the arrow's screen position is the clamped projection of his lake position, computed in a helper with a test (test)
- GDD: Systems › Setbacks

### T46 · At most one beer overboard per beer_loss_cooldown · done · S · agent
- Depends on: T9
- Touches: scripts/autoload/run_state.gd, scripts/resources/boat_tuning.gd (+beer_loss_cooldown), data/boat_tuning.tres, tests/test_run_state.gd, tests/test_hazards.gd
- Done when: after a beer goes over, beer_overboard() does nothing for beer_loss_cooldown seconds while shove/stop still apply, then works again (test) · the cooldown resets with the attempt (test)
- GDD: Systems › Hazards

### T47 · An empty boat drifts home at empty_drift_multiplier times the headwind · done · S · agent
- Depends on: T9
- Touches: scripts/autoload/run_state.gd, scripts/resources/boat_tuning.gd (+empty_drift_multiplier), data/boat_tuning.tres, tests/test_run_state.gd
- Done when: with nobody aboard, Motion.drift_to_shore is current_speed × empty_drift_multiplier per second; with anyone aboard it is current_speed (test)
- GDD: Systems › Setbacks

### T48 · The control scheme is written in the sand on the launch shore · done · S · agent
- Depends on: T22
- Touches: scenes/lake.tscn, tools/gen_sprites.gd, assets/sprites/sand_text.png (new)
- Done when: at the launch shore, text scratched into the sand shows the four keys at their seats (Q A left, I K right, hold to charge, release to stroke) beside the boat's start, and nothing of it is on screen once the boat has left (play)
- GDD: Presentation and Platforms

### T49 · Remove the unused single-pose guy sprites and their generator branch · done · S · agent
- Depends on: T23
- Touches: tools/gen_sprites.gd, assets/sprites/guy_0..3.png (+.import, deleted)
- Done when: no scene or script references assets/sprites/guy_<seat>.png and the files and their generator code are gone (check)
- GDD: (none)

### T50 · The Loch-Brez beast: boundary enforcer and rare deep-water visitor · done · L · agent
- Depends on: T10, T9, T22
- Touches: scripts/systems/beast.gd (new), scripts/hazards/beast.gd (new), scenes/hazards/beast.tscn (new), scripts/lake.gd (spawned once per lake, not planned), scripts/resources/lake_tuning.gd (+beast_edge_margin, +beast_beyond_island, +beast_warning, +beast_speed, +beast_shove, +beast_spit_distance, +beast_random_rate, +beast_ram_distance, +beast_hit_radius, +beast_ram_timeout, +beast_pause, +beast_dive_time), data/lake_tuning.tres, scripts/autoload/run_state.gd (beast_grab(hull, from, spit_distance), signal guy_grabbed), tools/gen_sprites.gd, assets/sprites/beast_*.png (new), tests/test_beast.gd (new)
- Done when: the beast rises when the boat is within beast_edge_margin of a lake edge or beyond the island's far side by beast_beyond_island, and rarely elsewhere from the attempt's seed at beast_random_rate; it circles for beast_warning, then rams (a shove of beast_shove toward the lake's middle) and grabs the guy on the hull it hit, who is spat out beast_spit_distance back toward the shore as a swimmer (test) · it dives once the boat is back inside, or after one grab on a random visit (test) · the fin, the circling and the grab read at a glance (play)
- GDD: Systems › Hazards

### T51 · Once the geese hiss, the charge always comes · done · S · agent
- Depends on: T15
- Touches: scripts/systems/geese.gd, tests/test_geese.gd
- Done when: leaving geese_radius during the hiss no longer calms the flock; the charge follows the warning regardless (test)
- GDD: Systems › Hazards

### T52 · The jet-ski crosses on a diagonal from the lake edge · done · S · agent
- Depends on: T21
- Touches: scripts/systems/jetski.gd, tests/test_jetski.gd
- Done when: the course runs from the lake edge at the trigger's y through the point jetski_lead ahead of the boat and on past the far edge, at jetski_speed (test)
- GDD: Systems › Hazards

### T53 · Reverse strokes: eight keys, two per seat · done · M · agent
- Depends on: T6, T48
- Touches: project.godot (input actions), scripts/catamaran.gd, scripts/autoload/run_state.gd (stroke(seat, hold_time, backwards)), scripts/systems/paddling.gd, scripts/resources/boat_tuning.gd (+reverse_thrust_fraction), data/boat_tuning.tres, scripts/ui/hud.gd (key labels), tools/gen_sprites.gd, assets/sprites/sand_text.png, tests/test_paddling.gd, tests/test_run_state.gd
- Done when: Q/A, W/S, I/K, O/L map to forward/reverse strokes of the left front, left back, right front and right back seats (check: the input map quoted) · a reverse stroke's thrust is the forward thrust times reverse_thrust_fraction, negated, with the same turn magnitude negated and the same stamina burn (test) · the HUD labels and the sand text show the new keys (play)
- GDD: Core Loop › Moment to moment · Presentation and Platforms

### T54 · Touch controls: hull pads, seat by height, flick to reverse · done · M · agent
- Depends on: T53
- Touches: scripts/ui/touch_pads.gd (new), scenes/lake.tscn (HUD), scripts/catamaran.gd, scripts/resources/boat_tuning.gd (+touch_flick_distance), data/boat_tuning.tres, scripts/win_cutscene.gd, scenes/win.tscn, tests/test_touch_pads.gd (new), tools/gen_sprites.gd, assets/sprites/pad.png
- Done when: a pure helper maps a touch's position and its release motion to (seat, backwards): left/right half → hull, upper/lower part → front/back, a downward flick of at least flick_distance before release → reverse (test) · each finger charges from touch to release and strokes through RunState.stroke(seat, hold_time, backwards), several fingers at once (play) · the pads show only on a touchscreen and the keyboard still works (play)
- GDD: Presentation and Platforms

### T55 · Mobile web layout check on real phones and tablets · todo · (none) · human
- Depends on: T54
- Touches: project.godot (stretch settings if needed), export_presets.cfg
- Done when: the game launches from the itch.io page on an Android phone and an iPhone in landscape, the canvas is neither cropped nor blurred, and the pads are reachable with thumbs (play)
- GDD: Presentation and Platforms

### T56 · Swedish speech bubbles: each guy says what he is about to do, and one calls out each hazard · done · M · agent
- Depends on: T23, T13, T14, T26
- Touches: scripts/ui/speech_bubbles.gd (new), data/lines.tres (new, Swedish lines per telegraph), scripts/resources/lines.gd (new), scenes/lake.tscn (HUD), scripts/autoload/run_state.gd (telegraph, pick_line, lines), scripts/hazards/hazard_base.gd (_telegraph), scripts/hazards/*.gd, scripts/resources/lake_tuning.gd (+call_out_distance), scripts/resources/boat_tuning.gd (+call_out_time), data/lake_tuning.tres, data/boat_tuning.tres, tests/test_lines.gd (new), tests/test_speech_bubbles.gd (new)
- Done when: at each wind-up (stamina warning, antic wind-up, timing-bar wind-up, jump wind-up) a small bubble over the guy shows a Swedish line for that telegraph, drawn from a per-telegraph list in data (e.g. pee: "Jag måste pissa", break: "Fyfan va trött jag är!"), and goes away at the effect (play) · when a hazard telegraphs (geese hiss, gust or headwind warning, wake's motorboat, jet-ski warning, beast circling, a log or rock ahead on the path) one guy aboard, the one on the hull it comes from or else any, calls it out in a bubble ("Nu jävlar blåser det!", "Se upp för fåglarna!") (play) · the lines live in a Resource the human can edit, with a test that every telegraph and every hazard has at least one line (test)
- GDD: World and Narrative · Systems › Drunkenness · Systems › Stamina

### T57 · Key columns: outer keys are the back seats, inner keys the front · done · S · agent
- Depends on: T53
- Touches: project.godot (input actions), scripts/ui/hud.gd (labels), scripts/catamaran.gd (comments), tools/gen_sprites.gd, assets/sprites/sand_text.png
- Done when: Q/A drive the left back seat, W/S the left front, I/K the right front, O/L the right back (check: the input map quoted) · the HUD labels and the sand text show it (play)
- GDD: Presentation and Platforms

### T58 · Touch pads split sideways like the keys: outer back, inner front · done · S · agent
- Depends on: T54, T57
- Touches: scripts/ui/touch_pads.gd, tests/test_touch_pads.gd
- Done when: within a screen half, the outer part maps to the back seat and the inner part to the front seat, the whole height of the half counting (test) · the four pads sit outer/inner in each half with the same up/down hints (play)
- GDD: Presentation and Platforms

### T59 · After a few seconds adrift a swimmer swims slowly back toward the boat · done · S · agent
- Depends on: T9
- Touches: scripts/systems/rescue.gd, scripts/resources/boat_tuning.gd (+swim_back_delay, +swim_back_speed), data/boat_tuning.tres, tests/test_rescue.gd
- Done when: a FLOATING swimmer, after swim_back_delay seconds, moves toward the boat at swim_back_speed on top of the drift, with swim_back_speed a placeholder below loose_drift_speed (test) · a SWIMMING guy (after his beer) and a washed-up one are unaffected (test)
- GDD: Systems › Setbacks

### B5 · The guaranteed path can lead into the beast's edge zone · done · S · agent · high
- Depends on: T37, T50
- Touches: scripts/systems/hazards.gd (path_reach), tests/test_hazards.gd, tests/test_beast.gd
- Repro: follow the corridor where it wanders to the lake's side → expected: the beast never rises on the path / actual: path_reach allows corridor centres up to lake_width/2 − path_width/2 = 740 px while the beast rises beyond lake_width/2 − beast_edge_margin = 680 px, so the path summons it
- Found in: ad hoc (the human's play)
- GDD: Systems › Hazards

### T60 · The beast's random visit is super rare · done · S · agent
- Depends on: T50
- Touches: data/lake_tuning.tres (beast_random_rate), scripts/resources/lake_tuning.gd
- Done when: beast_random_rate is set so the expected number of random visits in a five-minute crossing is well below one (the arithmetic quoted) (check)
- GDD: Systems › Hazards

### T61 · The hazard boats are drawn big enough to recognise: motorboat, jet-ski, dinghy · done · S · agent
- Depends on: T24
- Touches: tools/gen_sprites.gd, assets/sprites/hazards/{motorboat,motorboat_spray_0,motorboat_spray_1,jetski_0,jetski_1,dinghy}.png, scenes/hazards/wake.tscn, scripts/hazards/fishing_line.gd
- Done when: the motorboat and the dinghy are at least the catamaran's size (40×56) and the jet-ski at least 32×18 with its rider, the sprays and the fisherman scaled with them, and the hit radii still match the art (check: sizes quoted) · they read at a glance in play (play)
- GDD: Presentation and Platforms

### T62 · Reset: R on the keyboard, a hold-to-reset corner button on touch · done · S · agent
- Depends on: T28, T54
- Touches: project.godot (input action reset R), scripts/lake.gd (restart on reset), scripts/ui/reset_button.gd (new), scenes/lake.tscn, scripts/resources/boat_tuning.gd (+reset_hold_time), data/boat_tuning.tres, tools/gen_sprites.gd, assets/sprites/reset.png (new), tests/test_reset_button.gd (new)
- Done when: pressing R starts a new attempt (RunState.new_attempt and the lake's restart), also during the win cutscene (play) · on a touchscreen a small corner button resets only after being held for reset_hold_time with a ring filling, and a shorter touch does nothing; the hold logic is a pure helper with a test (test) · the button never overlaps the pads (play)
- GDD: Presentation and Platforms

### T63 · Drunkenness comes down: puking at the top, a little relief from peeing · done · M · agent
- Depends on: T13, T23, T56
- Touches: scripts/systems/antics.gd (PUKING, just_finished), scripts/systems/drunkenness.gd (relieve), scripts/resources/drink_tuning.gd (+puke_level, +puke_time, +puke_relief, +pee_relief), data/drink_tuning.tres, scripts/autoload/run_state.gd, scripts/catamaran.gd, scripts/ui/speech_bubbles.gd, tools/gen_sprites.gd, assets/sprites/guys/ (puke frames), data/lines.tres (puke lines), scripts/resources/lines.gd, tests/test_antics.gd, tests/test_drunkenness.gd, tests/test_run_state.gd
- Done when: a guy whose level reaches 1.0 winds up and pukes overboard: his seat gives no strokes for puke_time, then his level drops by puke_relief (test) · finishing a pee lowers his level by pee_relief (test) · the puke has its own frames and a Swedish line, and the meter visibly falls (play)
- GDD: Systems › Drunkenness

### T64 · Puking has a one-in-fifty chance of drawing the beast · done · S · agent
- Depends on: T63, T50
- Touches: scripts/autoload/run_state.gd (signal puked), scripts/systems/beast.gd, scripts/hazards/beast.gd, scripts/resources/lake_tuning.gd (+beast_puke_chance), data/lake_tuning.tres, tests/test_beast.gd, tests/test_run_state.gd
- Done when: when a puke finishes RunState emits puked(seat) (test) · the beast, hearing it while submerged and in open water, rolls beast_puke_chance from its own RNG and on a hit starts a random visit (one grab) (test)
- GDD: Systems › Drunkenness · Systems › Hazards

### T65 · The timing-bar tier lasts bar_duration, then ends and can return after bar_cooldown · done · S · agent
- Depends on: T31
- Touches: scripts/systems/drunkenness.gd, scripts/resources/drink_tuning.gd (+bar_duration, +bar_cooldown), data/drink_tuning.tres, tests/test_drunkenness.gd
- Done when: after its wind-up the bar applies for bar_duration (10–15 s placeholder) then ends even if the level stays at or above bar_level (test) · it can be announced again after bar_cooldown if the level is still at or above bar_level (test) · dropping below bar_level ends it as before (test)
- GDD: Systems › Drunkenness

### T66 · The sand text also shows R = reset · done · S · agent
- Depends on: T62
- Touches: tools/gen_sprites.gd, assets/sprites/sand_text.png
- Done when: the sand diagram carries a third line "R = RESET" (or Swedish "R = OM IGEN") under the key lines, legible at 1× (play)
- GDD: Presentation and Platforms

### T67 · The sand text is drawn at twice the scale · done · S · agent
- Depends on: T66
- Touches: scenes/lake.tscn (SandText scale and position)
- Done when: the sand diagram shows at 2× on the beach beside the launch, fully on the sand and still gone once the boat has left (play)
- GDD: Presentation and Platforms

### T68 · The guys get names from the crew's list; the HUD shows names, not keys · done · M · agent
- Depends on: T6, T56
- Touches: scripts/resources/names.gd (new), data/names.tres (new), scripts/autoload/run_state.gd (names per attempt), scripts/ui/hud.gd (labels), scripts/win_cutscene.gd, scenes/win.tscn (names on the title), tests/test_names.gd (new), tests/test_run_state.gd
- Done when: each new attempt gives the four seats distinct names drawn from data/names.tres with the attempt's RNG (test) · the HUD shows each guy's name instead of the seat and key labels (play) · the list is a Resource the human can edit, with a test that it holds at least four names (test)
- GDD: Characters and Units

### T69 · A guy warns when the boat approaches the beast's water · done · S · agent
- Depends on: T50, T56
- Touches: scripts/systems/beast.gd (near_bounds, check_approach, rise_cause), scripts/hazards/beast.gd (debug print of the rise cause), scripts/systems/hazards.gd (path_reach also clears the warning band), scripts/resources/lake_tuning.gd (+beast_warn_margin), data/lake_tuning.tres, scripts/resources/lines.gd, data/lines.tres (edge lines), tests/test_beast.gd, tests/test_hazards.gd
- Done when: near_bounds(position) is true within beast_warn_margin of the out-of-bounds line at either edge or beyond the island's far side, and false inside (test) · entering that zone from inside telegraphs `edge` on the hull facing the edge once per approach, re-armed when the boat is back inside (test) · a Swedish line shows over the hull's guy (play)
- GDD: Systems › Hazards

### T70 · Wire the play log · done · M · agent
- Depends on: (none)
- Touches: tools/play_log.gd (the seed's hooks), scripts/autoload/run_state.gd (begin_run at new_attempt, log each stroke, jump, pickup, hazard effect, antic, win and shore reset with stable event ids, log_snapshot where the player acts), scripts/lake.gd (view_changed for the lake and the win screen), tests/test_play_log.gd (new)
- Done when: a new attempt begins a run whose log holds a line with a stable event id for every player action, hazard effect, antic, rescue step, shore reset and win, asserted through `PlayLog.start_capture()` (test) · `_build_snapshot()` and `progress_block_reason()` are filled from RunState (test) · the log of a played session reads as what happened (play)
- GDD: (none)

### T71 · Wire autoplay · done · M · agent
- Depends on: T70
- Touches: tools/autoplay_adapter.gd (start_run with the seed, list_actions with the eight strokes and reset as `ui` actions, state, is_run_over), tools/autoplay_scenarios.gd (smoke plus a scripted crossing), tools/autoplay_invariants.gd (progress never below 0, four guys accounted for), tools/check.cfg ([autoplay] on)
- Done when: `bash tools/autoplay.sh --all` exits 0 and `bash tools/log_review.sh --latest` writes a review (check) · the check plays smoke with `check_in_check=true` and `enforce=["smoke"]` (check)
- GDD: (none)

### T72 · Wire the dev menu: register the systems with their debug hooks · done · S · agent
- Depends on: (none)
- Touches: tools/dev_menu.gd (register_system for RunState, Rescue, Beast, Antics, Stamina, Drunkenness), scripts/autoload/run_state.gd (debug_* actions: beer overboard per hull, force an antic, set a level; debug_inspect())
- Done when: F12 in a debug build opens tabs for the systems with their actions and inspectors and a Log tab, and the menu is absent in a release build (play) · `inspect_text("Run")` lists progress, phase and the four guys (test)
- GDD: (none)

### T73 · Set up release · todo · M · agent
- Depends on: Q7
- Touches: release.cfg (new), AGENTS.md, .github/workflows/release.yml (new, if the human uses GitHub Actions)
- Done when: `release.cfg` names an upload command for each preset Q7's decision names, and `bash tools/release.sh uat --dry-run` lists them (check)
- GDD: (none)

### T81 · The screen catalog lists the lake and the win screen · done · S · agent
- Depends on: T71
- Touches: tools/ui_screens.gd (entries lake and win with their overlays: HUD, pads, bubbles, arrows, reset button), tools/autoplay_scenarios.gd (smoke no longer skips "main")
- Done when: `bash tools/log_review.sh --latest` after `bash tools/autoplay.sh smoke` reports the lake as a catalog view that smoke opened, and the stub "main" entry is gone (check) · `bash tools/ui_capture.sh --list` lists lake and win (check)
- GDD: (none)

### T82 · The play log's block reason is empty at the launch shore · done · XS · agent
- Depends on: T70
- Touches: tools/play_log.gd (progress_block_reason), scripts/autoload/run_state.gd (block_reason), tests/test_play_log.gd
- Done when: block_reason() is "" in LAUNCH as in CROSSING, since strokes are allowed at the shore, and still "nobody aboard" and "won" (test) · a person's log no longer starts with `progress.blocked: launch` (check: the signature sig-7a33327f no longer appears in a fresh run's review)
- GDD: (none)

### T83 · A reset during an autoplay run keeps one log file · done · S · agent
- Depends on: T71
- Touches: scripts/autoload/run_state.gd (new_attempt continues the run under autoplay instead of beginning a new one, or logs the reset as a step of the same run), tools/autoplay_adapter.gd (the reset action's weight above 0 once it is safe), tests/test_play_log.gd
- Done when: a scripted scenario step through the `reset` ui action leaves one `.log`/`.jsonl` pair in the run folder and `bash tools/log_review.sh` reviews the autoplay lines, not a "played by a person" log (check) · the reset action gets a random weight above 0 in the adapter (check)
- GDD: (none)

### T85 · The lake is a third of the length · done · XS · agent
- Depends on: T33
- Touches: data/lake_tuning.tres (island_distance 24000 → 8000), design/gdd.md
- Done when: island_distance is 8000, a third of before, and the GDD's session length says about two minutes clean (check: the values quoted)
- GDD: Core Loop › Session

### T87 · A snagged guy yells about the fishing line · done · S · agent
- Depends on: T18, T56
- Touches: scripts/autoload/run_state.gd (signal snagged), scripts/resources/lines.gd (+snag), data/lines.tres, scripts/ui/speech_bubbles.gd (the yell on his seat), tests/test_hazards.gd, tests/test_speech_bubbles.gd
- Done when: snag() emits snagged(seat) when it found a guy and nothing for an empty hull (test) · the `snag` kind has at least one Swedish line (test) · the snagged guy's bubble shows one for call_out_time in play (play)
- GDD: World and Narrative

### T97 · Landing short-handed is a win: the left-behind are named on the win title with a dark joke · done · M · agent
- Depends on: T28, T86
- Touches: scripts/autoload/run_state.gd (arrive() wins with one or more aboard and records `left_behind`, the seats in the water; arrived_short goes), scripts/lake.gd (the island stops the boat), scenes/lake.tscn (an island body if needed), scripts/win_cutscene.gd and scenes/win.tscn (only the guys aboard hop ashore and camp; the heading says how many made it; a line per left-behind guy), scripts/resources/lines.gd and data/lines.tres (+left_behind: dark jokes with a %s for the name), scripts/systems/stats.gd (a "Left behind" row), tests/test_run_state.gd, tests/test_stats.gd, tests/test_lines.gd
- Done when: arrive() with one to four aboard sets WON, logs run.won with the left-behind seats, and keeps them in `left_behind`; with nobody aboard it does nothing (test) · the boat can't sail over the island: it stops at its shore (test or play) · the win title's heading is "They made it" with a full crew and "%d of 4 made it" short-handed, and each left-behind guy gets a line drawn from `left_behind` with his name (test on the pure helper) · the cutscene hops and seats only the guys who were aboard (play) · Stats has a Left behind row (test)
- GDD: Win and Loss

### T96 · The splash plays the song with vocals in the NES style · done · XS · agent
- Depends on: T95
- Touches: assets/audio/music/vi_ses_om_ett_ar_igen_nes.wav (new, looping), assets/audio/music/vi_ses_om_ett_ar_igen_16bit.wav.import (skip), scenes/splash.tscn (music), tools/song_styles.py, design/gdd.md, AGENTS.md
- Done when: the splash's `music` is the NES-style render with vocals from `tools/song_styles.py`, imported looping (check: the scene quoted) · the MIDI rendition and the plain recording are not in the build (check) · it plays on the splash (play)
- GDD: Presentation and Platforms

### T95 · The splash song as 16-bit MIDI music: melody, bass and beat transcribed and rendered · done · M · agent
- Depends on: T93
- Touches: tools/song_midi.py (new: transcribe and render), assets/audio/music/vi_ses_om_ett_ar_igen.mid (new), assets/audio/music/vi_ses_om_ett_ar_igen_16bit.wav (new, looping), assets/audio/music/vi_ses_om_ett_ar_igen.wav.import (skip), scenes/splash.tscn (music), design/gdd.md, AGENTS.md
- Done when: `python -I tools/song_midi.py transcribe` writes a type-1 MIDI file of the song's melody, bass and beat at its tempo and key (check: 123.6 BPM, B minor, 85 bars, 341 melody and 197 bass notes) · `render` plays it with FM brass, FM slap bass, synthesised drums and an echo to a looping WAV the splash plays (check: the scene quoted) · the plain recording is not in the build (check) · it sounds like the song as 16-bit console music (play)
- GDD: Presentation and Platforms

### B8 · The splash is silent on the web · done · S · agent · high
- Depends on: T92
- Touches: scripts/ui/splash.gd (hold_for_sound, needs_sound_input, the first input turns the music on), tests/test_splash.gd, design/gdd.md
- Repro: open the game on itch.io: the splash shows but no music plays. The browser holds all audio until the first key, click or tap inside the game, and that first press also dismissed the splash, so the song was never heard
- Done when: on the web the splash first prompts "Press any key for sound" ("Tap for sound"), the first input restarts the music and resets the guard without fading, and the next input after the guard fades it; off the web nothing changes (test: a regression test drives both presses) · the song plays on itch.io after the first press (play)
- GDD: Presentation and Platforms

### T94 · A MIDI-like babble whenever a guy talks · done · S · agent
- Depends on: T56, T26
- Touches: scripts/autoload/run_state.gd (pick_line(kind, seat) emits spoke(seat, kind) for a non-empty line), scripts/ui/speech_bubbles.gd (passes the speaker's seat), scripts/autoload/audio.gd (plays the seat's babble on spoke), tools/gen_audio.gd (guy_talk_0..3), assets/audio/guy_talk_0..3.wav (new), tests/test_lines.gd
- Done when: pick_line(kind, seat) emits spoke(seat, kind) when it returns a line and nothing for a kind without lines (test) · every bubble the speech bubbles show is drawn with its speaker's seat (test or check: the calls quoted) · Audio plays guy_talk_<seat>, four short square-wave babbles in each guy's own pitch, generated by tools/gen_audio.gd (check) · you hear who talks, not too loud over the rest (play)
- GDD: World and Narrative

### T93 · The splash plays the director's song "Vi ses om ett år igen" · done · XS · agent
- Depends on: T92
- Touches: assets/audio/music/vi_ses_om_ett_ar_igen.wav (new, converted), scenes/splash.tscn (music), .gitignore (the source WAV and its .import), design/gdd.md
- Done when: the source WAV (32-bit float stereo 44.1 kHz, 58 MB) is converted to 16-bit mono 22 kHz in assets/audio/music/ and the splash's `music` points at it (check: the scene quoted) · the source in the repository root is gitignored and set to skip import, so it stays out of the build (check) · it plays on the splash (play)
- GDD: Presentation and Platforms

### T92 · A splash screen with the title, "Press any key" and placeholder chiptune music · done · M · agent
- Depends on: T24, T26, T54
- UI: design/ui/splash.md
- Touches: scenes/splash.tscn (new), scripts/ui/splash.gd (new), scenes/main.tscn (the splash over the lake), assets/audio/default_bus_layout.tres (+Music bus), tools/gen_audio.gd (the placeholder theme), assets/audio/music/splash_theme.wav (new), tools/ui_screens.gd (catalog entry splash), tools/autoplay_adapter.gd (start_run dismisses the splash), tests/test_splash.gd (new)
- Done when: on launch the splash covers the lake with %Backdrop (water, island, the catamaran with the four guys bobbing), %Title "PKSEI", %Subtitle "Paddla Kanot Som En Idiot" and a blinking %Prompt ("Press any key", "Tap to start" on a touchscreen), and a looping theme plays on the Music bus (test: the scene opens with its named elements and a playing stream) · any key, click or tap after the input guard fades the screen and the music out over FADE_TIME and frees the splash; input before it is gone never reaches the boat (test) · the splash shows once per launch, not on a reset or after the win (test) · the music is one exported AudioStream on the splash, so the human's mp3 replaces the placeholder by dropping the file in and pointing the stream at it (check: the scene quoted) · the capture is lint-clean at every configured size and matches the spec (check) · it looks and sounds right (play)
- GDD: Presentation and Platforms

### T91 · The motorboat's hull and the fisherman's dinghy knock a beer over when the boat hits them · done · M · agent
- Depends on: T88, T18
- Touches: scripts/systems/wake.gd (a ram while CROSSING: the boat within wake_hull_radius of the motorboat, once per event), scripts/hazards/wake.gd (applies it: beer overboard on the hull facing the motorboat, a shove of wake_ram_shove along its travel), scripts/resources/lake_tuning.gd (+wake_hull_radius, +wake_ram_shove, +dinghy_radius, +dinghy_shove), data/lake_tuning.tres, scripts/hazards/fishing_line.gd and scenes/hazards/fishing_line.tscn (a Hull area round the dinghy, apart from the line's Snag: beer overboard on the hull facing it and a shove away, with the spec's hit_cooldown), tests/test_wake.gd, tests/test_fishing_line.gd
- Done when: a boat within wake_hull_radius of the crossing motorboat gets one ram per event, its hull the one facing the motorboat and its shove along the motorboat's travel, separate from the wave's one hit (test) · a boat touching the dinghy gets a beer overboard on the hull facing it and a shove away from it, at most once per hit_cooldown, and crossing the line or the float alone still only snags (test) · both read as a crash in play (play)
- GDD: Systems › Hazards

### T90 · The devlog's section 11: the token split by model, the transcript figures, the measured subscription caps · done · XS · agent
- Depends on: T78
- Touches: design/devlog/01-how-pksei-was-made.md
- Done when: the model-sizing recipe says 48 of the 89 subagent runs inherited Fable 5.1 and cost $67 of the $211 transcript figure while the 41 Haiku and Sonnet runs cost $4, and that a builder's model must be passed from the sizing table, never inherited · a sentence after the token table gives the transcript figures ($211, 0.82 million output tokens, cache within four percent of the report) and says the blog post uses them · the subscription paragraph cites Wokey's measured caps for the week of 2026-10-12 (Pro about $170 over 474 accounts, Max 20x about $1,640 over 17) and the director's heaviest week ($1,401 across six projects), instead of "the director's estimate" (check: the text quoted)
- GDD: (none)

### T89 · Seeing double is reversed controls, not a timing bar · done · M · agent
- Depends on: T65
- Touches: scripts/systems/drunkenness.gd (the tier's cycle stays: wind-up → reversed for bar_duration → cooldown; `reversed(seat)` replaces uses_bar; bar_position, bar_hit, bar_period and green_width go), scripts/resources/drink_tuning.gd (−bar_period, −green_width; the cycle's tunables renamed double_level/double_duration/double_cooldown or kept as bar_*: the builder picks and says), data/drink_tuning.tres, scripts/autoload/run_state.gd (stroke(): backwards flipped while reversed; the log's bar tier → "double"), scripts/catamaran.gd (no bar drawn; the sway frames stay for the tier), scripts/ui/hud.gd, scripts/ui/speech_bubbles.gd (the wind-up line stays), tools/dev_menu.gd, tests/test_drunkenness.gd, tests/test_run_state.gd, tests/test_hud.gd, tests/test_speech_bubbles.gd
- Done when: while a guy is in the top tier every stroke's direction is flipped: a forward key gives the weaker reverse stroke and a reverse key a forward one, with no dependence on the hold time (test) · the wind-up, the duration, the cooldown and the fall below the level end it as before (test) · no bar is drawn and the bar helpers are gone (check: `grep -rn "bar_hit\|bar_position\|green_width\|bar_period" scripts tools` is empty) · the guy sways and the HUD says "seeing double" while it lasts (play)
- GDD: Systems › Drunkenness

### T88 · The motorboat's wake is a V: two fronts at wake_angle either side of its course · done · M · agent
- Depends on: T19
- Touches: scripts/systems/wake.gd (two fronts behind the motorboat, each a line at ±wake_angle from its travel, spreading as it crosses and rolling on after; the hit is the front that crosses the boat, head-on judged against that front's normal), scripts/resources/lake_tuning.gd (+wake_angle, the old front_y/wake_speed kept for the roll), data/lake_tuning.tres, scripts/hazards/wake.gd (two crest lines drawn along the fronts), scenes/hazards/wake.tscn, tests/test_wake.gd
- Done when: each front is a line through the motorboat's position at ±wake_angle (30° placeholder) from its travel, extending behind it, and after the crossing both keep spreading at wake_speed (test) · a boat sitting on the course behind the motorboat is hit by whichever front reaches it first, at most once per event, with the shove and the water of before (test) · a boat heading into a front within wake_head_on_angle of its normal takes no hit, so the boat can cross from one side of the V to the other at an angle (test) · the two crests are drawn as diagonal lines in play (play)
- GDD: Systems › Hazards

### T86 · Run stats, shown on the win screen · done · M · agent
- Depends on: T28, T68, T70
- Touches: scripts/systems/stats.gd (new, RefCounted: counters and `rows()`), scripts/autoload/run_state.gd (owns a Stats, counts where it logs: strokes, beers overboard, jumps, falls, grabs, pickups, pukes, pisses, naps, stand-ups, paddles dropped, breaks, snags, water, hazard hits, shore resets, drunkenness gained, max level; reset at new_attempt), scripts/resources/drink_tuning.gd (+level_per_beer), data/drink_tuning.tres, scripts/win_cutscene.gd, scenes/win.tscn (a stats block under the time), tests/test_stats.gd (new), tests/test_run_state.gd
- Done when: Stats counts every event RunState logs, with a test per counter driven through RunState (strokes landed/fumbled/reverse, beers overboard and rescued, jumps, falls, grabs, pickups, pukes, pisses, naps, stand-ups, paddles dropped, breaks, snags, water aboard, hazard hits by kind, shore resets, max drunkenness) and beers drunk = drunkenness gained / level_per_beer rounded (test) · `Stats.rows()` gives label/value pairs in a stable order with zero rows kept, and the win title lists them under the time in two columns that fit the 640×360 canvas (play) · a new attempt starts the stats over; a shore reset keeps them (test)
- GDD: Win and Loss

### T84 · The dev menu gets a Beast tab: the lake registers its beast on spawn · done · XS · agent
- Depends on: T72
- Touches: scripts/lake.gd (DevMenu.register_system("Beast", ...) when the beast scene spawns, unregister on a new lake), scripts/systems/beast.gd or scripts/hazards/beast.gd (debug_inspect: state, rise cause, bounds), tests/test_beast.gd
- Done when: with a lake up, `DevMenu.systems()` has Beast and `inspect_text("Beast")` names its state and rise cause (test) · a new attempt replaces the registration rather than leaving a stale one (test)
- GDD: (none)

### T80 · Decouple: the swim kind moves from the speech bubbles into Rescue · done · S · agent
- Depends on: T79
- Touches: scripts/systems/rescue.gd (Swimmer.kind(swim_back_delay) or Rescue.swim_kind, with the four kinds as constants), scripts/ui/speech_bubbles.gd (reads it), scripts/ui/hud.gd (reads it; no SpeechBubbles reference), tests/test_rescue.gd, tests/test_speech_bubbles.gd, tests/test_hud.gd
- Done when: the swim kind (fetching, drinking, fallen in, swimming back, washed up) is a Rescue rule with its own test, and neither screen script references the other (check: `grep -n SpeechBubbles scripts/ui/hud.gd` is empty) · the bubbles and the HUD show what they did before (test)
- GDD: Systems › Setbacks

### T79 · The HUD says what each guy is doing whenever he can't paddle · done · S · agent
- Depends on: T68, T74
- Touches: scripts/ui/hud.gd (class_name Hud, a status line per guy, status_text), tests/test_hud.gd (new)
- Done when: Hud.status_text() names the first that applies of the water (after the beer, drinking, fell in, swimming back, washed up), the antic's wind-up by kind and the antic itself ("taking a piss", "puking", "asleep", "standing up!", "dropped the paddle!"), the jump after a beer, a snag, the break and its warning, bailing and the timing bar, and is empty while he paddles (test) · the line sits under the name in a warning colour and reads at a glance in play (play)
- GDD: Core Loop

### T78 · The devlog's claims hold: title, the framework's example page, what the upgrade really brought · done · XS · agent
- Depends on: (none)
- Touches: design/devlog/01-how-pksei-was-made.md
- Done when: the title says "two days", as the numbers table does · the intro links the PKSEI example page on the Director-Driven Development site · section 9 says the upgrade came from a snapshot of Godot Director's development branch (the open pull request Freakling/Godot-Director#25) on top of the v3.13.0 release, and does not claim the release ships the play log, autoplay or the dev menu (check: the text quoted)
- GDD: (none)

### T77 · Touch: the press's height picks forward or reverse, no flick · done · S · agent
- Depends on: T58
- Touches: scripts/ui/touch_pads.gd (is_reverse by press height, no drag tracking), scripts/resources/boat_tuning.gd (-touch_flick_distance), data/boat_tuning.tres, tools/gen_sprites.gd, assets/sprites/pad.png (a middle line), tests/test_touch_pads.gd
- Done when: is_reverse(press, view_size) is true below the pads' line (LINE_OFFSET under PAD_Y of the view's height, the down arrow under it) and false on or above it, whatever the x (test) · a drag before the release changes nothing and touch_flick_distance is gone (check) · each pad shows the line low across it, and the pads sit low on the screen (play)
- GDD: Presentation and Platforms

### B7 · The reset button is hard to press on a phone · done · S · agent · med
- Depends on: T62
- Touches: scenes/lake.tscn (ResetButton rect 48×48 in the corner), scripts/ui/reset_button.gd (DRAG_SLACK, ResetHold.keeps_hold), tests/test_reset_button.gd
- Repro: on an iPhone, press and hold the corner button: the 28 px target is about 30 screen pixels, and a thumb that drifts a few pixels off it cancels the hold, so the reset rarely fires
- Done when: the button's touch target is 48×48 canvas pixels (about 44 pt on a phone) with the icon centred (check: the scene quoted) · a holding finger keeps the hold while within DRAG_SLACK of the rect and loses it further out (test) · the hold fires on a phone with a normal thumb (play)
- GDD: Presentation and Platforms

### B6 · On a phone the game shows at 1× with huge black bands · done · S · agent · high
- Depends on: T54
- Touches: project.godot (window/stretch/scale_mode), AGENTS.md (Project facts)
- Done when: the stretch scale mode is fractional, so the 640×360 canvas fills the shorter side of any window instead of stopping at the largest whole multiple (an iPhone in landscape got 1×, a third of the screen); nearest filtering and pixel snapping stay (check) · the web build at 844×390 and 390×844 fills the height or the width with the letterbox only from the aspect (check: screenshots) · the itch.io page has "Mobile friendly" on so the embed fills the phone's screen (human)
- GDD: Presentation and Platforms

### T76 · Logs and rocks crowd the path: objects land within object_spread of the corridor; more of them · done · S · agent
- Depends on: T10, T20, T21
- Touches: scripts/systems/hazards.gd (place), scripts/resources/lake_tuning.gd (+object_spread), data/lake_tuning.tres (object_spread, density_curve 2→4), data/hazards/log.tres, data/hazards/rock.tres (weight 3), tests/test_hazards.gd
- Done when: with object_spread > 0 every object's centre lies within object_spread of the corridor's centre at its y while still keeping path_width / 2 + half_width clear of it, and with object_spread = 0 placement is over the whole lake as before (test) · logs and rocks weigh 3 against 1 for the rest and the density curve runs 2→4 per band, so a 400 px band holds about one to two obstacles beside the path (check: data quoted) · obstacles appear beside the path every screen or so in play (play)
- GDD: Systems › Hazards

### T75 · Apply the upgraded Claude Code settings · todo · (none) · human
- Depends on: (none)
- Touches: .claude/settings.json
- Done when: the merged settings the 3.13.0 upgrade proposed (kept at `.godot/godot-director/settings.json.upgrade-3.13.0` on the dev machine: adds the `guard-protected.sh` hooks for Edit/Write, `bash tools/autoplay.sh*`, `bash tools/log_review.sh*`, WebSearch and WebFetch to the allow list) replace `.claude/settings.json`, keeping `Bash(git commit *)` in allow; the agent cannot edit that file (play)
- GDD: (none)

### T74 · The guys talk while in the water: fetching, drinking, then nagging to be fetched · done · M · agent
- Depends on: T56, T59
- Touches: scripts/ui/speech_bubbles.gd (bubbles over swimmers; swim_kind), scripts/resources/lines.gd (+swim_fetch, +swim_drink, +swim_fell, +swim_back in KINDS), data/lines.tres (the Swedish lines), scripts/resources/boat_tuning.gd (+swim_talk_interval), data/boat_tuning.tres, tests/test_speech_bubbles.gd, tests/test_lines.gd
- Done when: swim_kind(state, has_beer, adrift, swim_back_delay, washed_up) is `swim_fetch` while he swims for his beer, `swim_drink` while he floats with it before swim_back_delay, `swim_fell` while he floats without a beer before it, `swim_back` once he is swimming back, and empty when washed up (test) · a swimmer's bubble sits over his lake position and shows a freshly drawn line of his kind at once when the kind changes and again every swim_talk_interval seconds, each for call_out_time (test on the pure cadence helper) · each kind has at least three Swedish lines, among them "Ska bara dricka sen kommer jag" (swim_drink) and "Kom och hämta mig dåååå!" (swim_back) (test) · the lines read over the swimmers in play and go away at the pickup (play)
- GDD: Systems › Setbacks · World and Narrative

### T15 · Angry geese guarding goslings · done · M · agent
- Depends on: T10
- Touches: scripts/systems/geese.gd (new), scripts/hazards/geese.gd (new), scenes/hazards/geese.tscn (new), data/hazards/geese.tres (new), scripts/resources/lake_tuning.gd, data/lake_tuning.tres (+geese_radius, +geese_warning, +geese_attack_time, +geese_speed, +geese_peck_interval, +geese_peck_range, +geese_cooldown), tests/test_geese.gd (new)
- Done when: a flock hisses when the boat enters geese_radius, charges and pecks for geese_attack_time, each peck a beer overboard, then returns (test) · the warning and the attack read at a glance (play)
- GDD: Systems › Hazards

### T40 · The lake hands each hazard its tuning, so hazard scripts don't load lake_tuning.tres · done · S · agent
- Depends on: T15
- Touches: scripts/lake.gd, scripts/hazards/*.gd (all nine)
- Done when: lake.gd sets `tuning` (and `spec`) on each spawned hazard that declares it, and no hazard script loads data/lake_tuning.tres itself (check)
- GDD: (none)

### T16 · Motorboat wake · done · M · agent
- Depends on: T10
- Touches: scripts/systems/wake.gd (new), scripts/hazards/wake.gd (new), scenes/hazards/wake.tscn (new), data/hazards/wake.tres (new), scripts/resources/lake_tuning.gd, data/lake_tuning.tres (+wake_trigger_radius, +wake_boat_speed, +wake_lead, +wake_speed, +wake_head_on_angle, +wake_shove, +wake_water), tests/test_wake.gd (new)
- Done when: a motorboat crosses ahead, then a wave front follows it; a head-on crossing does nothing, a broadside one knocks a beer overboard on the high side, shoves the boat sideways by wake_shove and puts wake_water aboard, which the guy on that side bails at bail_rate while his seat gives no strokes (test) · the boat is seen before the wave (play)
- GDD: Systems › Hazards

### T41 · Event triggers are placed on the path, objects beside it · done · M · agent
- Depends on: T16
- Touches: scripts/resources/hazard.gd (+is_event), scripts/systems/hazards.gd, data/hazards/wake.tres, data/hazards/gust.tres, data/hazards/headwind.tres, data/hazards/jetski.tres, tests/test_hazards.gd, scripts/lake.gd (debug marker for triggers)
- Done when: a HazardSpec marked `is_event` is placed inside the corridor (on the path the boat must take) and objects outside it, so every event can fire (test) · in debug builds a small marker shows each trigger point with the F7 overlay (play)
- GDD: Systems › Hazards

### T17 · Wind: gusts and harsh-wind stretches · done · M · agent
- Depends on: T10, T14
- Touches: scripts/systems/gust.gd (new), scripts/systems/headwind.gd (new), scripts/hazards/gust.gd (new), scripts/hazards/headwind.gd (new), scenes/hazards/gust.tscn (new), scenes/hazards/headwind.tscn (new), data/hazards/gust.tres (new), data/hazards/headwind.tres (new), scripts/resources/lake_tuning.gd, data/lake_tuning.tres (+gust_trigger_radius, +gust_warning, +gust_shove, +gust_time, +headwind_force, +headwind_length), scripts/autoload/run_state.gd (push/take_push, set_extra_drift), scripts/catamaran.gd, tests/test_gust.gd (new), tests/test_headwind.gd (new)
- Done when: ripples precede a gust by about a second, then the boat is shoved sideways by gust_shove for gust_time (test) · inside a headwind stretch the current is stronger by headwind_force, so only strong strokes gain water (test) · whitecaps mark the stretch before the boat reaches it (play)
- GDD: Systems › Hazards

### T42 · Shared base for hazard scene scripts (find the boat, the rect, the tuning) · done · S · agent
- Depends on: T17, T40
- Touches: scripts/hazards/hazard_base.gd (new), scripts/hazards/*.gd (seven; log and rock keep their Area2D root)
- Done when: one base script holds `_find_boat()`, `_rect()`, the `tuning`/`spec` fields and their null guards, and every hazard scene script extends it with no duplicate helper left (check)
- GDD: (none)

### T18 · Cross-current stripe · done · S · agent
- Depends on: T10
- Touches: scripts/systems/cross_current.gd (new), scripts/hazards/cross_current.gd (new), scenes/hazards/cross_current.tscn (new), data/hazards/cross_current.tres (new), scripts/resources/lake_tuning.gd, data/lake_tuning.tres (+stripe_force, +stripe_length), tests/test_cross_current.gd (new)
- Done when: while the boat is inside the stripe it is pushed by stripe_force in the stripe's direction (test) · the stripe is visible as a band of faster water (play)
- GDD: Systems › Hazards

### T19 · Rock or buoy · done · S · agent
- Depends on: T10
- Touches: scripts/hazards/rock.gd (new), scenes/hazards/rock.tscn (new), data/hazards/rock.tres (new), data/lake_tuning.tres, tests/test_rock.gd (new)
- Done when: hitting it stops the boat and knocks a beer overboard on the side hit (test)
- GDD: Systems › Hazards

### T20 · Fishing line · done · S · agent
- Depends on: T10
- Touches: scripts/hazards/fishing_line.gd (new), scenes/hazards/fishing_line.tscn (new), data/hazards/fishing_line.tres (new), scripts/resources/lake_tuning.gd, data/lake_tuning.tres (+snag_time, +line_length), tests/test_fishing_line.gd (new)
- Done when: crossing the line snags the paddle on the side that crossed it for snag_time (test) · the dinghy and the line are visible before the boat reaches them (play)
- GDD: Systems › Hazards

### T43 · Objects with an extent keep their whole footprint out of the corridor · done · S · agent
- Depends on: T37, T20
- Touches: scripts/resources/hazard.gd (+half_width), scripts/systems/hazards.gd, data/hazards/fishing_line.tres, data/hazards/log.tres, data/hazards/rock.tres, data/hazards/geese.tres, tests/test_hazards.gd
- Done when: placement keeps a spec's half_width clear of the corridor on both sides, so a fishing line's full length never crosses the path (test)
- GDD: Systems › Hazards

### T21 · Jet-ski idiot · done · M · agent
- Depends on: T10
- Touches: scripts/systems/jetski.gd (new), scripts/hazards/jetski.gd (new), scenes/hazards/jetski.tscn (new), data/hazards/jetski.tres (new), scripts/resources/lake_tuning.gd, data/lake_tuning.tres (+jetski_trigger_radius, +jetski_warning, +jetski_speed, +jetski_lead, +jetski_hit_radius, +jetski_shove), tests/test_jetski.gd (new)
- Done when: a warning of jetski_warning sounds from offscreen, then the jet-ski crosses on a straight line at jetski_speed; a hit shoves the boat hard and knocks a beer overboard (test) · the warning is loud enough to react to (play)
- GDD: Systems › Hazards

### T22 · Pixel art pass 1: catamaran, four guys, water, shore and island · done · M · agent
- Depends on: T6
- Touches: tools/gen_sprites.gd (new, the generator), assets/sprites/*.png (+.import), scenes/catamaran.tscn, scenes/lake.tscn, scenes/hazards/log.tscn, scripts/catamaran.gd, scripts/lake.gd
- Done when: the `Visual` nodes show sprites drawn for the 640×360 canvas, nearest-filtered, in place of the primitives (play) · the human signs off the look (play)
- GDD: Presentation and Platforms

### T23 · Guy animations: stroke, fumble, break warning, antic wind-ups, timing-bar tell · done · M · agent
- Depends on: T22, T13, T14
- Touches: tools/gen_sprites.gd, assets/sprites/guys/ (new, 60 frames), scenes/catamaran.tscn, scripts/catamaran.gd
- Done when: every telegraph in GDD › Drunkenness and GDD › Stamina has its own animation that starts at the warning and ends at the effect (play) · a late or missed stroke is visible as a fumble (play)
- GDD: Systems › Drunkenness · Systems › Stamina

### T24 · Hazard telegraph animations · done · M · agent
- Depends on: T22, T15, T16, T17, T18, T19, T20, T21
- Touches: tools/gen_sprites.gd, assets/sprites/hazards/ (new, 27 frames), scenes/hazards/*.tscn, scripts/hazards/*.gd
- Done when: each telegraph in the GDD › Hazards table is an animation that plays before the effect (play) · the jet-ski sprite faces along its diagonal course (play)
- GDD: Systems › Hazards

### T25 · Audio framework: buses, stroke, splash and guy noises · done · M · agent
- Depends on: T6
- Touches: tools/gen_audio.gd (new, the generator), assets/audio/*.wav (+.import), assets/audio/default_bus_layout.tres (new), scripts/autoload/audio.gd (new), project.godot (autoload, audio buses), scripts/autoload/run_state.gd (signals only), tests/test_run_state.gd
- Done when: the check runs the autoload without errors (check) · strokes, splashes, jumps and pick-ups have sounds, and the master volume follows the player setting (play)
- GDD: Presentation and Platforms

### T26 · Audio telegraphs: engine before the wake, jet-ski offscreen, geese hiss, wind rising · done · M · agent
- Depends on: T25, T15, T16, T17, T21, T50
- Touches: tools/gen_audio.gd, assets/audio/hazards/ (new), scripts/autoload/audio.gd (play_loop/stop_loop), scripts/autoload/run_state.gd (signal guy_fell_in), scripts/hazards/hazard_base.gd, scripts/hazards/{wake,jetski,geese,gust,headwind,beast}.gd, tests/test_run_state.gd
- Done when: each audio telegraph in GDD › Presentation and Platforms › Audio sounds before its hazard is visible, or at its wind-up (play) · a guy knocked in during a pee splashes like a jumper (RunState emits a signal for `guy_overboard`) (test) · the beast's circling has a low rumble and the grab a sound, from `guy_grabbed` (play)
- GDD: Systems › Hazards

### T29 · Shared curve helper replaces the duplicate ramp() in DrinkTuning and StaminaTuning · done · S · agent
- Depends on: T14
- Touches: scripts/resources/curves.gd (new), scripts/resources/drink_tuning.gd, scripts/resources/stamina_tuning.gd, scripts/resources/lake_tuning.gd, tests/test_drunkenness.gd, tests/test_stamina.gd, tests/test_hazards.gd, tests/test_run_state.gd
- Done when: one `ramp()` helper exists and both tunings use it, with the existing tests still passing (check)
- GDD: (none)

### T30 · BoatTuning.current_speed doc says progress units; the boat applies pixels · done · S · agent
- Depends on: T6
- Touches: scripts/resources/boat_tuning.gd
- Done when: the field's doc comment says pixels per second, matching how catamaran.gd applies drift (check)
- GDD: (none)

### T28 · Win cutscene: the boys land, make camp and drink · done · M · agent
- Depends on: T6
- Touches: scenes/win.tscn (new), scripts/win_cutscene.gd (new), scripts/lake.gd (hand-off on `WON`, go-again via new_attempt), scenes/lake.tscn, scripts/catamaran.gd, scripts/ui/hud.gd, scripts/autoload/audio.gd (cheer), tools/gen_sprites.gd, tools/gen_audio.gd, assets/sprites/{guy_camp_0..3,tent,campfire_0,campfire_1}.png, assets/audio/cheer.wav
- Done when: when RunState's phase becomes `WON` (already set by `arrive()`, T6) the cutscene plays: the boys step onto the island, set up camp and drink, then the crossing ends (play) · the check loads the scene (check)
- GDD: Win and Loss

### B4 · Hazards keep acting during the win cutscene · done · S · agent · low
- Depends on: T28, T50
- Touches: scripts/lake.gd (disable the Hazards node's processing while the cutscene runs), scripts/catamaran.gd, scripts/hazards/hazard_base.gd (stop_telegraph), tests/test_catamaran.gd (new)
- Repro: win while a gust, wake, jet-ski or geese charge is active near the island → expected: nothing touches the boat or the guys through the cutscene / actual: take_shove/take_push still move the boat and hits still land (the beast alone guards WON)
- Found in: T28
- GDD: Win and Loss

### T13 · Antics: stand up, drop the paddle, nod off, pee, each with a wind-up · done · M · agent
- Depends on: T5, T6, T9
- Touches: scripts/systems/antics.gd (new), scripts/resources/drink_tuning.gd (+antic_thresholds, +windup_time, +stand_time, +stand_rock, +fish_time, +nap_time, +pee_time, +pee_fall_shove, +stand_rock_period), data/drink_tuning.tres, scripts/autoload/run_state.gd, scripts/systems/drunkenness.gd (comment), scripts/catamaran.gd, scenes/catamaran.tscn, tests/test_antics.gd (new), tests/test_run_state.gd
- Done when: crossing an antic threshold starts a wind-up of windup_time before the antic fires (test) · standing up rocks the boat, dropping the paddle disables that seat until it is fished out, nodding off makes the seat dead weight, peeing disables the seat for pee_time; each recovers on its own (test) · a shove of pee_fall_shove or more during a pee puts that guy in the water without a beer, handled by Rescue (test) · each antic reads at a glance on the guy (play)
- GDD: Systems › Drunkenness

### T12 · Placeholder main scene so the web export has something to ship · done · S · agent
- Depends on: (none)
- Touches: scenes/main.tscn (new), project.godot (main scene)
- Done when: `bash tools/ship.sh --export-only` writes build/web/index.html (check) · the check loads the scene (check)
- GDD: (none)
- Note: a flat-colour screen with a label; T6 replaces it with the grey-box lake.

### T11 · Ship to itch.io on demand (freakling.itch.io/pksei) · done · (none) · human
- Depends on: (none)
- Touches: export_presets.cfg, tools/ship.sh
- Done when: Godot 4.7.2 web export templates are installed (Editor › Manage Export Templates) and `bash tools/ship.sh --export-only` produces build/web/index.html (check) · butler is installed and `butler login` done, `bash tools/ship.sh` pushes the html5 channel and the game runs at the itch.io page, with "This file will be played in the browser" set on that upload (play)
- GDD: Presentation and Platforms

## Notes
- T34–T38 come from the human's first play (2026-10-17) and go before the hazard set: static objects, slow boat drift, the guaranteed path, a huge lake.
- T15–T21 are independent of each other once T10 is done; T17 also needs T14 (stamina). Objects (T15 flock, T18 stripe, T19 rock, T20 line) are fixed; events (T15 charge, T16, T17, T21) happen as the boat passes.
- Stages, as the human wants them: functionality (through T21), then pixel art and animation with telegraphs first (T22–T24), then audio with telegraphs first (T25–T26).
- Player settings have no item yet; the human will decide what they should do later.
- Godot Director 3.13.0 upgrade (2026-10-17): T70 (play log) comes before T71 (autoplay); the check's `[autoplay]` stays off until T71. `tools/ship.sh` stays the release path until Q7 is answered.
- data/hazards/fishing_line.tres `half_width` must stay equal to LakeTuning.line_length by hand.
- T3, T4, T5 and T14 don't share files and can be built in any order after T2.
