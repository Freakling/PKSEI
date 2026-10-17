extends Control
class_name SpeechBubbles
## SpeechBubbles · one Swedish speech bubble per guy over his seat (GDD › World and Narrative:
## the guys speak Swedish; every telegraph gets a bubble, so the warning is also the joke). Lives
## under lake.tscn's HUD CanvasLayer, so its coordinates are screen pixels: each frame it maps a
## guy's lake position (the boat's guy_global_position) through the world canvas transform, as
## OffscreenArrows does, and sits his bubble (a Label in a rounded panel with a tail) just above
## him. For his own wind-ups it reads the states catamaran.gd reads (GDD › Systems › Drunkenness,
## Stamina; GDD › Systems › Setbacks for the jump): an antic's wind-up, the jump after a beer, the
## break warning and the timing bar's wind-up, in that order of priority, each a kind in
## Lines.KINDS (windup_kind); the line is drawn once per wind-up through RunState.pick_line() and
## the bubble goes away at the effect, when the wind-up state ends. For a hazard it listens to
## RunState.telegraphed and puts the line on the guy on that hull (front seat first; any aboard
## guy when the hull is empty or unknown: speaker_for, Rescue's jumper rule) for
## BoatTuning.call_out_time seconds, over his wind-up's bubble while it lasts. A guy in the water
## shows no bubble, nor does anyone once the attempt is won; a reset clears them all. A screen:
## it only reads RunState and calls its methods; it rolls nothing. The pure parts are static, so
## tests/test_speech_bubbles.gd runs them without a tree.

const FONT_SIZE: int = 8
const BUBBLE_COLOUR: Color = Color(1.0, 1.0, 1.0, 1.0)
const BORDER_COLOUR: Color = Color(0.1, 0.1, 0.1, 1.0)
const TEXT_COLOUR: Color = Color(0.1, 0.1, 0.1, 1.0)
const CORNER_RADIUS: int = 3
const BORDER_WIDTH: int = 1
## The panel's padding around the text (pixels): sides, then top and bottom.
const PAD_X: int = 3
const PAD_Y: int = 1
## The tail under the bubble: its height below the panel and half its width at the base.
const TAIL_HEIGHT: float = 3.0
const TAIL_HALF_WIDTH: float = 2.0
## Pixels from the guy's sprite centre up to the tail's tip.
const LIFT: float = 8.0
## The line kind for each antic's wind-up (Antics.Kind).
const ANTIC_KINDS: Dictionary[int, StringName] = {
	Antics.Kind.STAND: &"antic_stand",
	Antics.Kind.DROP_PADDLE: &"antic_paddle",
	Antics.Kind.NOD_OFF: &"antic_nap",
	Antics.Kind.PEE: &"antic_pee",
	Antics.Kind.PUKE: &"antic_puke",
}
const STAMINA_KIND: StringName = &"stamina_warning"
const BAR_KIND: StringName = &"bar_windup"
const JUMP_KIND: StringName = &"jump_windup"

## The boat, set in lake.tscn: where each guy is on the lake.
@export var boat: CharacterBody2D

var _bubbles: Array[PanelContainer] = []
var _labels: Array[Label] = []
var _tails: Array[Polygon2D] = []
## Per seat, the kind of the wind-up his bubble shows now (empty for none) and its line, drawn
## once when the wind-up starts.
var _windup_kinds: Array[StringName] = [&"", &"", &"", &""]
var _windup_lines: Array[String] = ["", "", "", ""]
## Per seat, the hazard line he is calling out (empty for none) and its seconds left.
var _call_outs: Array[String] = ["", "", "", ""]
var _call_out_left: Array[float] = [0.0, 0.0, 0.0, 0.0]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for seat: int in RunState.GUY_COUNT:
		_bubbles.append(_build_bubble(seat))
	RunState.telegraphed.connect(_on_telegraphed)
	RunState.run_reset.connect(_clear)


func _process(delta: float) -> void:
	var to_screen: Transform2D = get_viewport().get_canvas_transform()
	var won: bool = RunState.phase == RunState.Phase.WON
	for seat: int in _bubbles.size():
		_call_out_left[seat] = maxf(_call_out_left[seat] - delta, 0.0)
		if _call_out_left[seat] <= 0.0:
			_call_outs[seat] = ""
		var aboard: bool = RunState.guys[seat].aboard and not won
		var kind: StringName = _windup_kind_of(seat) if aboard else &""
		if kind != _windup_kinds[seat]:
			_windup_kinds[seat] = kind
			_windup_lines[seat] = RunState.pick_line(kind) if not kind.is_empty() else ""
		var text: String = _call_outs[seat] if not _call_outs[seat].is_empty() else _windup_lines[seat]
		var bubble: PanelContainer = _bubbles[seat]
		bubble.visible = aboard and boat != null and not text.is_empty()
		if not bubble.visible:
			continue
		if _labels[seat].text != text:
			_labels[seat].text = text
			bubble.reset_size()
		var guy_at: Vector2 = to_screen * boat.guy_global_position(seat)
		bubble.position = bubble_position(guy_at, bubble.size, TAIL_HEIGHT + LIFT)
		_tails[seat].position = Vector2(bubble.size.x * 0.5, bubble.size.y)


