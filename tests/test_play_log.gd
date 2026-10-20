extends "res://tools/test_case.gd"
## T70 · The play log: a new attempt begins a run whose log holds a line with a stable event id
## for every player action, hazard effect, antic, rescue step, shore reset and win, asserted
## through PlayLog.start_capture(); _build_snapshot() and progress_block_reason() are filled from
## RunState (rules.md › Everything is logged).

const RunStateScript: GDScript = preload("res://scripts/autoload/run_state.gd")
const TICK: float = 1.0 / 60.0
const BOAT: Vector2 = Vector2(0.0, -300.0)


## A RunState of its own (not the autoload) with the stroke misses off, so a stroke lands.
func _state() -> Node:
	var state: Node = RunStateScript.new()
	state.rng.seed = 7
	state.reset()
	state.drunkenness.tuning = state.drunkenness.tuning.duplicate()
	state.drunkenness.tuning.miss_curve = null
	state.drunkenness.tuning.lag_curve = null
	return state


func _events(lines: Array[Dictionary]) -> PackedStringArray:
	var events: PackedStringArray = PackedStringArray()
	for line: Dictionary in lines:
		events.append(str(line["event"]))
	return events


## The first captured line with this event id, or an empty Dictionary.
func _line(lines: Array[Dictionary], event: String) -> Dictionary:
	for line: Dictionary in lines:
		if str(line["event"]) == event:
			return line
	return {}


func _step(state: Node, seconds: float) -> void:
	var steps: int = ceili(seconds / TICK)
	for i: int in steps:
		state.step(TICK, BOAT)


## A fresh process has no run open: clears the PlayLog autoload's run id, so the next new_attempt()
## begins one (its run.new line, as the boot's does).
func _fresh_run() -> void:
	PlayLog.run_id = ""


func test_a_session_leaves_a_line_for_every_action_and_step() -> void:
	_fresh_run()
	PlayLog.start_capture()
	var state: Node = _state()
	state.new_attempt()
	state.stroke(0, 0.3)
	_step(state, 1.0)
	state.beer_overboard(Rescue.Hull.LEFT, BOAT)
	state.set_progress(0.2)
	_step(state, state.paddling.tuning.jump_delay + 0.5)
	var jumper: int = 0 if not state.guys[0].aboard else 1
	state.shove(Vector2(10.0, 0.0))
	state.stop()
	state.push(Vector2(5.0, 0.0))
	state.take_push()
	state.take_push()
	state.snag(Rescue.Hull.RIGHT, 2.0)
	state.force_break(Rescue.Hull.RIGHT)
	state.water_aboard(Rescue.Hull.RIGHT, 1.0)
	state.telegraph(&"log", Rescue.Hull.LEFT)
	state.guy_overboard(3, BOAT, "test")
	state.pickup(jumper)
	state.shore_touched()
	state.set_progress(0.5)
	state.arrive()
	var lines: Array[Dictionary] = PlayLog.stop_capture()
	state.free()
	var events: PackedStringArray = _events(lines)
	for event: String in [
			"run.new", "run.attempt_started", "snapshot", "run.crossing_started",
			"action.stroke", "rescue.beer_overboard", "rescue.jumped", "rescue.fell_in", "rescue.picked_up",
			"hazard.shove", "hazard.stop", "hazard.push", "hazard.push_ended", "hazard.snag", "hazard.forced_break",
			"hazard.water_aboard", "hazard.telegraphed", "run.shore_reset", "run.won"]:
		expect(events.has(event), "the log holds %s (got %s)" % [event, ", ".join(events)])


func test_an_attempt_begins_a_run_with_its_lake_seed() -> void:
	_fresh_run()
	PlayLog.start_capture()
	var state: Node = _state()
	state.new_attempt()
	var lines: Array[Dictionary] = PlayLog.stop_capture()
	var started: Dictionary = _line(lines, "run.attempt_started")
	expect(not started.is_empty(), "run.attempt_started was logged")
	if not started.is_empty():
		expect_eq((started["data"] as Dictionary)["lake_seed"], state.lake_seed, "the line carries the lake seed")
		expect_eq(((started["data"] as Dictionary)["names"] as Array).size(), 4, "and the four names")
		expect_eq((started["data"] as Dictionary)["attempt"], 1, "the first attempt of its run")
	var events: PackedStringArray = _events(lines)
	expect(events.find("run.new") < events.find("run.attempt_started"), "the run begins before its first line")
	expect(events.find("run.attempt_started") < events.find("snapshot"), "a snapshot follows the start")
	state.free()


