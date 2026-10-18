class_name Stamina
extends RefCounted
## Stamina · what strokes cost the four guys and when they take a break
## (GDD › Systems › Stamina, GDD › Core Loop › Moment to moment).
##
## A plain rule class: it receives its StaminaTuning and never touches the scene tree or RunState.
## It holds one level per seat (seats equal RunState.Guy.seat and Paddling.Seat) on a 0..1 scale,
## 0 burnt out and 1 full. A stroke burns burn_per_power times its power, the stroke force
## Paddling.stroke_force() computes from the hold time; the boat scene calls burn() with it.
##
## Each seat runs a small state machine, advanced by step():
##   PADDLING: recovers at recover_rate; a burnt-out guy (level 0) or a random roll per
##             random_break_curve calls a break;
##   WARNING:  the telegraph, break_warning seconds; he still paddles and recovers at recover_rate;
##   BREAK:    break_duration seconds with no strokes (can_stroke() is false), recovering at
##             break_recover_rate; then back to PADDLING.
## Random breaks are rolled from the caller's RandomNumberGenerator, so tests seed it. Faster
## drinking on a break is Drunkenness's rule; the caller passes it on_break().

## What a seat is doing.
enum State { PADDLING, WARNING, BREAK }

var tuning: StaminaTuning
## One level per seat, 0..1.
var levels: Array[float] = []
## One State per seat.
var states: Array[State] = []
## Seconds left in the current WARNING or BREAK per seat; 0 while PADDLING.
var times_left: Array[float] = []


func _init(stamina_tuning: StaminaTuning) -> void:
	tuning = stamina_tuning
	reset()


## Every guy back to full and paddling (the starting conditions and the shore reset).
func reset() -> void:
	levels.clear()
	states.clear()
	times_left.clear()
	for seat: int in Paddling.Seat.size():
		levels.append(1.0)
		states.append(State.PADDLING)
		times_left.append(0.0)


func level_of(seat: int) -> float:
	return levels[seat]


func set_level(seat: int, level: float) -> void:
	levels[seat] = clampf(level, 0.0, 1.0)


func state_of(seat: int) -> State:
	return states[seat]


## Seconds left of this guy's warning or break; 0 while he paddles.
func time_left(seat: int) -> float:
	return times_left[seat]


## Whether this seat gives strokes: yes while paddling and during the warning, no on a break.
func can_stroke(seat: int) -> bool:
	return states[seat] != State.BREAK


func on_break(seat: int) -> bool:
	return states[seat] == State.BREAK


## Whether this guy has no stamina left, so his next step calls a break.
func burnt_out(seat: int) -> bool:
	return levels[seat] <= 0.0


## Fraction of this guy's stamina he has burnt, 0 full to 1 burnt out.
func burnt_fraction(seat: int) -> float:
	return 1.0 - levels[seat]


## Burns one stroke of this power off a guy's stamina and returns his level.
func burn(seat: int, power: float) -> float:
	levels[seat] = clampf(levels[seat] - burn_of(power), 0.0, 1.0)
	return levels[seat]


## Stamina a stroke of this power costs: burn_per_power per unit of power.
func burn_of(power: float) -> float:
	return maxf(tuning.burn_per_power * power, 0.0)


## Advances one guy by `delta` seconds and returns his state: recovery, the warning and break
## timers, and the break calls. `rng` rolls the random breaks.
func step(seat: int, delta: float, rng: RandomNumberGenerator) -> State:
	match states[seat]:
		State.PADDLING:
			if burnt_out(seat) or rolls_break(seat, delta, rng):
				call_break(seat)
			_recover(seat, tuning.recover_rate, delta)
		State.WARNING:
			_recover(seat, tuning.recover_rate, delta)
			if _tick(seat, delta):
				_enter(seat, State.BREAK, tuning.break_duration)
		State.BREAK:
			_recover(seat, tuning.break_recover_rate, delta)
			if _tick(seat, delta):
				_enter(seat, State.PADDLING, 0.0)
	return states[seat]


## Starts the telegraph for a break now: break_warning seconds of WARNING, then the break.
## Does nothing to a guy already warned or on a break.
func call_break(seat: int) -> void:
	if states[seat] == State.PADDLING:
		_enter(seat, State.WARNING, tuning.break_warning)


## Chance per second 0..1 of a random break at this level, per random_break_curve at the burnt
## fraction (1 − level).
func random_break_chance(level: float) -> float:
	if tuning.random_break_curve == null:
		return 0.0
	return clampf(tuning.random_break_curve.sample(clampf(1.0 - level, 0.0, 1.0)), 0.0, 1.0)


## Rolls whether this guy takes a random break in a step of `delta` seconds: the per-second
## chance at his level, scaled by the step. No roll is spent when the chance is zero.
func rolls_break(seat: int, delta: float, rng: RandomNumberGenerator) -> bool:
	var chance: float = random_break_chance(levels[seat]) * delta
	if chance <= 0.0:
		return false
	return rng.randf() < chance


func _recover(seat: int, rate: float, delta: float) -> void:
	levels[seat] = clampf(levels[seat] + rate * delta, 0.0, 1.0)


## Counts down the current state's timer; true once it has run out.
func _tick(seat: int, delta: float) -> bool:
	times_left[seat] = maxf(times_left[seat] - delta, 0.0)
	return times_left[seat] <= 0.0


func _enter(seat: int, state: State, duration: float) -> void:
	states[seat] = state
	times_left[seat] = maxf(duration, 0.0)


## The dev menu's inspector (T72, tools/dev_menu.gd): per seat, the level, the state and its time left.
func debug_inspect() -> Dictionary:
	var values: Dictionary = {}
	for seat: int in levels.size():
		values["seat %d" % seat] = "level %.2f, %s, %.1fs left" % [levels[seat],
				str(State.keys()[states[seat]]).to_lower(), times_left[seat]]
	return values
