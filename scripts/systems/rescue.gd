class_name Rescue
extends RefCounted
## Rescue · the guys in the water and the beers they went in after (GDD › Systems › Setbacks).
##
## A plain rule class: it receives the current, its BoatTuning and the boat's position each step
## and never touches the scene tree or RunState. Seats equal RunState.Guy.seat and Paddling.Seat.
## Positions are Vector2 in lake pixels. A beer knocked overboard first bobs away loose for
## BoatTuning.jump_delay seconds while the guy chosen by jumper() winds up aboard (he still
## paddles); when the countdown ends in step() he jumps in from where the boat is then and swims
## toward the beer at swim_speed (on top of the current, like everything in the water) until he
## reaches it, then floats, drifting with the current and drinking. After swim_back_delay seconds
## adrift (Swimmer.adrift, counted while FLOATING) he swims slowly back toward the boat at
## swim_back_speed on top of the drift (T59): slower than the wind carries him, so the rescue is
## still the boat's job, but a patient one can meet him halfway. A guy can also fall in some other way (the pee antic, T13): with no beer
## loose he floats at once and doesn't drink; caught mid-wind-up he swims for his beer anyway, as
## if he had jumped early. There is no limit on how many are in the water at a time. Nothing
## loose drifts past the shoreline: a beer or a guy stops
## shore_margin above it (B2) and a guy lying there is washed up, within pickup_radius of a boat
## resting at the shore; he doesn't swim back from there.

## Which hull a hazard hit; the guy who jumps comes from that side when one is aboard.
enum Hull { LEFT, RIGHT }
## Going for the beer, or holding it and drifting.
enum State { SWIMMING, FLOATING }
## No guy was aboard to jump.
const NOBODY: int = -1
## The swim kinds (T80): what a guy in the water is doing, named by Swimmer.kind(). The speech
## bubbles read them (a Lines.KINDS key for the line they draw; the first four) and so does the
## HUD's status line. Their values are the data keys in data/lines.tres, so they don't change.
const KIND_FETCH: StringName = &"swim_fetch"
const KIND_DRINK: StringName = &"swim_drink"
const KIND_FELL: StringName = &"swim_fell"
const KIND_BACK: StringName = &"swim_back"
const KIND_WASHED_UP: StringName = &"washed_up"


## One guy in the water.
class Swimmer extends RefCounted:
	var seat: int = 0
	var position: Vector2 = Vector2.ZERO
	## Where the beer is: loose while SWIMMING, in his hand while FLOATING with has_beer.
	var beer_position: Vector2 = Vector2.ZERO
	var state: State = State.SWIMMING
	var has_beer: bool = true
	## Lying at the shoreline, as far as the current takes him (set by step()).
	var washed_up: bool = false
	## Seconds he has been FLOATING (counted by step()): past swim_back_delay he swims back.
	var adrift: float = 0.0

	func _init(swimmer_seat: int, at: Vector2, beer_at: Vector2, swimmer_state: State, beer: bool) -> void:
		seat = swimmer_seat
		position = at
		beer_position = beer_at
		state = swimmer_state
		has_beer = beer

	## What he is doing, for the speech bubbles and the HUD (the swim kinds above): washed up
	## (KIND_WASHED_UP) at the shoreline; swimming for his beer (KIND_FETCH); floating with it
	## (KIND_DRINK) or without one (KIND_FELL) until his adrift time is past `swim_back_delay`,
	## when he swims back (KIND_BACK). Exactly at the delay he has not started back yet.
	func kind(swim_back_delay: float) -> StringName:
		if washed_up:
			return KIND_WASHED_UP
		if state == State.SWIMMING:
			return KIND_FETCH
		if adrift > swim_back_delay:
			return KIND_BACK
		return KIND_DRINK if has_beer else KIND_FELL


