extends "res://tools/autoplay_adapter_base.gd"
## The autoplay adapter · project-owned: edit freely.
##
## How `bash tools/autoplay.sh` plays this game: tools/autoplay.gd talks to the game only through this
## file. The action format, and tree, views, play_log(), node(), unique() and wait_frames(), are in
## tools/autoplay_adapter_base.gd.
##
## The game is real-time and has no turns. The driver presses a key for one frame, so a `ui` stroke is a
## tap (the weakest stroke). Each stroke therefore has an `api` twin that calls RunState.stroke() with a
## medium hold, which is what a player's charged stroke does; the twins are the ones that move the boat.
## For the driver, one forward `api` stroke is a "turn": perform() advances the play log's turn counter.
##
## The `pilot` action plays like a steady player for one beat, for the shore-to-island scenario.
## Picking up the guys in the water comes first: while anyone is in the water it steers for the
## nearest one (where he will float, while he still swims for his beer), backing up to a guy behind
## the boat instead of turning round, and easing off the strokes close in so it doesn't overshoot.
## It never aims into the beast's water at the lake's edges or its warning band. Far off course it
## pivots, one side forward and the other backwards (pilot_strokes). With nobody in the water it steers for the guaranteed corridor a look-ahead up the lake, or the
## island once it is close. It strokes the seats that turn the boat toward the target (a left stroke
## turns right; in reverse, the other way round) or all four when it is lined up, pressing the other
## key for a guy who sees double and skipping a guy who can't paddle, then lets the boat run for
## PILOT_FRAMES. Weight 0: the random and smoke strategies never pick it.
##
## The `splash` action shows the game's splash for recording a run, a second at a time: the first one
## puts scenes/splash.tscn up again (start_run takes the boot one down), with its music, and after
## SPLASH_SECONDS the last one fades it out the way a key press does. The `pause` action holds still
## for a second: INTRO_SECONDS once the splash is gone, before the first stroke, and, once the win
## title with the stats is up, OUTRO_SECONDS before the run counts as over. Both have weight 0, so
## only a scenario that scores them (island) picks them; smoke and the check never see the splash.

## The strokes in Paddling.Seat order (S, A, K, L): the seat's name for ids and labels.
const SEATS: Array[String] = ["left_front", "left_back", "right_front", "right_back"]
## The hold of an api stroke, in seconds (BoatTuning.charge_time is 1.0: a half-charged stroke).
const MEDIUM_HOLD: float = 0.5
## Frames the "wait" action lets the boat drift.
const WAIT_FRAMES: int = 12
## The pilot: frames the boat runs after each beat, how far up the lake it aims along the corridor,
## the heading error (radians) past which it only turns, and how close the island must be before it
## aims straight for it.
const PILOT_FRAMES: int = 15
const PILOT_LOOKAHEAD: float = 200.0
const PILOT_TURN: float = 0.18
## Past this heading error (radians) the pilot pivots: one side forward, the other backwards.
const PILOT_PIVOT: float = 0.6
## Off the corridor's centre by more than this share of path_width, it aims back at a nearer point.
const PILOT_OFF_CORRIDOR: float = 0.25
const PILOT_RETURN_LOOKAHEAD: float = 110.0
const PILOT_ISLAND_RANGE: float = 700.0
## Rescue: a guy within this distance and more than PILOT_BEHIND radians off the bow is backed up to;
## within PILOT_EASE the strokes are short (PILOT_EASE_HOLD) so the boat doesn't sail past him.
const PILOT_BACK_RANGE: float = 360.0
const PILOT_BEHIND: float = 1.9
const PILOT_EASE: float = 110.0
const PILOT_EASE_HOLD: float = 0.2
const LAKE_TUNING: LakeTuning = preload("res://data/lake_tuning.tres") as LakeTuning
## The recording pauses: seconds the splash stays up, seconds held after it fades before the first
## stroke, and seconds held on the win title's stats.
const SPLASH_SECONDS: int = 15
const INTRO_SECONDS: int = 3
const OUTRO_SECONDS: int = 20
const SPLASH_SCENE: String = "res://scenes/splash.tscn"

