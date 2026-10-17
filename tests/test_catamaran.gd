extends "res://tools/test_case.gd"
## B4 · The hazards keep acting during the win cutscene: once RunState's phase is WON, a stop, a
## shove or a push still waiting for the boat is taken and dropped by the catamaran, so the boat
## is not moved through the cutscene (GDD › Win and Loss). Under way the same effects move it.
## The catamaran reads the RunState autoload, so these tests use it and reset it when done.

const BoatScene: PackedScene = preload("res://scenes/catamaran.tscn")
const FRAME: float = 1.0 / 60.0
const SHOVE: Vector2 = Vector2(600.0, 0.0)
const PUSH: Vector2 = Vector2(300.0, 0.0)


func before_each() -> void:
	RunState.reset()


## The boat scene in the test's tree, at its own origin.
func _add_boat() -> CharacterBody2D:
	var boat: CharacterBody2D = BoatScene.instantiate() as CharacterBody2D
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(boat)
	return boat


func _remove_boat(boat: CharacterBody2D) -> void:
	boat.get_parent().remove_child(boat)
	boat.free()
	RunState.reset()


func test_after_the_win_a_shove_a_push_and_a_stop_leave_the_boat_still() -> void:
	var boat: CharacterBody2D = _add_boat()
	RunState.phase = RunState.Phase.WON
	RunState.shove(SHOVE)
	RunState.push(PUSH)
	RunState.stop()
	boat.call(&"_physics_process", FRAME)
	expect_eq(boat.velocity, Vector2.ZERO, "no speed from the effects after the win")
	expect_eq(boat.position, Vector2.ZERO, "the boat stays where it was")
	expect_eq(RunState.take_shove(), Vector2.ZERO, "the shove was taken, not left for later")
	expect_eq(RunState.take_push(), Vector2.ZERO, "the push was taken, not left for later")
	expect_false(RunState.take_stop(), "the stop was taken, not left for later")
	_remove_boat(boat)


func test_under_way_a_shove_and_a_push_move_the_boat() -> void:
	var boat: CharacterBody2D = _add_boat()
	RunState.phase = RunState.Phase.CROSSING
	RunState.shove(SHOVE)
	RunState.push(PUSH)
	boat.call(&"_physics_process", FRAME)
	expect(boat.velocity.x > 0.0, "the shove and the push add to the boat's speed while under way")
	_remove_boat(boat)
