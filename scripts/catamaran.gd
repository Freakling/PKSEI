extends CharacterBody2D
## Catamaran · the boat scene (GDD › Systems › Catamaran and paddling, GDD › Presentation and
## Platforms).
##
## Reads the four stroke keys, calls RunState.stroke() on each release and RunState.step() every
## physics frame, and moves by the Motion it gets back: thrust along its facing, turn as yaw, and
## the current's drift down-screen toward the shore (the island is up-screen). Damping stands in
## for the water; the scales and damping are BoatTuning's, read through RunState.paddling. The
## art under `Visual` is pixel art from assets/sprites/ (drawn by tools/gen_sprites.gd): the hull
## sprite and one sprite per guy, in his seat's shirt colour. The telegraphs stay primitives. The
## guys' sprites show the break telegraph from RunState's Stamina state (a flashing
## marker during the warning, dimmed on the break) and the timing bar from its Drunkenness (it
## blinks beside a guy while his tier is announced, then shows beside him while his key is held,
## the marker sweeping over the green band); a guy winding up to jump after a beer (Rescue's
## winding_up, T34) rocks in his seat; a guy in the water has no sprite here (the lake draws
## him), and once the attempt is won nobody is drawn here (the win cutscene, T28, draws the boys
## stepping ashore from guy_global_position). Hazard effects come through RunState too: take_stop() zeroes the boat's speed
## and yaw, take_shove() is added to its speed, and take_push() (a gust's sustained wind) is a
## velocity the boat moves at this frame like the drift, undamped and stopped by the shore. In
## debug builds F5/F6 knock a beer over on the left/right without a hazard. No rules live here.

## One input action per seat, in Paddling.Seat order (Q, A, I, K).
const ACTIONS: Array[StringName] = [
	&"stroke_left_front", &"stroke_left_back", &"stroke_right_front", &"stroke_right_back",
]
## Debug-only: a beer overboard on each side (F5, F6) without a hazard.
const DEBUG_BEER_ACTIONS: Array[StringName] = [&"debug_beer_left", &"debug_beer_right"]
## The guys' sprites under Visual, in Paddling.Seat order.
const GUY_PATHS: Array[String] = [
	"Visual/LeftFront", "Visual/LeftBack", "Visual/RightFront", "Visual/RightBack",
]
const BREAK_DIM: Color = Color(0.4, 0.4, 0.4, 1.0)
## Seconds per flash of the break warning marker and the bar's wind-up (cosmetic).
const WARNING_FLASH_PERIOD: float = 0.3
## The jump wind-up: a guy's sprite rocks this far (radians) each way, once per period
## (cosmetic), quickening as his wind-up runs out.
const WIND_UP_ROCK: float = 0.35
const WIND_UP_ROCK_PERIOD: float = 0.4
## The timing bar beside a guy's sprite (cosmetic sizes, in canvas pixels): a dark track
## with a green band of DrinkTuning.green_width and a sweeping marker.
const BAR_WIDTH: float = 16.0
const BAR_HEIGHT: float = 3.0
## From the square's centre to the bar's centre, out past the hull.
const BAR_OFFSET: float = 14.0
const BAR_MARKER_WIDTH: float = 2.0
const BAR_TRACK_COLOUR: Color = Color(0.15, 0.15, 0.15, 1.0)
const BAR_GREEN_COLOUR: Color = Color(0.2, 0.9, 0.3, 1.0)
const BAR_MARKER_COLOUR: Color = Color(1.0, 1.0, 1.0, 1.0)

## Speed from strokes, kept apart from `velocity` so a shore collision never feeds the current
## back into it.
var _stroke_velocity: Vector2 = Vector2.ZERO
var _yaw_rate: float = 0.0
var _hold_times: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _flash_clock: float = 0.0
var _rock_clock: float = 0.0
var _guys: Array[Sprite2D] = []
var _warnings: Array[Node2D] = []
var _bars: Array[Node2D] = []
var _bar_markers: Array[Node2D] = []


func _ready() -> void:
	for seat: int in GUY_PATHS.size():
		var guy: Sprite2D = get_node(GUY_PATHS[seat]) as Sprite2D
		_guys.append(guy)
		_warnings.append(guy.get_node("Warning") as Node2D)
		_bars.append(_build_bar(guy, seat))


func _physics_process(delta: float) -> void:
	_read_keys(delta)
	if OS.is_debug_build() or OS.has_feature("dev_tools"):
		_read_debug_keys()
	var tuning: BoatTuning = RunState.paddling.tuning
	var motion: Paddling.Motion = RunState.step(delta, position)
	_stroke_velocity += Vector2.UP.rotated(rotation) * motion.thrust * tuning.thrust_scale
	_yaw_rate += motion.turn * tuning.turn_scale
	if RunState.take_stop():
		_stroke_velocity = Vector2.ZERO
		_yaw_rate = 0.0
	_stroke_velocity += RunState.take_shove()
	_stroke_velocity *= exp(-tuning.linear_damping * delta)
	_yaw_rate *= exp(-tuning.angular_damping * delta)
	rotation += _yaw_rate * delta
	# The drift and the wind's push go through velocity so the shore collision stops them.
	velocity = _stroke_velocity + RunState.take_push() + Vector2.DOWN * motion.drift_to_shore / delta
	move_and_slide()
	_show_telegraphs(delta)


