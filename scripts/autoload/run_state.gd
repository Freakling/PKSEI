extends Node
## RunState · the current attempt at the crossing (GDD › Core Loop › Starting conditions).
##
## Holds state only: four guys, progress along the crossing, elapsed time and the phase.
## Rules that change this state live in scripts/systems/ (paddling, drunkenness, stamina) and
## arrive with their own items. Reads and writes no player data.

## One of the four guys. Each has his own drunkenness and stamina (GDD › Drunkenness, Stamina).
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


## Phases of an attempt. `won` is added by T28 (GDD › Win and Loss).
enum Phase { LAUNCH }

const GUY_COUNT: int = 4
## Full stamina (GDD › Setbacks: the shore reset restores "stamina full").
const STAMINA_FULL: float = 1.0
## "Mildly tipsy" on a 0..1 drunkenness scale. ## PLACEHOLDER: tuned once T5 lands its schema.
const STARTING_DRUNKENNESS: float = 0.15

## Emitted after reset() has restored the starting conditions.
signal run_reset()

var guys: Array[Guy] = []
## 0.0 at the shore, rising toward the island.
var progress: float = 0.0
var elapsed: float = 0.0
var phase: Phase = Phase.LAUNCH


func _ready() -> void:
	if Engine.has_meta("godot_director_check"):
		return
	reset()


## Restores the starting conditions (also the shore reset, GDD › Setbacks): four guys, mildly
## tipsy, all aboard, stamina full, zero progress, phase `launch`.
func reset() -> void:
	guys.clear()
	for seat: int in GUY_COUNT:
		guys.append(Guy.new(seat, STARTING_DRUNKENNESS))
	progress = 0.0
	elapsed = 0.0
	phase = Phase.LAUNCH
	run_reset.emit()
