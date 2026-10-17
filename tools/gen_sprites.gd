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
const BEAST: Color = Color8(46, 112, 78)
const BEAST_LIGHT: Color = Color8(92, 164, 108)
const BEAST_DARK: Color = Color8(28, 74, 56)
const BEAST_EYE: Color = Color8(250, 220, 60)
const BEAST_MOUTH: Color = Color8(204, 60, 84)
const ROCK: Color = Color8(122, 124, 136)
const ROCK_LIGHT: Color = Color8(178, 182, 194)
const ROCK_DARK: Color = Color8(76, 78, 92)
const GOOSE: Color = Color8(246, 246, 250)
const GOOSE_DARK: Color = Color8(186, 188, 200)
const GOOSE_BEAK: Color = Color8(250, 122, 40)
const GOSLING: Color = Color8(250, 222, 72)
const NEST: Color = Color8(164, 128, 64)
const NEST_LIGHT: Color = Color8(214, 180, 104)
const MOTOR: Color = Color8(58, 58, 72)
const JETSKI: Color = Color8(252, 202, 36)
const JETSKI_DARK: Color = Color8(214, 150, 24)
const RIDER: Color = Color8(232, 68, 52)
const FISHER: Color = Color8(62, 122, 204)
const FLOAT_RED: Color = Color8(232, 52, 52)
## The touch pad's translucency (T54): its body, its arrow hints and its outline.
const PAD_ALPHA: float = 0.35
const PAD_HINT_ALPHA: float = 0.9
const PAD_OUTLINE_ALPHA: float = 0.6

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
	"windup_1", "stand", "paddle_dropped", "nodded_off", "peeing", "puke_0", "puke_1", "bar_0",
	"bar_1",
]
const ZEE: Color = Color8(217, 230, 255)
## The splash of a guy puking over the side (T63).
const PUKE: Color = Color8(150, 210, 70)

## The hazard telegraph frames (T24): PNGs in assets/sprites/hazards/, drawn by the _rock() to
## _beast_ripple() functions below; the hazard scenes (scenes/hazards/*.tscn and their scripts in
## scripts/hazards/) load them by name, so the names are their contract.
const HAZARDS_DIR: String = "hazards"

var _preview_dir: String = ""


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in args.size():
		if args[i] == "--preview" and i + 1 < args.size():
			_preview_dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(OUT_DIR.path_join(GUYS_DIR))
	DirAccess.make_dir_recursive_absolute(OUT_DIR.path_join(HAZARDS_DIR))
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
	_save(_pad(), "pad")
	_save(_reset(), "reset")
	for frame: int in 2:
		_save(_beast_fin(frame), "beast_fin_%d" % frame)
		_save(_beast_head(frame), "beast_head_%d" % frame)
	_save(_rock(), "rock", HAZARDS_DIR)
	_save(_goslings(), "goslings", HAZARDS_DIR)
	_save(_goose_calm(), "goose_calm", HAZARDS_DIR)
	_save(_motorboat(), "motorboat", HAZARDS_DIR)
	_save(_dinghy(), "dinghy", HAZARDS_DIR)
	_save(_gust_streak(), "gust_streak", HAZARDS_DIR)
	for frame: int in 2:
		_save(_goose_hiss(frame), "goose_hiss_%d" % frame, HAZARDS_DIR)
		_save(_goose_fly(frame), "goose_fly_%d" % frame, HAZARDS_DIR)
		_save(_motorboat_spray(frame), "motorboat_spray_%d" % frame, HAZARDS_DIR)
		_save(_wake_crest(frame), "wake_crest_%d" % frame, HAZARDS_DIR)
		_save(_whitecap(frame), "whitecap_%d" % frame, HAZARDS_DIR)
		_save(_current_arrow(frame), "current_arrow_%d" % frame, HAZARDS_DIR)
		_save(_jetski(frame), "jetski_%d" % frame, HAZARDS_DIR)
		_save(_float(frame), "float_%d" % frame, HAZARDS_DIR)
		_save(_beast_ripple(frame), "beast_ripple_%d" % frame, HAZARDS_DIR)
	for frame: int in 3:
		_save(_gust_ripple(frame), "gust_ripple_%d" % frame, HAZARDS_DIR)
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
##   puke_0/1 (leaning out over the hull's edge, paddle laid inboard, a green splash that
##   alternates; T63) · bar_0/1 (swaying with the paddle, head lolling).
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
		"puke_0", "puke_1":
			# Leaning out over the water side: the paddle laid inboard, the torso shifted to the
			# edge, both hands on the gunwale, the head out past it and heaving on the second frame.
			var heave: int = 1 if frame == "puke_1" else 0
			_paddle(img, 10, 2, 8, 9)
			_torso(img, 2, 6, shirt)
			_hands(img, Vector2i(1, 7), Vector2i(1, 10))
			_head_turned(img, 3, 7 + heave, hair, -1)
			if heave == 0:
				dots = [Vector2i(0, 9)]
			else:
				dots = [Vector2i(0, 10), Vector2i(1, 12), Vector2i(0, 12)]
			dot_colour = PUKE
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
## Input): a catamaran from above with its eight keys, two beside each seat, the forward key with
## an up arrow over the reverse key with a down arrow (Q↑ A↓ and W↑ S↓ beside the left hull's
## front and back seats, I↑ K↓ and O↑ L↓ beside the right hull's), then the two lines
## HOLD = CHARGE and UP FWD · DOWN BACK. Its grooves are 1-px darker sand with a lighter edge
## (_scratch); the rest is transparent, so the sand shows through. Its place is in lake.tscn,
## under the shore, so it scrolls off with it.
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
	# The keys beside each seat, the forward one above its thwart and the reverse one below:
	# left keys left of the left hull, right keys right of the right hull.
	var seat_keys: Dictionary[Vector2i, String] = {
		Vector2i(left_x - 12, front_row): "WS", Vector2i(left_x - 12, back_row): "QA",
		Vector2i(right_x + 6, front_row): "IK", Vector2i(right_x + 6, back_row): "OL",
	}
	for at: Vector2i in seat_keys:
		_text_grooves(grooves, seat_keys[at][0] + "↑", at.y - 5, at.x + 3)
		_text_grooves(grooves, seat_keys[at][1] + "↓", at.y + 1, at.x + 3)
	# The two lines, centred under the boat.
	_text_grooves(grooves, "HOLD = CHARGE", 41, 60)
	_text_grooves(grooves, "UP FWD · DOWN BACK", 50, 60)
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