## A beer bobbing away while its guy winds up aboard (T34): he jumps when time_left runs out.
class LooseBeer extends RefCounted:
	## The guy winding up for it.
	var seat: int = 0
	var position: Vector2 = Vector2.ZERO
	## Seconds of wind-up left before he jumps.
	var time_left: float = 0.0

	func _init(jumper_seat: int, at: Vector2, delay: float) -> void:
		seat = jumper_seat
		position = at
		time_left = delay


var _swimmers: Array[Swimmer] = []
var _beers: Array[LooseBeer] = []


## Everyone back aboard, no beer loose (the starting conditions and the shore reset).
func reset() -> void:
	_swimmers.clear()
	_beers.clear()


## A beer went over on `side` at `beer_at`: it floats loose from here, and the guy chosen by
## jumper() among `seats_aboard` (less those already winding up) starts a wind-up of
## `jump_delay` seconds, after which step() puts him in the water after it. Returns his seat, or
## NOBODY when nobody was free to jump (then there is no beer to go after either).
func beer_overboard(side: Hull, seats_aboard: Array[int], beer_at: Vector2, jump_delay: float) -> int:
	var free: Array[int] = []
	for seat: int in seats_aboard:
		if not winding_up(seat):
			free.append(seat)
	var seat: int = jumper(side, free)
	if seat == NOBODY:
		return NOBODY
	_beers.append(LooseBeer.new(seat, beer_at, jump_delay))
	return seat


## A guy fell in at `at` some other way than a jump (GDD › Drunkenness: the pee antic). With no
## beer loose for him he floats from the start and doesn't drink. Winding up when he went in,
## he swims for his beer from `at` anyway, as after a jump: the wind-up is over early and the
## loose beer is his to reach. Nothing happens if he is already in the water.
func guy_overboard(seat: int, at: Vector2) -> void:
	if is_in_water(seat):
		return
	var beer: LooseBeer = beer_of(seat)
	if beer == null:
		_swimmers.append(Swimmer.new(seat, at, at, State.FLOATING, false))
		return
	_beers.erase(beer)
	_swimmers.append(Swimmer.new(seat, at, beer.position, State.SWIMMING, true))


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
## (FLOATING) once he reaches it this step. A floating guy's `adrift` clock runs, and once it
## is past swim_back_delay he also swims swim_back_speed toward `boat_at` on top of the drift,
## never past it; not from the shoreline, where he lies washed up. Every wind-up counts down,
## and a guy whose wind-up ends this step jumps in at `boat_at` (where the boat is now, not where
## the beer went over) and swims for his beer from next step. Nothing drifts past the shoreline:
## beers and guys stop at y = -shore_margin, and a guy lying there is washed_up. Returns the
## seats that jumped this step, so the holder can take them off the boat.
func step(delta: float, current: Vector2, tuning: BoatTuning, boat_at: Vector2) -> Array[int]:
	var drift: Vector2 = current * delta
	var shoreline: float = -tuning.shore_margin
	for swimmer: Swimmer in _swimmers:
		if swimmer.state == State.SWIMMING:
			swimmer.beer_position = held_back(swimmer.beer_position + drift, shoreline)
			var reach: float = tuning.swim_speed * delta
			var drifted: Vector2 = held_back(swimmer.position + drift, shoreline)
			var to_beer: Vector2 = swimmer.beer_position - drifted
			if to_beer.length() <= reach:
				swimmer.position = swimmer.beer_position
				swimmer.state = State.FLOATING
			else:
				swimmer.position = drifted + to_beer.normalized() * reach
		else:
			var drifted: Vector2 = held_back(swimmer.position + drift, shoreline)
			swimmer.adrift += delta
			if swimmer.adrift > tuning.swim_back_delay and drifted.y < shoreline:
				var reach: float = tuning.swim_back_speed * delta
				var to_boat: Vector2 = boat_at - drifted
				if to_boat.length() <= reach:
					drifted = boat_at
				else:
					drifted += to_boat.normalized() * reach
			swimmer.position = held_back(drifted, shoreline)
			swimmer.beer_position = swimmer.position
		swimmer.washed_up = swimmer.position.y >= shoreline
	var jumped: Array[int] = []
	var loose: Array[LooseBeer] = []
	for beer: LooseBeer in _beers:
		beer.position = held_back(beer.position + drift, shoreline)
		beer.time_left -= delta
		if beer.time_left <= 0.0:
			var swimmer: Swimmer = Swimmer.new(beer.seat, held_back(boat_at, shoreline), beer.position, State.SWIMMING, true)
			swimmer.washed_up = swimmer.position.y >= shoreline
			_swimmers.append(swimmer)
			jumped.append(beer.seat)
		else:
			loose.append(beer)
	_beers = loose
	return jumped


