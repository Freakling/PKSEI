extends HazardBase
## Jet-ski · loud from offscreen, then a jet-ski crosses the boat's path on a straight line at
## speed (GDD › Systems › Hazards, the Jet-ski idiot row). An event: the lake places this node
## where the plan put it, but the placement is only the trigger and nothing shows there. When
## the boat comes near, the warning shows as a flashing marker at the screen's edge on the side
## the jet-ski will come from (Visual/Warning/Marker, a stand-in for the sound until T26's audio;
## Visual-only), then the jet-ski (Visual/JetSki: the two-frame jet-ski sprite with its rider
## and spray from assets/sprites/hazards/, T24, drawn by tools/gen_sprites.gd, turned to face
## along the rule's course) crosses at the JetSki rule's position. The rule decides everything;
## this script steps it each physics frame with the boat's position and heading, and applies
## its one hit through RunState: shove() along the jet-ski's travel and beer_overboard() on the
## hull it came from. No rules and no randomness here; the tunables are the jetski_* fields on
## LakeTuning, which the lake sets as `tuning` before the node enters the tree.

const JETSKI_FRAMES: Array[Texture2D] = [
	preload("res://assets/sprites/hazards/jetski_0.png"),
	preload("res://assets/sprites/hazards/jetski_1.png"),
]
## Seconds each frame shows (cosmetic): slow enough to read at 1×.
const FRAME_PERIOD: float = 0.15
## The warning marker (cosmetic): pixels in from the screen's edge, and its flash period in
## seconds (on for the first half).
const MARKER_INSET: float = 12.0
const FLASH_PERIOD: float = 0.3

@onready var _jetski: Sprite2D = $Visual/JetSki
@onready var _marker: Polygon2D = $Visual/Warning/Marker

var _rule: JetSki
## The boat: the only CharacterBody2D on the lake, found in _setup().
var _boat: CharacterBody2D
## Seconds the warning has shown, for the flash.
var _flash: float = 0.0
## Seconds into the animation.
var _clock: float = 0.0


## Runs once HazardBase has checked the lake's tunables.
func _setup() -> void:
	_rule = JetSki.new(tuning, global_position)
	_boat = _find_boat()
	_jetski.visible = false
	_marker.visible = false


func _physics_process(delta: float) -> void:
	if _boat == null:
		return
	var hit: JetSki.Hit = _rule.step(delta, _boat.global_position, _boat.global_rotation)
	if hit != null:
		RunState.shove(hit.shove)
		RunState.beer_overboard(hit.hull, _boat.global_position)
	_show_state(delta)


## Visual only: the marker flashes at the screen's edge on the jet-ski's side while the warning
## lasts; the jet-ski shows while it crosses, facing along its course (the sprite is drawn
## pointing right) with its spray dancing.
func _show_state(delta: float) -> void:
	_clock += delta
	var warning: bool = _rule.state == JetSki.State.WARNING
	if warning:
		_flash += delta
		var view: Vector2 = get_viewport().get_visible_rect().size
		var edge_x: float = MARKER_INSET if _rule.direction > 0.0 else view.x - MARKER_INSET
		_marker.position = Vector2(edge_x, view.y * 0.5)
		_marker.scale.x = _rule.direction
	else:
		_flash = 0.0
	_marker.visible = warning and fmod(_flash, FLASH_PERIOD) < FLASH_PERIOD * 0.5
	_jetski.visible = _rule.state == JetSki.State.CROSSING
	_jetski.position = to_local(_rule.jetski)
	_jetski.rotation = _rule.course.angle()
	_jetski.texture = JETSKI_FRAMES[_frame_at(_clock, JETSKI_FRAMES.size(), FRAME_PERIOD)]