## 16×16 the beast's fin cutting the water, pointing up (scenes/hazards/beast.gd turns it the
## way it goes), two frames: a dark green fin swept back, with a lighter leading edge, inside a
## broken ripple ring that widens on the second frame. The fin is outlined; the ripple is not.
func _beast_fin(frame: int) -> Image:
	var img: Image = _new(16, 16)
	var lean: int = frame
	# The fin: a tall triangle swept back toward the bottom right.
	for row: int in 8:
		var y: int = 3 + row
		var left: int = 8 - (row + 1) / 2 + lean * (row / 4)
		var right: int = 8 + (row + 1) / 3 + lean * (row / 3)
		_rect(img, left, y, right - left + 1, 1, BEAST_DARK)
		_px(img, left, y, BEAST_LIGHT)
	_outline(img, OUTLINE)
	_ring(img, 8, 8, 6 + frame, WATER_LIGHT)
	return img


## 24×16 the beast's head surfaced and charging, seen from above and pointing up: a dark green
## serpent head with a lighter spine, two yellow eyes and nostrils on the snout, a white bow
## wave either side. On the second frame the jaws are open (a red mouth with teeth) and the
## eyes narrowed.
func _beast_head(frame: int) -> Image:
	var img: Image = _new(24, 16)
	_ellipse(img, 12, 10, 8, 5, BEAST)
	_ellipse(img, 12, 5, 5, 4, BEAST)
	_rect(img, 12, 3, 1, 11, BEAST_LIGHT)
	for scale: Vector2i in [Vector2i(8, 11), Vector2i(16, 11), Vector2i(7, 13), Vector2i(17, 13),
			Vector2i(10, 14), Vector2i(14, 14)]:
		_px(img, scale.x, scale.y, BEAST_LIGHT)
	_px(img, 10, 2, OUTLINE)
	_px(img, 14, 2, OUTLINE)
	if frame == 0:
		_rect(img, 8, 6, 2, 2, BEAST_EYE)
		_rect(img, 14, 6, 2, 2, BEAST_EYE)
		_px(img, 9, 7, OUTLINE)
		_px(img, 14, 7, OUTLINE)
	else:
		_rect(img, 8, 7, 2, 1, BEAST_EYE)
		_rect(img, 14, 7, 2, 1, BEAST_EYE)
		_rect(img, 9, 1, 6, 2, BEAST_MOUTH)
		_px(img, 10, 1, SPLASH)
		_px(img, 13, 1, SPLASH)
	_outline(img, OUTLINE)
	for splash: Vector2i in [Vector2i(2, 7 + frame), Vector2i(1, 10), Vector2i(21, 7 + frame),
			Vector2i(22, 10), Vector2i(3, 14), Vector2i(20, 14)]:
		_px(img, splash.x, splash.y, SPLASH)
	return img


