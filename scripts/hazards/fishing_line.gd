extends Node2D
## FishingLine · a fisherman in a dinghy and his line across the water (GDD › Systems › Hazards,
## the Fishing line row). An object: the dinghy (Visual/Dinghy and the fisherman, Visual/Fisherman)
## sits where the lake placed it and never moves, and the line (Visual/Line) runs sideways from it,
## outward from the lake's middle line, across line_length pixels, so it is visible from far off
## before the boat reaches it. The Snag area lies along the line. When the boat crosses it, the hull
## hit is the side of the boat the dinghy is on, in the boat's own frame, and RunState snags that
## hull's guy for snag_time seconds (the Snag a paddle effect). One crossing is one hit: the spec's
## hit_cooldown passes before it can hit again. No rules and no randomness here: the lake places it
## from Hazards.plan() and sets `spec`; the tunables are the line_length and snag_time fields on
## LakeTuning, loaded when the node enters the tree (a preload would be a cycle: the tuning lists the
## fishing line spec, whose scene has this script).

const TUNING_PATH: String = "res://data/lake_tuning.tres"
## The hit area's thickness across the line, in pixels: thin, so the line itself is what is crossed.
const HIT_THICKNESS: float = 4.0

@onready var _line: Line2D = $Visual/Line
@onready var _snag: Area2D = $Snag
@onready var _shape: CollisionShape2D = $Snag/CollisionShape2D

## The spec the lake placed this line from: its strengths. Set by the lake before it is added.
var spec: HazardSpec
## The lake's tunables, loaded when the line enters the tree.
var tuning: LakeTuning
var _cooldown: float = 0.0
## Which way the line runs from the dinghy: away from the lake's middle line, -1 left, +1 right.
var _direction: float = 1.0


func _ready() -> void:
	tuning = load(TUNING_PATH) as LakeTuning
	_direction = -1.0 if global_position.x < 0.0 else 1.0
	var reach: float = tuning.line_length
	_line.points = PackedVector2Array([Vector2.ZERO, Vector2(_direction * reach, 0.0)])
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(reach, HIT_THICKNESS)
	_shape.shape = rect
	_snag.position = Vector2(_direction * reach * 0.5, 0.0)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)


## The boat crossed the line (only the boat is a CharacterBody2D on the lake). The hull hit is the side
## of the boat the dinghy is on, in the boat's own frame, as rock.gd does with its position.
func _on_body_entered(body: Node2D) -> void:
	if not body is CharacterBody2D or _cooldown > 0.0 or spec == null:
		return
	_cooldown = spec.hit_cooldown
	var on_left: bool = body.to_local(global_position).x < 0.0
	var hull: Rescue.Hull = Rescue.Hull.LEFT if on_left else Rescue.Hull.RIGHT
	RunState.snag(hull, tuning.snag_time)
