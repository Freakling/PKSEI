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

## The strokes in Paddling.Seat order (S, A, K, L): the seat's name for ids and labels.
const SEATS: Array[String] = ["left_front", "left_back", "right_front", "right_back"]
## The hold of an api stroke, in seconds (BoatTuning.charge_time is 1.0: a half-charged stroke).
const MEDIUM_HOLD: float = 0.5
## Frames the "wait" action lets the boat drift.
const WAIT_FRAMES: int = 12

var _turn: int = 0


## Seeds the run's generator, then starts a new attempt the way R does (the lake's restart), so the
## same seed draws the same lake (RunState.lake_seed) and crew.
func start_run(run_seed: int) -> void:
	RunState.rng.seed = run_seed
	var lake: Node = tree.current_scene.get_node_or_null("Lake") if tree.current_scene != null else null
	if lake != null and lake.has_method("_new_attempt"):
		lake.call("_new_attempt")
	else:
		RunState.new_attempt()
	_turn = 0
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
		actions.append({"id": "again", "label": "Go again", "kind": "ui", "input": "ui_accept", "progress": true})
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
	# Weight 0: the random picks leave it out, since a reset starts a new attempt and so a new play-log file, and
	# a review reads only the newest file. A scenario may still name it.
	actions.append({"id": "reset", "label": "Reset to the shore", "kind": "ui", "input": "reset", "weight": 0.0})
	actions.append({"id": "wait", "label": "Let the boat drift", "kind": "api", "weight": 0.5})
	return actions


## The api actions: a medium-hold stroke (a forward one ends the driver's "turn") and the wait.
func perform(action: Dictionary) -> bool:
	if str(action.get("id", "")) == "wait":
		await wait_frames(WAIT_FRAMES)
		return true
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


func is_run_over() -> bool:
	return RunState.phase == RunState.Phase.WON


## "win" while the island cutscene is up, else "lake".
func current_view() -> String:
	return "win" if RunState.phase == RunState.Phase.WON else "lake"