# --- hazard telegraphs (T24, assets/sprites/hazards/) ------------------------------------------

## 20×16 a rock: a grey boulder with a lighter hump, a crack, a dark waterline, and foam where
## the water breaks on it. Static: it is visible from far off, that is its telegraph.
func _rock() -> Image:
	var img: Image = _new(20, 16)
	_ellipse(img, 10, 9, 8, 5, ROCK)
	_ellipse(img, 9, 6, 5, 3, ROCK)
	_ellipse(img, 8, 5, 3, 1, ROCK_LIGHT)
	_rect(img, 4, 13, 12, 1, ROCK_DARK)
	for crack: Vector2i in [Vector2i(12, 8), Vector2i(13, 9), Vector2i(13, 10), Vector2i(14, 11)]:
		_px(img, crack.x, crack.y, ROCK_DARK)
	_outline(img, OUTLINE)
	for foam: Vector2i in [Vector2i(0, 8), Vector2i(1, 11), Vector2i(19, 7), Vector2i(18, 12),
			Vector2i(5, 15), Vector2i(15, 15)]:
		_px(img, foam.x, foam.y, SPLASH)
	return img


## 24×16 the geese's nest: a ring of reeds with three goslings in it, each a yellow fluff with
## a beak and an eye, looking different ways.
func _goslings() -> Image:
	var img: Image = _new(24, 16)
	_ellipse(img, 12, 8, 11, 7, NEST)
	for reed: int in 12:
		var angle: float = TAU * float(reed) / 12.0
		_px(img, 12 + roundi(cos(angle) * 9.5), 8 + roundi(sin(angle) * 5.5), NEST_LIGHT)
	_ellipse(img, 12, 8, 7, 4, NEST_LIGHT)
	for gosling: Vector3i in [Vector3i(7, 9, -1), Vector3i(12, 6, 0), Vector3i(17, 9, 1)]:
		_disc(img, gosling.x, gosling.y, 1, GOSLING)
		_px(img, gosling.x + gosling.z, gosling.y - 2, GOOSE_BEAK)
		_px(img, gosling.x - gosling.z, gosling.y - 1, OUTLINE)
	_outline(img, OUTLINE)
	return img


## A goose's body, neck and head pointing up, centred on x = cx with the body's centre at
## (cx, body_y) and `neck` pixels of neck: the wings and the beak are the frames' business.
func _goose_body(img: Image, cx: int, body_y: int, neck: int) -> void:
	_ellipse(img, cx, body_y, 3, 3, GOOSE)
	_px(img, cx, body_y + 3, GOOSE_DARK)
	_rect(img, cx, body_y - 3 - neck, 1, neck + 1, GOOSE)
	_disc(img, cx, body_y - 4 - neck, 1, GOOSE)
	_px(img, cx - 1, body_y - 4 - neck, OUTLINE)
	_px(img, cx + 1, body_y - 4 - neck, OUTLINE)


## 12×12 a goose on the nest, calm: wings folded along its sides, neck tucked, beak closed.
func _goose_calm() -> Image:
	var img: Image = _new(12, 12)
	_goose_body(img, 6, 8, 1)
	_rect(img, 3, 7, 1, 3, GOOSE_DARK)
	_rect(img, 9, 7, 1, 3, GOOSE_DARK)
	_px(img, 6, 1, GOOSE_BEAK)
	_outline(img, OUTLINE)
	return img


## 16×14 a goose hissing: wings raised out and up, neck stretched, beak open wide. Two frames:
## the wings lift higher on the second and the beak gapes wider.
func _goose_hiss(frame: int) -> Image:
	var img: Image = _new(16, 14)
	_goose_body(img, 8, 10, 2)
	var tip_y: int = 5 - frame * 2
	for side: int in [-1, 1]:
		var root: Vector2i = Vector2i(8 + side * 3, 10)
		var tip: Vector2i = Vector2i(8 + side * 7, tip_y)
		_line(img, root, tip, GOOSE)
		_line(img, root + Vector2i(0, 1), tip + Vector2i(0, 1), GOOSE)
		_px(img, tip.x, tip.y + 1, GOOSE_DARK)
	if frame == 0:
		_rect(img, 8, 0, 1, 2, GOOSE_BEAK)
	else:
		_rect(img, 7, 0, 3, 1, GOOSE_BEAK)
		_px(img, 8, 1, GOOSE_BEAK)
	_outline(img, OUTLINE)
	return img


