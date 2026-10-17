class_name HazardBase
extends Node2D
## HazardBase · the shared base of the Node2D hazard scripts in this folder (GDD › Systems › Hazards).
## It holds what they share: the `tuning` and `spec` fields the lake sets before add_child (T40), the
## null guard that reports a missing one and stops the node, the boat lookup, and the frame pick
## for a looping animation. A hazard does its own setup in _setup(), run once the guard has passed, and
## overrides _needs_spec() to return true when it reads `spec`. The Area2D hazards (log, rock) don't
## extend it: their root is the Area2D itself. No rules and no randomness here.

## The lake's tunables, set by the lake before the node enters the tree.
var tuning: LakeTuning
## The spec the lake placed this hazard from; read only by a hazard whose _needs_spec() is true.
var spec: HazardSpec


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
	var hazards: Node = get_parent()
	if hazards == null or hazards.get_parent() == null:
		return null
	for child: Node in hazards.get_parent().get_children():
		if child is CharacterBody2D:
			return child as CharacterBody2D
	return null


## Which frame of a looping animation of `count` frames shows `clock` seconds in, at `period`
## seconds a frame: the hazards' telegraphs flip between their frames with this (T24).
static func _frame_at(clock: float, count: int, period: float) -> int:
	return int(floorf(clock / period)) % count
