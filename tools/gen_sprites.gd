extends SceneTree
## Sprite generator · draws the pixel art in assets/sprites/ pixel by pixel with the Image API
## (GDD › Presentation and Platforms: top-down, bright, a bit retro). Kept here so the art is
## reproducible and tweakable in code; the human reviews the result like any other asset.
##
## Run from the project root:
##   godot --headless --path . -s tools/gen_sprites.gd [-- --preview <dir>]
## `--preview <dir>` also writes each sprite scaled up 8× to <dir>, for looking at the art.
##
## Everything is drawn for the 640×360 canvas, so the sprites are small. Each shape gets a 1-px
## dark outline (_outline adds it on the transparent neighbours of what was drawn). Sizes match
## the scenes: the catamaran is its 40×56 collision box, a guy sits on his hull's centre line,
## the island is drawn at lake.gd's ISLAND_ART_RADIUS and scaled from there.

const OUT_DIR: String = "res://assets/sprites"
const PREVIEW_SCALE: int = 8

# --- palette (bright, retro) ---
const OUTLINE: Color = Color8(30, 24, 44)
const WATER: Color = Color8(58, 134, 214)
const WATER_LIGHT: Color = Color8(126, 194, 242)
const WATER_DEEP: Color = Color8(42, 108, 188)
const WATER_SHALLOW: Color = Color8(112, 192, 232)
const SAND: Color = Color8(234, 210, 130)
const SAND_DARK: Color = Color8(206, 178, 98)
const SAND_LIGHT: Color = Color8(250, 236, 172)
const GRASS: Color = Color8(98, 182, 74)
const GRASS_DARK: Color = Color8(58, 132, 54)
const GRASS_LIGHT: Color = Color8(152, 216, 102)
const PINE_DARK: Color = Color8(32, 98, 56)
const PINE: Color = Color8(46, 132, 70)
const PINE_LIGHT: Color = Color8(94, 174, 92)
const TRUNK: Color = Color8(110, 70, 36)
const WOOD: Color = Color8(152, 98, 50)
const WOOD_LIGHT: Color = Color8(200, 144, 84)
const WOOD_DARK: Color = Color8(98, 58, 30)
const HULL: Color = Color8(190, 198, 206)
const HULL_LIGHT: Color = Color8(236, 240, 244)
const HULL_DARK: Color = Color8(132, 144, 158)
const HULL_FLOOR: Color = Color8(154, 166, 180)
const SKIN: Color = Color8(240, 192, 142)
const SKIN_LIGHT: Color = Color8(252, 226, 190)
const BEER_CAN: Color = Color8(250, 204, 40)
const BEER_LID: Color = Color8(222, 224, 232)
const BEER_LIGHT: Color = Color8(254, 238, 140)
const COOLER: Color = Color8(222, 52, 52)
const COOLER_LID: Color = Color8(246, 246, 250)
const FIRE: Color = Color8(250, 140, 40)
const FIRE_LIGHT: Color = Color8(254, 230, 96)
const ASH: Color = Color8(90, 86, 96)
const SPLASH: Color = Color8(255, 255, 255)
const TENT: Color = Color8(226, 92, 60)
const TENT_LIGHT: Color = Color8(246, 142, 104)
const TENT_DARK: Color = Color8(168, 58, 44)

## Shirt and hair per seat, in Paddling.Seat order (LF, LB, RF, RB). Hair alpha 0 = bald.
const SHIRTS: Array[Color] = [
	Color8(242, 217, 51), Color8(242, 128, 38), Color8(77, 217, 89), Color8(217, 77, 204),
]
const HAIRS: Array[Color] = [
	Color8(40, 36, 48), Color(0, 0, 0, 0), Color8(204, 82, 40), Color8(244, 214, 112),
]

var _preview_dir: String = ""


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in args.size():
		if args[i] == "--preview" and i + 1 < args.size():
			_preview_dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_save(_catamaran(), "catamaran")
	for seat: int in SHIRTS.size():
		_save(_guy(seat), "guy_%d" % seat)
		_save(_guy_swim(seat), "guy_swim_%d" % seat)
		_save(_guy_camp(seat), "guy_camp_%d" % seat)
	_save(_beer(), "beer")
	_save(_tent(), "tent")
	for frame: int in 2:
		_save(_campfire(frame), "campfire_%d" % frame)
	_save(_water(), "water")
	_save(_sand(), "sand")
	_save(_island(), "island")
	_save(_log(), "log")
	quit()