## 16×14 a goose flying: wings spread straight out on the first frame, swept back on the
## second, feet trailing, neck out, beak closed.
func _goose_fly(frame: int) -> Image:
	var img: Image = _new(16, 14)
	_goose_body(img, 8, 9, 2)
	_px(img, 8, 2, GOOSE_BEAK)
	for side: int in [-1, 1]:
		var root: Vector2i = Vector2i(8 + side * 3, 9)
		var tip: Vector2i = Vector2i(8 + side * 7, 8 if frame == 0 else 12)
		_line(img, root, tip, GOOSE)
		_line(img, root + Vector2i(0, 1), tip + Vector2i(0, 1), GOOSE)
		_px(img, tip.x, tip.y + 1, GOOSE_DARK)
		_px(img, tip.x - side, tip.y + 1, GOOSE_DARK)
	_px(img, 7, 13, GOOSE_BEAK)
	_px(img, 9, 13, GOOSE_BEAK)
	_outline(img, OUTLINE)
	return img


## 41×64 the motorboat pointing up, at the catamaran's scale (T61, GDD › Presentation and
## Platforms: other boats at least as large as the catamaran): a white speedboat hull with a
## pointed bow and a 29-px beam, a hatch on the foredeck, a red stripe down each side, a
## windscreen across the deck with the driver at the wheel behind it, a passenger with a beer on
## the rear bench, an outboard on the transom, and a white bow wave peeling off either side of
## the bow (drawn over the outline, as spray is). The hull is centred on x 20.
func _motorboat() -> Image:
	var img: Image = _new(41, 64)
	var cx: int = 20
	for y: int in range(1, 60):
		var half: int = _motorboat_half(y)
		_rect(img, cx - half, y, 2 * half + 1, 1, HULL_LIGHT)
		# The red stripe, one pixel in from the hull's edge once the bow has widened.
		if y >= 14 and y <= 56:
			_rect(img, cx - half + 1, y, 2, 1, COOLER)
			_rect(img, cx + half - 2, y, 2, 1, COOLER)
	# The foredeck hatch.
	_rect(img, cx - 3, 14, 7, 7, HULL_DARK)
	_rect(img, cx - 2, 15, 5, 5, HULL)
	# The windscreen: a dark frame, two rows of glass, the dash under it.
	_rect(img, cx - 10, 24, 21, 4, HULL_DARK)
	_rect(img, cx - 9, 25, 19, 2, WATER_LIGHT)
	# The cockpit well, the wheel and the rear bench.
	_rect(img, cx - 10, 28, 21, 29, HULL_FLOOR)
	_disc(img, cx - 5, 30, 2, OUTLINE)
	_disc(img, cx - 5, 30, 1, HULL_FLOOR)
	_rect(img, cx - 9, 47, 19, 4, HULL_DARK)
	# The driver at the wheel, hands on it; the passenger on the bench with a beer.
	_hands(img, Vector2i(cx - 7, 31), Vector2i(cx - 3, 31))
	_seated(img, cx - 5, 34, GOOSE, HAIRS[0], HULL_FLOOR)
	_hands(img, Vector2i(cx + 1, 45), Vector2i(cx + 9, 45))
	_rect(img, cx + 9, 43, 2, 2, BEER_CAN)
	_seated(img, cx + 5, 45, TENT_LIGHT, HAIRS[3], HULL_FLOOR)
	# The outboard on the transom.
	_rect(img, cx - 3, 58, 7, 5, MOTOR)
	_rect(img, cx - 2, 58, 5, 1, HULL_DARK)
	_outline(img, OUTLINE)
	# The bow wave: a white line peeling off each side of the bow, light water between it and
	# the hull, trailing off in drops down the sides.
	for y: int in range(3, 25):
		var gap: int = (y - 3) / 5
		var colour: Color = SPLASH if y % 4 != 3 else WATER_LIGHT
		var left: int = cx - _motorboat_half(y) - 2 - gap
		var right: int = cx + _motorboat_half(y) + 2 + gap
		_px(img, left, y, colour)
		_px(img, right, y, colour)
		if gap >= 1:
			_px(img, left + 1, y, WATER_LIGHT)
			_px(img, right - 1, y, WATER_LIGHT)
	for drop: Vector2i in [Vector2i(0, 27), Vector2i(40, 27), Vector2i(1, 31), Vector2i(39, 31)]:
		_px(img, drop.x, drop.y, WATER_LIGHT)
	return img


## The motorboat hull's half-width on row y: 0 at the bow tip, widening two pixels every three
## rows to 14, and tucked in over the last three rows for the transom.
static func _motorboat_half(y: int) -> int:
	if y > 56:
		return 14 - (y - 56)
	return mini(14, (y - 1) * 2 / 3)


