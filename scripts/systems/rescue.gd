class_name Rescue
extends RefCounted
## Rescue · the guys in the water and the beers they went in after (GDD › Systems › Setbacks).
##
## A plain rule class: it receives the current and its BoatTuning each step and never touches
## the scene tree or RunState. Seats equal RunState.Guy.seat and Paddling.Seat. Positions are
## Vector2 in lake pixels. A beer knocked overboard puts one guy in the water after it: he swims
## toward it at swim_speed (on top of the current, like everything in the water) until he
## reaches it, then floats, drifting with the current and drinking. He never swims back; the boat
## has to come to him. A guy can also fall in without a beer (the pee antic, T13): he floats at
## once and doesn't drink. There is no limit on how many are in the water at a time.

## Which hull a hazard hit; the guy who jumps comes from that side when one is aboard.
enum Hull { LEFT, RIGHT }
## Going for the beer, or holding it and drifting.
enum State { SWIMMING, FLOATING }
## No guy was aboard to jump.
const NOBODY: int = -1


## One guy in the water.
class Swimmer extends RefCounted:
	var seat: int = 0
	var position: Vector2 = Vector2.ZERO
	## Where the beer is: loose while SWIMMING, in his hand while FLOATING with has_beer.
	var beer_position: Vector2 = Vector2.ZERO
	var state: State = State.SWIMMING
	var has_beer: bool = true

	func _init(swimmer_seat: int, at: Vector2, beer_at: Vector2, swimmer_state: State, beer: bool) -> void:
		seat = swimmer_seat
		position = at
		beer_position = beer_at
		state = swimmer_state
		has_beer = beer


var _swimmers: Array[Swimmer] = []


## Everyone back aboard (the starting conditions and the shore reset).
func reset() -> void:
	_swimmers.clear()


## A beer went over on `side` at `beer_at`; the guy chosen by jumper() jumps in at `at` and
## swims for it. Returns his seat, or NOBODY when nobody was aboard to jump.
func beer_overboard(side: Hull, seats_aboard: Array[int], at: Vector2, beer_at: Vector2) -> int:
	var seat: int = jumper(side, seats_aboard)
	if seat == NOBODY:
		return NOBODY
	_swimmers.append(Swimmer.new(seat, at, beer_at, State.SWIMMING, true))
	return seat


## A guy fell in at `at` with no beer (GDD › Drunkenness: the pee antic): he floats from the
## start and doesn't drink. Nothing happens if he is already in the water.
func guy_overboard(seat: int, at: Vector2) -> void:
	if is_in_water(seat):
		return
	_swimmers.append(Swimmer.new(seat, at, at, State.FLOATING, false))


## Who goes in after a beer on `side`: the aboard guy on that hull, the front one if both are;
## any aboard guy (front first, the other hull) if that hull is empty; NOBODY if nobody is aboard.
static func jumper(side: Hull, seats_aboard: Array[int]) -> int:
	var order: Array[int] = seats_on(side) + seats_on(Hull.RIGHT if side == Hull.LEFT else Hull.LEFT)
	for seat: int in order:
		if seats_aboard.has(seat):
			return seat
	return NOBODY


## The two seats of a hull, front first.
static func seats_on(side: Hull) -> Array[int]:
	if side == Hull.LEFT:
		return [Paddling.Seat.LEFT_FRONT, Paddling.Seat.LEFT_BACK]
	return [Paddling.Seat.RIGHT_FRONT, Paddling.Seat.RIGHT_BACK]


## One timestep: every loose beer and every floating guy drifts by `current` (pixels per second);
## a swimming guy drifts too and swims swim_speed toward his beer on top of it, and holds it
## (FLOATING) once he reaches it this step.
func step(delta: float, current: Vector2, tuning: BoatTuning) -> void:
	var drift: Vector2 = current * delta
	for swimmer: Swimmer in _swimmers:
		if swimmer.state == State.SWIMMING:
			swimmer.beer_position += drift
			var reach: float = tuning.swim_speed * delta
			var to_beer: Vector2 = swimmer.beer_position - (swimmer.position + drift)
			if to_beer.length() <= reach:
				swimmer.position = swimmer.beer_position
				swimmer.state = State.FLOATING
			else:
				swimmer.position += drift + to_beer.normalized() * reach
		else:
			swimmer.position += drift
			swimmer.beer_position = swimmer.position


func swimmers() -> Array[Swimmer]:
	return _swimmers


func swimmer_of(seat: int) -> Swimmer:
	for swimmer: Swimmer in _swimmers:
		if swimmer.seat == seat:
			return swimmer
	return null


func is_in_water(seat: int) -> bool:
	return swimmer_of(seat) != null


## The floating guys within `radius` of `boat_position`: the ones the boat can pick up. A guy
## still swimming for his beer is out of reach, so a jump beside the boat isn't undone at once.
func within_reach(boat_position: Vector2, radius: float) -> Array[int]:
	var seats: Array[int] = []
	for swimmer: Swimmer in _swimmers:
		if swimmer.state == State.FLOATING and swimmer.position.distance_to(boat_position) <= radius:
			seats.append(swimmer.seat)
	return seats


## Takes him out of the water and returns whether he had his beer (false if he wasn't in it).
func pickup(seat: int) -> bool:
	var swimmer: Swimmer = swimmer_of(seat)
	if swimmer == null:
		return false
	_swimmers.erase(swimmer)
	return swimmer.has_beer