# --- sprites ------------------------------------------------------------------------------------

## 40×56: two double-ended aluminium canoes, two lashed cross-bars, a beer cooler between them.
## Hull centre lines at image x 6 and 34, matching the guys' seats at x = ±14.
func _catamaran() -> Image:
	var img: Image = _new(40, 56)
	for cx: int in [6, 34]:
		for y: int in range(1, 55):
			# Half-width 0 at each tip, widening by one every two rows to 4.
			var half: int = mini(4, (mini(y - 1, 54 - y) + 1) / 2)
			_rect(img, cx - half, y, 2 * half + 1, 1, HULL)
			if half >= 3:
				_rect(img, cx - half + 2, y, 2 * half - 3, 1, HULL_FLOOR)
			_px(img, cx - half, y, HULL_LIGHT)
		# Thwart across the middle of each hull.
		_rect(img, cx - 2, 27, 5, 2, HULL_DARK)
	_outline(img, OUTLINE)
	# Cross-bars fore and aft, lashed over both hulls.
	for y: int in [8, 44]:
		_rect(img, 1, y, 38, 4, OUTLINE)
		_rect(img, 2, y + 1, 36, 2, WOOD)
		_rect(img, 2, y + 1, 36, 1, WOOD_LIGHT)
		for x: int in [2, 10, 30, 38]:
			_rect(img, x, y + 1, 1, 2, WOOD_DARK)
	# A thin bar carrying the cooler between the hulls.
	_rect(img, 11, 27, 18, 2, OUTLINE)
	_rect(img, 12, 27, 16, 1, WOOD)
	# The cooler.
	_rect(img, 15, 23, 10, 9, OUTLINE)
	_rect(img, 16, 24, 8, 7, COOLER)
	_rect(img, 16, 25, 8, 2, COOLER_LID)
	_rect(img, 18, 24, 4, 1, OUTLINE)
	return img


## 12×12 top-down guy on his seat: shoulders in his shirt colour, head with hair (or bald), both
## hands on a paddle held out over the water on his hull's side. Seats on the right are mirrored.
## The body is centred on x 7 (left) or 4 (right); the scene offsets the sprite by 1 px.
func _guy(seat: int) -> Image:
	var img: Image = _new(12, 12)
	var shirt: Color = SHIRTS[seat]
	# Paddle: shaft and blade.
	_rect(img, 2, 1, 1, 8, WOOD)
	_rect(img, 1, 8, 3, 3, WOOD_LIGHT)
	_px(img, 2, 8, WOOD)
	# Shoulders.
	_rect(img, 4, 5, 7, 6, shirt)
	_rect(img, 4, 10, 7, 1, shirt.darkened(0.25))
	for corner: Vector2i in [Vector2i(4, 5), Vector2i(10, 5), Vector2i(4, 10), Vector2i(10, 10)]:
		_clear(img, corner.x, corner.y)
	# Hands on the shaft.
	_px(img, 3, 5, SKIN)
	_px(img, 3, 7, SKIN)
	_head(img, 7, 5, HAIRS[seat])
	_outline(img, OUTLINE)
	if seat == Paddling.Seat.RIGHT_FRONT or seat == Paddling.Seat.RIGHT_BACK:
		img.flip_x()
	return img


