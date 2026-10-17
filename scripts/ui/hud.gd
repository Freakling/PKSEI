extends CanvasLayer
## HUD · shows the crossing (GDD › Core Loop › Moment to moment): the progress bar and each
## guy's drunkenness and stamina with his seat and key. Hidden once the attempt is won, when
## the win cutscene (scenes/win.tscn, GDD › Win and Loss) takes the screen. A screen: it only
## reads RunState every frame.

## The guys' panels in the grid, laid out like the boat: front row, then back row.
const GRID_SEATS: Array[int] = [
	Paddling.Seat.LEFT_FRONT, Paddling.Seat.RIGHT_FRONT,
	Paddling.Seat.LEFT_BACK, Paddling.Seat.RIGHT_BACK,
]
## Seat and key per Paddling.Seat (GDD › Presentation and Platforms).
const SEAT_LABELS: Array[String] = ["LF  Q", "LB  A", "RF  I", "RB  K"]
const DRUNK_COLOUR: Color = Color(0.9, 0.45, 0.2, 1.0)
const STAMINA_COLOUR: Color = Color(0.3, 0.8, 0.35, 1.0)
const BAR_SIZE: Vector2 = Vector2(72, 5)
const FONT_SIZE: int = 10

@onready var _progress: ProgressBar = %Progress
@onready var _guys: GridContainer = %Guys

var _labels: Array[Label] = []
var _drunk_bars: Array[ProgressBar] = []
var _stamina_bars: Array[ProgressBar] = []


func _ready() -> void:
	_labels.resize(RunState.GUY_COUNT)
	_drunk_bars.resize(RunState.GUY_COUNT)
	_stamina_bars.resize(RunState.GUY_COUNT)
	for seat: int in GRID_SEATS:
		var panel: VBoxContainer = VBoxContainer.new()
		var label: Label = Label.new()
		label.add_theme_font_size_override("font_size", FONT_SIZE)
		var drunk: ProgressBar = _make_bar(DRUNK_COLOUR)
		var stamina: ProgressBar = _make_bar(STAMINA_COLOUR)
		panel.add_child(label)
		panel.add_child(drunk)
		panel.add_child(stamina)
		_guys.add_child(panel)
		_labels[seat] = label
		_drunk_bars[seat] = drunk
		_stamina_bars[seat] = stamina


func _process(_delta: float) -> void:
	_progress.value = RunState.progress
	for seat: int in RunState.GUY_COUNT:
		var guy: RunState.Guy = RunState.guys[seat]
		_drunk_bars[seat].value = guy.drunkenness
		_stamina_bars[seat].value = guy.stamina
		_labels[seat].text = SEAT_LABELS[seat] + _state_suffix(seat)
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


## What the guy is doing, after his seat and key.
func _state_suffix(seat: int) -> String:
	match RunState.stamina.state_of(seat):
		Stamina.State.WARNING:
			return "  break soon"
		Stamina.State.BREAK:
			return "  on a break"
		_:
			return ""