## A guy seated facing up, for the boats' crews: his 7×6 torso with its top at (cx - 3, cy)
## and his head at (cx, cy), the torso's corners left in the deck's `floor` colour rather than
## cleared, so no hole opens in the boat.
func _seated(img: Image, cx: int, cy: int, shirt: Color, hair: Color, floor: Color) -> void:
	_torso(img, cx - 3, cy, shirt)
	for corner: Vector2i in [Vector2i(cx - 3, cy), Vector2i(cx + 3, cy), Vector2i(cx - 3, cy + 5),
			Vector2i(cx + 3, cy + 5)]:
		_px(img, corner.x, corner.y, floor)
	_head(img, cx, cy, hair)


## 40×32 the motorboat's wake trail, placed astern (wake.tscn puts its top row on the hull's
## last): two white spray lines fanning out from the propeller, a short rooster tail between
## them and foam near the stern; the gaps in the lines move on the second frame.
func _motorboat_spray(frame: int) -> Image:
	var img: Image = _new(40, 32)
	for row: int in 32:
		var spread: int = 3 + row * 15 / 31
		var colour: Color = SPLASH if (row + frame) % 3 != 2 else WATER_LIGHT
		_rect(img, 19 - spread - 1, row, 2, 1, colour)
		_rect(img, 20 + spread, row, 2, 1, colour)
	# The rooster tail straight behind the propeller, a row taller on the second frame.
	_rect(img, 19, 0, 2, 6 + frame, SPLASH)
	_rect(img, 18, 0, 1, 3, WATER_LIGHT)
	_rect(img, 21, 0, 1, 3, WATER_LIGHT)
	for foam: Vector2i in [Vector2i(16, 4 + frame), Vector2i(23, 7 - frame), Vector2i(14, 10 + frame),
			Vector2i(25, 12), Vector2i(12, 16 - frame), Vector2i(27, 18 + frame), Vector2i(10, 22),
			Vector2i(29, 24 - frame)]:
		_px(img, foam.x, foam.y, WATER_LIGHT)
	return img


## 32×8 one tile of the wake's wave front, repeated across the lake: a lighter band with a
## white crest that rolls (its steps swap on the second frame) over a dark trough.
func _wake_crest(frame: int) -> Image:
	var img: Image = _new(32, 8)
	_rect(img, 0, 2, 32, 4, WATER_LIGHT)
	for x: int in 32:
		var crest_y: int = 1 + (x / 4 + frame) % 2
		_rect(img, x, crest_y, 1, 2, SPLASH)
		if (x + frame * 3) % 5 != 4:
			_px(img, x, 6, WATER_DEEP)
	return img


## 32×16 one tile of whitecaps, repeated over the harsh-wind stretch: three small waves, each a
## light crest with white foam on top; the foam shifts and spits a drop on the second frame.
func _whitecap(frame: int) -> Image:
	var img: Image = _new(32, 16)
	for cap: Vector2i in [Vector2i(3, 2), Vector2i(19, 5), Vector2i(11, 11)]:
		_rect(img, cap.x, cap.y + 1, 6, 1, WATER_LIGHT)
		_rect(img, cap.x + 1 + frame, cap.y, 3, 1, SPLASH)
		if frame == 1:
			_px(img, cap.x + 5, cap.y - 1, SPLASH)
	return img


## 32×16 one tile of the cross-current's faster water, repeated over the stripe: an arrow
## pointing right (the scene flips it for a leftward stripe) with streaks before and after it,
## all shifted along on the second frame so the water reads as moving.
func _current_arrow(frame: int) -> Image:
	var img: Image = _new(32, 16)
	var shaft_x: int = 6 + frame * 2
	_rect(img, shaft_x, 7, 10, 2, WATER_LIGHT)
	_rect(img, shaft_x + 10, 5, 1, 6, WATER_LIGHT)
	_rect(img, shaft_x + 11, 6, 1, 4, WATER_LIGHT)
	_rect(img, shaft_x + 12, 7, 1, 2, WATER_LIGHT)
	_rect(img, 22 + frame * 2, 2, 5, 1, WATER_SHALLOW)
	_rect(img, frame * 2, 13, 5, 1, WATER_SHALLOW)
	return img