## 14×12 the same guy in the water: head and shoulders, arms spread, a splash around him.
func _guy_swim(seat: int) -> Image:
	var img: Image = _new(14, 12)
	var shirt: Color = SHIRTS[seat]
	_rect(img, 4, 5, 7, 5, shirt)
	_rect(img, 4, 9, 7, 1, shirt.darkened(0.25))
	for corner: Vector2i in [Vector2i(4, 5), Vector2i(10, 5), Vector2i(4, 9), Vector2i(10, 9)]:
		_clear(img, corner.x, corner.y)
	# Arms out, hands splashing.
	_rect(img, 2, 6, 2, 1, SKIN)
	_rect(img, 11, 6, 2, 1, SKIN)
	_head(img, 7, 5, HAIRS[seat])
	_outline(img, OUTLINE)
	for splash: Vector2i in [Vector2i(1, 4), Vector2i(0, 7), Vector2i(13, 4), Vector2i(13, 8),
			Vector2i(5, 11), Vector2i(9, 11)]:
		_px(img, splash.x, splash.y, SPLASH)
	return img


## 9×12 the same guy ashore (the win cutscene, T28): shoulders and head facing up, no paddle,
## both hands held out in front, one of them for a beer. The body is centred on x 4.
func _guy_camp(seat: int) -> Image:
	var img: Image = _new(9, 12)
	var shirt: Color = SHIRTS[seat]
	_rect(img, 1, 4, 7, 6, shirt)
	_rect(img, 1, 9, 7, 1, shirt.darkened(0.25))
	for corner: Vector2i in [Vector2i(1, 4), Vector2i(7, 4), Vector2i(1, 9), Vector2i(7, 9)]:
		_clear(img, corner.x, corner.y)
	_px(img, 1, 3, SKIN)
	_px(img, 7, 3, SKIN)
	_head(img, 4, 4, HAIRS[seat])
	_outline(img, OUTLINE)
	return img


## 22×18 ridge tent seen from above: the lit slope, the shaded slope, the ridge between them and
## a door flap opening at the right end.
func _tent() -> Image:
	var img: Image = _new(22, 18)
	_rect(img, 1, 1, 20, 8, TENT_LIGHT)
	_rect(img, 1, 9, 20, 8, TENT)
	_rect(img, 1, 8, 20, 1, TENT_DARK)
	for corner: Vector2i in [Vector2i(1, 1), Vector2i(20, 1), Vector2i(1, 16), Vector2i(20, 16)]:
		_clear(img, corner.x, corner.y)
	# The door: a dark wedge opening toward the right end.
	for i: int in 3:
		_rect(img, 20 - i, 8 - i, 1, 2 * i + 1, OUTLINE)
	_outline(img, OUTLINE)
	return img


## 12×12 camp fire, two frames: an ash ring, two crossed logs and a flame whose tongues lick a
## different way each frame (the cutscene flips between them).
func _campfire(frame: int) -> Image:
	var img: Image = _new(12, 12)
	_disc(img, 6, 6, 4, ASH)
	_rect(img, 2, 6, 8, 2, WOOD)
	_rect(img, 5, 2, 2, 8, WOOD)
	_rect(img, 2, 6, 8, 1, WOOD_LIGHT)
	_disc(img, 6, 6, 2, FIRE)
	var tongues: Array[Vector2i] = [Vector2i(6, 3), Vector2i(8, 4), Vector2i(4, 5)]
	if frame == 1:
		tongues = [Vector2i(5, 3), Vector2i(8, 7), Vector2i(3, 4)]
	for tongue: Vector2i in tongues:
		_px(img, tongue.x, tongue.y, FIRE)
	_px(img, 6, 6, FIRE_LIGHT)
	_px(img, 6 - frame, 5, FIRE_LIGHT)
	_outline(img, OUTLINE)
	return img


## 4×6 beer can: outlined, a grey lid and a shine.
func _beer() -> Image:
	var img: Image = _new(4, 6)
	_rect(img, 0, 0, 4, 6, OUTLINE)
	_rect(img, 1, 1, 2, 4, BEER_CAN)
	_rect(img, 1, 1, 2, 1, BEER_LID)
	_px(img, 1, 2, BEER_LIGHT)
	return img


