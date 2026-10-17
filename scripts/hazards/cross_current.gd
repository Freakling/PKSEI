extends Node2D
## Cross-current stripe · a band of faster water that pushes the boat sideways while the boat is
## in it (GDD › Systems › Hazards, the Cross-current stripe row). An object placed like one: the
## lake puts this node where the plan put it, and the stripe is the CrossCurrent rule's rectangle
## from there toward the island across the whole lake. Visual/Band tints that stretch a slightly
## different blue and Visual/Arrows (small arrow dashes on a fixed grid, pointing the way the
## water runs) covers it, visible from spawn. Each physics frame the boat is inside, the rule's
## push goes to RunState.push(), which the boat moves by, the same sustained push as a gust. No
## rules and no randomness here; the tunables are the stripe_* fields on LakeTuning, which the lake
## sets as `tuning` before the node enters the tree.

## The arrows (cosmetic): the grid's spacing across and along the stripe in pixels, an arrow's
## length, shaft thickness, head length and head half-width, and their colours.
const ARROW_SPACING_X: float = 200.0
const ARROW_SPACING_Y: float = 120.0
const ARROW_LENGTH: float = 14.0
const ARROW_THICKNESS: float = 2.0
const ARROW_HEAD_LENGTH: float = 5.0
const ARROW_HEAD_HALF_WIDTH: float = 3.5
const BAND_COLOUR: Color = Color(0.3, 0.62, 0.92, 0.35)
const ARROW_COLOUR: Color = Color(0.75, 0.9, 1.0, 0.8)

@onready var _band: Polygon2D = $Visual/Band
@onready var _arrows: Polygon2D = $Visual/Arrows

## The lake's tunables, set by the lake before the node enters the tree. If it is null, _ready
## reports that and the node stays still.
var tuning: LakeTuning
var _stripe: CrossCurrent
## The boat: the only CharacterBody2D on the lake, found among the lake's children.
var _boat: CharacterBody2D


func _ready() -> void:
	if tuning == null:
		push_error("CrossCurrent: no LakeTuning; lake.gd sets it before adding the hazard")
		set_physics_process(false)
		return
	_stripe = CrossCurrent.new(tuning, global_position)
	_boat = _find_boat()
	var half: float = _stripe.half_width()
	# The island-side edge in this node's frame: the trigger is the origin, the island is up.
	var top: float = _stripe.far_y() - _stripe.near_y()
	_band.color = BAND_COLOUR
	_band.polygon = PackedVector2Array([
		Vector2(-half, top), Vector2(half, top), Vector2(half, 0.0), Vector2(-half, 0.0),
	])
	_build_arrows(half, top, _stripe.direction().x)


func _physics_process(_delta: float) -> void:
	if _boat == null:
		return
	if _stripe.inside(_boat.global_position):
		RunState.push(_stripe.push())


## Visual only: one Polygon2D holding every arrow, a grid ARROW_SPACING_X by ARROW_SPACING_Y over
## the stripe, every arrow a shaft and a head pointing along `facing` (+1 rightward, -1 leftward).
## Arrows that would poke past the stripe's sides are left out.
func _build_arrows(half: float, top: float, facing: float) -> void:
	var vertices: PackedVector2Array = PackedVector2Array()
	var shapes: Array = []
	var columns: int = int(floorf(half * 2.0 / ARROW_SPACING_X))
	var rows: int = int(floorf(-top / ARROW_SPACING_Y))
	var half_length: float = ARROW_LENGTH * 0.5
	var half_thickness: float = ARROW_THICKNESS * 0.5
	var head_start: float = half_length - ARROW_HEAD_LENGTH
	for row: int in rows:
		var y: float = top + (row + 0.5) * ARROW_SPACING_Y
		for column: int in columns:
			var x: float = -half + (column + 0.5) * ARROW_SPACING_X
			if absf(x) + half_length > half:
				continue
			var first: int = vertices.size()
			# The shaft, then the head, in offsets along the arrow that `facing` turns to the right.
			vertices.append(Vector2(x - facing * half_length, y - half_thickness))
			vertices.append(Vector2(x + facing * head_start, y - half_thickness))
			vertices.append(Vector2(x + facing * head_start, y + half_thickness))
			vertices.append(Vector2(x - facing * half_length, y + half_thickness))
			vertices.append(Vector2(x + facing * head_start, y - ARROW_HEAD_HALF_WIDTH))
			vertices.append(Vector2(x + facing * half_length, y))
			vertices.append(Vector2(x + facing * head_start, y + ARROW_HEAD_HALF_WIDTH))
			shapes.append(PackedInt32Array([first, first + 1, first + 2, first + 3]))
			shapes.append(PackedInt32Array([first + 4, first + 5, first + 6]))
	_arrows.color = ARROW_COLOUR
	_arrows.polygon = vertices
	_arrows.polygons = shapes


## The boat is the lake's CharacterBody2D; the hazards sit under the lake's Hazards node.
func _find_boat() -> CharacterBody2D:
	var hazards: Node = get_parent()
	if hazards == null or hazards.get_parent() == null:
		return null
	for child: Node in hazards.get_parent().get_children():
		if child is CharacterBody2D:
			return child as CharacterBody2D
	return null
