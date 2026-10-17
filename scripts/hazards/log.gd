extends Area2D
## Log · a log in the water (GDD › Systems › Hazards, the Log row). An object: it is fixed on the
## map where the lake placed it and never moves, so it is visible from far off before the boat
## reaches it. When the boat runs into it, the hull hit is the side the log is on in the boat's own
## frame, and the effects go through RunState: a beer overboard on that hull, and a shove that kills
## speed (stop(), then shove() away from the log at the spec's shove_strength). One bump is one hit:
## the spec's hit_cooldown passes before it can hit again. It has no warning of its own, so "ahead
## on the path" is its telegraph (T56): the first time the boat comes within
## LakeTuning.call_out_distance heading toward it (HazardBase.ahead_of), RunState.telegraph() gets
## it once with the hull it is beside, and that guy calls it out. No rules and no randomness here:
## the lake places it from Hazards.plan() and sets `spec` and `tuning`.

## The spec the lake placed this log from: its strengths. Set by the lake before it is added.
var spec: HazardSpec
## The lake's tunables (call_out_distance). Set by the lake before it is added; without it the
## log is never called out.
var tuning: LakeTuning
var _cooldown: float = 0.0
## Whether the guys have called this log out; once per placement.
var _called_out: bool = false
## The boat, found on the first step it is looked for; null until then.
var _boat: CharacterBody2D


func _ready() -> void:
	if spec == null:
		push_error("Log: the lake must set spec before adding the hazard")


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_call_out()


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


## The telegraph (T56): once, the first time the log is ahead on the boat's path.
func _call_out() -> void:
	if _called_out or tuning == null:
		return
	if _boat == null:
		_boat = HazardBase.find_boat_near(self)
		if _boat == null:
			return
	if HazardBase.ahead_of(_boat.global_position, _boat.global_rotation, global_position, tuning.call_out_distance):
		_called_out = true
		RunState.telegraph(&"log", HazardBase.hull_of(_boat, global_position))