## 32×32 tileable water: flat blue with a few lighter wave ticks, none touching the tile's edge.
func _water() -> Image:
	var img: Image = _new(32, 32)
	img.fill(WATER)
	var ticks: Array[Vector3i] = [  # x, y, length
		Vector3i(3, 4, 4), Vector3i(15, 2, 3), Vector3i(24, 7, 4), Vector3i(8, 13, 3),
		Vector3i(20, 16, 4), Vector3i(28, 12, 2), Vector3i(2, 22, 3), Vector3i(13, 25, 4),
		Vector3i(25, 27, 3), Vector3i(9, 19, 2),
	]
	for tick: Vector3i in ticks:
		_rect(img, tick.x, tick.y, tick.z, 1, WATER_LIGHT)
		_px(img, tick.x + tick.z, tick.y + 1, WATER_DEEP)
	return img


## 32×32 tileable sand: flat yellow with scattered darker and lighter grains.
func _sand() -> Image:
	var img: Image = _new(32, 32)
	img.fill(SAND)
	var dark: Array[Vector2i] = [
		Vector2i(3, 5), Vector2i(12, 2), Vector2i(21, 6), Vector2i(29, 9), Vector2i(7, 14),
		Vector2i(17, 17), Vector2i(26, 20), Vector2i(2, 24), Vector2i(11, 28), Vector2i(22, 29),
		Vector2i(30, 25), Vector2i(15, 10),
	]
	var light: Array[Vector2i] = [
		Vector2i(8, 8), Vector2i(25, 3), Vector2i(19, 23), Vector2i(4, 30), Vector2i(28, 15),
		Vector2i(13, 20),
	]
	for grain: Vector2i in dark:
		_px(img, grain.x, grain.y, SAND_DARK)
	for grain: Vector2i in light:
		_px(img, grain.x, grain.y, SAND_LIGHT)
	return img


## 160×140 island: shallows, an outlined sand beach, grass, three pines and a clearing with a
## fire pit. The beach reaches about 70 px from the centre (lake.gd scales it to island_radius).
func _island() -> Image:
	var img: Image = _new(160, 140)
	var c: Vector2i = Vector2i(80, 70)
	_ellipse(img, c.x, c.y, 79, 69, WATER_SHALLOW)
	_ellipse(img, c.x, c.y, 72, 62, OUTLINE)
	_ellipse(img, c.x, c.y, 71, 61, SAND)
	for grain: Vector2i in [Vector2i(20, 70), Vector2i(30, 40), Vector2i(140, 72), Vector2i(128, 100),
			Vector2i(80, 124), Vector2i(50, 118), Vector2i(110, 18), Vector2i(60, 16)]:
		_px(img, grain.x, grain.y, SAND_DARK)
	_ellipse(img, c.x, c.y - 4, 55, 45, GRASS_DARK)
	_ellipse(img, c.x, c.y - 4, 54, 44, GRASS)
	for tuft: Vector2i in [Vector2i(40, 60), Vector2i(60, 40), Vector2i(90, 30), Vector2i(118, 60),
			Vector2i(100, 96), Vector2i(50, 90), Vector2i(76, 70), Vector2i(116, 80)]:
		_rect(img, tuft.x, tuft.y, 2, 1, GRASS_LIGHT)
	# A tent-sized clearing with a fire pit.
	_ellipse(img, 96, 84, 13, 9, SAND_LIGHT)
	_disc(img, 96, 84, 2, ASH)
	_px(img, 96, 84, FIRE)
	for tree: Vector2i in [Vector2i(52, 52), Vector2i(104, 44), Vector2i(66, 92)]:
		_pine(img, tree.x, tree.y)
	return img


## 48×12 log: a floating trunk with a cut end, a highlight, bark knots and a branch stub.
func _log() -> Image:
	var img: Image = _new(48, 12)
	_rect(img, 2, 2, 44, 8, WOOD)
	for corner: Vector2i in [Vector2i(2, 2), Vector2i(45, 2), Vector2i(2, 9), Vector2i(45, 9)]:
		_clear(img, corner.x, corner.y)
	_rect(img, 5, 3, 40, 1, WOOD_LIGHT)
	_rect(img, 5, 8, 40, 1, WOOD_DARK)
	for knot: Vector2i in [Vector2i(14, 5), Vector2i(15, 5), Vector2i(30, 6), Vector2i(31, 6),
			Vector2i(38, 4)]:
		_px(img, knot.x, knot.y, WOOD_DARK)
	# Cut end with a ring.
	_rect(img, 2, 3, 3, 6, WOOD_LIGHT)
	_rect(img, 3, 5, 1, 2, WOOD)
	# Branch stub.
	_rect(img, 22, 1, 2, 1, WOOD)
	_outline(img, OUTLINE)
	return img