## The kind of wind-up this guy is in now, from the states catamaran.gd shows (empty for none).
func _windup_kind_of(seat: int) -> StringName:
	return windup_kind(RunState.antics.state_of(seat), RunState.antics.kind_of(seat),
			RunState.rescue.winding_up(seat), RunState.stamina.state_of(seat),
			RunState.drunkenness.bar_winding_up(seat))


## A hazard's warning started: the guy on its hull calls it out for call_out_time.
func _on_telegraphed(kind: StringName, hull: int) -> void:
	var seat: int = speaker_for(hull, _seats_aboard())
	if seat == Rescue.NOBODY:
		return
	var line: String = RunState.pick_line(kind)
	if line.is_empty():
		return
	_call_outs[seat] = line
	_call_out_left[seat] = RunState.paddling.tuning.call_out_time


## A reset (the shore reset, a new attempt): nothing is being said.
func _clear() -> void:
	for seat: int in _bubbles.size():
		_windup_kinds[seat] = &""
		_windup_lines[seat] = ""
		_call_outs[seat] = ""
		_call_out_left[seat] = 0.0
		_bubbles[seat].visible = false


func _seats_aboard() -> Array[int]:
	var seats: Array[int] = []
	for guy: RunState.Guy in RunState.guys:
		if guy.aboard:
			seats.append(guy.seat)
	return seats


## One guy's bubble: a rounded white panel holding his label, with a tail below its bottom
## centre; hidden until he has something to say.
func _build_bubble(seat: int) -> PanelContainer:
	var bubble: PanelContainer = PanelContainer.new()
	bubble.name = "Bubble%d" % seat
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.visible = false
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = BUBBLE_COLOUR
	style.border_color = BORDER_COLOUR
	style.set_border_width_all(BORDER_WIDTH)
	style.set_corner_radius_all(CORNER_RADIUS)
	style.anti_aliasing = false
	style.content_margin_left = PAD_X
	style.content_margin_right = PAD_X
	style.content_margin_top = PAD_Y
	style.content_margin_bottom = PAD_Y
	bubble.add_theme_stylebox_override("panel", style)
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", TEXT_COLOUR)
	bubble.add_child(label)
	_labels.append(label)
	var tail: Polygon2D = Polygon2D.new()
	tail.name = "Tail"
	tail.color = BUBBLE_COLOUR
	# Its base starts inside the panel's border, so the border doesn't cut it off.
	tail.polygon = PackedVector2Array([
		Vector2(-TAIL_HALF_WIDTH, -BORDER_WIDTH), Vector2(TAIL_HALF_WIDTH, -BORDER_WIDTH),
		Vector2(0.0, TAIL_HEIGHT),
	])
	bubble.add_child(tail)
	_tails.append(tail)
	add_child(bubble)
	return bubble


# --- the rules of what shows, pure ---------------------------------------------------------------

## The line kind for a guy's wind-up now, by priority: an antic's wind-up (its kind's line), the
## jump after a beer, the break warning, then the timing bar's wind-up; empty for none.
static func windup_kind(antic: Antics.State, antic_kind: Antics.Kind, jump_winding_up: bool,
		stamina: Stamina.State, bar_winding_up: bool) -> StringName:
	if antic == Antics.State.WINDING_UP:
		return ANTIC_KINDS[antic_kind] if ANTIC_KINDS.has(antic_kind) else &""
	if jump_winding_up:
		return JUMP_KIND
	if stamina == Stamina.State.WARNING:
		return STAMINA_KIND
	if bar_winding_up:
		return BAR_KIND
	return &""


## Who calls a hazard on `hull` out: the aboard guy on that hull, front first; any aboard guy
## when that hull is empty or the hull is Rescue.NOBODY; NOBODY with nobody aboard.
static func speaker_for(hull: int, seats_aboard: Array[int]) -> int:
	var side: Rescue.Hull = Rescue.Hull.LEFT if hull != Rescue.Hull.RIGHT else Rescue.Hull.RIGHT
	return Rescue.jumper(side, seats_aboard)


## Where a bubble of `size` sits over a guy at `guy_at` (screen pixels): its tail's tip `lift`
## above him, the bubble centred on him, on whole pixels.
static func bubble_position(guy_at: Vector2, size: Vector2, lift: float) -> Vector2:
	return (guy_at - Vector2(size.x * 0.5, size.y + lift)).round()
