extends Control
class_name TouchPads
## TouchPads · the touch controls (GDD › Presentation and Platforms, Touch; research in
## design/research/touch-controls.md). The left half of the screen is the left hull and the
## right half the right hull; within a half, a touch in the outer part (toward the screen edge)
## charges that hull's back seat and a touch in the inner part (toward the middle) its front
## seat (seat_for: the x position decides, the whole height counting). A finger charges from its
## press to its release, and the release strokes through RunState.stroke(seat, hold_time,
## backwards): the press's height decides the direction (is_reverse, T77): on or above the line
## drawn low across each pad (LINE_OFFSET below the pads' centre at PAD_Y of the view) is a
## forward stroke, below it, where the pads' down arrows are, a reverse one; forward is the main
## direction, so it gets most of each pad and everything above. No flick: a drag changes nothing. Each finger
## is tracked by its index, so several charge at once; a second finger on a seat already being
## charged is ignored.
## Lives under lake.tscn's HUD CanvasLayer, filling it, drawn before the HUD rows so the pads
## sit under them: four pad.png sprites (tools/gen_sprites.gd) tinted per seat, in a row across
## the bottom from the view size, one brightening while its seat is charged. Shown when
## DisplayServer says there is a touchscreen, or on the first touch; hidden on keyboard play,
## which stays in scripts/catamaran.gd. The boat
## listens to stroke_released for the reach animation. Touches are taken in _input, before the
## GUI, so the HUD's bars never swallow one; none is handled once the attempt is won, so the
## win cutscene's "any key" gets it. A screen: it only reads RunState and calls its stroke().
## The mapping is static, so tests/test_touch_pads.gd runs it without a tree.

## A finger charging `seat` is about to stroke: emitted just before RunState.stroke(), like a
## key's release, so the boat shows the reach before the stroke lands or fumbles.
signal stroke_released(seat: int)

const PAD_TEXTURE: Texture2D = preload("res://assets/sprites/pad.png")
## Where a pad's centre sits, as fractions of the view: the centre of its outer quarter of the
## screen (the back seats) or its inner quarter (the front seats), and this far down, where a
## thumb rests, low on the screen. The line between forward and reverse presses (is_reverse) is
## LINE_OFFSET pixels (at 1×) below the pads' centre, where the sprite draws it (gen_sprites _pad),
## so only the pads' bottom strip with the down arrow strokes in reverse.
const PAD_X_OUTER: float = 0.125
const PAD_X_INNER: float = 0.375
const PAD_Y: float = 0.8
const LINE_OFFSET: float = 10.0
## A pad's tint is its seat's shirt colour at IDLE_ALPHA, and while charged the colour
## lightened by PRESSED_LIGHTEN at full alpha.
const IDLE_ALPHA: float = 0.7
const PRESSED_LIGHTEN: float = 0.5


## One finger charging a seat: where it pressed and for how long.
class Finger extends RefCounted:
	var seat: int = Paddling.Seat.LEFT_FRONT
	var press_position: Vector2 = Vector2.ZERO
	var hold_time: float = 0.0

	func _init(finger_seat: int, at: Vector2) -> void:
		seat = finger_seat
		press_position = at


## The fingers down, by the touch's index.
var _fingers: Dictionary[int, Finger] = {}
## One pad per seat, in Paddling.Seat order.
var _pads: Array[Sprite2D] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for seat: int in RunState.GUY_COUNT:
		var pad: Sprite2D = Sprite2D.new()
		pad.name = "Pad%d" % seat
		pad.texture = PAD_TEXTURE
		add_child(pad)
		_pads.append(pad)
	visible = DisplayServer.is_touchscreen_available()
	resized.connect(_layout)
	RunState.run_reset.connect(_drop_fingers)
	_layout()


func _process(delta: float) -> void:
	for finger: Finger in _fingers.values():
		finger.hold_time += delta
	for seat: int in _pads.size():
		var colour: Color = OffscreenArrows.SEAT_COLOURS[seat]
		if _finger_on(seat) != null:
			_pads[seat].modulate = colour.lightened(PRESSED_LIGHTEN)
		else:
			_pads[seat].modulate = Color(colour, IDLE_ALPHA)


## Each touch's press starts a finger charging the seat under it and its release strokes.
## A handled touch stops at the pads, so the HUD's bars never take it. Once the attempt is won
## nothing is charged and nothing is handled (the win cutscene's "any key" takes the touch); a
## finger still down is dropped.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		visible = true
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if RunState.phase == RunState.Phase.WON:
			_fingers.erase(touch.index)
			return
		if touch.pressed:
			_press(touch.index, touch.position)
		else:
			_release(touch.index)
		get_viewport().set_input_as_handled()



func _press(index: int, at: Vector2) -> void:
	var seat: int = seat_for(at, size)
	if _finger_on(seat) != null:
		return
	_fingers[index] = Finger.new(seat, at)


func _release(index: int) -> void:
	if not _fingers.has(index):
		return
	var finger: Finger = _fingers[index]
	_fingers.erase(index)
	var backwards: bool = is_reverse(finger.press_position, size)
	stroke_released.emit(finger.seat)
	RunState.stroke(finger.seat, finger.hold_time, backwards)


## A new attempt or a shore reset drops every finger, as the boat's place() drops its timers.
func _drop_fingers() -> void:
	_fingers.clear()


## The finger charging `seat`, or null.
func _finger_on(seat: int) -> Finger:
	for finger: Finger in _fingers.values():
		if finger.seat == seat:
			return finger
	return null


## Visual only: the four pads in a row across the bottom of the view, one at each quarter's
## centre, so the outer pads are the back seats and the inner pads the front seats.
func _layout() -> void:
	for seat: int in _pads.size():
		var x_fraction: float = PAD_X_OUTER if Paddling.is_back_seat(seat) else PAD_X_INNER
		if Paddling.seat_side(seat) < 0.0:
			x_fraction = 1.0 - x_fraction
		_pads[seat].position = (size * Vector2(x_fraction, PAD_Y)).round()


# --- the mapping, pure --------------------------------------------------------------------------

## The seat a touch at `position` charges in a view of `view_size`. The x position decides it,
## the whole height counting: the left half of the screen is the left hull and the right half
## the right hull; within a half, the outer quarter (toward the screen edge) is the back seat and
## the inner part (toward the middle) the front seat. The midline counts as right (x = w/2 is the
## right hull). On the quarter lines the left hull's outer part is strictly below w/4, so w/4
## is inner; the right hull's outer part starts at 3w/4, so 3w/4 is outer.
static func seat_for(position: Vector2, view_size: Vector2) -> int:
	if position.x < view_size.x * 0.5:
		var outer_left: bool = position.x < view_size.x * 0.25
		return Paddling.Seat.LEFT_BACK if outer_left else Paddling.Seat.LEFT_FRONT
	var outer_right: bool = position.x >= view_size.x * 0.75
	return Paddling.Seat.RIGHT_BACK if outer_right else Paddling.Seat.RIGHT_FRONT


## True when a press at `press_position` is below the pads' line, LINE_OFFSET under their centre
## at PAD_Y of the view's height (with the down arrow under it): the stroke is a reverse one. On
## the line or above it, anywhere up the screen, it is a forward stroke. The line is on a whole
## pixel, as the pads are laid out.
static func is_reverse(press_position: Vector2, view_size: Vector2) -> bool:
	return press_position.y > roundf(view_size.y * PAD_Y) + LINE_OFFSET
