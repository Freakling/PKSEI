extends HazardBase
## FishingLine · a fisherman in a dinghy and his line across the water (GDD › Systems › Hazards,
## the Fishing line row). An object: the dinghy with its fisherman (Visual/Dinghy, the sprite from
## assets/sprites/hazards/, T24, drawn by tools/gen_sprites.gd) sits where the lake placed it and
## never moves, and the line (Visual/Line) runs from his rod's tip sideways, outward from the
## lake's middle line, across line_length pixels to its float (Visual/Float, bobbing between its
## two frames), so it is visible from far off before the boat reaches it. The Snag area lies
## along the line. When the boat crosses it, the hull hit is the side of the boat the dinghy is
## on, in the boat's own frame, and RunState snags that hull's guy for snag_time seconds (the Snag
## a paddle effect). One crossing is one hit: the spec's hit_cooldown passes before it can hit
## again. The dinghy itself is a bump (T91, the Hull area, a circle of dinghy_radius round it,
## apart from the line): a beer overboard on the hull facing it and a shove of dinghy_shove away
## from it, with its own hit_cooldown; crossing the line or the float alone only snags. No rules
## and no randomness here: the lake places it from Hazards.plan() and sets `spec`; the tunables
## are the line_length, snag_time, dinghy_radius and dinghy_shove fields on LakeTuning, which the
## lake sets as `tuning` before the node enters the tree.

const FLOAT_FRAMES: Array[Texture2D] = [
	preload("res://assets/sprites/hazards/float_0.png"),
	preload("res://assets/sprites/hazards/float_1.png"),
]
## Seconds each float frame shows (cosmetic): slow enough to read at 1×.
const FRAME_PERIOD: float = 0.25
## The rod's tip in the 44×30 dinghy sprite (T61), from its centre, for a line running right
## (cosmetic): the pixel past the rod's end at (42, 4), so the line carries on its diagonal.
const ROD_TIP: Vector2 = Vector2(21.0, -11.0)
## The hit area's thickness across the line, in pixels: thin, so the line itself is what is crossed.
const HIT_THICKNESS: float = 4.0

@onready var _line: Line2D = $Visual/Line
@onready var _dinghy: Sprite2D = $Visual/Dinghy
@onready var _float: Sprite2D = $Visual/Float
@onready var _snag: Area2D = $Snag
@onready var _shape: CollisionShape2D = $Snag/CollisionShape2D
@onready var _hull_shape: CollisionShape2D = $Hull/CollisionShape2D

var _cooldown: float = 0.0
## The dinghy bump's own cooldown, apart from the line's.
var _hull_cooldown: float = 0.0
## Which way the line runs from the dinghy: away from the lake's middle line, -1 left, +1 right.
var _direction: float = 1.0
## Seconds into the animation.
var _clock: float = 0.0


## The line is placed from a HazardSpec, so the base's guard checks for `spec` too.
func _needs_spec() -> bool:
	return true


## Runs once HazardBase has checked the lake's fields.
func _setup() -> void:
	_direction = -1.0 if global_position.x < 0.0 else 1.0
	var reach: float = tuning.line_length
	var tip: Vector2 = Vector2(_direction * reach, 0.0)
	# The dinghy is drawn with its rod to the right; flipped when the line runs left.
	_dinghy.scale.x = _direction
	_line.points = PackedVector2Array([Vector2(_direction * ROD_TIP.x, ROD_TIP.y), tip])
	_float.position = tip
	# The line snags from the dinghy's edge out to the float, so ramming the dinghy is only a bump.
	var start: float = minf(tuning.dinghy_radius, reach)
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(reach - start, HIT_THICKNESS)
	_shape.shape = rect
	_snag.position = Vector2(_direction * (start + (reach - start) * 0.5), 0.0)
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = tuning.dinghy_radius
	_hull_shape.shape = circle


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_hull_cooldown = maxf(_hull_cooldown - delta, 0.0)
	_clock += delta
	_float.texture = FLOAT_FRAMES[_frame_at(_clock, FLOAT_FRAMES.size(), FRAME_PERIOD)]


## The boat crossed the line (only the boat is a CharacterBody2D on the lake). The hull hit is the side
## of the boat the dinghy is on, in the boat's own frame, as rock.gd does with its position.
func _on_body_entered(body: Node2D) -> void:
	if not body is CharacterBody2D or _cooldown > 0.0 or spec == null or tuning == null:
		return
	_cooldown = spec.hit_cooldown
	var on_left: bool = body.to_local(global_position).x < 0.0
	var hull: Rescue.Hull = Rescue.Hull.LEFT if on_left else Rescue.Hull.RIGHT
	RunState.snag(hull, tuning.snag_time)


## The boat ran into the dinghy (T91): a beer overboard on the hull facing it and a shove away.
func _on_hull_body_entered(body: Node2D) -> void:
	if not body is CharacterBody2D or _hull_cooldown > 0.0 or spec == null or tuning == null:
		return
	_hull_cooldown = spec.hit_cooldown
	var bump: Dictionary = dinghy_hit(body.global_position, body.global_rotation, global_position, tuning.dinghy_shove)
	RunState.beer_overboard(bump["hull"], body.global_position)
	RunState.shove(bump["shove"])


## What bumping the dinghy does (pure): the hull of the boat the dinghy lies beside, in the boat's
## own frame (as HazardBase.hull_of decides it), and the shove, `strength` pixels per second from
## the dinghy toward the boat.
static func dinghy_hit(boat_position: Vector2, boat_rotation: float, dinghy_position: Vector2, strength: float) -> Dictionary:
	var local: Vector2 = (dinghy_position - boat_position).rotated(-boat_rotation)
	var hull: Rescue.Hull = Rescue.Hull.LEFT if local.x < 0.0 else Rescue.Hull.RIGHT
	return {"hull": hull, "shove": (boat_position - dinghy_position).normalized() * strength}
