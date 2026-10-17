extends Node2D
class_name OffscreenArrows
## OffscreenArrows · one arrow per seat at the edge of the view, pointing at that guy while he
## is in the water off-screen (GDD › Systems › Setbacks: a swimmer who is off-screen is pointed
## at by an arrow at the edge of the view, so he can always be found). Lives under lake.tscn's
## HUD CanvasLayer, so its coordinates are screen pixels: each frame it maps every swimmer's
## lake position through the world canvas transform (the Camera's view, zoom included) and puts
## his arrow where the ray from the view centre to him leaves the view, inset by MARGIN, in his
## shirt colour, turned toward him. Hidden while he is on screen; gone once he is picked up
## (Rescue stops listing him). A screen: it only reads RunState. The maths are static, so
## tests/test_offscreen_arrows.gd runs them without a tree.

const ARROW_TEXTURE: Texture2D = preload("res://assets/sprites/arrow.png")
## Pixels between the view's edge and the arrow's centre.
const MARGIN: float = 8.0
## The sprite is drawn pointing up; turning it by this makes it point right (angle 0).
const UP_TO_RIGHT: float = PI / 2.0
## Shirt colour per seat in Paddling.Seat order: SHIRTS in tools/gen_sprites.gd, the colour of
## the guy's sprites.
const SEAT_COLOURS: Array[Color] = [
	Color8(242, 217, 51), Color8(242, 128, 38), Color8(77, 217, 89), Color8(217, 77, 204),
]

## One arrow per seat, reused; hidden unless that seat's guy is in the water off-screen.
var _arrows: Array[Sprite2D] = []


func _ready() -> void:
	for seat: int in RunState.GUY_COUNT:
		var arrow: Sprite2D = Sprite2D.new()
		arrow.name = "Arrow%d" % seat
		arrow.texture = ARROW_TEXTURE
		arrow.modulate = SEAT_COLOURS[seat]
		arrow.visible = false
		add_child(arrow)
		_arrows.append(arrow)


func _process(_delta: float) -> void:
	for arrow: Sprite2D in _arrows:
		arrow.visible = false
	var to_screen: Transform2D = get_viewport().get_canvas_transform()
	var half_size: Vector2 = get_viewport_rect().size / 2.0
	var center: Vector2 = half_size
	for swimmer: Rescue.Swimmer in RunState.rescue.swimmers():
		var target: Vector2 = to_screen * swimmer.position
		if not is_offscreen(target, center, half_size):
			continue
		var arrow: Sprite2D = _arrows[swimmer.seat]
		arrow.position = edge_point(target, center, half_size, MARGIN).round()
		arrow.rotation = angle(target, center) + UP_TO_RIGHT
		arrow.visible = true


# --- the maths, pure ----------------------------------------------------------------------------

## True when the target lies outside the view rectangle (view_center ± half_size).
static func is_offscreen(target: Vector2, view_center: Vector2, half_size: Vector2) -> bool:
	var away: Vector2 = (target - view_center).abs()
	return away.x > half_size.x or away.y > half_size.y


## Where the ray from the view centre toward the target leaves the view rectangle inset by
## margin on every side: the arrow's spot, always on that inset rectangle's edge. A target at
## the centre itself gives the centre.
static func edge_point(target: Vector2, view_center: Vector2, half_size: Vector2, margin: float) -> Vector2:
	var inset: Vector2 = (half_size - Vector2(margin, margin)).max(Vector2.ZERO)
	var toward: Vector2 = target - view_center
	if toward.is_zero_approx():
		return view_center
	var scale: float = INF
	if not is_zero_approx(toward.x):
		scale = inset.x / absf(toward.x)
	if not is_zero_approx(toward.y):
		scale = minf(scale, inset.y / absf(toward.y))
	return view_center + (toward * scale).clamp(-inset, inset)


## The direction from the view centre to the target in radians, 0 pointing right and PI/2 down
## (Vector2.angle()).
static func angle(target: Vector2, view_center: Vector2) -> float:
	return (target - view_center).angle()
