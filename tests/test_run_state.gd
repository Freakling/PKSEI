extends "res://tools/test_case.gd"
## T3 · RunState.reset() restores the starting conditions (GDD › Core Loop › Starting conditions).

const RunStateScript: GDScript = preload("res://scripts/autoload/run_state.gd")


func test_reset_restores_starting_conditions() -> void:
	var state: Node = RunStateScript.new()
	state.progress = 0.7
	state.elapsed = 42.0
	state.reset()
	expect_eq(state.guys.size(), 4, "four guys")
	for i: int in state.guys.size():
		var guy: RefCounted = state.guys[i]
		expect_eq(guy.seat, i, "seat %d" % i)
		expect(guy.aboard, "guy %d aboard" % i)
		expect_near(guy.stamina, RunStateScript.STAMINA_FULL, 0.0001, "guy %d stamina full" % i)
		expect_near(guy.drunkenness, RunStateScript.STARTING_DRUNKENNESS, 0.0001, "guy %d mildly tipsy" % i)
		expect(guy.drunkenness > 0.0, "tipsy means above sober")
	expect_near(state.progress, 0.0, 0.0001, "progress at the shore")
	expect_near(state.elapsed, 0.0, 0.0001, "elapsed reset")
	expect_eq(state.phase, RunStateScript.Phase.LAUNCH, "phase launch")
	state.free()


func test_reset_emits_run_reset() -> void:
	var state: Node = RunStateScript.new()
	var fired: Array[bool] = []
	state.run_reset.connect(func() -> void: fired.append(true))
	state.reset()
	expect_eq(fired.size(), 1, "run_reset emitted once")
	state.free()


func test_reset_replaces_guys_rather_than_adding() -> void:
	var state: Node = RunStateScript.new()
	state.reset()
	state.reset()
	expect_eq(state.guys.size(), 4, "still four guys after two resets")
	state.free()
