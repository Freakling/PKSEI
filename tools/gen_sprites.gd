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
const SAND_GROOVE: Color = Color8(178, 144, 80)
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

## The animation frames per guy (T23): one 12×14 PNG per frame in assets/sprites/guys/, named
## guy_<seat>_<frame>.png, drawn by _guy_frame(); catamaran.gd builds its SpriteFrames from
## them, so the names are its contract.
const GUYS_DIR: String = "guys"
const GUY_FRAMES: Array[String] = [
	"idle", "stroke_0", "stroke_1", "fumble", "warning_0", "warning_1", "break", "windup_0",
	"windup_1", "stand", "paddle_dropped", "nodded_off", "peeing", "bar_0", "bar_1",
]
const ZEE: Color = Color8(217, 230, 255)

var _preview_dir: String = ""


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in args.size():
		if args[i] == "--preview" and i + 1 < args.size():
			_preview_dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(OUT_DIR.path_join(GUYS_DIR))
	_save(_catamaran(), "catamaran")
	for seat: int in SHIRTS.size():
		_save(_guy_swim(seat), "guy_swim_%d" % seat)
		_save(_guy_camp(seat), "guy_camp_%d" % seat)
		for frame: String in GUY_FRAMES:
			_save(_guy_frame(seat, frame), "guy_%d_%s" % [seat, frame], GUYS_DIR)
	_save(_beer(), "beer")
	_save(_tent(), "tent")
	for frame: int in 2:
		_save(_campfire(frame), "campfire_%d" % frame)
	_save(_water(), "water")
	_save(_sand(), "sand")
	_save(_sand_text(), "sand_text")
	_save(_island(), "island")
	_save(_log(), "log")
	_save(_arrow(), "arrow")
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


