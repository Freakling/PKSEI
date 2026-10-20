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
## With nobody in the water it steers for the guaranteed corridor a look-ahead up the lake, or the
## island once it is close. It strokes the seats that turn the boat toward the target (a left stroke
## turns right; in reverse, the other way round) or all four when it is lined up, pressing the other
## key for a guy who sees double and skipping a guy who can't paddle, then lets the boat run for
## PILOT_FRAMES. Weight 0: the random and smoke strategies never pick it.
##
## The `pause` action holds still for a second, for recording a run: it is offered (weight 0, so only
## a scenario that scores it picks it) for INTRO_SECONDS before the first other action of a run, and
## once the win title with the stats is up, for OUTRO_SECONDS before the run counts as over.

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
const PILOT_LOOKAHEAD: float = 260.0
const PILOT_TURN: float = 0.18
const PILOT_ISLAND_RANGE: float = 700.0
## Rescue: a guy within this distance and more than PILOT_BEHIND radians off the bow is backed up to;
## within PILOT_EASE the strokes are short (PILOT_EASE_HOLD) so the boat doesn't sail past him.
const PILOT_BACK_RANGE: float = 360.0
const PILOT_BEHIND: float = 1.9
const PILOT_EASE: float = 110.0
const PILOT_EASE_HOLD: float = 0.2
const LAKE_TUNING: LakeTuning = preload("res://data/lake_tuning.tres") as LakeTuning
## The recording pauses: seconds held before the first stroke and on the win title's stats.
const INTRO_SECONDS: int = 10
const OUTRO_SECONDS: int = 20

var _turn: int = 0
## Seconds of the intro and outro pauses still to hold in this run.
var _intro_left: int = INTRO_SECONDS
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
	if _intro_left > 0:
		actions.append({"id": "pause", "label": "Hold before the first stroke", "kind": "api", "weight": 0.0})
	return actions


## The api actions: a medium-hold stroke (a forward one ends the driver's "turn") and the wait.
func perform(action: Dictionary) -> bool:
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


## "win" while the island cutscene is up, else "lake".
func current_view() -> String:
	return "win" if RunState.phase == RunState.Phase.WON else "lake"


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
	var to_target: Vector2 = target - at
	var forward: Vector2 = Vector2.UP.rotated(boat.rotation)
	var hold: float = PILOT_EASE_HOLD if rescuing and to_target.length() < PILOT_EASE else MEDIUM_HOLD
	var backwards: bool = rescuing and to_target.length() < PILOT_BACK_RANGE \
			and absf(forward.angle_to(to_target)) > PILOT_BEHIND
	# The error from the way the boat will move: the bow going forward, the stern backing up.
	var error: float = (-forward if backwards else forward).angle_to(to_target)
	var lefts: Array[int] = [Paddling.Seat.LEFT_BACK, Paddling.Seat.LEFT_FRONT]
	var rights: Array[int] = [Paddling.Seat.RIGHT_BACK, Paddling.Seat.RIGHT_FRONT]
	var seats: Array[int] = [Paddling.Seat.LEFT_FRONT, Paddling.Seat.RIGHT_FRONT, Paddling.Seat.LEFT_BACK, Paddling.Seat.RIGHT_BACK]
	# Forward, a left stroke turns the boat right (clockwise); in reverse a right stroke does.
	if error > PILOT_TURN:
		seats = rights if backwards else lefts
	elif error < -PILOT_TURN:
		seats = lefts if backwards else rights
	for seat: int in seats:
		if RunState.can_paddle(seat):
			# A guy who sees double strokes the other way: press his other key.
			RunState.stroke(seat, hold, backwards != RunState.drunkenness.reversed(seat))
	_turn += 1
	play_log().call("set_turn", _turn)
	await wait_frames(PILOT_FRAMES)
	return true


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
## corridor's centre PILOT_LOOKAHEAD up the lake.
func _course_target(at: Vector2) -> Vector2:
	var island: Vector2 = Vector2(0.0, -LAKE_TUNING.island_distance)
	if at.distance_to(island) < PILOT_ISLAND_RANGE:
		return island
	var ahead: float = at.y - PILOT_LOOKAHEAD
	return Vector2(Hazards.corridor_x(LAKE_TUNING, RunState.lake_seed, ahead), ahead)
