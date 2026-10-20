class_name WinCutscene
extends Node2D
## WinCutscene · the win (GDD › Win and Loss): the boat has reached the island with at least one
## guy aboard, so the guys aboard step onto the island, make camp and drink more, and the crossing
## ends there. Anyone left in the water (RunState.left_behind, T97) does not appear: the title says
## how many made it and names each of the left-behind with a dark joke. The lake puts this scene at the island's position when RunState's phase becomes WON
## and calls begin(); it tears the scene down when the player goes again. Scripted with Tweens,
## no physics and no rules: it reads RunState.elapsed for the title and emits `again` on a key
## once the title is up (the lake starts the new attempt).
##
## Timeline: the camera eases from the boat onto the island; the boys (their seats' shirt
## colours, from tools/gen_sprites.gd) hop off the hulls one by one onto the beach on the boat's
## side and waddle up to the clearing; once all four are there the tent pops up beside the fire
## pit, the fire lights (two frames flickering), they sit round it with beers rising to their
## faces in a loop, and the title with the crossing time, the crew's names (T68) and "Press any
## key to go again" fades in on the Title layer. Spots on the island are island.png pixels from its centre (see
## _island in tools/gen_sprites.gd), scaled by the island's scale.

signal again()

const GUY_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/guy_camp_0.png"), preload("res://assets/sprites/guy_camp_1.png"),
	preload("res://assets/sprites/guy_camp_2.png"), preload("res://assets/sprites/guy_camp_3.png"),
]
const BEER_TEXTURE: Texture2D = preload("res://assets/sprites/beer.png")
const FIRE_FRAMES: Array[Texture2D] = [
	preload("res://assets/sprites/campfire_0.png"), preload("res://assets/sprites/campfire_1.png"),
]
## The title's heading with a full crew; short-handed it is heading_text()'s "%d of 4 made it".
const HEADING_FULL: String = "They made it"
## The order the boys hop off: the front seats first.
const HOP_ORDER: Array[int] = [
	Paddling.Seat.LEFT_FRONT, Paddling.Seat.RIGHT_FRONT,
	Paddling.Seat.LEFT_BACK, Paddling.Seat.RIGHT_BACK,
]
## The clearing's fire pit and the tent's spot beside it, in island.png pixels from the centre.
const FIRE_SPOT: Vector2 = Vector2(16.0, 14.0)
const TENT_SPOT: Vector2 = Vector2(37.0, 2.0)
## The walk passes here, south of the clearing and clear of the pines, before the fire.
const CLEARING_GATE: Vector2 = Vector2(16.0, 36.0)
## Each boy's place round the fire: this far from it, at his seat's angle (0 = east).
const SIT_RADIUS: float = 10.0
const SIT_ANGLES: Array[float] = [PI, PI * 0.5, 0.0, -PI * 0.5]
## The beach: the boys land this fraction of the island's radius from its centre, on the boat's
## side (the back seats a little further out), the left hull's boys to the left.
const LAND_DEPTH_FRONT: float = 0.72
const LAND_DEPTH_BACK: float = 0.84
const LAND_SPREAD: float = 9.0
## Timing (seconds) and sizes (pixels, radians) of the moves.
const CAMERA_TIME: float = 1.2
const HOP_INTERVAL: float = 0.45
const HOP_TIME: float = 0.4
const HOP_SCALE: float = 1.5
const WALK_SPEED: float = 36.0
const WADDLE: float = 0.25
const WADDLE_PERIOD: float = 0.3
const TENT_POP_TIME: float = 0.5
const FIRE_LIGHT_TIME: float = 0.25
const FIRE_FLICKER: float = 0.12
## A sip: the beer rises from the hand to the mouth, tilts, holds, and comes back down; each
## boy's rest between sips is longer by DRINK_STAGGER per seat, so they don't drink in step.
const DRINK_LIFT_TIME: float = 0.4
const DRINK_HOLD_TIME: float = 0.6
const DRINK_REST_TIME: float = 0.8
const DRINK_STAGGER: float = 0.35
const BEER_HAND: Vector2 = Vector2(3.0, -3.0)
const BEER_MOUTH: Vector2 = Vector2(0.0, -4.0)
const BEER_TILT: float = -0.8
const TITLE_FADE: float = 0.6
const PROMPT_BLINK: float = 0.7
const PROMPT_DIM: float = 0.35
## The stats block's font size (T86) and the gap between its two column pairs, in pixels.
const STATS_FONT_SIZE: int = 8
const STATS_PAIR_GAP: int = 16
## The block's dark outline, so the figures read over the island's pale sand.
const STATS_OUTLINE_COLOR: Color = Color(0.05, 0.1, 0.2, 0.9)
const STATS_OUTLINE_SIZE: int = 3

