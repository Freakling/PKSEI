extends Node
## RunState · the current attempt at the crossing (GDD › Core Loop › Starting conditions,
## GDD › Win and Loss).
##
## Holds the state and owns the rule classes that change it: four guys, progress along the
## crossing, elapsed time and the phase, plus one Paddling, Drunkenness, Stamina and Rescue (with
## their data/*.tres tunings) and one RandomNumberGenerator for their rolls. The boat scene calls
## stroke() on each key release and step() once per physics frame, and applies the Motion it
## gets back; the lake sets progress from the boat's position, calls arrive() at the island,
## pickup() when the boat reaches a floating guy and shore_touched() whenever the boat touches
## the shore; RunState decides whether that is a shore reset. Hazards (T10) call
## beer_overboard(); a guy who falls in without a beer (T13) goes through guy_overboard().
## Screens only read. Reads and writes no player data.

## One of the four guys. Each has his own drunkenness and stamina (GDD › Drunkenness, Stamina);
## step() mirrors the rule classes' levels into them so screens read one place.
class Guy extends RefCounted:
	var seat: int = 0
	var drunkenness: float = 0.0
	var stamina: float = 1.0
	var aboard: bool = true

	func _init(guy_seat: int, start_drunkenness: float) -> void:
		seat = guy_seat
		drunkenness = start_drunkenness
		stamina = STAMINA_FULL
		aboard = true


## A stroke that has been released but hasn't landed yet (GDD › Drunkenness: lag).
class PendingStroke extends RefCounted:
	var stroke: Paddling.Stroke
	var time_left: float = 0.0

	func _init(pending: Paddling.Stroke, delay: float) -> void:
		stroke = pending
		time_left = delay


## Phases of an attempt: at the shore, under way, and arrived with all four aboard
## (GDD › Win and Loss). The win cutscene is T28's.
enum Phase { LAUNCH, CROSSING, WON }

const GUY_COUNT: int = 4
## Full stamina (GDD › Setbacks: the shore reset restores "stamina full").
const STAMINA_FULL: float = 1.0

## Emitted after reset() has restored the starting conditions.
signal run_reset()
## Emitted after a shore reset: the boat under way touched the shore, and the attempt is back
## at its starting conditions (after run_reset). The lake puts the boat back at its start.
signal shore_reset_done()

var guys: Array[Guy] = []
## 0.0 at the shore, 1.0 at the island; the lake sets it with set_progress().
var progress: float = 0.0
var elapsed: float = 0.0
var phase: Phase = Phase.LAUNCH

var paddling: Paddling = Paddling.new(preload("res://data/boat_tuning.tres") as BoatTuning)
var drunkenness: Drunkenness = Drunkenness.new(preload("res://data/drink_tuning.tres") as DrinkTuning)
var stamina: Stamina = Stamina.new(preload("res://data/stamina_tuning.tres") as StaminaTuning)
## The guys in the water and their beers; reads its tunables from paddling's BoatTuning.
var rescue: Rescue = Rescue.new()
## Rolls the misses and the random breaks; tests seed it.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _pending: Array[PendingStroke] = []


func _ready() -> void:
	if Engine.has_meta("godot_director_check"):
		return
	reset()


## Restores the starting conditions (also the shore reset, GDD › Setbacks): four guys at
## DrinkTuning.start_level, all aboard, stamina full, zero progress, phase `launch`.
func reset() -> void:
	drunkenness.reset()
	stamina.reset()
	rescue.reset()
	_pending.clear()
	guys.clear()
	for seat: int in GUY_COUNT:
		guys.append(Guy.new(seat, drunkenness.level_of(seat)))
	progress = 0.0
	elapsed = 0.0
	phase = Phase.LAUNCH
	run_reset.emit()


## The boat touched the shore. Once it is under way (CROSSING) that is the shore reset
## (GDD › Setbacks, Shore reset), with or without anyone in the water: the attempt returns to
## its starting conditions, then shore_reset_done tells the lake to replace the boat. While
## launching the boat rests against the shore, so nothing happens; nor after the win.
func shore_touched() -> void:
	if phase != Phase.CROSSING:
		return
	reset()
	shore_reset_done.emit()