## 36×20 the jet-ski pointing right, at the catamaran's scale (T61): a yellow hull 29 px long
## with a pointed nose, a dark stripe on the nose and a dark skirt along its lower side, a grey
## seat with the rider on it in a red vest, arms out to the handlebars across the deck, the jet's
## white wash and spray thrown off the tail and the bow; the spray dances between the two
## frames. Centred on row 10; the scene turns it along its course.
func _jetski(frame: int) -> Image:
	var img: Image = _new(36, 20)
	var cy: int = 10
	for x: int in range(7, 36):
		# Half-height 5 along the body, narrowing to a point over the nose's last ten columns.
		var half: int = mini(5, (35 - x) / 2)
		_rect(img, x, cy - half, 1, 2 * half + 1, JETSKI)
		if half >= 2:
			_rect(img, x, cy + half - 1, 1, 2, JETSKI_DARK)
	# The tail's corners rounded, the jet's outlet in it.
	_clear(img, 7, cy - 5)
	_clear(img, 7, cy + 5)
	_rect(img, 7, cy - 1, 2, 3, MOTOR)
	# The nose stripe, the seat, the handlebars.
	_rect(img, 24, cy - 1, 8, 2, JETSKI_DARK)
	_rect(img, 9, cy - 2, 12, 5, HULL_DARK)
	_rect(img, 22, cy - 4, 1, 9, HULL_DARK)
	# The rider: vest, arms forward to the grips, head looking ahead.
	_rounded_rect(img, 10, cy - 3, 7, 7, 2, RIDER)
	_rect(img, 17, cy - 2, 5, 1, SKIN)
	_rect(img, 17, cy + 2, 5, 1, SKIN)
	_head_turned(img, 15, cy, HAIRS[0], 1)
	_outline(img, OUTLINE)
	# The jet's wash straight out of the outlet, longer on the second frame, and the drops.
	_rect(img, 2 - frame, cy - 1, 4 + frame, 3, SPLASH)
	_px(img, 1 - frame, cy, WATER_LIGHT)
	var spray: Array[Array] = [
		[Vector2i(5, 2), Vector2i(2, 4), Vector2i(0, 6), Vector2i(4, 14), Vector2i(1, 16),
			Vector2i(6, 18), Vector2i(32, 6), Vector2i(32, 14)],
		[Vector2i(3, 1), Vector2i(0, 3), Vector2i(4, 6), Vector2i(1, 13), Vector2i(5, 15),
			Vector2i(2, 18), Vector2i(30, 5), Vector2i(30, 15)],
	]
	for drop: Vector2i in spray[frame]:
		_px(img, drop.x, drop.y, SPLASH)
	return img


## 44×30 the fisherman's dinghy, at the catamaran's scale (T61): a wooden rowing boat 40 px
## long lying across the image, bow to the right and transom to the left, with a light gunwale,
## three thwarts, the oars shipped along the sides and a red tackle box aft; the fisherman in
## blue sits on the middle thwart under a bucket hat looking right, and his rod reaches out
## past the bow to the top-right corner, its tip at pixel (42, 4), where the scene's Line2D
## takes over (ROD_TIP in scripts/hazards/fishing_line.gd; the scene flips it when the line runs
## left). The hull is centred on row 19.
func _dinghy() -> Image:
	var img: Image = _new(44, 30)
	var cy: int = 19
	for x: int in range(2, 42):
		# Half-height 5 at the transom, 7 along the body, narrowing to a point over the bow's
		# last twelve columns.
		var half: int = mini(7, mini(5 + (x - 2) / 2, (41 - x) * 7 / 12))
		_rect(img, x, cy - half, 1, 2 * half + 1, WOOD)
		_px(img, x, cy - half, WOOD_LIGHT)
		_px(img, x, cy + half, WOOD_LIGHT)
	# The thwarts, the shipped oars (shafts along the sides, blades aft) and the tackle box.
	for x: int in [9, 20]:
		_rect(img, x, cy - 6, 3, 13, WOOD_LIGHT)
	_rect(img, 33, cy - 4, 2, 9, WOOD_LIGHT)
	_rect(img, 8, cy - 5, 24, 1, WOOD_DARK)
	_rect(img, 8, cy + 5, 24, 1, WOOD_DARK)
	_rect(img, 4, cy - 6, 5, 3, WOOD_DARK)
	_rect(img, 4, cy + 4, 5, 3, WOOD_DARK)
	_rect(img, 13, cy - 2, 5, 4, COOLER)
	_rect(img, 13, cy - 2, 5, 1, COOLER_LID)
	# The fisherman: his back to the transom, arms out to the rod, the hat over his head.
	_rounded_rect(img, 19, cy - 3, 6, 7, 2, FISHER)
	_rect(img, 25, cy - 2, 4, 1, SKIN)
	_rect(img, 25, cy + 2, 4, 1, SKIN)
	_line(img, Vector2i(27, cy), Vector2i(42, 4), WOOD_LIGHT)
	_disc(img, 24, cy, 3, NEST)
	_disc(img, 24, cy, 2, NEST_LIGHT)
	_outline(img, OUTLINE)
	return img