## Hold to charge, release to stroke: the hold time goes to RunState with the seat.
func _read_keys(delta: float) -> void:
	for seat: int in ACTIONS.size():
		var action: StringName = ACTIONS[seat]
		if Input.is_action_just_pressed(action):
			_hold_times[seat] = 0.0
		if Input.is_action_pressed(action):
			_hold_times[seat] += delta
		if Input.is_action_just_released(action):
			RunState.stroke(seat, _hold_times[seat])
			_hold_times[seat] = 0.0


## Debug-only (see DEBUG_BEER_ACTIONS): a beer overboard at the boat, on the key's side.
func _read_debug_keys() -> void:
	for side: int in DEBUG_BEER_ACTIONS.size():
		if Input.is_action_just_pressed(DEBUG_BEER_ACTIONS[side]):
			RunState.beer_overboard(side as Rescue.Hull, position)


## Where `seat`'s guy sits, in world pixels: the win cutscene starts his sprite there.
func guy_global_position(seat: int) -> Vector2:
	return _guys[seat].global_position


## Puts the boat at `at`, facing the island, still: the lake calls it after a shore reset and
## for a new attempt.
func place(at: Vector2) -> void:
	position = at
	rotation = 0.0
	velocity = Vector2.ZERO
	_stroke_velocity = Vector2.ZERO
	_yaw_rate = 0.0
	_hold_times.fill(0.0)


## Visual only: a swimmer's sprite is hidden, a warned guy's marker flashes, a guy on a break is
## dim, a guy winding up to jump rocks in his seat, and the timing bar shows beside a guy on the
## top tier.
func _show_telegraphs(delta: float) -> void:
	_flash_clock = fmod(_flash_clock + delta, WARNING_FLASH_PERIOD)
	_rock_clock = fmod(_rock_clock + delta, WIND_UP_ROCK_PERIOD)
	var flash_on: bool = _flash_clock < WARNING_FLASH_PERIOD * 0.5
	for seat: int in _guys.size():
		var state: Stamina.State = RunState.stamina.state_of(seat)
		_guys[seat].visible = RunState.guys[seat].aboard and RunState.phase != RunState.Phase.WON
		_guys[seat].modulate = BREAK_DIM if state == Stamina.State.BREAK else Color.WHITE
		_guys[seat].rotation = _wind_up_rock(seat)
		_warnings[seat].visible = state == Stamina.State.WARNING and flash_on
		_show_bar(seat, flash_on)


## Visual only: the rock of a guy's sprite while Rescue has him winding up to jump, growing as
## the time left runs out so the jump reads as coming; 0 when he isn't.
func _wind_up_rock(seat: int) -> float:
	var rescue: Rescue = RunState.rescue
	if not rescue.winding_up(seat):
		return 0.0
	var delay: float = maxf(RunState.paddling.tuning.jump_delay, 0.001)
	var build_up: float = 1.0 - clampf(rescue.wind_up_left(seat) / delay, 0.0, 1.0)
	return WIND_UP_ROCK * (0.5 + 0.5 * build_up) * sin(TAU * _rock_clock / WIND_UP_ROCK_PERIOD)


## Visual only: the bar blinks beside a guy while his tier is announced (the wind-up), then
## shows steady while his key is held once it applies, its marker where Drunkenness says the
## sweep is for this hold, so what the player sees is what RunState.stroke() judges.
func _show_bar(seat: int, flash_on: bool) -> void:
	var drunkenness: Drunkenness = RunState.drunkenness
	var held: bool = _hold_times[seat] > 0.0
	var announcing: bool = drunkenness.bar_winding_up(seat) and flash_on
	_bars[seat].visible = announcing or (drunkenness.uses_bar(seat) and held)
	_bar_markers[seat].position.x = (drunkenness.bar_position(_hold_times[seat]) - 0.5) * BAR_WIDTH


## Builds one guy's bar under his sprite (a telegraph: flat primitives under Visual), out
## past his hull: the track, the green band sized by DrinkTuning.green_width, and the marker.
func _build_bar(guy: Node2D, seat: int) -> Node2D:
	var bar: Node2D = Node2D.new()
	bar.name = "Bar"
	bar.position = Vector2(-Paddling.seat_side(seat) * BAR_OFFSET, 0.0)
	bar.visible = false
	bar.add_child(_rect("Track", BAR_WIDTH, BAR_HEIGHT, BAR_TRACK_COLOUR))
	var green_width: float = clampf(RunState.drunkenness.tuning.green_width, 0.0, 1.0)
	bar.add_child(_rect("Green", BAR_WIDTH * green_width, BAR_HEIGHT, BAR_GREEN_COLOUR))
	var marker: Polygon2D = _rect("Marker", BAR_MARKER_WIDTH, BAR_HEIGHT + 2.0, BAR_MARKER_COLOUR)
	bar.add_child(marker)
	_bar_markers.append(marker)
	guy.add_child(bar)
	return bar


## A flat rectangle centred on its origin.
static func _rect(rect_name: String, width: float, height: float, colour: Color) -> Polygon2D:
	var rect: Polygon2D = Polygon2D.new()
	rect.name = rect_name
	rect.color = colour
	var half_width: float = width * 0.5
	var half_height: float = height * 0.5
	rect.polygon = PackedVector2Array([
		Vector2(-half_width, -half_height), Vector2(half_width, -half_height),
		Vector2(half_width, half_height), Vector2(-half_width, half_height),
	])
	return rect
