extends CanvasLayer
class_name Hud
## HUD · shows the crossing (GDD › Core Loop › Moment to moment): the progress bar and each
## guy's drunkenness and stamina under his name (T68, GDD › Characters and Units: the names, not
## the keys; the sand text teaches those), with a status line under the name saying what he is
## doing whenever he is not available to paddle (T79): in the water (after the beer, drinking,
## fallen in, swimming back, washed up), his antic and its wind-up by kind (taking a piss,
## puking, asleep, standing up, the paddle dropped), the jump after a beer, a snag, his break
## and its warning, bailing, and the timing bar; empty while he just paddles. The line is in a
## warning colour so a guy who isn't responding is explained at a glance (status_text, pure).
## Hidden once the attempt is won, when the win cutscene (scenes/win.tscn, GDD › Win and Loss)
## takes the screen. A screen: it only reads RunState every frame.

## The guys' panels in the grid, laid out like the boat: front row, then back row.
const GRID_SEATS: Array[int] = [
	Paddling.Seat.LEFT_FRONT, Paddling.Seat.RIGHT_FRONT,
	Paddling.Seat.LEFT_BACK, Paddling.Seat.RIGHT_BACK,
]
const DRUNK_COLOUR: Color = Color(0.9, 0.45, 0.2, 1.0)
const STAMINA_COLOUR: Color = Color(0.3, 0.8, 0.35, 1.0)
const STATUS_COLOUR: Color = Color(1.0, 0.9, 0.3, 1.0)
const BAR_SIZE: Vector2 = Vector2(72, 5)
const FONT_SIZE: int = 10
const STATUS_FONT_SIZE: int = 9
## A guy washed up on the shore: the swim kind SpeechBubbles.swim_kind() has no name for.
const WASHED_UP: StringName = &"washed_up"

## What the status line says for a guy in the water, by his swim kind.
const WATER_TEXT: Dictionary[StringName, String] = {
	SpeechBubbles.SWIM_FETCH_KIND: "swimming after the beer",
	SpeechBubbles.SWIM_DRINK_KIND: "drinking in the lake",
	SpeechBubbles.SWIM_FELL_KIND: "fell in!",
	SpeechBubbles.SWIM_BACK_KIND: "swimming back",
	WASHED_UP: "washed up ashore",
}
## What it says while an antic winds up, by kind, and while it runs, by state.
const WINDUP_TEXT: Dictionary[Antics.Kind, String] = {
	Antics.Kind.STAND: "about to stand up",
	Antics.Kind.DROP_PADDLE: "fumbling the paddle",
	Antics.Kind.NOD_OFF: "dozing off",
	Antics.Kind.PEE: "needs a piss",
	Antics.Kind.PUKE: "feeling sick",
}
const ANTIC_TEXT: Dictionary[Antics.State, String] = {
	Antics.State.STANDING: "standing up!",
	Antics.State.PADDLE_DROPPED: "dropped the paddle!",
	Antics.State.NODDED_OFF: "asleep",
	Antics.State.PEEING: "taking a piss",
	Antics.State.PUKING: "puking",
	Antics.State.RECOVERING: "sitting back down",
}
const JUMP_TEXT: String = "going after the beer"
const SNAG_TEXT: String = "snagged on a line"
const BREAK_TEXT: String = "on a break, drinking"
const WARNING_TEXT: String = "break soon"
const BAILING_TEXT: String = "bailing water"
const BAR_TEXT: String = "seeing double"

@onready var _progress: ProgressBar = %Progress
@onready var _guys: GridContainer = %Guys

var _labels: Array[Label] = []
var _status: Array[Label] = []
var _drunk_bars: Array[ProgressBar] = []
var _stamina_bars: Array[ProgressBar] = []


func _ready() -> void:
	_labels.resize(RunState.GUY_COUNT)
	_status.resize(RunState.GUY_COUNT)
	_drunk_bars.resize(RunState.GUY_COUNT)
	_stamina_bars.resize(RunState.GUY_COUNT)
	for seat: int in GRID_SEATS:
		var panel: VBoxContainer = VBoxContainer.new()
		var label: Label = Label.new()
		label.add_theme_font_size_override("font_size", FONT_SIZE)
		var status: Label = Label.new()
		status.add_theme_font_size_override("font_size", STATUS_FONT_SIZE)
		status.add_theme_color_override("font_color", STATUS_COLOUR)
		var drunk: ProgressBar = _make_bar(DRUNK_COLOUR)
		var stamina: ProgressBar = _make_bar(STAMINA_COLOUR)
		panel.add_child(label)
		panel.add_child(status)
		panel.add_child(drunk)
		panel.add_child(stamina)
		_guys.add_child(panel)
		_labels[seat] = label
		_status[seat] = status
		_drunk_bars[seat] = drunk
		_stamina_bars[seat] = stamina


func _process(_delta: float) -> void:
	_progress.value = RunState.progress
	for seat: int in RunState.GUY_COUNT:
		var guy: RunState.Guy = RunState.guys[seat]
		_drunk_bars[seat].value = guy.drunkenness
		_stamina_bars[seat].value = guy.stamina
		_labels[seat].text = RunState.name_of(seat)
		_status[seat].text = status_text(_swim_kind_of(seat), RunState.antics.state_of(seat),
				RunState.antics.kind_of(seat), RunState.rescue.winding_up(seat),
				RunState.is_snagged(seat), RunState.stamina.state_of(seat),
				RunState.is_bailing(seat), RunState.drunkenness.uses_bar(seat))
	visible = RunState.phase != RunState.Phase.WON


func _make_bar(fill: Color) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.max_value = 1.0
	bar.step = 0.001
	bar.show_percentage = false
	bar.custom_minimum_size = BAR_SIZE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	bar.add_theme_stylebox_override("fill", style)
	return bar


## The guy's swim kind when he is in the water (WASHED_UP ashore), empty aboard.
func _swim_kind_of(seat: int) -> StringName:
	var swimmer: Rescue.Swimmer = RunState.rescue.swimmer_of(seat)
	if swimmer == null:
		return &""
	if swimmer.washed_up:
		return WASHED_UP
	return SpeechBubbles.swim_kind(swimmer.state, swimmer.has_beer, swimmer.adrift,
			RunState.paddling.tuning.swim_back_delay, swimmer.washed_up)


# --- the status line, pure ---------------------------------------------------------------------

## What a guy is doing, for the line under his name: the first that applies of being in the
## water (`swim`, a SpeechBubbles swim kind or WASHED_UP; empty aboard), his antic (its wind-up
## by `kind`, then its state), the jump after a beer, a snag, his break then its warning,
## bailing, and the timing bar; "" when he is simply paddling.
static func status_text(swim: StringName, antic: Antics.State, kind: Antics.Kind,
		jump_winding_up: bool, snagged: bool, stamina: Stamina.State, bailing: bool,
		bar: bool) -> String:
	if not swim.is_empty():
		return WATER_TEXT.get(swim, "in the water")
	if antic == Antics.State.WINDING_UP:
		return WINDUP_TEXT.get(kind, "up to something")
	if ANTIC_TEXT.has(antic):
		return ANTIC_TEXT[antic]
	if jump_winding_up:
		return JUMP_TEXT
	if snagged:
		return SNAG_TEXT
	if stamina == Stamina.State.BREAK:
		return BREAK_TEXT
	if stamina == Stamina.State.WARNING:
		return WARNING_TEXT
	if bailing:
		return BAILING_TEXT
	if bar:
		return BAR_TEXT
	return ""