## 7×8 the float at the line's tip: red over white, bobbing: on the second frame it sits one
## pixel lower with a ripple either side.
func _float(frame: int) -> Image:
	var img: Image = _new(7, 8)
	_rect(img, 2, 1 + frame, 3, 2, FLOAT_RED)
	_rect(img, 2, 3 + frame, 3, 2, SPLASH)
	_outline(img, OUTLINE)
	if frame == 1:
		_px(img, 0, 5, WATER_LIGHT)
		_px(img, 6, 5, WATER_LIGHT)
	return img


## 16×8 one ripple arc of a gust's warning, convex toward the right (the scene flips it for a
## leftward wind): three frames, the arc filling out and whitening as it races.
func _gust_ripple(frame: int) -> Image:
	var img: Image = _new(16, 8)
	var bulge: Array[int] = [0, 2, 3, 4, 4, 3, 2, 0]
	for row: int in 8:
		var x: int = 5 + bulge[row] * (frame + 1) / 3 + frame
		_px(img, x, row, WATER_LIGHT if frame == 0 else SPLASH)
		if frame >= 1:
			_px(img, x - 1, row, WATER_LIGHT)
		if frame == 2 and row > 1 and row < 6:
			_px(img, x - 3, row, WATER_LIGHT)
	return img


## 18×4 a streak of wind over the water while the gust blows: white over a lighter line, both
## tapered. The scene leans it.
func _gust_streak() -> Image:
	var img: Image = _new(18, 4)
	_rect(img, 1, 1, 16, 1, SPLASH)
	_rect(img, 3, 2, 12, 1, WATER_LIGHT)
	_px(img, 0, 1, WATER_LIGHT)
	_px(img, 17, 1, WATER_LIGHT)
	return img


## 24×24 the ripple rings under the beast's fin while it circles: two broken rings that widen
## on the second frame.
func _beast_ripple(frame: int) -> Image:
	var img: Image = _new(24, 24)
	_ring(img, 12, 12, 7 + frame, WATER_LIGHT)
	_ring(img, 12, 12, 10 + frame, WATER_LIGHT)
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


## 36×52 touch pad (T54): a translucent rounded rectangle, white so scripts/ui/touch_pads.gd
## tints it per seat, with the hints of the touch scheme (GDD › Presentation and Platforms):
## an up arrow near the top (release strokes forward) and a down arrow near the bottom (a flick
## down strokes in reverse), both brighter than the pad, in a soft outline.
func _pad() -> Image:
	var img: Image = _new(36, 52)
	_rounded_rect(img, 1, 1, 34, 50, 6, Color(SPLASH, PAD_ALPHA))
	_arrow_glyph(img, 17, 7, 1, Color(SPLASH, PAD_HINT_ALPHA))
	_arrow_glyph(img, 17, 44, -1, Color(SPLASH, PAD_HINT_ALPHA))
	_outline(img, Color(OUTLINE, PAD_OUTLINE_ALPHA))
	return img


## 20×20 reset icon (T62, scripts/ui/reset_button.gd): a translucent white disc like the pad's
## body, with a circular arrow over it in the pad's hint white: a 2-px ring open at the top
## right and an arrowhead at the top pointing clockwise, in the pad's soft outline. White so
## the button can tint it.
func _reset() -> Image:
	var img: Image = _new(20, 20)
	var centre: Vector2 = Vector2(9.5, 9.5)
	for y: int in 20:
		for x: int in 20:
			var offset: Vector2 = Vector2(x, y) - centre
			var distance: float = offset.length()
			if distance <= 9.0:
				_px(img, x, y, Color(SPLASH, PAD_ALPHA))
			var in_gap: bool = offset.y < 0.0 and offset.x > 0.0
			if distance >= 5.5 and distance <= 7.5 and not in_gap:
				_px(img, x, y, Color(SPLASH, PAD_HINT_ALPHA))
	# The arrowhead: a triangle pointing right, its base on the ring's top end and its tip 4 px on.
	for column: int in 4:
		var half: int = 3 - column
		_rect(img, 10 + column, 3 - half, 1, 2 * half + 1, Color(SPLASH, PAD_HINT_ALPHA))
	_outline(img, Color(OUTLINE, PAD_OUTLINE_ALPHA))
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


