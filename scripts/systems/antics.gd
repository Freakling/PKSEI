class_name Antics
extends RefCounted
## Antics · the stupid things a guy does at drunkenness thresholds (GDD › Systems › Drunkenness,
## the middle tier).
##
## A plain rule class: it receives its DrinkTuning and never touches the scene tree or RunState.
## Each seat (seats equal RunState.Guy.seat and Paddling.Seat) runs a small state machine,
## advanced by step() with the guy's drunkenness level:
##   IDLE:           nothing; a threshold crossing starts a wind-up;
##   WINDING_UP:     the telegraph, windup_time seconds; he still paddles;
##   STANDING:       stand_time seconds rocking the boat: rock() is a yaw impulse per second the
##                   caller adds to the boat's turn, swinging side to side; he still paddles;
##   PADDLE_DROPPED: fish_time seconds with no strokes while he fishes the paddle out;
##   NODDED_OFF:     nap_time seconds as dead weight: no strokes;
##   PEEING:         pee_time seconds at the hull's edge with no strokes; a shove of
##                   pee_fall_shove or more lands him in the water (knocked_in(); the caller puts
##                   him in and calls interrupt());
##   RECOVERING:     RECOVER_TIME seconds settling back into his seat; he paddles again.
## Each threshold in antic_thresholds fires one antic per attempt, the first time the level
## reaches it (rising only; reset() forgets them). Which antic it is comes from the caller's
## RandomNumberGenerator, so tests seed it, and start() lets a caller pick one. A crossing
## while he is busy with an antic waits and fires when he is idle again, so no crossing is
## lost and none fires twice.

## What a seat is doing.
enum State { IDLE, WINDING_UP, STANDING, PADDLE_DROPPED, NODDED_OFF, PEEING, RECOVERING }
## The antic a wind-up leads to.
enum Kind { STAND, DROP_PADDLE, NOD_OFF, PEE }

## Seconds a guy takes to settle back into his seat after an antic. Cosmetic timing, not a
## tunable: he paddles again from its start.
const RECOVER_TIME: float = 0.5

var tuning: DrinkTuning
## One State per seat.
var states: Array[State] = []
## The antic each seat is winding up for or doing; meaningful outside IDLE and RECOVERING.
var kinds: Array[Kind] = []
## Seconds left in the current state per seat; 0 while IDLE.
var times_left: Array[float] = []
## How many of antic_thresholds each seat's level has reached so far (rising only).
var _crossed: Array[int] = []
## How many antics each seat has started; a crossing not yet fired waits for IDLE.
var _fired: Array[int] = []


func _init(drink_tuning: DrinkTuning) -> void:
	tuning = drink_tuning
	reset()


## Every guy idle with no threshold crossed (the starting conditions and the shore reset).
func reset() -> void:
	states.clear()
	kinds.clear()
	times_left.clear()
	_crossed.clear()
	_fired.clear()
	for seat: int in Paddling.Seat.size():
		states.append(State.IDLE)
		kinds.append(Kind.STAND)
		times_left.append(0.0)
		_crossed.append(0)
		_fired.append(0)


func state_of(seat: int) -> State:
	return states[seat]


func kind_of(seat: int) -> Kind:
	return kinds[seat]


## Seconds left of this guy's wind-up, antic or recovery; 0 while idle.
func time_left(seat: int) -> float:
	return times_left[seat]


## Whether this seat gives strokes: not while his paddle is gone, he naps or he pees.
func can_stroke(seat: int) -> bool:
	return states[seat] != State.PADDLE_DROPPED and states[seat] != State.NODDED_OFF \
			and states[seat] != State.PEEING


## Whether this guy has just crossed a threshold and his antic is still being announced.
func winding_up(seat: int) -> bool:
	return states[seat] == State.WINDING_UP


## Whether he is in the middle of an antic (after the wind-up, before the recovery).
func busy(seat: int) -> bool:
	return states[seat] != State.IDLE and states[seat] != State.WINDING_UP \
			and states[seat] != State.RECOVERING


