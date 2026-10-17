extends HazardBase
## Headwind · a stretch of whitecaps where a sustained headwind strengthens the current, so only
## strong strokes gain water (GDD › Systems › Hazards, the Harsh wind row). An event placed like
## an object: the lake puts this node where the plan put it, and the stretch is the Headwind
## rule's rectangle from there toward the island across the whole lake. Visual/Band tints it and
## Visual/Whitecaps (one Polygon2D of small white dashes on a fixed grid) covers it, so the
## stretch is seen long before the boat reaches it. Each physics frame the boat is inside, the
## rule's extra drift goes to RunState.set_extra_drift(), so the current pulls harder for that
## step. No rules and no randomness here; the tunables are the headwind_* fields on LakeTuning, which the lake
## sets as `tuning` before the node enters the tree.

## The whitecaps (cosmetic): the grid's spacing in pixels, every other row shifted by half of
## it, and a dash's size.
const WHITECAP_SPACING: float = 40.0
const WHITECAP_LENGTH: float = 6.0
const WHITECAP_THICKNESS: float = 2.0

@onready var _band: Polygon2D = $Visual/Band
@onready var _whitecaps: Polygon2D = $Visual/Whitecaps

var _wind: Headwind
## The boat: the only CharacterBody2D on the lake, found in _setup().
var _boat: CharacterBody2D


## Runs once HazardBase has checked the lake's tunables.
func _setup() -> void:
	_wind = Headwind.new(tuning, global_position)
	_boat = _find_boat()
	var half: float = _wind.half_width()
	# The island-side edge in this node's frame: the trigger is the origin, the island is up.
	var top: float = _wind.far_y() - _wind.near_y()
	_band.polygon = PackedVector2Array([
		Vector2(-half, top), Vector2(half, top), Vector2(half, 0.0), Vector2(-half, 0.0),
	])
	_build_whitecaps(half, top)


func _physics_process(_delta: float) -> void:
	if _boat == null:
		return
	var extra: float = _wind.extra_drift(_boat.global_position)
	if extra > 0.0:
		RunState.set_extra_drift(extra)


## Visual only: one Polygon2D holding every dash, a grid WHITECAP_SPACING apart over the
## stretch with every other row shifted by half a spacing, all inside the rectangle.
func _build_whitecaps(half: float, top: float) -> void:
	var vertices: PackedVector2Array = PackedVector2Array()
	var dashes: Array = []
	var columns: int = int(floorf(half * 2.0 / WHITECAP_SPACING))
	var rows: int = int(floorf(-top / WHITECAP_SPACING))
	var half_length: float = WHITECAP_LENGTH * 0.5
	var half_thickness: float = WHITECAP_THICKNESS * 0.5
	for row: int in rows:
		var y: float = top + (row + 0.5) * WHITECAP_SPACING
		var shift: float = WHITECAP_SPACING * 0.5 if row % 2 == 1 else 0.0
		for column: int in columns:
			var x: float = -half + (column + 0.5) * WHITECAP_SPACING + shift
			if x + half_length > half:
				continue
			var first: int = vertices.size()
			vertices.append(Vector2(x - half_length, y - half_thickness))
			vertices.append(Vector2(x + half_length, y - half_thickness))
			vertices.append(Vector2(x + half_length, y + half_thickness))
			vertices.append(Vector2(x - half_length, y + half_thickness))
			dashes.append(PackedInt32Array([first, first + 1, first + 2, first + 3]))
	_whitecaps.polygon = vertices
	_whitecaps.polygons = dashes