## 12×14 one animation frame of the guy on his seat (one of GUY_FRAMES; catamaran.gd plays
## them): a paddle, a torso and a head, with a row above and below for the paddle's reach, the
## head going back and the glyphs. Drawn for the left seats (the water to the left) and mirrored
## for the right ones; the body is centred on x 7 with the head at (7, 6), so the scene's 1-px
## offset still applies. Each frame is one pose:
##   idle · stroke_0 (the reach: blade planted ahead) · stroke_1 (the pull: blade back, splash)
##   fumble (paddle slipping outboard, splash) · warning_0 (wiping his brow, sweating) ·
##   warning_1 (slumping) · break (paddle laid down, head back, a beer at his mouth) ·
##   windup_0/1 (looking left and right, the paddle wobbling) · stand (bigger: closer to the
##   camera, paddle raised over his head) · paddle_dropped (no paddle, arms out over the water)
##   nodded_off (head on his chest, paddle drooping, a "z") · peeing (turned to the hull's edge)
##   bar_0/1 (swaying with the paddle, head lolling).
func _guy_frame(seat: int, frame: String) -> Image:
	var img: Image = _new(12, 14)
	var shirt: Color = SHIRTS[seat]
	var hair: Color = HAIRS[seat]
	var dots: Array[Vector2i] = []
	var dot_colour: Color = SPLASH
	match frame:
		"idle":
			_paddle(img, 2, 2, 8, 9)
			_torso(img, 4, 6, shirt)
			_hands(img, Vector2i(3, 6), Vector2i(3, 8))
			_head(img, 7, 6, hair)
		"stroke_0":
			_paddle(img, 2, 3, 8, 1)
			_torso(img, 4, 6, shirt)
			_hands(img, Vector2i(3, 5), Vector2i(3, 7))
			_head(img, 7, 6, hair)
		"stroke_1":
			_paddle(img, 2, 3, 8, 10)
			_torso(img, 4, 6, shirt)
			_hands(img, Vector2i(3, 7), Vector2i(3, 9))
			_head(img, 7, 6, hair)
			dots = [Vector2i(0, 9), Vector2i(5, 13)]
		"fumble":
			_paddle(img, 1, 4, 7, 10)
			_torso(img, 4, 6, shirt)
			_hands(img, Vector2i(3, 5), Vector2i(3, 7))
			_head(img, 6, 6, hair)
			dots = [Vector2i(0, 3), Vector2i(0, 13), Vector2i(2, 13)]
		"warning_0":
			_paddle(img, 2, 2, 8, 9)
			_torso(img, 4, 6, shirt)
			_hands(img, Vector2i(4, 5), Vector2i(3, 8))
			_px(img, 5, 4, SKIN)
			_head(img, 7, 6, hair)
			dots = [Vector2i(10, 4), Vector2i(11, 7)]
			dot_colour = WATER_LIGHT
		"warning_1":
			_paddle(img, 2, 3, 8, 10)
			_torso(img, 4, 7, shirt)
			_hands(img, Vector2i(3, 7), Vector2i(3, 9))
			_head(img, 7, 7, hair)
			dots = [Vector2i(10, 5)]
			dot_colour = WATER_LIGHT
		"break":
			_paddle(img, 2, 2, 8, 9)
			_torso(img, 4, 6, shirt)
			_head_back(img, 7, 7, hair)
			_px(img, 10, 3, BEER_LID)
			_rect(img, 10, 4, 1, 2, BEER_CAN)
			_px(img, 10, 6, SKIN)
		"windup_0":
			_paddle(img, 2, 2, 8, 9)
			_torso(img, 4, 6, shirt)
			_hands(img, Vector2i(3, 6), Vector2i(3, 8))
			_head_turned(img, 6, 6, hair, -1)
		"windup_1":
			_paddle(img, 2, 3, 8, 10)
			_torso(img, 4, 6, shirt)
			_hands(img, Vector2i(3, 7), Vector2i(3, 9))
			_head_turned(img, 8, 6, hair, 1)
		"stand":
			_rect(img, 1, 1, 3, 3, WOOD_LIGHT)
			_rect(img, 3, 2, 8, 1, WOOD)
			_rect(img, 3, 5, 8, 8, shirt)
			_rect(img, 3, 12, 8, 1, shirt.darkened(0.25))
			for corner: Vector2i in [Vector2i(3, 5), Vector2i(10, 5), Vector2i(3, 12), Vector2i(10, 12)]:
				_clear(img, corner.x, corner.y)
			_hands(img, Vector2i(5, 3), Vector2i(9, 3))
			_big_head(img, 7, 7, hair)
		"paddle_dropped":
			_torso(img, 3, 6, shirt)
			_rect(img, 1, 7, 2, 1, SKIN)
			_rect(img, 1, 9, 2, 1, SKIN)
			_head(img, 6, 6, hair)
		"nodded_off":
			_paddle(img, 2, 4, 7, 10)
			_torso(img, 4, 6, shirt)
			_px(img, 3, 8, SKIN)
			_head(img, 7, 8, hair)
		"peeing":
			_rect(img, 6, 4, 5, 8, shirt)
			_rect(img, 10, 4, 1, 8, shirt.darkened(0.25))
			for corner: Vector2i in [Vector2i(6, 4), Vector2i(10, 4), Vector2i(6, 11), Vector2i(10, 11)]:
				_clear(img, corner.x, corner.y)
			_hands(img, Vector2i(4, 4), Vector2i(4, 10))
			_head_turned(img, 5, 7, hair, -1)
			dots = [Vector2i(1, 6), Vector2i(0, 7), Vector2i(0, 8)]
			dot_colour = WATER_LIGHT
		"bar_0":
			_paddle(img, 2, 2, 8, 9)
			_torso(img, 3, 6, shirt)
			_hands(img, Vector2i(3, 6), Vector2i(3, 8))
			_head(img, 5, 6, hair)
		"bar_1":
			_paddle(img, 3, 2, 8, 9)
			_torso(img, 4, 6, shirt)
			_hands(img, Vector2i(3, 6), Vector2i(3, 8))
			_head(img, 8, 6, hair)
		_:
			push_error("unknown guy frame %s" % frame)
	_outline(img, OUTLINE)
	for dot: Vector2i in dots:
		_px(img, dot.x, dot.y, dot_colour)
	var mirrored: bool = seat == Paddling.Seat.RIGHT_FRONT or seat == Paddling.Seat.RIGHT_BACK
	if mirrored:
		img.flip_x()
	if frame == "nodded_off":
		_zee(img, 0 if mirrored else 9, 1)
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


## 120×60 writing scratched in the sand on the launch shore (GDD › Presentation and Platforms,
## Input): a catamaran from above, with Q and A beside the left hull's front and back seats and I
## and K beside the right hull's, then the two lines HOLD = CHARGE and RELEASE = STROKE. Its
## grooves are 1-px darker sand with a lighter edge (_scratch); the rest is transparent, so the
## sand shows through. Its place is in lake.tscn, under the shore, so it scrolls off with it.
func _sand_text() -> Image:
	var img: Image = _new(120, 60)
	var grooves: Dictionary[Vector2i, bool] = {}
	var boat_top: int = 3
	var boat_height: int = 34
	var left_x: int = 44
	var right_x: int = 76
	var front_row: int = boat_top + 9
	var back_row: int = boat_top + 22
	for hull_x: int in [left_x, right_x]:
		# Two pointed hulls, half-width 3 at the middle, as in _catamaran().
		for row: int in boat_height:
			var half: int = mini(3, (mini(row, boat_height - 1 - row) + 1) / 2)
			_groove_px(grooves, hull_x - half, boat_top + row)
			_groove_px(grooves, hull_x + half, boat_top + row)
		# A thwart across each seat.
		for seat_row: int in [front_row, back_row]:
			for x: int in range(hull_x - 1, hull_x + 2):
				_groove_px(grooves, x, seat_row)
	# Cross-bars lashing the hulls, fore and aft of the seats.
	for bar_row: int in [boat_top + 6, boat_top + 27]:
		for x: int in range(left_x + 4, right_x - 3):
			_groove_px(grooves, x, bar_row)
	# The keys, each beside its seat: left keys on the left, right keys on the right.
	_glyph_grooves(grooves, "Q", left_x - 8, front_row - 2)
	_glyph_grooves(grooves, "A", left_x - 8, back_row - 2)
	_glyph_grooves(grooves, "I", right_x + 6, front_row - 2)
	_glyph_grooves(grooves, "K", right_x + 6, back_row - 2)
	# The two lines, centred under the boat.
	_text_grooves(grooves, "HOLD = CHARGE", 41, 60)
	_text_grooves(grooves, "RELEASE = STROKE", 50, 60)
	_scratch(img, grooves)
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


