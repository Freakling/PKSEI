extends SceneTree
## gen_thumbnail · the itch.io cover image (630×500, the page's recommended size), composed from
## the game's own sprites at 4× with speech bubbles in the guys' Swedish and the title over it:
## the catamaran mid-lake with the four idiots each in his own mess, one in the water drinking his
## rescued beer while the Loch-Brez fin closes in, the geese hissing, the island far off.
## Needs a display (it renders a SubViewport), so not --headless:
##   <godot> --path . -s tools/gen_thumbnail.gd
## Writes design/itch/thumbnail.png. Fonts are Godot's default; everything else is assets/sprites.

const OUT_DIR: String = "res://design/itch"
const OUT: String = "res://design/itch/thumbnail.png"
const SIZE: Vector2i = Vector2i(630, 500)
## Sprite scale: the game's pixels drawn 4 wide.
const PX: float = 4.0
const INK: Color = Color(0.1, 0.1, 0.1, 1.0)
const BUBBLE_TAIL: float = 14.0

var _bubbles: Array[PanelContainer] = []
var _anchors: Array[Vector2] = []


func _init() -> void:
	_run()


func _run() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = SIZE
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


func _compose(parent: Node) -> void:
	var world: Node2D = Node2D.new()
	parent.add_child(world)
	# Water everywhere, the game's tile at 4×.
	var water: Sprite2D = _sprite(world, "res://assets/sprites/water.png", Vector2.ZERO)
	water.centered = false
	water.region_enabled = true
	water.region_rect = Rect2(Vector2.ZERO, Vector2(SIZE) / PX)
	water.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	# The island, far off at the top right.
	_sprite(world, "res://assets/sprites/island.png", Vector2(590.0, 50.0), 0.0, 1.0)
	# Hazards about: a rock, a log, the geese with their goslings, a jet-ski tearing past.
	_sprite(world, "res://assets/sprites/hazards/rock.png", Vector2(480.0, 175.0))
	_sprite(world, "res://assets/sprites/log.png", Vector2(85.0, 300.0), 0.6)
	_sprite(world, "res://assets/sprites/hazards/goslings.png", Vector2(570.0, 335.0))
	_sprite(world, "res://assets/sprites/hazards/goose_hiss_0.png", Vector2(525.0, 300.0), -0.6)
	_sprite(world, "res://assets/sprites/hazards/jetski_1.png", Vector2(400.0, 70.0), 0.3)
	# The beast: ripples and the fin, closing on the swimmer.
	_sprite(world, "res://assets/sprites/hazards/beast_ripple_1.png", Vector2(395.0, 462.0))
	_sprite(world, "res://assets/sprites/beast_fin_0.png", Vector2(395.0, 450.0), -0.3)
	# The swimmer, beer in hand, drifting happily.
	_sprite(world, "res://assets/sprites/guy_swim_1.png", Vector2(300.0, 430.0), 0.2)
	_sprite(world, "res://assets/sprites/beer.png", Vector2(326.0, 418.0), 0.4)
	# The catamaran, slewed, with the other three aboard and the empty seat.
	var boat: Node2D = Node2D.new()
	boat.position = Vector2(320.0, 270.0)
	boat.rotation = -0.45
	world.add_child(boat)
	_sprite(boat, "res://assets/sprites/catamaran.png", Vector2.ZERO)
	_sprite(boat, "res://assets/sprites/guys/guy_0_stroke_1.png", Vector2(-14.0, -14.0) * PX)
	_sprite(boat, "res://assets/sprites/guys/guy_1_windup_0.png", Vector2(-14.0, 14.0) * PX)
	_sprite(boat, "res://assets/sprites/guys/guy_3_peeing.png", Vector2(14.0, 14.0) * PX)
	# What they say.
	_bubble(parent, "Paddla för fan!", boat.position + Vector2(-70.0, -70.0))
	_bubble(parent, "Vilket håll är fram?", boat.position + Vector2(-50.0, 60.0))
	_bubble(parent, "Jag måste pissa", boat.position + Vector2(85.0, 30.0))
	_bubble(parent, "Ska bara dricka sen kommer jag", Vector2(300.0, 404.0))
	# The title and the tagline.
	_text(parent, "PKSEI", Vector2(22.0, 8.0), 64, 8)
	_text(parent, "Paddla Kanot Som En Idiot", Vector2(26.0, 92.0), 22, 5)
	_text(parent, "Fyra idioter. Två kanoter. En ö.", Vector2(22.0, 462.0), 18, 4)


func _sprite(parent: Node, path: String, at: Vector2, rot: float = 0.0, px: float = PX) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = load(path) as Texture2D
	sprite.position = at
	sprite.rotation = rot
	sprite.scale = Vector2(px, px)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(sprite)
	return sprite


## A speech bubble whose tail's tip ends at `anchor`; placed once its size is known.
func _bubble(parent: Node, text: String, anchor: Vector2) -> void:
	var bubble: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.border_color = INK
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	bubble.add_theme_stylebox_override("panel", style)
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", INK)
	bubble.add_child(label)
	var tail: Polygon2D = Polygon2D.new()
	tail.name = "Tail"
	tail.color = Color.WHITE
	tail.polygon = PackedVector2Array([Vector2(-8.0, -3.0), Vector2(8.0, -3.0), Vector2(0.0, BUBBLE_TAIL)])
	bubble.add_child(tail)
	var tail_edge: Line2D = Line2D.new()
	tail_edge.width = 3.0
	tail_edge.default_color = INK
	tail_edge.points = PackedVector2Array([Vector2(-8.0, 0.0), Vector2(0.0, BUBBLE_TAIL), Vector2(8.0, 0.0)])
	tail.add_child(tail_edge)
	parent.add_child(bubble)
	_bubbles.append(bubble)
	_anchors.append(anchor)


func _place_bubbles() -> void:
	for i: int in _bubbles.size():
		var bubble: PanelContainer = _bubbles[i]
		var size: Vector2 = bubble.size
		var at: Vector2 = _anchors[i] - Vector2(size.x * 0.5, size.y + BUBBLE_TAIL)
		at.x = clampf(at.x, 6.0, SIZE.x - size.x - 6.0)
		bubble.position = at.round()
		var tail: Polygon2D = bubble.get_node("Tail") as Polygon2D
		tail.position = Vector2(clampf(_anchors[i].x - at.x, 14.0, size.x - 14.0), size.y)


func _text(parent: Node, text: String, at: Vector2, font_size: int, outline: int) -> void:
	var label: Label = Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.8, 1.0))
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", outline)
	parent.add_child(label)