## T83: a reset is a second attempt of the open run, so one run.new (one file pair), two attempts.
func test_a_reset_is_another_attempt_of_the_same_run() -> void:
	_fresh_run()
	PlayLog.start_capture()
	var state: Node = _state()
	state.new_attempt()
	state.new_attempt()
	var lines: Array[Dictionary] = PlayLog.stop_capture()
	state.free()
	var events: PackedStringArray = _events(lines)
	expect_eq(events.count("run.new"), 1, "one run begins, so one log file pair")
	var attempts: Array = []
	for line: Dictionary in lines:
		if str(line["event"]) == "run.attempt_started":
			attempts.append((line["data"] as Dictionary)["attempt"])
	expect_eq(attempts.size(), 2, "two attempts logged under one capture")
	if attempts.size() == 2:
		expect_eq(attempts[0], 1, "the first attempt of the run")
		expect_eq(attempts[1], 2, "and the reset is the second")
	var opened: Dictionary = _line(lines, "run.new")
	if not opened.is_empty():
		expect_eq((opened["data"] as Dictionary)["run"], PlayLog.run_id, "the run that is still open is the one begun")


func test_a_stroke_is_one_line_with_its_outcome() -> void:
	var state: Node = _state()
	PlayLog.start_capture()
	state.stroke(2, 0.4, true)
	_step(state, 1.0)
	var lines: Array[Dictionary] = PlayLog.stop_capture()
	var strokes: Array[Dictionary] = []
	for line: Dictionary in lines:
		if str(line["event"]) == "action.stroke":
			strokes.append(line)
	expect_eq(strokes.size(), 1, "one line for one stroke")
	if strokes.size() == 1:
		var data: Dictionary = strokes[0]["data"] as Dictionary
		expect_eq(data["outcome"], "landed", "it landed")
		expect_eq(data["seat"], 2, "from his seat")
		expect_eq(data["backwards"], true, "the reverse key")
	state.free()


func test_a_fumbled_stroke_logs_its_outcome() -> void:
	var state: Node = _state()
	state.drunkenness.tuning.miss_curve = Curve.new()
	state.drunkenness.tuning.miss_curve.add_point(Vector2(0.0, 1.0))
	state.drunkenness.tuning.miss_curve.add_point(Vector2(1.0, 1.0))
	PlayLog.start_capture()
	state.stroke(0, 0.4)
	var lines: Array[Dictionary] = PlayLog.stop_capture()
	var stroke: Dictionary = _line(lines, "action.stroke")
	expect(not stroke.is_empty(), "the stroke was logged")
	if not stroke.is_empty():
		expect_eq((stroke["data"] as Dictionary)["outcome"], "fumbled", "as fumbled")
	state.free()


func test_a_stroke_that_cannot_be_made_says_why() -> void:
	var state: Node = _state()
	state.guy_overboard(1, BOAT)
	PlayLog.start_capture()
	state.stroke(1, 0.3)
	var lines: Array[Dictionary] = PlayLog.stop_capture()
	var blocked: Dictionary = _line(lines, "action.stroke_blocked")
	expect(not blocked.is_empty(), "the release was logged")
	if not blocked.is_empty():
		expect_eq((blocked["data"] as Dictionary)["reason"], "in the water", "with the reason")
	state.free()


func test_a_stroke_dropped_when_its_guy_goes_overboard_is_logged() -> void:
	var state: Node = _state()
	state.stroke(0, 0.3)
	PlayLog.start_capture()
	state.guy_overboard(0, BOAT)
	var lines: Array[Dictionary] = PlayLog.stop_capture()
	expect(_events(lines).has("action.stroke_dropped"), "the stroke that never landed is logged")
	state.free()


func test_antics_breaks_and_seeing_double_log_where_they_change() -> void:
	var state: Node = _state()
	state.drunkenness.set_level(0, 1.0)
	state.stamina.call_break(1)
	PlayLog.start_capture()
	_step(state, 6.0)
	var lines: Array[Dictionary] = PlayLog.stop_capture()
	var events: PackedStringArray = _events(lines)
	expect(events.has("guy.antic"), "an antic wound up (got %s)" % ", ".join(events))
	expect(events.has("guy.break"), "a break started")
	expect(events.has("guy.double"), "seeing double started")
	expect(events.size() < 40, "state changes only, not every frame (%d lines)" % events.size())
	state.free()


func test_the_swimmers_steps_are_logged() -> void:
	var state: Node = _state()
	state.set_progress(0.2)
	state.beer_overboard(Rescue.Hull.LEFT, BOAT)
	PlayLog.start_capture()
	_step(state, state.paddling.tuning.jump_delay + 0.5)
	_step(state, 20.0)
	var lines: Array[Dictionary] = PlayLog.stop_capture()
	var events: PackedStringArray = _events(lines)
	expect(events.has("rescue.jumped"), "he jumped")
	expect(events.has("rescue.floating"), "he reached his beer")
	state.free()


func test_a_headwind_logs_its_start_and_its_end() -> void:
	var state: Node = _state()
	PlayLog.start_capture()
	state.set_extra_drift(20.0)
	state.step(TICK, BOAT)
	state.set_extra_drift(20.0)
	state.step(TICK, BOAT)
	state.step(TICK, BOAT)
	var lines: Array[Dictionary] = PlayLog.stop_capture()
	var events: PackedStringArray = _events(lines)
	expect_eq(events.count("hazard.headwind"), 1, "once at its start")
	expect_eq(events.count("hazard.headwind_ended"), 1, "once at its end")
	state.free()