## 11×11 arrow pointing up, white so a scene can tint it (the off-screen swimmer arrows in
## scripts/ui/offscreen_arrows.gd modulate it per seat): a 7-wide head over a 3-wide shaft,
## outlined, with a 1-px clear border so the outline fits.
func _arrow() -> Image:
	var img: Image = _new(11, 11)
	for row: int in 4:
		_rect(img, 5 - row, 1 + row, 2 * row + 1, 1, SPLASH)
	_rect(img, 4, 5, 3, 5, SPLASH)
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


## A paddle held along the hull: a 1-px shaft of shaft_len from (x, shaft_y) and a 3×3 blade
## whose top row is at blade_y, ahead of the shaft when blade_y < shaft_y.
func _paddle(img: Image, x: int, shaft_y: int, shaft_len: int, blade_y: int) -> void:
	_rect(img, x - 1, blade_y, 3, 3, WOOD_LIGHT)
	_rect(img, x, shaft_y, 1, shaft_len, WOOD)


## 7×6 shoulders seen from above with the top-left corner at (x, y): a darker back row and
## rounded corners.
func _torso(img: Image, x: int, y: int, shirt: Color) -> void:
	_rect(img, x, y, 7, 6, shirt)
	_rect(img, x, y + 5, 7, 1, shirt.darkened(0.25))
	for corner: Vector2i in [Vector2i(x, y), Vector2i(x + 6, y), Vector2i(x, y + 5), Vector2i(x + 6, y + 5)]:
		_clear(img, corner.x, corner.y)


func _hands(img: Image, a: Vector2i, b: Vector2i) -> void:
	_px(img, a.x, a.y, SKIN)
	_px(img, b.x, b.y, SKIN)


## A head tilted back (drinking): the face shows, the hair only along its back edge.
func _head_back(img: Image, cx: int, cy: int, hair: Color) -> void:
	_disc(img, cx, cy, 2, SKIN)
	if hair.a > 0.0:
		_rect(img, cx - 1, cy + 2, 3, 1, hair)
		_px(img, cx - 2, cy + 1, hair)
		_px(img, cx + 2, cy + 1, hair)
	else:
		_px(img, cx, cy - 1, SKIN_LIGHT)


## A head turned to look sideways: `side` -1 looks left (the hair over the right half), +1
## right.
func _head_turned(img: Image, cx: int, cy: int, hair: Color, side: int) -> void:
	_disc(img, cx, cy, 2, SKIN)
	var back: int = -side
	if hair.a > 0.0:
		for i: int in 3:
			var half: int = 2 if i < 2 else 1
			_rect(img, cx + back * i, cy - half, 1, 2 * half + 1, hair)
		_px(img, cx - back, cy - 2, hair)
		_px(img, cx - back, cy + 2, hair)
	else:
		_px(img, cx + side, cy - 1, SKIN_LIGHT)


## A head one size up, for a guy standing closer to the camera: a radius-3 disc.
func _big_head(img: Image, cx: int, cy: int, hair: Color) -> void:
	_disc(img, cx, cy, 3, SKIN)
	if hair.a > 0.0:
		for dy: int in range(0, 4):
			var half: int = 3 if dy < 2 else (2 if dy == 2 else 1)
			_rect(img, cx - half, cy + dy, 2 * half + 1, 1, hair)
		_px(img, cx - 3, cy - 1, hair)
		_px(img, cx + 3, cy - 1, hair)
	else:
		_px(img, cx - 1, cy - 2, SKIN_LIGHT)


