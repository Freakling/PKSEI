extends Area2D
## Rock · a rock or buoy in the water (GDD › Systems › Hazards, the Rock or buoy row). An object:
## it is fixed on the map where the lake placed it and never moves, so it is visible from far off
## before the boat reaches it. When the boat runs into it, the hull hit is the side the rock is on
## in the boat's own frame, and the effects go through RunState: the boat stops (stop(), its speed
## goes to zero on the hard hit) and a beer goes overboard on that hull. No shove. One bump is one
## hit: the spec's hit_cooldown passes before it can hit again. No rules and no randomness here:
## the lake places it from Hazards.plan() and sets `spec`.

## The spec the lake placed this rock from: its strengths. Set by the lake before it is added.
var spec: HazardSpec
var _cooldown: float = 0.0


func _ready() -> void:
	if spec == null:
		push_error("Rock: the lake must set spec before adding the hazard")


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)


## The boat ran into the rock (only the boat is a CharacterBody2D on the lake).
func _on_body_entered(body: Node2D) -> void:
	if not body is CharacterBody2D or _cooldown > 0.0 or spec == null:
		return
	_cooldown = spec.hit_cooldown
	var on_left: bool = body.to_local(global_position).x < 0.0
	var side: Rescue.Hull = Rescue.Hull.LEFT if on_left else Rescue.Hull.RIGHT
	RunState.stop()
	RunState.beer_overboard(side, body.global_position)
