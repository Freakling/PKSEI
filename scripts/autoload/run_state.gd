extends Node
## RunState · the current attempt at the crossing (GDD › Core Loop › Starting conditions,
## GDD › Win and Loss).
##
## Holds the state and owns the rule classes that change it: four guys, progress along the
## crossing, elapsed time and the phase, plus one Paddling, Drunkenness and Stamina (with their
## data/*.tres tunings) and one RandomNumberGenerator for their rolls. The boat scene calls
## stroke() on each key release and step() once per physics frame, and applies the Motion it
## gets back; the lake sets progress from the boat's position and calls arrive() at the island.
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

var guys: Array[Guy] = []
## 0.0 at the shore, 1.0 at the island; the lake sets it with set_progress().
var progress: float = 0.0
var elapsed: float = 0.0
var phase: Phase = Phase.LAUNCH

var paddling: Paddling = Paddling.new(preload("res://data/boat_tuning.tres") as BoatTuning)
var drunkenness: Drunkenness = Drunkenness.new(preload("res://data/drink_tuning.tres") as DrinkTuning)
var stamina: Stamina = Stamina.new(preload("res://data/stamina_tuning.tres") as StaminaTuning)
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
	_pending.clear()
	guys.clear()
	for seat: int in GUY_COUNT:
		guys.append(Guy.new(seat, drunkenness.level_of(seat)))
	progress = 0.0
	elapsed = 0.0
	phase = Phase.LAUNCH
	run_reset.emit()


## One key released: `seat` is the key's owner, `hold_time` how long it was held. The key drives
## drunkenness.key_target(seat) (his own seat, or the one beside him while scrambled); nothing
## happens if that guy is on a break, in the water, or the attempt is over. He burns stamina for
## the stroke's power at once; the stroke then lands after his drunkenness's lag, or misses.
func stroke(seat: int, hold_time: float) -> void:
	if phase == Phase.WON:
		return
	var target: int = drunkenness.key_target(seat)
	if not guys[target].aboard or not stamina.can_stroke(target):
		return
	var level: float = drunkenness.level_of(target)
	stamina.burn(target, paddling.stroke_force(hold_time))
	guys[target].stamina = stamina.level_of(target)
	if drunkenness.misses(level, rng):
		return
	var pending: Paddling.Stroke = Paddling.Stroke.new(target, hold_time)
	_pending.append(PendingStroke.new(pending, drunkenness.stroke_delay(level)))


## One physics frame: every guy drinks and recovers or breaks, the levels are mirrored into
## the guys, elapsed advances, and the strokes that land this frame become the boat's Motion.
## Nothing moves once the attempt is won.
func step(delta: float) -> Paddling.Motion:
	if phase == Phase.WON:
		return Paddling.Motion.new()
	elapsed += delta
	for seat: int in GUY_COUNT:
		var guy: Guy = guys[seat]
		stamina.step(seat, delta, rng)
		drunkenness.drink(seat, delta, stamina.on_break(seat), not guy.aboard)
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