## Yaw impulse per second a standing guy puts on the boat now, signed like Paddling's turn
## (+ = right): stand_rock swinging side to side once per stand_rock_period, starting toward
## his own hull's turn. 0 unless he stands, or the period is not positive (no swing).
func rock(seat: int) -> float:
	if states[seat] != State.STANDING or tuning.stand_rock_period <= 0.0:
		return 0.0
	var elapsed: float = maxf(tuning.stand_time - times_left[seat], 0.0)
	return Paddling.seat_side(seat) * tuning.stand_rock * sin(TAU * elapsed / tuning.stand_rock_period)


## Whether a shove of this magnitude (lake pixels per second) knocks this guy in: only while
## he pees, and only at pee_fall_shove or more.
func knocked_in(seat: int, shove_magnitude: float) -> bool:
	return states[seat] == State.PEEING and shove_magnitude >= tuning.pee_fall_shove


## Advances one guy by `delta` seconds at drunkenness `level` and returns his state: the
## thresholds his level reached are noted, a crossing not yet fired starts a wind-up while he is
## idle (its antic drawn from `rng`), and the timers run the machine.
func step(seat: int, delta: float, level: float, rng: RandomNumberGenerator) -> State:
	_note_crossings(seat, level)
	match states[seat]:
		State.IDLE:
			if _fired[seat] < _crossed[seat]:
				_fired[seat] += 1
				start(seat, pick(rng))
		State.WINDING_UP:
			if _tick(seat, delta):
				_begin_antic(seat)
		State.STANDING, State.PADDLE_DROPPED, State.NODDED_OFF, State.PEEING:
			if _tick(seat, delta):
				_enter(seat, State.RECOVERING, RECOVER_TIME)
		State.RECOVERING:
			if _tick(seat, delta):
				_enter(seat, State.IDLE, 0.0)
	return states[seat]


## Starts the wind-up for `kind` now: windup_time seconds of WINDING_UP, then the antic. A
## forced antic (a test, a debug key) that spends no threshold crossing. Does nothing to a guy
## who isn't idle.
func start(seat: int, kind: Kind) -> void:
	if states[seat] != State.IDLE:
		return
	kinds[seat] = kind
	_enter(seat, State.WINDING_UP, tuning.windup_time)


## Ends whatever this guy is doing at once (he went in the water): back to IDLE. A wind-up cut
## short is spent; it does not fire later.
func interrupt(seat: int) -> void:
	_enter(seat, State.IDLE, 0.0)


## Draws which antic fires next from `rng`: each Kind equally likely.
static func pick(rng: RandomNumberGenerator) -> Kind:
	return rng.randi_range(0, Kind.size() - 1) as Kind


## Seconds the antic of `kind` lasts, per the tuning.
func antic_time(kind: Kind) -> float:
	match kind:
		Kind.STAND:
			return tuning.stand_time
		Kind.DROP_PADDLE:
			return tuning.fish_time
		Kind.NOD_OFF:
			return tuning.nap_time
	return tuning.pee_time


## Counts the thresholds `level` has reached, never fewer than before: a level that drops back
## does not un-cross them, so each fires once per attempt.
func _note_crossings(seat: int, level: float) -> void:
	var reached: int = 0
	for threshold: float in tuning.antic_thresholds:
		if level >= threshold:
			reached += 1
	_crossed[seat] = maxi(_crossed[seat], reached)


func _begin_antic(seat: int) -> void:
	var kind: Kind = kinds[seat]
	var state: State = State.STANDING
	match kind:
		Kind.DROP_PADDLE:
			state = State.PADDLE_DROPPED
		Kind.NOD_OFF:
			state = State.NODDED_OFF
		Kind.PEE:
			state = State.PEEING
	_enter(seat, state, antic_time(kind))


## Counts the current state's timer down; true once it has run out.
func _tick(seat: int, delta: float) -> bool:
	times_left[seat] = maxf(times_left[seat] - delta, 0.0)
	return times_left[seat] <= 0.0


func _enter(seat: int, state: State, duration: float) -> void:
	states[seat] = state
	times_left[seat] = maxf(duration, 0.0)
