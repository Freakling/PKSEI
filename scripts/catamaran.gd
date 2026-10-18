extends CharacterBody2D
## Catamaran · the boat scene (GDD › Systems › Catamaran and paddling, GDD › Presentation and
## Platforms).
##
## Reads the eight stroke keys (a forward and a reverse key per seat, GDD › Presentation and
## Platforms), calls RunState.stroke() on each release and RunState.step() every physics frame, and moves by the Motion it gets back: thrust along its facing, turn as yaw, and
## the current's drift down-screen toward the shore (the island is up-screen). Damping stands in
## for the water; the scales and damping are BoatTuning's, read through RunState.paddling. The
## art under `Visual` is pixel art from assets/sprites/ (drawn by tools/gen_sprites.gd): the hull
## sprite and one AnimatedSprite2D per guy, in his seat's shirt colour, whose frames are the
## PNGs in assets/sprites/guys/ (FRAME_PATH, built into SpriteFrames here). Every telegraph in
## GDD › Drunkenness and GDD › Stamina is one of his animations (ANIMATIONS), chosen each frame
## by _animation_for(): the antic wind-up, the antics themselves, the break warning and the
## break from RunState's Antics and Stamina states, seeing double (the wind-up and the reversal, a sway) from
## Drunkenness; a stroke is a reach on the key's release, the pull when RunState says it landed
## (so his lag shows as the reach held) and a fumble when it missed. The flat primitives that
## remain are a white marker flashing over a warned guy (it keeps the warning readable through
## his strokes) and his dropped paddle floating beside the hull; a finger on the touch pads
## (scripts/ui/touch_pads.gd) gives the reach on its release. A guy
## winding up to jump after a beer (Rescue's winding_up, T34) rocks in his seat; a guy in the
## water has no sprite here (the lake draws him), and once the attempt is won nobody is drawn
## here (the win cutscene, T28, draws the boys stepping ashore from guy_global_position). Hazard
## effects come through RunState too: take_stop() zeroes the boat's speed and yaw, take_shove()
## is added to its speed, and take_push() (a gust's sustained wind) is a velocity the boat moves
## at this frame like the drift, undamped and stopped by the shore. Once the attempt is won they
## are taken and dropped (B4). In debug builds F5/F6 knock a beer over on the left/right without
## a hazard. No rules live here.

## The forward-stroke action per seat, in Paddling.Seat order (W, Q, I, O).
const ACTIONS: Array[StringName] = [
	&"stroke_left_front", &"stroke_left_back", &"stroke_right_front", &"stroke_right_back",
]
## The reverse-stroke action per seat, in Paddling.Seat order (S, A, K, L).
const REVERSE_ACTIONS: Array[StringName] = [
	&"reverse_left_front", &"reverse_left_back", &"reverse_right_front", &"reverse_right_back",
]
## Debug-only: a beer overboard on each side (F5, F6) without a hazard.
const DEBUG_BEER_ACTIONS: Array[StringName] = [&"debug_beer_left", &"debug_beer_right"]
## The guys' sprites under Visual, in Paddling.Seat order.
const GUY_PATHS: Array[String] = [
	"Visual/LeftFront", "Visual/LeftBack", "Visual/RightFront", "Visual/RightBack",
]
## A guy's frame PNGs (seat, frame name), drawn by tools/gen_sprites.gd's GUY_FRAMES.
const FRAME_PATH: String = "res://assets/sprites/guys/guy_%d_%s.png"
## The guys' animations: each a list of frame names for FRAME_PATH. The two-frame ones loop at
## LOOP_FPS; the others hold one pose.
const ANIMATIONS: Dictionary[StringName, Array] = {
	&"idle": ["idle"],
	&"reach": ["stroke_0"],
	&"pull": ["stroke_1"],
	&"fumble": ["fumble"],
	&"warning": ["warning_0", "warning_1"],
	&"break": ["break"],
	&"windup": ["windup_0", "windup_1"],
	&"stand": ["stand"],
	&"paddle_dropped": ["paddle_dropped"],
	&"nodded_off": ["nodded_off"],
	&"peeing": ["peeing"],
	&"puking": ["puke_0", "puke_1"],
	&"sway": ["bar_0", "bar_1"],
}
const LOOP_FPS: float = 4.0
## The animation for each Antics state that shows on the guy (IDLE and RECOVERING don't).
const ANTIC_ANIMATIONS: Dictionary[int, StringName] = {
	Antics.State.WINDING_UP: &"windup",
	Antics.State.STANDING: &"stand",
	Antics.State.PADDLE_DROPPED: &"paddle_dropped",
	Antics.State.NODDED_OFF: &"nodded_off",
	Antics.State.PEEING: &"peeing",
	Antics.State.PUKING: &"puking",
}
## The strokes as one-shots (seconds, cosmetic): the reach holds from the key's release until
## the stroke lands or fumbles, at most REACH_TIME (a stroke dropped because he went
## overboard); the pull and the fumble then show for their time before he sits back idle.
const REACH_TIME: float = 2.0
const PULL_TIME: float = 0.25
const FUMBLE_TIME: float = 0.5
## Seconds per flash of the break warning marker (cosmetic).
const WARNING_FLASH_PERIOD: float = 0.3
## The jump wind-up: a guy's sprite rocks this far (radians) each way, once per period
## (cosmetic), quickening as his wind-up runs out.
const WIND_UP_ROCK: float = 0.35
const WIND_UP_ROCK_PERIOD: float = 0.4
## Speed from strokes, kept apart from `velocity` so a shore collision never feeds the current
## back into it.
var _stroke_velocity: Vector2 = Vector2.ZERO
var _yaw_rate: float = 0.0
## Seconds each seat's forward key and reverse key have been held (0 while up).
var _hold_times: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _reverse_hold_times: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _flash_clock: float = 0.0
var _rock_clock: float = 0.0
var _guys: Array[AnimatedSprite2D] = []
var _warnings: Array[Node2D] = []
var _paddles: Array[Node2D] = []
## Per seat, the stroke one-shot in progress (empty for none) and its seconds left.
var _one_shots: Array[StringName] = [&"", &"", &"", &""]
var _one_shot_left: Array[float] = [0.0, 0.0, 0.0, 0.0]
## The touch pads (scripts/ui/touch_pads.gd, the "touch_pads" group) when the lake has them;
## null for the boat alone (tests). Their release gives the reach.
var _touch_pads: TouchPads = null


