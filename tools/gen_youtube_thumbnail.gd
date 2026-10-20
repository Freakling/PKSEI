extends SceneTree
## gen_youtube_thumbnail · the YouTube thumbnail for the crossing video, 1280×720, composed from the
## game's own sprites like tools/gen_thumbnail.gd's cover: the headline in big outlined letters on the
## left, and on the right the catamaran up close with one seat empty, the guy who didn't make it in
## the water with his beer, yelling to be fetched, and the Loch-Brez fin closing in behind him.
## Needs a display (it renders a SubViewport), so not --headless:
##   <godot> --path . -s tools/gen_youtube_thumbnail.gd
## Writes design/itch/youtube_thumbnail.png. The layout is designed at 640×360 and drawn at 2×, so the
## text is rendered sharp rather than scaled up.

const OUT_DIR: String = "res://design/itch"
const OUT: String = "res://design/itch/youtube_thumbnail.png"
const BASE_SIZE: Vector2 = Vector2(640.0, 360.0)
const K: float = 2.0
## Game pixels per canvas pixel at 1×: sprites drawn 4 wide.
const PX: float = 4.0
const INK: Color = Color(0.08, 0.08, 0.1, 1.0)
const CREAM: Color = Color(1.0, 0.96, 0.8, 1.0)
const YELLOW: Color = Color(1.0, 0.84, 0.2, 1.0)
const BUBBLE_TAIL: float = 12.0

var _bubbles: Array[PanelContainer] = []
var _anchors: Array[Vector2] = []


func _init() -> void:
	_run()


func _run() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(BASE_SIZE * K)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	_compose(viewport)
	await process_frame
	_place_bubbles()
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var err: Error = image.save_png(OUT)
	print("wrote %s (%d×%d): %s" % [OUT, image.get_width(), image.get_height(), error_string(err)])
	quit(0 if err == OK else 1)


func _at(x: float, y: float) -> Vector2:
	return Vector2(x, y) * K


func _compose(parent: Node) -> void:
	var world: Node2D = Node2D.new()
	parent.add_child(world)
	var water: Sprite2D = _sprite(world, "res://assets/sprites/water.png", Vector2.ZERO)
	water.centered = false
	water.region_enabled = true
	water.region_rect = Rect2(Vector2.ZERO, BASE_SIZE / PX)
	water.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	# A darker band behind the headline so it pops.
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.0, 0.05, 0.15, 0.35)
	shade.position = Vector2.ZERO
	shade.size = _at(330.0, 360.0)
	parent.add_child(shade)
	# The island far off, top right.
	_sprite(world, "res://assets/sprites/island.png", _at(600.0, 18.0), 0.0, 1.0)
	# The catamaran up close, three aboard and one seat empty.
	var boat: Node2D = Node2D.new()
	boat.position = _at(470.0, 150.0)
	boat.rotation = -0.3
	world.add_child(boat)
	_sprite(boat, "res://assets/sprites/catamaran.png", Vector2.ZERO)
	_sprite(boat, "res://assets/sprites/guys/guy_0_stroke_1.png", _at(-14.0, -14.0) * PX)
	_sprite(boat, "res://assets/sprites/guys/guy_2_windup_0.png", _at(14.0, -14.0) * PX)
	_sprite(boat, "res://assets/sprites/guys/guy_3_puke_1.png", _at(14.0, 14.0) * PX)
	# The one left behind, beer in hand, and the fin coming for him.
	_sprite(world, "res://assets/sprites/hazards/beast_ripple_1.png", _at(560.0, 318.0))
	_sprite(world, "res://assets/sprites/beast_fin_0.png", _at(560.0, 306.0), -0.2)
	_sprite(world, "res://assets/sprites/guy_swim_1.png", _at(410.0, 300.0), 0.3)
	_sprite(world, "res://assets/sprites/beer.png", _at(434.0, 288.0), 0.4)
	_bubble(parent, "Kom och hämta mig dåååå!", _at(410.0, 280.0), 15)
	# The headline.
	_text(parent, "3 OF 4", _at(18.0, 40.0), 92, 10, YELLOW)
	_text(parent, "MADE IT", _at(18.0, 140.0), 76, 10, CREAM)
	_text(parent, "Paddla Kanot Som En Idiot", _at(22.0, 240.0), 20, 5, CREAM)


func _sprite(parent: Node, path: String, at: Vector2, rot: float = 0.0, px: float = PX) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = load(path) as Texture2D
	sprite.position = at
	sprite.rotation = rot
	sprite.scale = Vector2.ONE * px * K
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(sprite)
	return sprite


func _bubble(parent: Node, text: String, anchor: Vector2, font_size: int) -> void:
	var bubble: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.border_color = INK
	style.set_border_width_all(roundi(3.0 * K))
	style.set_corner_radius_all(roundi(8.0 * K))
	style.content_margin_left = 9.0 * K
	style.content_margin_right = 9.0 * K
	style.content_margin_top = 3.0 * K
	style.content_margin_bottom = 3.0 * K
	bubble.add_theme_stylebox_override("panel", style)
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", roundi(font_size * K))
	label.add_theme_color_override("font_color", INK)
	bubble.add_child(label)
	var tail: Polygon2D = Polygon2D.new()
	tail.name = "Tail"
	tail.color = Color.WHITE
	tail.polygon = PackedVector2Array([Vector2(-7.0, -3.0) * K, Vector2(7.0, -3.0) * K, Vector2(0.0, BUBBLE_TAIL) * K])
	bubble.add_child(tail)
	var edge: Line2D = Line2D.new()
	edge.width = 3.0 * K
	edge.default_color = INK
	edge.points = PackedVector2Array([Vector2(-7.0, 0.0) * K, Vector2(0.0, BUBBLE_TAIL) * K, Vector2(7.0, 0.0) * K])
	tail.add_child(edge)
	parent.add_child(bubble)
	_bubbles.append(bubble)
	_anchors.append(anchor)


func _place_bubbles() -> void:
	var canvas: Vector2 = BASE_SIZE * K
	for i: int in _bubbles.size():
		var bubble: PanelContainer = _bubbles[i]
		var size: Vector2 = bubble.size
		var at: Vector2 = _anchors[i] - Vector2(size.x * 0.5, size.y + BUBBLE_TAIL * K)
		at.x = clampf(at.x, 6.0 * K, canvas.x - size.x - 6.0 * K)
		bubble.position = at.round()
		var tail: Polygon2D = bubble.get_node("Tail") as Polygon2D
		tail.position = Vector2(clampf(_anchors[i].x - at.x, 14.0 * K, size.x - 14.0 * K), size.y)


func _text(parent: Node, text: String, at: Vector2, font_size: int, outline: int, colour: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", roundi(font_size * K))
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", roundi(outline * K))
	parent.add_child(label)
