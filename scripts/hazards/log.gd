extends Area2D
## FloatingLog · the floating log (GDD › Systems › Hazards, the Floating log row).
##
## Drifts down-screen with the current at BoatTuning.current_speed, so it is in view ahead of
## the boat before it arrives (its telegraph). When the boat runs into it, the hull hit is the
## side the log is on in the boat's own frame, and the effects go through RunState: a beer
## overboard on that hull, and a shove that kills speed (stop(), then shove() away from the log
## at the spec's shove_strength). One bump is one hit: the spec's hit_cooldown passes before it
## can hit again. Gone once its trailing edge has drifted past the shore line, before it would
## slide onto the beach drawn above it. No rules and no randomness here: the lake places it from
## Hazards.plan() and sets `spec`.

## The spec the lake placed this log from: its strengths. Set by the lake before it is added.
var spec: HazardSpec
var _cooldown: float = 0.0
## Pixels from the log's centre to its trailing edge along the drift (half its shape's height):
## past the shore line (y = 0) by this much, the whole log is on the beach and it is removed.
@onready var _half_depth: float = _shape_half_depth()


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if RunState.phase == RunState.Phase.WON:
		return
	position.y += RunState.paddling.tuning.current_speed * delta
	if position.y > _half_depth:
		queue_free()


## The boat ran into the log (only the boat is a CharacterBody2D on the lake).
func _on_body_entered(body: Node2D) -> void:
	if not body is CharacterBody2D or _cooldown > 0.0 or spec == null:
		return
	_cooldown = spec.hit_cooldown
	var on_left: bool = body.to_local(global_position).x < 0.0
	var side: Rescue.Hull = Rescue.Hull.LEFT if on_left else Rescue.Hull.RIGHT
	RunState.beer_overboard(side, body.global_position)
	RunState.stop()
	var away: Vector2 = (body.global_position - global_position).normalized()
	RunState.shove(away * spec.shove_strength)


func _shape_half_depth() -> float:
	var shape: CollisionShape2D = $CollisionShape2D
	var rect: RectangleShape2D = shape.shape as RectangleShape2D
	return rect.size.y * 0.5 if rect != null else 0.0