# --- parts --------------------------------------------------------------------------------------

## A top-down head at (cx, cy): a skin disc with the hair over its back half, or a bald shine.
func _head(img: Image, cx: int, cy: int, hair: Color) -> void:
	_disc(img, cx, cy, 2, SKIN)
	if hair.a > 0.0:
		for dy: int in range(0, 3):
			var half: int = 2 if dy < 2 else 1
			_rect(img, cx - half, cy + dy, 2 * half + 1, 1, hair)
		_px(img, cx - 2, cy - 1, hair)
		_px(img, cx + 2, cy - 1, hair)
	else:
		_px(img, cx - 1, cy - 1, SKIN_LIGHT)


## A pine seen from above: a dark crown with lighter branch spokes and the trunk's tip.
func _pine(img: Image, cx: int, cy: int) -> void:
	_disc(img, cx + 2, cy + 2, 10, GRASS_DARK)
	_disc(img, cx, cy, 10, OUTLINE)
	_disc(img, cx, cy, 9, PINE_DARK)
	for i: int in 8:
		var angle: float = TAU * float(i) / 8.0 + TAU / 16.0
		for t: int in range(2, 9):
			_px(img, cx + roundi(cos(angle) * t), cy + roundi(sin(angle) * t), PINE)
	_disc(img, cx, cy, 2, PINE_LIGHT)
	_px(img, cx, cy, TRUNK)


# --- drawing helpers ----------------------------------------------------------------------------

static func _new(width: int, height: int) -> Image:
	return Image.create_empty(width, height, false, Image.FORMAT_RGBA8)


static func _px(img: Image, x: int, y: int, colour: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, colour)


static func _clear(img: Image, x: int, y: int) -> void:
	_px(img, x, y, Color(0, 0, 0, 0))


static func _rect(img: Image, x: int, y: int, width: int, height: int, colour: Color) -> void:
	for yy: int in range(y, y + height):
		for xx: int in range(x, x + width):
			_px(img, xx, yy, colour)


static func _disc(img: Image, cx: int, cy: int, radius: int, colour: Color) -> void:
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			if dx * dx + dy * dy <= radius * radius + radius:
				_px(img, cx + dx, cy + dy, colour)


static func _ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, colour: Color) -> void:
	for dy: int in range(-ry, ry + 1):
		for dx: int in range(-rx, rx + 1):
			var fx: float = float(dx) / (float(rx) + 0.5)
			var fy: float = float(dy) / (float(ry) + 0.5)
			if fx * fx + fy * fy <= 1.0:
				_px(img, cx + dx, cy + dy, colour)


## Every transparent pixel next to a drawn one (4-neighbours) becomes the outline.
static func _outline(img: Image, colour: Color) -> void:
	var source: Image = img.duplicate() as Image
	for y: int in img.get_height():
		for x: int in img.get_width():
			if source.get_pixel(x, y).a > 0.0:
				continue
			if _solid(source, x - 1, y) or _solid(source, x + 1, y) \
					or _solid(source, x, y - 1) or _solid(source, x, y + 1):
				img.set_pixel(x, y, colour)


static func _solid(img: Image, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return false
	return img.get_pixel(x, y).a > 0.0


func _save(img: Image, sprite_name: String) -> void:
	var path: String = OUT_DIR.path_join(sprite_name + ".png")
	var err: Error = img.save_png(path)
	print("%s %s (%d×%d)" % ["wrote" if err == OK else "FAILED", path, img.get_width(), img.get_height()])
	if not _preview_dir.is_empty():
		var big: Image = img.duplicate() as Image
		big.resize(img.get_width() * PREVIEW_SCALE, img.get_height() * PREVIEW_SCALE, Image.INTERPOLATE_NEAREST)
		big.save_png(_preview_dir.path_join(sprite_name + "_x%d.png" % PREVIEW_SCALE))