var _turn: int = 0
## Seconds of the intro and outro pauses still to hold in this run.
var _intro_left: int = INTRO_SECONDS
var _splash_left: int = SPLASH_SECONDS
var _outro_left: int = OUTRO_SECONDS


## Seeds the run's generator, then starts a new attempt the way R does (the lake's restart), so the
## same seed draws the same lake (RunState.lake_seed) and crew.
func start_run(run_seed: int) -> void:
	RunState.rng.seed = run_seed
	# The game's boot already began a run (RunState._ready), before the driver pointed the log at this
	# run's folder: begin the run again here, so its files are in the folder.
	play_log().call("begin_run")
	# The splash (T92) pauses the game and swallows input until a key; a run starts on the lake.
	var splash: Node = tree.current_scene.get_node_or_null("Splash") if tree.current_scene != null else null
	if splash != null and splash.has_method("dismiss_now"):
		splash.call("dismiss_now")
	var lake: Node = tree.current_scene.get_node_or_null("Lake") if tree.current_scene != null else null
	if lake != null and lake.has_method("_new_attempt"):
		lake.call("_new_attempt")
	else:
		RunState.new_attempt()
	_turn = 0
	_splash_left = SPLASH_SECONDS
	_intro_left = INTRO_SECONDS
	_outro_left = OUTRO_SECONDS
	play_log().call("set_turn", _turn)
	await wait_frames(2)


## The game has no saves.
func load_save(_path: String) -> bool:
	return false


## The game has no saves.
func save_run(_path: String) -> bool:
	return false


## The strokes, then the reset, then the wait, in a stable order. Each stroke is a `ui` action on its
## InputMap action (a tap) and an `api` twin with a medium hold (forward ones are the progress action).
## The win screen offers only "again".
func list_actions() -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if current_view() == "win":
		# The cutscene plays first: until its title (time, crew, stats) is up, only waiting is legal.
		if _win_title_up() and _outro_left > 0:
			actions.append({"id": "pause", "label": "Hold on the stats", "kind": "api"})
		elif _win_title_up():
			actions.append({"id": "again", "label": "Go again", "kind": "ui", "input": "ui_accept", "progress": true})
		else:
			actions.append({"id": "wait", "label": "Watch the landing", "kind": "api"})
		return actions
	for index: int in SEATS.size():
		actions.append({"id": "stroke_" + SEATS[index], "label": "Tap-stroke " + SEATS[index], "kind": "ui",
			"input": "stroke_" + SEATS[index], "weight": 0.5, "unblocks": true})
		actions.append({"id": "reverse_" + SEATS[index], "label": "Tap-reverse " + SEATS[index], "kind": "ui",
			"input": "reverse_" + SEATS[index], "weight": 0.25})
	for index: int in SEATS.size():
		actions.append({"id": "paddle_" + SEATS[index], "label": "Paddle " + SEATS[index], "kind": "api",
			"seat": index, "backwards": false, "progress": true, "unblocks": true})
		actions.append({"id": "back_paddle_" + SEATS[index], "label": "Back-paddle " + SEATS[index], "kind": "api",
			"seat": index, "backwards": true, "weight": 0.5})
	actions.append({"id": "reset", "label": "Reset to the shore", "kind": "ui", "input": "reset", "weight": 0.25})
	actions.append({"id": "wait", "label": "Let the boat drift", "kind": "api", "weight": 0.5})
	actions.append({"id": "pilot", "label": "Steer for the corridor, a swimmer or the island", "kind": "api",
		"weight": 0.0, "unblocks": true})
	if _splash_left > 0:
		actions.append({"id": "splash", "label": "Show the splash", "kind": "api", "weight": 0.0})
	elif _intro_left > 0:
		actions.append({"id": "pause", "label": "Hold before the first stroke", "kind": "api", "weight": 0.0})
	return actions