## A 3×3 "z" with its top-left corner at (x, y), drawn over everything (no outline).
func _zee(img: Image, x: int, y: int) -> void:
	_rect(img, x, y, 3, 1, ZEE)
	_px(img, x + 1, y + 1, ZEE)
	_rect(img, x, y + 2, 3, 1, ZEE)


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


## A groove pixel for _scratch(): recorded, not drawn yet, so each groove's lighter edge can be
## told from the grooves beside it.
static func _groove_px(grooves: Dictionary[Vector2i, bool], x: int, y: int) -> void:
	grooves[Vector2i(x, y)] = true


## Paints the grooves SAND_GROOVE, and the lighter edge of each (its bottom-right neighbour,
## unless that is a groove too) SAND_LIGHT, as if the scratch threw a little light.
static func _scratch(img: Image, grooves: Dictionary[Vector2i, bool]) -> void:
	for groove: Vector2i in grooves:
		var edge: Vector2i = groove + Vector2i(1, 1)
		if not grooves.has(edge):
			_px(img, edge.x, edge.y, SAND_LIGHT)
	for groove: Vector2i in grooves:
		_px(img, groove.x, groove.y, SAND_GROOVE)


## One line of the sand writing, centred on x = centre_x with its top at y. A glyph is 3×5 with
## 1 px before the next; a space is 2 px. Letters without a glyph are an error.
static func _text_grooves(grooves: Dictionary[Vector2i, bool], line: String, y: int, centre_x: int) -> void:
	var x: int = centre_x - _text_width(line) / 2
	for letter: String in line:
		if letter == " ":
			x += 3
		else:
			_glyph_grooves(grooves, letter, x, y)
			x += 4


## The width of a line from _text_grooves: the glyphs' and spaces' advances, less the last gap.
static func _text_width(line: String) -> int:
	var width: int = -1
	for letter: String in line:
		width += 3 if letter == " " else 4
	return width


## Draws one 3×5 glyph with its top-left corner at (x, y): each '#' in its rows is a groove.
static func _glyph_grooves(grooves: Dictionary[Vector2i, bool], letter: String, x: int, y: int) -> void:
	var rows: PackedStringArray = _glyph(letter)
	for row: int in rows.size():
		for col: int in 3:
			if rows[row][col] == "#":
				_groove_px(grooves, x + col, y + row)


## The 3×5 glyphs for the sand writing: '#' is a groove, '.' is sand. Only the letters the
## scheme needs (the keys, HOLD, CHARGE, RELEASE, STROKE), and the '=' between the two lines.
static func _glyph(letter: String) -> PackedStringArray:
	match letter:
		"A": return PackedStringArray([".#.", "#.#", "###", "#.#", "#.#"])
		"C": return PackedStringArray([".##", "#..", "#..", "#..", ".##"])
		"D": return PackedStringArray(["##.", "#.#", "#.#", "#.#", "##."])
		"E": return PackedStringArray(["###", "#..", "##.", "#..", "###"])
		"G": return PackedStringArray([".##", "#..", "#.#", "#.#", ".##"])
		"H": return PackedStringArray(["#.#", "#.#", "###", "#.#", "#.#"])
		"I": return PackedStringArray(["###", ".#.", ".#.", ".#.", "###"])
		"K": return PackedStringArray(["#.#", "#.#", "##.", "#.#", "#.#"])
		"L": return PackedStringArray(["#..", "#..", "#..", "#..", "###"])
		"O": return PackedStringArray(["###", "#.#", "#.#", "#.#", "###"])
		"Q": return PackedStringArray(["###", "#.#", "#.#", "###", "..#"])
		"R": return PackedStringArray(["##.", "#.#", "##.", "#.#", "#.#"])
		"S": return PackedStringArray(["###", "#..", "###", "..#", "###"])
		"T": return PackedStringArray(["###", ".#.", ".#.", ".#.", ".#."])
		"=": return PackedStringArray(["...", "###", "...", "###", "..."])
		_:
			push_error("no sand glyph for '%s'" % letter)
			return PackedStringArray()


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


## Writes the sprite to OUT_DIR (or its `sub_dir`) and, with --preview, an 8× copy.
func _save(img: Image, sprite_name: String, sub_dir: String = "") -> void:
	var path: String = OUT_DIR.path_join(sub_dir).path_join(sprite_name + ".png")
	var err: Error = img.save_png(path)
	print("%s %s (%d×%d)" % ["wrote" if err == OK else "FAILED", path, img.get_width(), img.get_height()])
	if not _preview_dir.is_empty():
		var big: Image = img.duplicate() as Image
		big.resize(img.get_width() * PREVIEW_SCALE, img.get_height() * PREVIEW_SCALE, Image.INTERPOLATE_NEAREST)
		big.save_png(_preview_dir.path_join(sprite_name + "_x%d.png" % PREVIEW_SCALE))
