class_name HazardBase
extends Node2D
## HazardBase · the shared base of the Node2D hazard scripts in this folder (GDD › Systems › Hazards).
## It holds what they share: the `tuning` and `spec` fields the lake sets before add_child (T40), the
## null guard that reports a missing one and stops the node, the boat lookup, the frame pick
## for a looping animation, and the one Audio loop a hazard's telegraph may run (T26): _start_loop()
## and _stop_loop(), the latter also when the node leaves the tree, so a hazard the lake frees (a
## shore reset, a new attempt) falls silent. A hazard does its own setup in _setup(), run once the
## guard has passed, and overrides _needs_spec() to return true when it reads `spec`. The Area2D
## hazards (log, rock) don't extend it: their root is the Area2D itself; they use the static
## helpers. A hazard whose warning starts calls _telegraph(kind, from) once (T56): it tells
## RunState.telegraph() the kind and the hull `from` lies on, as the hit code decides a hull, so
## the guy on that hull calls it out in a bubble. ahead_of() is the log's and the rock's rule for
## "ahead on the path": within LakeTuning.call_out_distance and the boat heading toward it. No
## rules beyond that and no randomness here.

## The lake's tunables, set by the lake before the node enters the tree.
var tuning: LakeTuning
## The spec the lake placed this hazard from; read only by a hazard whose _needs_spec() is true.
var spec: HazardSpec
## The Audio loop handle of the telegraph running now (an engine, a whine, the wind, a rumble);
## 0 while silent.
var _loop: int = 0


## Stops the loop when the node leaves the tree.
func _exit_tree() -> void:
	_stop_loop()


## Starts the Audio loop `sound_name` as this hazard's telegraph, ending the one before, if any.
func _start_loop(sound_name: StringName) -> void:
	_stop_loop()
	_loop = Audio.play_loop(sound_name)


## Stops this hazard's loop, if one runs.
func _stop_loop() -> void:
	Audio.stop_loop(_loop)
	_loop = 0


## Ends the telegraph loop now, if one runs. The lake calls it when the win cutscene starts (B4):
## it disables the Hazards node, so this hazard's _physics_process, which would end the loop on
## its own, no longer runs.
func stop_telegraph() -> void:
	_stop_loop()


## Checks the lake's fields, then runs the hazard's _setup(). If one is missing, it says so and the
## node stays still.
func _ready() -> void:
	var needs_spec: bool = _needs_spec()
	if tuning == null or (needs_spec and spec == null):
		push_error("%s: the lake must set %s before adding the hazard"
				% [scene_file_path.get_file(), "tuning and spec" if needs_spec else "tuning"])
		set_physics_process(false)
		return
	_setup()


## Whether the hazard reads `spec`, so the guard checks it too. Overridden where it does.
func _needs_spec() -> bool:
	return false


## The hazard's own setup, run by _ready once the guard has passed. Overridden instead of _ready().
func _setup() -> void:
	pass


## The boat: the only CharacterBody2D on the lake, found among the lake's children. The hazards sit
## under the lake's Hazards node, so the boat is under its parent. Null if there isn't one.
func _find_boat() -> CharacterBody2D:
	return find_boat_near(self)


## The boat for any hazard node under the lake's Hazards node (the Area2D ones too): the only
## CharacterBody2D among its grandparent's children. Null if there isn't one.
static func find_boat_near(hazard: Node) -> CharacterBody2D:
	var hazards: Node = hazard.get_parent()
	if hazards == null or hazards.get_parent() == null:
		return null
	for child: Node in hazards.get_parent().get_children():
		if child is CharacterBody2D:
			return child as CharacterBody2D
	return null


## This hazard's warning has started (T56): RunState.telegraph() gets `kind` (a Lines.KINDS entry)
## and the hull the warning comes from, the side of the boat `from` lies on (the nest, the
## motorboat, the fin, the edge the wind or the jet-ski comes from). Called once per warning.
func _telegraph(kind: StringName, from: Vector2) -> void:
	RunState.telegraph(kind, hull_of(_find_boat(), from))


## The hull of `boat` that `from` lies beside, in the boat's own frame, as the hit code decides
## the side hit; Rescue.NOBODY without a boat.
static func hull_of(boat: Node2D, from: Vector2) -> int:
	if boat == null:
		return Rescue.NOBODY
	return Rescue.Hull.LEFT if boat.to_local(from).x < 0.0 else Rescue.Hull.RIGHT


## Whether `target` is ahead on the boat's path: within `distance` of a boat at `boat_at`, and in
## front of it, the boat's facing (up when `boat_rotation` is 0) pointing toward it.
static func ahead_of(boat_at: Vector2, boat_rotation: float, target: Vector2, distance: float) -> bool:
	var toward: Vector2 = target - boat_at
	if toward.length() > distance:
		return false
	return Vector2.UP.rotated(boat_rotation).dot(toward) > 0.0


## Which frame of a looping animation of `count` frames shows `clock` seconds in, at `period`
## seconds a frame: the hazards' telegraphs flip between their frames with this (T24).
static func _frame_at(clock: float, count: int, period: float) -> int:
	return int(floorf(clock / period)) % count
