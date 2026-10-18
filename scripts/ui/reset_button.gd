extends Control
class_name ResetButton
## ResetButton · the hold-to-reset corner button on touchscreens (GDD › Presentation and
## Platforms, Reset: a small corner button that must be held for a moment while a ring fills,
## so a stray tap can't reset). A child of TouchPads in lake.tscn's HUD, so it shows and hides
## with the pads and, coming after them in the tree, takes its touches in _input before they
## do: a press inside its rect starts the hold and is marked handled, so it never charges a
## seat; a touch anywhere else is left to the pads. The hold counts up in _process while the
## finger stays down, and draws a ring filling around the icon (reset.png from
## tools/gen_sprites.gd); lifting the finger, or dragging it further than DRAG_SLACK outside
## the rect (a thumb wobbles; B7), before BoatTuning.reset_hold_time cancels the hold and
## nothing happens; reaching it emits
## reset_requested, which the lake answers with a new attempt. Hidden with the HUD once the
## attempt is won, when the cutscene's "any touch" goes again instead. A screen: it only reads
## RunState's tuning. The hold is the pure ResetHold below, which tests/test_reset_button.gd
## runs without a tree.

## The hold reached reset_hold_time: the lake starts a new attempt.
signal reset_requested()

const RESET_TEXTURE: Texture2D = preload("res://assets/sprites/reset.png")
## The filling ring: pixels between the icon's edge and the ring, its width and its colour.
const RING_GAP: float = 2.0
const RING_WIDTH: float = 2.0
const RING_SEGMENTS: int = 32
const RING_COLOUR: Color = Color(1.0, 1.0, 1.0, 0.9)
## The icon's tint while idle and while held.
const IDLE_ALPHA: float = 0.7
const HELD_ALPHA: float = 1.0
## No finger is holding the button.
const NO_FINGER: int = -1
## Pixels (at 1×) a holding finger may drift outside the rect before the hold is cancelled:
## the rect is the target to press, not to stay inside (B7).
const DRAG_SLACK: float = 24.0


## The hold-to-reset rule, pure: how far along a hold of `held_seconds` is toward `hold_time`,
## and whether it has got there.
class ResetHold extends RefCounted:
	## 0 at the press, 1 at hold_time and beyond; a hold_time of zero or less fires at once.
	static func progress(held_seconds: float, hold_time: float) -> float:
		if hold_time <= 0.0:
			return 1.0
		return clampf(held_seconds / hold_time, 0.0, 1.0)

	## True once the finger has been down for hold_time or longer.
	static func fires(held_seconds: float, hold_time: float) -> bool:
		return held_seconds >= hold_time

	## True while a holding finger at `at` is still close enough to `rect` to keep the hold: on
	## it, or within `slack` of it on every side (B7: a thumb drifts a few pixels during a hold).
	static func keeps_hold(rect: Rect2, at: Vector2, slack: float) -> bool:
		return rect.grow(maxf(slack, 0.0)).has_point(at)


## The index of the finger holding the button, NO_FINGER for none, and its seconds down.
var _finger: int = NO_FINGER
var _held: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	RunState.run_reset.connect(_cancel)


func _process(delta: float) -> void:
	if _finger == NO_FINGER:
		return
	_held += delta
	queue_redraw()
	if ResetHold.fires(_held, _hold_time()):
		_cancel()
		reset_requested.emit()


## A press inside the rect starts the hold and is handled, so the pads never charge a seat
## from it; the hold's finger lifting or leaving the rect cancels it. Touches elsewhere pass
## on to the pads. Nothing is taken while hidden (keyboard play, or the HUD gone on the win).
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			if _finger == NO_FINGER and get_global_rect().has_point(touch.position):
				_finger = touch.index
				_held = 0.0
				queue_redraw()
				get_viewport().set_input_as_handled()
		elif touch.index == _finger:
			_cancel()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if drag.index == _finger:
			if not ResetHold.keeps_hold(get_global_rect(), drag.position, DRAG_SLACK):
				_cancel()
			get_viewport().set_input_as_handled()


## Visual only: the icon centred, brighter while held, with the ring filling clockwise from
## the top around it by the hold's progress.
func _draw() -> void:
	var centre: Vector2 = size * 0.5
	var held: bool = _finger != NO_FINGER
	var icon_size: Vector2 = RESET_TEXTURE.get_size()
	draw_texture(RESET_TEXTURE, (centre - icon_size * 0.5).round(),
			Color(1.0, 1.0, 1.0, HELD_ALPHA if held else IDLE_ALPHA))
	if not held:
		return
	var fraction: float = ResetHold.progress(_held, _hold_time())
	if fraction <= 0.0:
		return
	var radius: float = icon_size.x * 0.5 + RING_GAP + RING_WIDTH * 0.5
	draw_arc(centre, radius, -PI / 2.0, -PI / 2.0 + TAU * fraction, RING_SEGMENTS, RING_COLOUR, RING_WIDTH)


## The hold is over, fired or not: no finger, no ring.
func _cancel() -> void:
	_finger = NO_FINGER
	_held = 0.0
	queue_redraw()


func _hold_time() -> float:
	return RunState.paddling.tuning.reset_hold_time