func test_the_win_is_logged() -> void:
	var state: Node = _state()
	state.set_progress(0.9)
	PlayLog.start_capture()
	state.arrive()
	var lines: Array[Dictionary] = PlayLog.stop_capture()
	expect(_events(lines).has("run.won"), "run.won")
	state.free()


func test_reaching_the_island_short_handed_logs_the_win_with_the_left_behind() -> void:
	var state: Node = _state()
	state.set_progress(0.9)
	state.guy_overboard(1, BOAT)
	PlayLog.start_capture()
	state.arrive()
	var lines: Array[Dictionary] = PlayLog.stop_capture()
	var events: PackedStringArray = _events(lines)
	expect(events.has("run.won"), "run.won")
	expect_false(events.has("run.arrived_short"), "the short arrival event is gone")
	for line: Dictionary in lines:
		if line.get("event", "") == "run.won":
			var data: Dictionary = line.get("data", {})
			expect_eq(data.get("left_behind", []), [1], "run.won carries the seats left behind")
			expect_eq((data.get("left_behind_names", []) as Array).size(), 1, "and their names")
	state.free()


func test_every_event_id_is_stable_snake_case() -> void:
	var state: Node = _state()
	PlayLog.start_capture()
	state.new_attempt()
	state.stroke(0, 0.3)
	state.shove(Vector2(1.0, 0.0))
	state.telegraph(&"log", Rescue.NOBODY)
	var lines: Array[Dictionary] = PlayLog.stop_capture()
	var pattern: RegEx = RegEx.create_from_string(PlayLog.EVENT_ID)
	for line: Dictionary in lines:
		expect(pattern.search(str(line["event"])) != null, "'%s' is a stable id" % str(line["event"]))
	state.free()


func test_the_snapshot_holds_the_run_and_each_guy() -> void:
	var state: Node = _state()
	state.new_attempt()
	state.set_progress(0.3)
	state.guy_overboard(2, BOAT)
	var snapshot: Dictionary = state.snapshot()
	expect_eq(snapshot["phase"], "crossing", "the phase")
	expect_near(float(snapshot["progress"]), 0.3, 0.001, "progress")
	expect_eq(snapshot["lake_seed"], state.lake_seed, "the lake seed")
	expect(snapshot.has("elapsed"), "elapsed")
	var crew: Array = snapshot["guys"] as Array
	expect_eq(crew.size(), 4, "four guys")
	var swimmer: Dictionary = crew[2] as Dictionary
	expect_eq(swimmer["seat"], 2, "seat")
	expect_eq(swimmer["name"], state.name_of(2), "name")
	expect_eq(swimmer["aboard"], false, "aboard")
	expect_eq(swimmer["in_water"], true, "in the water")
	expect_eq(swimmer["swim"], "floating", "his swim state")
	expect_near(float(swimmer["drunkenness"]), state.guys[2].drunkenness, 0.001, "drunkenness")
	expect_near(float(swimmer["stamina"]), state.guys[2].stamina, 0.001, "stamina")
	for key: String in ["stamina_state", "antic_state", "antic_kind"]:
		expect(swimmer.has(key), key)
	expect_eq((crew[0] as Dictionary)["swim"], "aboard", "a guy aboard")
	state.free()


func test_the_play_logs_snapshot_is_the_run_states() -> void:
	RunState.reset()
	var snapshot: Dictionary = PlayLog._build_snapshot()
	expect_eq(snapshot["phase"], "launch", "the autoload's phase")
	expect_eq((snapshot["guys"] as Array).size(), 4, "four guys")
	expect_eq(snapshot["lake_seed"], RunState.lake_seed, "the lake seed")
	RunState.reset()


func test_the_progress_block_reason_follows_the_phase_and_the_crew() -> void:
	RunState.reset()
	expect_eq(PlayLog.progress_block_reason(), "", "at the launch shore, before the boat has left")
	RunState.set_progress(0.4)
	expect_eq(PlayLog.progress_block_reason(), "", "while crossing")
	for seat: int in 4:
		RunState.guy_overboard(seat, BOAT)
	expect_eq(PlayLog.progress_block_reason(), "nobody aboard", "with all four in the water")
	RunState.reset()
	RunState.set_progress(0.9)
	RunState.arrive()
	expect_eq(PlayLog.progress_block_reason(), "won", "after the win")
	RunState.reset()


func test_a_shore_reset_and_a_new_attempt_each_log_a_snapshot() -> void:
	var state: Node = _state()
	state.set_progress(0.5)
	PlayLog.start_capture()
	state.shore_touched()
	var lines: Array[Dictionary] = PlayLog.stop_capture()
	var events: PackedStringArray = _events(lines)
	expect(events.has("run.shore_reset"), "the reset")
	expect(events.find("run.shore_reset") < events.find("snapshot"), "its snapshot comes after")
	state.free()