## A rectangle with its corners rounded by `radius` (the corner pixels inside a disc of that
## radius, as _disc draws them).
static func _rounded_rect(img: Image, x: int, y: int, width: int, height: int, radius: int, colour: Color) -> void:
	for yy: int in range(y, y + height):
		for xx: int in range(x, x + width):
			var dx: int = maxi(maxi(x + radius - xx, xx - (x + width - 1 - radius)), 0)
			var dy: int = maxi(maxi(y + radius - yy, yy - (y + height - 1 - radius)), 0)
			if dx * dx + dy * dy <= radius * radius + radius:
				_px(img, xx, yy, colour)


## An arrow 7 wide and 9 tall with its tip at (cx, tip_y), pointing up for direction 1 (the
## rest of it below the tip) and down for -1: a 4-row head over a 3-wide shaft, as _arrow().
static func _arrow_glyph(img: Image, cx: int, tip_y: int, direction: int, colour: Color) -> void:
	for row: int in 4:
		_rect(img, cx - row, tip_y + row * direction, 2 * row + 1, 1, colour)
	var shaft_top: int = tip_y + 4 if direction > 0 else tip_y - 8
	_rect(img, cx - 1, shaft_top, 3, 5, colour)


static func _disc(img: Image, cx: int, cy: int, radius: int, colour: Color) -> void:
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			if dx * dx + dy * dy <= radius * radius + radius:
				_px(img, cx + dx, cy + dy, colour)


## A broken ring of radius `radius` around (cx, cy): 24 points round the circle, every third
## left out, so it reads as ripples rather than a solid circle. Drawn over whatever is there.
static func _ring(img: Image, cx: int, cy: int, radius: int, colour: Color) -> void:
	for i: int in 24:
		if i % 3 == 2:
			continue
		var angle: float = TAU * float(i) / 24.0
		_px(img, cx + roundi(cos(angle) * radius), cy + roundi(sin(angle) * radius), colour)


## A 1-px line from a to b, every step along the longer axis one pixel.
static func _line(img: Image, a: Vector2i, b: Vector2i, colour: Color) -> void:
	var steps: int = maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i: int in steps + 1:
		var t: float = float(i) / maxf(float(steps), 1.0)
		_px(img, roundi(lerpf(float(a.x), float(b.x), t)), roundi(lerpf(float(a.y), float(b.y), t)), colour)


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
## scheme needs (the eight keys, HOLD, CHARGE, UP, FWD, DOWN, BACK), the up and down arrows
## beside the keys, and the '=' and '·' in the two lines.
static func _glyph(letter: String) -> PackedStringArray:
	match letter:
		"A": return PackedStringArray([".#.", "#.#", "###", "#.#", "#.#"])
		"B": return PackedStringArray(["##.", "#.#", "##.", "#.#", "##."])
		"C": return PackedStringArray([".##", "#..", "#..", "#..", ".##"])
		"D": return PackedStringArray(["##.", "#.#", "#.#", "#.#", "##."])
		"E": return PackedStringArray(["###", "#..", "##.", "#..", "###"])
		"F": return PackedStringArray(["###", "#..", "##.", "#..", "#.."])
		"G": return PackedStringArray([".##", "#..", "#.#", "#.#", ".##"])
		"H": return PackedStringArray(["#.#", "#.#", "###", "#.#", "#.#"])
		"I": return PackedStringArray(["###", ".#.", ".#.", ".#.", "###"])
		"K": return PackedStringArray(["#.#", "#.#", "##.", "#.#", "#.#"])
		"L": return PackedStringArray(["#..", "#..", "#..", "#..", "###"])
		"N": return PackedStringArray(["##.", "#.#", "#.#", "#.#", "#.#"])
		"O": return PackedStringArray(["###", "#.#", "#.#", "#.#", "###"])
		"P": return PackedStringArray(["##.", "#.#", "##.", "#..", "#.."])
		"Q": return PackedStringArray(["###", "#.#", "#.#", "###", "..#"])
		"R": return PackedStringArray(["##.", "#.#", "##.", "#.#", "#.#"])
		"S": return PackedStringArray(["###", "#..", "###", "..#", "###"])
		"U": return PackedStringArray(["#.#", "#.#", "#.#", "#.#", "###"])
		"W": return PackedStringArray(["#.#", "#.#", "#.#", "###", "#.#"])
		"↑": return PackedStringArray([".#.", "###", ".#.", ".#.", ".#."])
		"↓": return PackedStringArray([".#.", ".#.", ".#.", "###", ".#."])
		"=": return PackedStringArray(["...", "###", "...", "###", "..."])
		"·": return PackedStringArray(["...", "...", ".#.", "...", "..."])
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