## The api actions: a medium-hold stroke (a forward one ends the driver's "turn") and the wait.
func perform(action: Dictionary) -> bool:
	if str(action.get("id", "")) == "splash":
		return await _show_splash()
	if str(action.get("id", "")) == "pause":
		return await _pause()
	_intro_left = 0
	if str(action.get("id", "")) == "wait":
		await wait_frames(WAIT_FRAMES)
		return true
	if str(action.get("id", "")) == "pilot":
		return await _pilot()
	if not action.has("seat"):
		return false
	RunState.stroke(int(action["seat"]), MEDIUM_HOLD, bool(action["backwards"]))
	if bool(action.get("progress", false)):
		_turn += 1
		play_log().call("set_turn", _turn)
	return true


func state() -> Dictionary:
	return RunState.snapshot()


## What blocks progress: nobody aboard (all four swimming) and, at the end, the island. RunState's
## answer as it is.
func progress_block_reason() -> String:
	# Once the boat has landed nothing is blocked: the run is ending, through the cutscene, the title
	# and the recording's hold on the stats (the driver would call that wait a softlock).
	if RunState.phase == RunState.Phase.WON:
		return ""
	return RunState.block_reason()


## Over once the boat is on the island and the win title, with the crossing's stats, is up, so the
## last screenshot of a run that wins shows them.
func is_run_over() -> bool:
	return RunState.phase == RunState.Phase.WON and _win_title_up() and _outro_left <= 0


## One second of a recording pause: the intro's before the first stroke, else the outro's on the stats.
func _pause() -> bool:
	await tree.create_timer(1.0).timeout
	if RunState.phase == RunState.Phase.WON:
		_outro_left -= 1
	else:
		_intro_left -= 1
	return true


## Whether the win cutscene's title is up (the lake's WinCutscene has armed its prompt).
func _win_title_up() -> bool:
	var win: Node = tree.current_scene.find_child("Win", true, false) if tree.current_scene != null else null
	return win != null and bool(win.get("_title_shown"))


## "win" while the island cutscene is up, "splash" while the splash is, else "lake".
func current_view() -> String:
	if RunState.phase == RunState.Phase.WON:
		return "win"
	return "splash" if _splash() != null else "lake"


## The splash over the lake, or null.
func _splash() -> Node:
	return tree.current_scene.get_node_or_null("Splash") if tree.current_scene != null else null


## One second of the splash for a recording: put it up on the first, then hold; on the last, fade it
## out as a key press would and wait until it is gone.
func _show_splash() -> bool:
	if tree.current_scene == null:
		return false
	var splash: Node = _splash()
	if splash == null and _splash_left == SPLASH_SECONDS:
		splash = (load(SPLASH_SCENE) as PackedScene).instantiate()
		splash.name = "Splash"
		tree.current_scene.add_child(splash)
	await tree.create_timer(1.0).timeout
	_splash_left -= 1
	if _splash_left <= 0 and splash != null and is_instance_valid(splash):
		splash.call("start_fade")
		var frames: int = 0
		while is_instance_valid(splash) and frames < 180:
			await wait_frames(1)
			frames += 1
	return true


## One beat of the pilot (see the header): strokes toward its target, then PILOT_FRAMES of running.
## False without a lake or a boat.
func _pilot() -> bool:
	var lake: Node = tree.current_scene.get_node_or_null("Lake") if tree.current_scene != null else null
	var boat: Node2D = lake.get_node_or_null("Catamaran") as Node2D if lake != null else null
	if boat == null:
		return false
	var at: Vector2 = boat.global_position
	var swimmer: Vector2 = _nearest_swimmer(at)
	var rescuing: bool = swimmer != Vector2.INF
	var target: Vector2 = swimmer if rescuing else _course_target(at)
	# Never into the beast's water or its warning band: a guy out there swims back to the boat himself.
	var safe: float = LAKE_TUNING.lake_width * 0.5 - LAKE_TUNING.beast_edge_margin - LAKE_TUNING.beast_warn_margin - 20.0
	target.x = clampf(target.x, -safe, safe)
	var to_target: Vector2 = target - at
	var forward: Vector2 = Vector2.UP.rotated(boat.rotation)
	var hold: float = PILOT_EASE_HOLD if rescuing and to_target.length() < PILOT_EASE else MEDIUM_HOLD
	var backwards: bool = rescuing and to_target.length() < PILOT_BACK_RANGE \
			and absf(forward.angle_to(to_target)) > PILOT_BEHIND
	# The error from the way the boat will move: the bow going forward, the stern backing up.
	var error: float = (-forward if backwards else forward).angle_to(to_target)
	for stroke: Array in pilot_strokes(error, backwards):
		var seat: int = stroke[0]
		if RunState.can_paddle(seat):
			# A guy who sees double strokes the other way: press his other key.
			RunState.stroke(seat, hold, bool(stroke[1]) != RunState.drunkenness.reversed(seat))
	_turn += 1
	play_log().call("set_turn", _turn)
	await wait_frames(PILOT_FRAMES)
	return true