func _ready() -> void:
	_touch_pads = get_tree().get_first_node_in_group(&"touch_pads") as TouchPads
	if _touch_pads != null:
		_touch_pads.stroke_released.connect(_on_touch_released)
	for seat: int in GUY_PATHS.size():
		var guy: AnimatedSprite2D = get_node(GUY_PATHS[seat]) as AnimatedSprite2D
		guy.sprite_frames = _build_frames(seat)
		guy.play(&"idle")
		_guys.append(guy)
		_warnings.append(guy.get_node("Warning") as Node2D)
		_paddles.append(guy.get_node("Paddle") as Node2D)
	RunState.stroke_landed.connect(_on_stroke_landed)
	RunState.stroke_fumbled.connect(_on_stroke_fumbled)


func _physics_process(delta: float) -> void:
	_read_keys(delta)
	if OS.is_debug_build() or OS.has_feature("dev_tools"):
		_read_debug_keys()
	var tuning: BoatTuning = RunState.paddling.tuning
	var motion: Paddling.Motion = RunState.step(delta, position)
	_stroke_velocity += Vector2.UP.rotated(rotation) * motion.thrust * tuning.thrust_scale
	_yaw_rate += motion.turn * tuning.turn_scale
	# The hazards' effects are taken every frame, so none is left for the next attempt. Once the
	# attempt is won (B4) they are dropped: the boat is not stopped, shoved or pushed by them.
	var stopped: bool = RunState.take_stop()
	var shove: Vector2 = RunState.take_shove()
	var push: Vector2 = RunState.take_push()
	if RunState.phase == RunState.Phase.WON:
		stopped = false
		shove = Vector2.ZERO
		push = Vector2.ZERO
	if stopped:
		_stroke_velocity = Vector2.ZERO
		_yaw_rate = 0.0
	_stroke_velocity += shove
	_stroke_velocity *= exp(-tuning.linear_damping * delta)
	_yaw_rate *= exp(-tuning.angular_damping * delta)
	rotation += _yaw_rate * delta
	# The drift and the wind's push go through velocity so the shore collision stops them.
	velocity = _stroke_velocity + push + Vector2.DOWN * motion.drift_to_shore / delta
	move_and_slide()
	_show_telegraphs(delta)


## Hold to charge, release to stroke: the hold time goes to RunState with the seat, and
## whether it was the reverse key. A guy who can paddle reaches at once (the input is honoured
## in the animation); what the stroke then does comes back as stroke_landed or stroke_fumbled.
func _read_keys(delta: float) -> void:
	for seat: int in ACTIONS.size():
		_read_key(seat, ACTIONS[seat], _hold_times, false, delta)
		_read_key(seat, REVERSE_ACTIONS[seat], _reverse_hold_times, true, delta)


