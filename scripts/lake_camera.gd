extends Camera2D
## LakeCamera · follows the boat and leads it toward its direction of travel (GDD › Presentation
## and Platforms, Camera line; camera_lead is BoatTuning's).
##
## Lives in lake.tscn beside the boat, not under it, so the view stays upright while the boat
## turns. Each physics frame it eases its lead toward the boat's velocity, scaled so that full
## speed gives camera_lead and capped there, and sits at the boat's position plus that lead,
## rounded to whole pixels. A still boat's lead returns to zero. The boat's velocity includes the
## current, so a boat left to drift leads a little toward the shore. Cosmetic only: no rules here.

## How fast the lead eases toward its target, per second (the lerp weight is 1 - exp(-speed * delta)).
const LEAD_SMOOTHING: float = 4.0

## The boat, set in lake.tscn. The camera sits after the boat there, so it reads the boat's
## position once the boat has moved this frame.
@export var boat: CharacterBody2D

## Pixels of lead at full speed, from BoatTuning.
var _camera_lead: float = 0.0
## Speed that counts as full: the terminal speed of a full-power stroke's push against the
## water's drag (stroke_force_max * thrust_scale / linear_damping), so the lead needs no tunable
## of its own.
var _full_speed: float = 1.0
var _lead: Vector2 = Vector2.ZERO


func _ready() -> void:
	var tuning: BoatTuning = RunState.paddling.tuning
	_camera_lead = tuning.camera_lead
	var push: float = tuning.stroke_force_max * tuning.thrust_scale
	_full_speed = maxf(push / maxf(tuning.linear_damping, 0.001), 1.0)
	if boat != null:
		global_position = boat.global_position


func _physics_process(delta: float) -> void:
	if boat == null:
		return
	var target: Vector2 = boat.velocity.limit_length(_full_speed) / _full_speed * _camera_lead
	_lead = _lead.lerp(target, 1.0 - exp(-LEAD_SMOOTHING * delta))
	global_position = (boat.global_position + _lead).round()