@onready var _guys_node: Node2D = $Visual/Guys
@onready var _tent: Sprite2D = $Visual/Tent
@onready var _fire: Sprite2D = $Visual/Fire
@onready var _title: CanvasLayer = $Title
@onready var _title_box: Control = %TitleBox
@onready var _heading: Label = %Heading
@onready var _left_behind_box: VBoxContainer = %LeftBehind
@onready var _time_label: Label = %Time
@onready var _stats_grid: GridContainer = %Stats
@onready var _crew_label: Label = %Crew
@onready var _prompt: Label = %Prompt

var _island_scale: float = 1.0
## One sprite per seat, in Paddling.Seat order; null for a guy left behind (T97).
var _guys: Array[Sprite2D] = []
## The seats that made it, in seat order, read from RunState when begin() is called.
var _crew: Array[int] = []
var _seated: int = 0
var _fire_frame: int = 0
var _title_shown: bool = false
var _done: bool = false


## Starts the cutscene: `boat` is where the boys hop off from, `camera` eases onto this node,
## the beach is `island_radius` from here and the island's art is drawn at `island_scale`.
## Call once this node is in the tree at the island's position.
func begin(boat: CharacterBody2D, camera: Camera2D, island_radius: float, island_scale: float) -> void:
	_island_scale = island_scale
	_tent.position = TENT_SPOT * island_scale
	_fire.position = FIRE_SPOT * island_scale
	var toward_boat: Vector2 = to_local(boat.global_position).normalized()
	if toward_boat.is_zero_approx():
		toward_boat = Vector2.DOWN
	var along_beach: Vector2 = toward_boat.orthogonal()
	_guys.resize(RunState.GUY_COUNT)
	_crew.clear()
	for seat: int in RunState.GUY_COUNT:
		if not RunState.guys[seat].aboard:
			continue
		_crew.append(seat)
		var guy: Sprite2D = Sprite2D.new()
		guy.name = "Guy%d" % seat
		guy.texture = GUY_TEXTURES[seat]
		guy.position = to_local(boat.guy_global_position(seat))
		guy.rotation = boat.global_rotation
		_guys_node.add_child(guy)
		_guys[seat] = guy
	var master: Tween = create_tween()
	master.tween_property(camera, "global_position", global_position, CAMERA_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	master.tween_callback(Audio.play.bind(&"cheer"))
	for seat: int in HOP_ORDER:
		if not _crew.has(seat):
			continue
		var depth: float = LAND_DEPTH_BACK if Paddling.is_back_seat(seat) else LAND_DEPTH_FRONT
		var landing: Vector2 = toward_boat * island_radius * depth \
				- along_beach * Paddling.seat_side(seat) * LAND_SPREAD
		master.tween_callback(_hop.bind(seat, landing))
		master.tween_interval(HOP_INTERVAL)


## Once the title is up, any key (or ui_accept), or a touch on a touchscreen (T54), ends the
## crossing: the lake goes again.
func _unhandled_input(event: InputEvent) -> void:
	if _done or not _title_shown:
		return
	var key: bool = event is InputEventKey and event.is_pressed() and not event.is_echo()
	var touch: bool = event is InputEventScreenTouch and event.is_pressed()
	if key or touch or event.is_action_pressed(&"ui_accept"):
		_done = true
		again.emit()


## The title's heading for `made_it` guys of GUY_COUNT who reached the island.
static func heading_text(made_it: int) -> String:
	if made_it >= RunState.GUY_COUNT:
		return HEADING_FULL
	return "%d of %d made it" % [made_it, RunState.GUY_COUNT]


## One dark joke per name in `names`, in order: each drawn from `lines` with `rng` and holding the
## name where the line has its %s. The lines are not repeated until they run out (two left-behind
## guys do not get the same joke); a line without a %s is used as it is. Empty when `lines` is.
static func left_behind_lines(names: Array[String], lines: PackedStringArray, rng: RandomNumberGenerator) -> Array[String]:
	var out: Array[String] = []
	if lines.is_empty():
		return out
	var pool: Array[String] = []
	for who: String in names:
		if pool.is_empty():
			pool.assign(lines)
		var line: String = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		out.append(line % who if line.contains("%s") else line)
	return out


## The crossing time as m:ss.
static func format_time(seconds: float) -> String:
	return Stats.format_time(seconds)


## One boy hops from his seat onto the beach at `landing` (he grows and shrinks as he jumps),
## waddles to the clearing's gate and then to his place by the fire, and sits.
func _hop(seat: int, landing: Vector2) -> void:
	var guy: Sprite2D = _guys[seat]
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_callback(_face.bind(guy, landing))
	tween.tween_property(guy, "position", landing, HOP_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(guy, "scale", Vector2.ONE * HOP_SCALE, HOP_TIME * 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(guy, "scale", Vector2.ONE, HOP_TIME * 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(HOP_TIME * 0.5)
	tween.set_parallel(false)
	var gate: Vector2 = CLEARING_GATE * _island_scale
	var place: Vector2 = (FIRE_SPOT + Vector2.from_angle(SIT_ANGLES[seat]) * SIT_RADIUS) * _island_scale
	_walk(tween, guy, landing, gate)
	_walk(tween, guy, gate, place)
	tween.tween_callback(_sit.bind(seat))


## Appends one leg of a walk to `tween`: the boy turns to face `to`, waddles there at
## WALK_SPEED.
func _walk(tween: Tween, guy: Sprite2D, from: Vector2, to: Vector2) -> void:
	var seconds: float = from.distance_to(to) / WALK_SPEED
	tween.tween_callback(_start_leg.bind(guy, to, seconds))
	tween.tween_property(guy, "position", to, seconds)


## Starts a leg's waddle: the boy faces `to` and rocks either way of it for `seconds`.
func _start_leg(guy: Sprite2D, to: Vector2, seconds: float) -> void:
	_face(guy, to)
	var facing: float = guy.rotation
	var waddle: Tween = create_tween().set_loops(maxi(int(seconds / WADDLE_PERIOD), 1))
	waddle.tween_property(guy, "rotation", facing + WADDLE, WADDLE_PERIOD * 0.5)
	waddle.tween_property(guy, "rotation", facing - WADDLE, WADDLE_PERIOD * 0.5)


## Turns `guy` (his sprite faces up) toward `to`.
func _face(guy: Sprite2D, to: Vector2) -> void:
	if not guy.position.is_equal_approx(to):
		guy.rotation = (to - guy.position).angle() + PI * 0.5


## The boy is at his place: he faces the fire and keeps drinking. The last one to sit starts
## the camp.
func _sit(seat: int) -> void:
	var guy: Sprite2D = _guys[seat]
	_face(guy, FIRE_SPOT * _island_scale)
	var beer: Sprite2D = Sprite2D.new()
	beer.name = "Beer"
	beer.texture = BEER_TEXTURE
	beer.position = BEER_HAND
	guy.add_child(beer)
	var sip: Tween = create_tween().set_loops()
	sip.tween_interval(DRINK_REST_TIME + DRINK_STAGGER * seat)
	sip.tween_property(beer, "position", BEER_MOUTH, DRINK_LIFT_TIME).set_trans(Tween.TRANS_SINE)
	sip.tween_property(beer, "rotation", BEER_TILT, DRINK_LIFT_TIME * 0.5)
	sip.tween_interval(DRINK_HOLD_TIME)
	sip.tween_property(beer, "rotation", 0.0, DRINK_LIFT_TIME * 0.5)
	sip.tween_property(beer, "position", BEER_HAND, DRINK_LIFT_TIME).set_trans(Tween.TRANS_SINE)
	_seated += 1
	if _seated == _crew.size():
		_make_camp()


## The tent pops up, the fire lights, and the title fades in.
func _make_camp() -> void:
	_tent.scale = Vector2.ZERO
	_tent.visible = true
	_fire.scale = Vector2.ZERO
	var tween: Tween = create_tween()
	tween.tween_property(_tent, "scale", Vector2.ONE, TENT_POP_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_fire.show)
	tween.tween_property(_fire, "scale", Vector2.ONE, FIRE_LIGHT_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_light_fire)
	tween.tween_callback(_show_title)


## Keeps the fire flickering between its two frames.
func _light_fire() -> void:
	var flicker: Tween = create_tween().set_loops()
	flicker.tween_callback(_flicker).set_delay(FIRE_FLICKER)


func _flicker() -> void:
	_fire_frame = (_fire_frame + 1) % FIRE_FRAMES.size()
	_fire.texture = FIRE_FRAMES[_fire_frame]


## The title with the crossing time and the crew's names fades in; the prompt then blinks, and
## keys count.
func _show_title() -> void:
	_time_label.text = "Crossing time %s" % format_time(RunState.elapsed)
	_heading.text = heading_text(_crew.size())
	var crew_names: Array[String] = []
	for seat: int in _crew:
		crew_names.append(RunState.name_of(seat))
	_crew_label.text = ", ".join(crew_names)
	_fill_left_behind()
	_fill_stats()
	_title_box.modulate.a = 0.0
	_title.visible = true
	var fade: Tween = create_tween()
	fade.tween_property(_title_box, "modulate:a", 1.0, TITLE_FADE)
	fade.tween_callback(_arm_prompt)


## A dark joke for each guy left in the water, under the crew line, drawn once as the title comes up
## from the run's RNG.
func _fill_left_behind() -> void:
	for child: Node in _left_behind_box.get_children():
		_left_behind_box.remove_child(child)
		child.queue_free()
	var names: Array[String] = []
	for seat: int in RunState.left_behind:
		names.append(RunState.name_of(seat))
	for line: String in left_behind_lines(names, RunState.lines.lines_of(&"left_behind"), RunState.rng):
		var label: Label = Label.new()
		label.text = line
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_style_stat(label)
		_left_behind_box.add_child(label)


## The crossing's stats (T86) under the time, in two columns of label and value pairs: the first
## half of RunState.stats.rows() down the left, the rest down the right. The Time row is left out,
## the time label above shows it.
func _fill_stats() -> void:
	for child: Node in _stats_grid.get_children():
		_stats_grid.remove_child(child)
		child.queue_free()
	var level_per_beer: float = RunState.drunkenness.tuning.level_per_beer
	var rows: Array[Dictionary] = RunState.stats.rows(RunState.elapsed, level_per_beer).slice(1)
	var half: int = ceili(rows.size() / 2.0)
	for i: int in half:
		_add_stat(rows[i], false)
		if i + half < rows.size():
			_add_stat(rows[i + half], true)
		else:
			_add_stat({"label": "", "value": ""}, true)


## One label and value pair of the grid; the right column's label is set off by STATS_PAIR_GAP.
func _add_stat(row: Dictionary, right_column: bool) -> void:
	var label: Label = Label.new()
	label.text = str(row["label"])
	_style_stat(label)
	if right_column:
		var margin: MarginContainer = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", STATS_PAIR_GAP)
		margin.add_child(label)
		_stats_grid.add_child(margin)
	else:
		_stats_grid.add_child(label)
	var value: Label = Label.new()
	value.text = str(row["value"])
	_style_stat(value)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stats_grid.add_child(value)


func _style_stat(label: Label) -> void:
	label.add_theme_font_size_override("font_size", STATS_FONT_SIZE)
	label.add_theme_color_override("font_outline_color", STATS_OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", STATS_OUTLINE_SIZE)


func _arm_prompt() -> void:
	_title_shown = true
	var blink: Tween = create_tween().set_loops()
	blink.tween_property(_prompt, "modulate:a", PROMPT_DIM, PROMPT_BLINK * 0.5)
	blink.tween_property(_prompt, "modulate:a", 1.0, PROMPT_BLINK * 0.5)
