extends Node2D
## Wake · a motorboat crosses ahead and its wake rolls back at the boat (GDD › Systems › Hazards,
## the Motorboat wake row). An event: the lake places this node where the plan put it, but the
## placement is only the trigger and nothing shows there. When the boat comes near, the motorboat
## (Visual/Motorboat, a white rectangle) crosses the lake ahead of it at the MotorboatWake rule's
## position, and once it is across the wave front (Visual/Front, a lake-wide lighter-blue line)
## rolls toward the shore at the rule's front_y, so the boat is seen before the wave. The rule
## decides everything; this script steps it each physics frame with the boat's position and
## heading, and applies its one hit through RunState: beer_overboard() on the high hull, shove()
## and water_aboard() on that hull. No rules and no randomness here; the tunables are the wake_*
## fields on LakeTuning, loaded when the node enters the tree (a preload would be a cycle: the
## tuning lists the wake spec, whose scene has this script).

const TUNING_PATH: String = "res://data/lake_tuning.tres"
## The front's thickness in pixels (cosmetic).
const FRONT_THICKNESS: float = 6.0

@onready var _motorboat: Node2D = $Visual/Motorboat
@onready var _front: Node2D = $Visual/Front
@onready var _crest: Polygon2D = $Visual/Front/Crest

var _wake: MotorboatWake
## The boat: the only CharacterBody2D on the lake, found among the lake's children.
var _boat: CharacterBody2D


func _ready() -> void:
	var tuning: LakeTuning = load(TUNING_PATH) as LakeTuning
	_wake = MotorboatWake.new(tuning, global_position)
	_boat = _find_boat()
	var half: float = tuning.lake_width * 0.5
	var thick: float = FRONT_THICKNESS * 0.5
	_crest.polygon = PackedVector2Array([
		Vector2(-half, -thick), Vector2(half, -thick), Vector2(half, thick), Vector2(-half, thick),
	])
	_motorboat.visible = false
	_front.visible = false


func _physics_process(delta: float) -> void:
	if _boat == null:
		return
	var hit: MotorboatWake.Hit = _wake.step(delta, _boat.global_position, _boat.global_rotation)
	if hit != null:
		RunState.beer_overboard(hit.hull, _boat.global_position)
		RunState.shove(hit.shove)
		RunState.water_aboard(hit.hull, hit.water)
	_show_state()


## The motorboat shows while it crosses, pointing the way it goes; the front while it rolls.
func _show_state() -> void:
	_motorboat.visible = _wake.state == MotorboatWake.State.CROSSING
	_motorboat.position = to_local(_wake.motorboat)
	_motorboat.scale.x = _wake.direction
	_front.visible = _wake.state == MotorboatWake.State.ROLLING
	_front.position = to_local(Vector2(0.0, _wake.front_y))


## The boat is the lake's CharacterBody2D; the hazards sit under the lake's Hazards node.
func _find_boat() -> CharacterBody2D:
	var hazards: Node = get_parent()
	if hazards == null or hazards.get_parent() == null:
		return null
	for child: Node in hazards.get_parent().get_children():
		if child is CharacterBody2D:
			return child as CharacterBody2D
	return null