## One key's hold timer in `hold_times[seat]`: reset on press, counted while held, and sent as
## a stroke on release.
func _read_key(seat: int, action: StringName, hold_times: Array[float], backwards: bool, delta: float) -> void:
	if Input.is_action_just_pressed(action):
		hold_times[seat] = 0.0
	if Input.is_action_pressed(action):
		hold_times[seat] += delta
	if Input.is_action_just_released(action):
		if RunState.can_paddle(seat):
			_start_one_shot(seat, &"reach", REACH_TIME)
		RunState.stroke(seat, hold_times[seat], backwards)
		hold_times[seat] = 0.0


## A finger on the touch pads released this seat (just before its stroke, as a key's release):
## a guy who can paddle reaches at once.
func _on_touch_released(seat: int) -> void:
	if RunState.can_paddle(seat):
		_start_one_shot(seat, &"reach", REACH_TIME)


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
	_reverse_hold_times.fill(0.0)


## Visual only: a swimmer's sprite is hidden, each guy plays the animation his state picks, a
## warned guy's marker flashes over him, a guy winding up to jump rocks in his seat, a dropped
## paddle floats beside the hull.
func _show_telegraphs(delta: float) -> void:
	_flash_clock = fmod(_flash_clock + delta, WARNING_FLASH_PERIOD)
	_rock_clock = fmod(_rock_clock + delta, WIND_UP_ROCK_PERIOD)
	var flash_on: bool = _flash_clock < WARNING_FLASH_PERIOD * 0.5
	for seat: int in _guys.size():
		_one_shot_left[seat] = maxf(_one_shot_left[seat] - delta, 0.0)
		var stamina_state: Stamina.State = RunState.stamina.state_of(seat)
		var antic: Antics.State = RunState.antics.state_of(seat)
		var guy: AnimatedSprite2D = _guys[seat]
		guy.visible = RunState.guys[seat].aboard and RunState.phase != RunState.Phase.WON
		guy.rotation = _wind_up_rock(seat)
		var animation: StringName = _animation_for(seat, stamina_state, antic)
		if guy.animation != animation:
			guy.play(animation)
		_warnings[seat].visible = stamina_state == Stamina.State.WARNING and flash_on
		_paddles[seat].visible = antic == Antics.State.PADDLE_DROPPED


## Visual only: the animation a guy shows this frame, by priority. An antic wind-up or antic
## first, so its telegraph runs unbroken from the wind-up to the antic; then his break; then a
## stroke or fumble in progress; then the break warning; then the sway while he sees double (the wind-up and the reversal); else idle.
func _animation_for(seat: int, stamina_state: Stamina.State, antic: Antics.State) -> StringName:
	if ANTIC_ANIMATIONS.has(antic):
		return ANTIC_ANIMATIONS[antic]
	if stamina_state == Stamina.State.BREAK:
		return &"break"
	if _one_shot_left[seat] > 0.0:
		return _one_shots[seat]
	if stamina_state == Stamina.State.WARNING:
		return &"warning"
	if RunState.drunkenness.double_winding_up(seat) or RunState.drunkenness.reversed(seat):
		return &"sway"
	return &"idle"


## His stroke landed (after his lag, so the reach held that long): the pull.
func _on_stroke_landed(seat: int) -> void:
	_start_one_shot(seat, &"pull", PULL_TIME)


## His stroke missed: the paddle slips.
func _on_stroke_fumbled(seat: int) -> void:
	_start_one_shot(seat, &"fumble", FUMBLE_TIME)


func _start_one_shot(seat: int, animation: StringName, time: float) -> void:
	_one_shots[seat] = animation
	_one_shot_left[seat] = time


## Visual only: the rock of a guy's sprite while Rescue has him winding up to jump, growing as
## the time left runs out so the jump reads as coming; 0 when he isn't.
func _wind_up_rock(seat: int) -> float:
	var rescue: Rescue = RunState.rescue
	if not rescue.winding_up(seat):
		return 0.0
	var delay: float = maxf(RunState.paddling.tuning.jump_delay, 0.001)
	var build_up: float = 1.0 - clampf(rescue.wind_up_left(seat) / delay, 0.0, 1.0)
	return WIND_UP_ROCK * (0.5 + 0.5 * build_up) * sin(TAU * _rock_clock / WIND_UP_ROCK_PERIOD)


## One guy's SpriteFrames from his frame PNGs (FRAME_PATH), one animation per ANIMATIONS entry.
static func _build_frames(seat: int) -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")
	for animation: StringName in ANIMATIONS:
		frames.add_animation(animation)
		frames.set_animation_speed(animation, LOOP_FPS)
		for frame: String in ANIMATIONS[animation]:
			frames.add_frame(animation, load(FRAME_PATH % [seat, frame]) as Texture2D)
	return frames