## `at` held above the shoreline: the same point, no lower than `shoreline` (y grows toward the
## shore).
static func held_back(at: Vector2, shoreline: float) -> Vector2:
	return Vector2(at.x, minf(at.y, shoreline))


func swimmers() -> Array[Swimmer]:
	return _swimmers


func swimmer_of(seat: int) -> Swimmer:
	for swimmer: Swimmer in _swimmers:
		if swimmer.seat == seat:
			return swimmer
	return null


func is_in_water(seat: int) -> bool:
	return swimmer_of(seat) != null


## The beers bobbing away with a guy still winding up for each.
func loose_beers() -> Array[LooseBeer]:
	return _beers


## The beer `seat` is winding up for, or null.
func beer_of(seat: int) -> LooseBeer:
	for beer: LooseBeer in _beers:
		if beer.seat == seat:
			return beer
	return null


## Whether `seat` is still aboard, winding up to jump after a beer.
func winding_up(seat: int) -> bool:
	return beer_of(seat) != null


## Seconds of wind-up left before `seat` jumps; 0 when he isn't winding up.
func wind_up_left(seat: int) -> float:
	var beer: LooseBeer = beer_of(seat)
	return 0.0 if beer == null else beer.time_left


## The floating guys within `radius` of `boat_position`: the ones the boat can pick up. A guy
## still swimming for his beer is out of reach, so a jump beside the boat isn't undone at once.
func within_reach(boat_position: Vector2, radius: float) -> Array[int]:
	var seats: Array[int] = []
	for swimmer: Swimmer in _swimmers:
		if swimmer.state == State.FLOATING and swimmer.position.distance_to(boat_position) <= radius:
			seats.append(swimmer.seat)
	return seats


## The floating guys lying at the shoreline: the ones a boat resting at the shore reaches. A guy
## still swimming for his beer reaches it there first (it stopped at the shoreline too).
func washed_up() -> Array[int]:
	var seats: Array[int] = []
	for swimmer: Swimmer in _swimmers:
		if swimmer.state == State.FLOATING and swimmer.washed_up:
			seats.append(swimmer.seat)
	return seats


## Takes him out of the water and returns whether he had his beer (false if he wasn't in it).
func pickup(seat: int) -> bool:
	var swimmer: Swimmer = swimmer_of(seat)
	if swimmer == null:
		return false
	_swimmers.erase(swimmer)
	return swimmer.has_beer


## The dev menu's inspector (T72, tools/dev_menu.gd): each guy in the water with his state, beer and
## time adrift, and each beer loose with the seat that will jump after it.
func debug_inspect() -> Dictionary:
	var values: Dictionary = {}
	for swimmer: Swimmer in _swimmers:
		values["in the water, seat %d" % swimmer.seat] = "%s, %s, adrift %.1fs" % [
				str(State.keys()[swimmer.state]).to_lower(), "with his beer" if swimmer.has_beer else "no beer",
				swimmer.adrift]
	for beer: LooseBeer in _beers:
		values["beer loose, seat %d" % beer.seat] = "jumps in after %.2fs" % beer.time_left
	if values.is_empty():
		values["in the water"] = "nobody"
	return values