## The strokes for one beat, as [seat, backwards] pairs, from the heading error (radians, + means the
## target is clockwise of the way the boat will move) and whether it is backing up. A forward stroke on
## the left turns the boat clockwise, and so does a reverse stroke on the right. Past PILOT_PIVOT it
## pivots, one side forward and the other backwards, turning almost on the spot; past PILOT_TURN only
## one side strokes, the way the boat is going; lined up, all four stroke together.
static func pilot_strokes(error: float, backwards: bool) -> Array[Array]:
	var lefts: Array[int] = [Paddling.Seat.LEFT_BACK, Paddling.Seat.LEFT_FRONT]
	var rights: Array[int] = [Paddling.Seat.RIGHT_BACK, Paddling.Seat.RIGHT_FRONT]
	var out: Array[Array] = []
	if absf(error) <= PILOT_TURN:
		for seat: int in lefts + rights:
			out.append([seat, backwards])
		return out
	# Clockwise: the left side forward, the right side backwards; anticlockwise the other way round.
	var ahead_side: Array[int] = lefts if error > 0.0 else rights
	var back_side: Array[int] = rights if error > 0.0 else lefts
	if absf(error) > PILOT_PIVOT:
		for seat: int in ahead_side:
			out.append([seat, false])
		for seat: int in back_side:
			out.append([seat, true])
	elif backwards:
		for seat: int in back_side:
			out.append([seat, true])
	else:
		for seat: int in ahead_side:
			out.append([seat, false])
	return out


## The nearest guy in the water who isn't washed up: where he floats, or, while he still swims for his
## beer, where the beer is (he will float there). Vector2.INF with nobody in the water.
func _nearest_swimmer(at: Vector2) -> Vector2:
	var nearest: Vector2 = Vector2.INF
	for swimmer: Rescue.Swimmer in RunState.rescue.swimmers():
		if swimmer.washed_up:
			continue
		var spot: Vector2 = swimmer.beer_position if swimmer.state == Rescue.State.SWIMMING else swimmer.position
		if at.distance_to(spot) < at.distance_to(nearest):
			nearest = spot
	return nearest


## With nobody in the water: the island once it is within PILOT_ISLAND_RANGE, else the guaranteed
## corridor's centre PILOT_LOOKAHEAD up the lake, or only PILOT_RETURN_LOOKAHEAD when the boat has
## strayed off the corridor's middle, so it steers back in sooner.
func _course_target(at: Vector2) -> Vector2:
	var island: Vector2 = Vector2(0.0, -LAKE_TUNING.island_distance)
	if at.distance_to(island) < PILOT_ISLAND_RANGE:
		return island
	var off: float = absf(at.x - Hazards.corridor_x(LAKE_TUNING, RunState.lake_seed, at.y))
	var lookahead: float = PILOT_RETURN_LOOKAHEAD if off > LAKE_TUNING.path_width * PILOT_OFF_CORRIDOR else PILOT_LOOKAHEAD
	var ahead: float = at.y - lookahead
	return Vector2(Hazards.corridor_x(LAKE_TUNING, RunState.lake_seed, ahead), ahead)