## A hazard knocked a beer over on `side` with the boat at `at_position`: the beer lands
## beer_toss to that side, and the guy Rescue picks (that hull, front first) jumps in after it
## and is no longer aboard. Returns his seat, or Rescue.NOBODY when nobody was aboard.
func beer_overboard(side: Rescue.Hull, at_position: Vector2) -> int:
	var toss: float = paddling.tuning.beer_toss
	var beer_at: Vector2 = at_position + Vector2(-toss if side == Rescue.Hull.LEFT else toss, 0.0)
	var seat: int = rescue.beer_overboard(side, _seats_aboard(), at_position, beer_at)
	if seat != Rescue.NOBODY:
		guys[seat].aboard = false
	return seat


## A guy fell in without a beer (GDD › Drunkenness: the pee antic, T13): he floats from the
## start and doesn't drink. Nothing happens if he is already in the water.
func guy_overboard(seat: int, at_position: Vector2) -> void:
	if not guys[seat].aboard:
		return
	rescue.guy_overboard(seat, at_position)
	guys[seat].aboard = false


## The boat reached him: he is aboard again. Returns whether he brought his beer back.
func pickup(seat: int) -> bool:
	var had_beer: bool = rescue.pickup(seat)
	guys[seat].aboard = true
	return had_beer


## One key released: `seat` is the key's owner, `hold_time` how long it was held. Nothing
## happens if he is on a break, in the water, or the attempt is over. He burns stamina for the
## stroke's power at once; the stroke then lands after his drunkenness's lag, or misses. On the
## timing bar (drunkenness.uses_bar) a release outside the green zone is a backwards stroke of
## the same power, so it burns the same stamina: he swung.
func stroke(seat: int, hold_time: float) -> void:
	if phase == Phase.WON:
		return
	if not guys[seat].aboard or not stamina.can_stroke(seat):
		return
	var level: float = drunkenness.level_of(seat)
	stamina.burn(seat, paddling.stroke_force(hold_time))
	guys[seat].stamina = stamina.level_of(seat)
	if drunkenness.misses(level, rng):
		return
	var backwards: bool = drunkenness.uses_bar(seat) and not drunkenness.bar_hit(hold_time)
	var pending: Paddling.Stroke = Paddling.Stroke.new(seat, hold_time, backwards)
	_pending.append(PendingStroke.new(pending, drunkenness.stroke_delay(level)))


## One physics frame: the swimmers and their beers move with the current, every guy drinks
## (a floating guy with his beer at the water rate; one without a beer not at all) and recovers
## or breaks, the levels are mirrored into the guys, elapsed advances, and
## the strokes that land this frame become the boat's Motion. With nobody aboard the Motion is
## only the current's drift. Nothing moves once the attempt is won.
func step(delta: float) -> Paddling.Motion:
	if phase == Phase.WON:
		return Paddling.Motion.new()
	elapsed += delta
	rescue.step(delta, Vector2.DOWN * paddling.tuning.current_speed, paddling.tuning)
	for seat: int in GUY_COUNT:
		var guy: Guy = guys[seat]
		stamina.step(seat, delta, rng)
		var swimmer: Rescue.Swimmer = rescue.swimmer_of(seat)
		var in_water: bool = swimmer != null
		var drinking: bool = not in_water or swimmer.has_beer
		drunkenness.drink(seat, delta, guy.aboard and stamina.on_break(seat), in_water, drinking)
		guy.stamina = stamina.level_of(seat)
		guy.drunkenness = drunkenness.level_of(seat)
	return paddling.step(_land_strokes(delta), delta)


## Where the boat is between the shore (0) and the island (1). Leaving the shore starts the
## crossing.
func set_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	if phase == Phase.LAUNCH and progress > 0.0:
		phase = Phase.CROSSING


## The boat has touched the island: the attempt is won if all four are aboard
## (GDD › Win and Loss); otherwise nothing happens and the boat can come back for them.
func arrive() -> void:
	if phase != Phase.WON and all_aboard():
		phase = Phase.WON


func all_aboard() -> bool:
	for guy: Guy in guys:
		if not guy.aboard:
			return false
	return true


func _seats_aboard() -> Array[int]:
	var seats: Array[int] = []
	for guy: Guy in guys:
		if guy.aboard:
			seats.append(guy.seat)
	return seats


## Counts the pending strokes down by `delta` and returns the ones that land now.
func _land_strokes(delta: float) -> Array[Paddling.Stroke]:
	var landed: Array[Paddling.Stroke] = []
	var waiting: Array[PendingStroke] = []
	for pending: PendingStroke in _pending:
		pending.time_left -= delta
		if pending.time_left <= 0.0:
			landed.append(pending.stroke)
		else:
			waiting.append(pending)
	_pending = waiting
	return landed
