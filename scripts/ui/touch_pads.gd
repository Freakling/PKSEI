extends Control
class_name TouchPads
## TouchPads · the touch controls (GDD › Presentation and Platforms, Touch; research in
## design/research/touch-controls.md). The left half of the screen is the left hull and the
## right half the right hull; a touch in the upper half of the screen charges that hull's front
## seat, in the lower half its back seat (seat_for: the whole half counts, not just the pad
## art). A finger charges from its press to its release, and the release strokes through
## RunState.stroke(seat, hold_time, backwards): forward, or backwards after a flick down of at
## least BoatTuning.touch_flick_distance between the press and the release (is_reverse). Each
## finger is tracked by its index, so several charge at once; a second finger on a seat
## already being charged is ignored. The seat is the press position's, so a flick may cross
## the midline. Lives under lake.tscn's HUD CanvasLayer, filling it, drawn before the HUD rows
## so the pads sit under them: four pad.png sprites (tools/gen_sprites.gd) tinted per seat,
## laid out from the view size, one brightening while its seat is charged. Shown when
## DisplayServer says there is a touchscreen, or on the first touch; hidden on keyboard play,
## which stays in scripts/catamaran.gd. The boat reads held_time(seat) for its timing bar and
## listens to stroke_released for the reach animation. Touches are taken in _input, before the
## GUI, so the HUD's bars never swallow one; none is handled once the attempt is won, so the
## win cutscene's "any key" gets it. A screen: it only reads RunState and calls its stroke().
## The mapping is static, so tests/test_touch_pads.gd runs it without a tree.

## A finger charging `seat` is about to stroke: emitted just before RunState.stroke(), like a
## key's release, so the boat shows the reach before the stroke lands or fumbles.
signal stroke_released(seat: int)

const PAD_TEXTURE: Texture2D = preload("res://assets/sprites/pad.png")
## Where a pad's centre sits, as fractions of the view: this far in from its hull's side of
## the screen, and this far down for the front and the back row (where a thumb rests; the
## HUD's rows are in the top-left corner, above the left front pad).
const PAD_X_FRACTION: float = 0.15
const PAD_Y_FRONT: float = 0.3
const PAD_Y_BACK: float = 0.72
## A pad's tint is its seat's shirt colour at IDLE_ALPHA, and while charged the colour
## lightened by PRESSED_LIGHTEN at full alpha.
const IDLE_ALPHA: float = 0.7
const PRESSED_LIGHTEN: float = 0.5


## One finger charging a seat: where it pressed, where it is now, and for how long.
class Finger extends RefCounted:
	var seat: int = Paddling.Seat.LEFT_FRONT
	var press_position: Vector2 = Vector2.ZERO
	var latest_position: Vector2 = Vector2.ZERO
	var hold_time: float = 0.0

	func _init(finger_seat: int, at: Vector2) -> void:
		seat = finger_seat
		press_position = at
		latest_position = at


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


## Each touch's press starts a finger charging the seat under it and its release strokes;
## a drag keeps the finger's latest position for the flick. A handled touch stops at the pads,
## so the HUD's bars never take it. Once the attempt is won nothing is charged and nothing is
## handled (the win cutscene's "any key" takes the touch); a finger still down is dropped.
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
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if _fingers.has(drag.index):
			_fingers[drag.index].latest_position = drag.position
			get_viewport().set_input_as_handled()


## How long the finger charging `seat` has been down, 0 with none: the boat's timing bar reads
## it beside its own key timers.
func held_time(seat: int) -> float:
	var finger: Finger = _finger_on(seat)
	return finger.hold_time if finger != null else 0.0


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
	var flick_distance: float = RunState.paddling.tuning.touch_flick_distance
	var backwards: bool = is_reverse(finger.press_position, finger.latest_position, flick_distance)
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


## Visual only: the pads from the view size, each on its hull's side at its row's height.
func _layout() -> void:
	for seat: int in _pads.size():
		var left: bool = Paddling.seat_side(seat) > 0.0
		var x_fraction: float = PAD_X_FRACTION if left else 1.0 - PAD_X_FRACTION
		var y_fraction: float = PAD_Y_BACK if Paddling.is_back_seat(seat) else PAD_Y_FRONT
		_pads[seat].position = (size * Vector2(x_fraction, y_fraction)).round()


# --- the mapping, pure --------------------------------------------------------------------------

## The seat a touch at `position` charges in a view of `view_size`: the left half of the
## screen is the left hull and the right half the right hull; the upper half of the screen is
## the front seat and the lower half the back. The midlines count as right and back.
static func seat_for(position: Vector2, view_size: Vector2) -> int:
	var left: bool = position.x < view_size.x * 0.5
	var front: bool = position.y < view_size.y * 0.5
	if left:
		return Paddling.Seat.LEFT_FRONT if front else Paddling.Seat.LEFT_BACK
	return Paddling.Seat.RIGHT_FRONT if front else Paddling.Seat.RIGHT_BACK


## True when the finger was released at least `flick_distance` below where it pressed (a
## flick down, screen pixels): the stroke is a reverse one. Any smaller move, or one up or
## sideways, is a forward stroke.
static func is_reverse(press_position: Vector2, release_position: Vector2, flick_distance: float) -> bool:
	return release_position.y - press_position.y >= flick_distance
