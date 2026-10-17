extends Node
## RunState · the current attempt at the crossing (GDD › Core Loop › Starting conditions,
## GDD › Win and Loss).
##
## Holds the state and owns the rule classes that change it: four guys, progress along the
## crossing, elapsed time and the phase, plus one Paddling, Drunkenness, Antics, Stamina and
## Rescue (with their data/*.tres tunings) and one RandomNumberGenerator for their rolls.
## Antics (GDD › Drunkenness, the middle tier) is stepped per guy aboard with his drunkenness
## level in step(); a seat busy with one gives no strokes (can_paddle), a standing guy's rock
## goes into the Motion's turn, and a shove() of DrinkTuning.pee_fall_shove or more while a guy
## pees knocks him in through guy_overboard() at the boat's last stepped position. The boat scene calls
## stroke() on each key release and step() once per physics frame with its position (where a guy
## whose wind-up ends jumps from, T34), and applies the Motion it gets back; the lake sets
## progress from the boat's position, calls arrive() at the island,
## pickup() when the boat reaches a floating guy and shore_touched() whenever the boat touches
## the shore; RunState decides whether that is a shore reset. While the boat still rests at the
## launch shore (LAUNCH) a guy washed up at the shoreline climbs back aboard on his own in step()
## (B2); under way he waits there for the boat or the shore reset. Hazard scenes call the effects
## palette (GDD › Systems › Hazards, Effects): beer_overboard(), shove(), push(), snag(), stop(),
## force_break(), water_aboard() and set_extra_drift(); the boat takes the shove, the push and
## the stop with take_shove(), take_push() and take_stop(), the extra drift goes into step()'s
## Motion, and a snagged or bailing seat gives no strokes. A guy who falls in some other
## way than a jump (T13) goes through guy_overboard(); the beast's grab (T50, beast_grab) puts
## the hit hull's guy in the water a long way back toward the shore. new_attempt() draws lake_seed from the
## RNG, the seed the lake plans its hazards from (Hazards.plan), and then resets; a shore reset
## only resets, so the attempt meets the same lake again. The guys' lines (T56, GDD › World and
## Narrative) live here too: a hazard whose warning starts calls telegraph(kind, hull), which
## emits telegraphed for the speech bubbles (scripts/ui/speech_bubbles.gd), and pick_line(kind)
## draws one of data/lines.tres's Swedish lines for a telegraph with the RNG, so no screen rolls
## one. Screens only read. Reads and writes no player data.

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
## The things that make a noise (T25, the Audio autoload listens): a stroke landing in step(),
## a stroke missed in stroke(), a guy jumping in step(), a guy back aboard in pickup(), and a
## beer actually going over in beer_overboard() (with a guy free to go after it).
signal stroke_landed(seat: int)
signal stroke_fumbled(seat: int)
signal guy_jumped(seat: int)
signal guy_picked_up(seat: int)
signal beer_overboard_started(hull: Rescue.Hull)
## A guy knocked in (not a jump, not a grab) in guy_overboard() (T26: the splash).
signal guy_fell_in(seat: int)
## The beast grabbed a guy in beast_grab() (T50; T26: the chomp).
signal guy_grabbed(seat: int)
## A hazard's warning started (T56): `kind` is one of Lines.KINDS, `hull` the Rescue.Hull it
## comes from, or Rescue.NOBODY when it comes from nowhere in particular (a headwind). Emitted
## by telegraph(); the speech bubbles put the line on the guy on that hull.
signal telegraphed(kind: StringName, hull: int)

var guys: Array[Guy] = []
## 0.0 at the shore, 1.0 at the island; the lake sets it with set_progress().
var progress: float = 0.0
var elapsed: float = 0.0
var phase: Phase = Phase.LAUNCH

var paddling: Paddling = Paddling.new(preload("res://data/boat_tuning.tres") as BoatTuning)
var drunkenness: Drunkenness = Drunkenness.new(preload("res://data/drink_tuning.tres") as DrinkTuning)
var stamina: Stamina = Stamina.new(preload("res://data/stamina_tuning.tres") as StaminaTuning)
## The stupid things the guys do at drunkenness thresholds; shares drunkenness's DrinkTuning.
var antics: Antics = Antics.new(preload("res://data/drink_tuning.tres") as DrinkTuning)
## The guys in the water and their beers; reads its tunables from paddling's BoatTuning.
var rescue: Rescue = Rescue.new()
## What the guys say at each telegraph (T56), per kind; pick_line() draws from it.
var lines: Lines = preload("res://data/lines.tres") as Lines
## Rolls the misses and the random breaks, and each attempt's lake_seed; tests seed it.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Seed of this attempt's hazard plan, drawn from rng at new_attempt(): the lake differs between
## attempts, stays the same across the attempt's shore resets, and is the same again for a logged
## seed.
var lake_seed: int = 0

var _pending: Array[PendingStroke] = []
## Hazard effects waiting for the boat: a shove it adds to its speed, a sustained push it moves
## at this frame, and a stop that zeroes its speed.
var _shove: Vector2 = Vector2.ZERO
var _push: Vector2 = Vector2.ZERO
var _stop: bool = false
## Pixels per second a headwind adds to the current's pull this step; set each step the boat
## is in a stretch, consumed by step().
var _extra_drift: float = 0.0
## Seconds until another beer may go over (BoatTuning.beer_loss_cooldown, GDD › Systems › Hazards):
## set when a beer goes over, counted down in step(), cleared by reset().
var _beer_loss_left: float = 0.0
## Seconds each seat's paddle is still snagged; 0 when free.
var _snag_left: Array[float] = []
## Water aboard per hull (Rescue.Hull order); the hull's guy bails it at BoatTuning.bail_rate.
var _water: Array[float] = []
## Where the boat was at the last step(): where a guy knocked in by a shove() goes in.
var _boat_at: Vector2 = Vector2.ZERO


func _ready() -> void:
	if Engine.has_meta("godot_director_check"):
		return
	new_attempt()


## A new attempt at the crossing: a fresh lake_seed is drawn, then the starting conditions are
## restored with reset(). Called at start, and by the win flow (T28) once there is one; a shore
## reset is not a new attempt and keeps the seed.
func new_attempt() -> void:
	lake_seed = rng.randi()
	reset()


## Restores the starting conditions (also the shore reset, GDD › Setbacks): four guys at
## DrinkTuning.start_level, all aboard, stamina full, zero progress, phase `launch`, and no
## hazard effect left pending. lake_seed stays: the same lake again.
func reset() -> void:
	drunkenness.reset()
	stamina.reset()
	antics.reset()
	rescue.reset()
	_pending.clear()
	_shove = Vector2.ZERO
	_push = Vector2.ZERO
	_stop = false
	_extra_drift = 0.0
	_beer_loss_left = 0.0
	_snag_left.clear()
	_water.clear()
	guys.clear()
	for seat: int in GUY_COUNT:
		guys.append(Guy.new(seat, drunkenness.level_of(seat)))
		_snag_left.append(0.0)
	for side: int in Rescue.Hull.size():
		_water.append(0.0)
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
## beer_toss to that side and bobs away, and the guy Rescue picks (that hull, front first, not
## already winding up) winds up for BoatTuning.jump_delay seconds (T34). He stays aboard and
## paddles meanwhile; step() takes him off the boat when he jumps. Returns his seat, or
## Rescue.NOBODY when nobody was free to jump. While the beer-loss cooldown runs (T46) nothing
## goes over and NOBODY comes back; the cooldown starts only when a beer does go over. shove()
## and stop() are not held back by it.
func beer_overboard(side: Rescue.Hull, at_position: Vector2) -> int:
	if _beer_loss_left > 0.0:
		return Rescue.NOBODY
	var toss: float = paddling.tuning.beer_toss
	var beer_at: Vector2 = at_position + Vector2(-toss if side == Rescue.Hull.LEFT else toss, 0.0)
	var seat: int = rescue.beer_overboard(side, _seats_aboard(), beer_at, paddling.tuning.jump_delay)
	if seat != Rescue.NOBODY:
		_beer_loss_left = paddling.tuning.beer_loss_cooldown
		beer_overboard_started.emit(side)
	return seat


## A guy fell in some other way than a jump (GDD › Drunkenness: the pee antic): he is off the
## boat, whatever antic he was busy with is over, and his strokes still waiting to land are
## dropped. With no beer loose for him he floats from the start and doesn't drink; caught
## winding up, he swims for his beer anyway (Rescue.guy_overboard). Nothing happens if he is
## already in the water. Emits guy_fell_in: his splash.
func guy_overboard(seat: int, at_position: Vector2) -> void:
	if _take_off(seat, at_position):
		guy_fell_in.emit(seat)


## The beast rammed `side` with the boat at `from_position` and grabbed that hull's guy (front
## first, of those aboard): swallowed, dived with, and spat out `spit_distance` back toward the
## shore (down-screen), where he goes in beerless like a guy knocked in (GDD › Systems ›
## Hazards, the Loch-Brez beast row). Rescue holds him at the shoreline if that is past it.
## No beer goes over, so the beer-loss cooldown neither holds this back nor starts. Returns his
## seat, or Rescue.NOBODY when nobody is aboard that hull. Emits guy_grabbed, not guy_fell_in:
## the grab is its own sound.
func beast_grab(side: Rescue.Hull, from_position: Vector2, spit_distance: float) -> int:
	var seat: int = _hull_guy(side)
	if seat == Rescue.NOBODY:
		return Rescue.NOBODY
	_take_off(seat, from_position + Vector2.DOWN * spit_distance)
	guy_grabbed.emit(seat)
	return seat


## Puts the guy at `seat` in the water at `at_position` beerless (Rescue.guy_overboard), ends
## his antic and drops his waiting strokes. False, and nothing done, if he wasn't aboard.
func _take_off(seat: int, at_position: Vector2) -> bool:
	if not guys[seat].aboard:
		return false
	rescue.guy_overboard(seat, at_position)
	guys[seat].aboard = false
	antics.interrupt(seat)
	_drop_pending(seat)
	return true


## The boat reached him: he is aboard again. Returns whether he brought his beer back.
func pickup(seat: int) -> bool:
	var had_beer: bool = rescue.pickup(seat)
	guys[seat].aboard = true
	guy_picked_up.emit(seat)
	return had_beer


## A hazard pushes the boat (GDD › Systems › Hazards, Shove): `impulse` in lake pixels per
## second, which the boat adds to its speed next frame. Shoves in the same frame add up. A guy
## peeing at the edge loses his balance to a shove of DrinkTuning.pee_fall_shove or more
## (Antics.knocked_in) and goes in without his beer where the boat last stepped.
func shove(impulse: Vector2) -> void:
	_shove += impulse
	for seat: int in GUY_COUNT:
		if guys[seat].aboard and antics.knocked_in(seat, impulse.length()):
			guy_overboard(seat, _boat_at)


## The shove waiting for the boat, once: cleared when taken.
func take_shove() -> Vector2:
	var impulse: Vector2 = _shove
	_shove = Vector2.ZERO
	return impulse


## A hazard's wind pushes the boat for as long as it blows (Shove, sustained): `velocity` in lake
## pixels per second, which the boat moves at this frame on top of its strokes and the current,
## undamped, so a gust reads as the boat carried sideways while it lasts. The hazard calls it
## every frame it blows; pushes in the same frame add up.
func push(velocity: Vector2) -> void:
	_push += velocity


## The push waiting for the boat this frame, once: cleared when taken.
func take_push() -> Vector2:
	var velocity: Vector2 = _push
	_push = Vector2.ZERO
	return velocity


## A headwind makes the current stronger this step (the Harsh wind row): `per_second` pixels
## per second more of drift toward the shore, added to the next step()'s Motion.drift_to_shore
## and then forgotten, so a stretch sets it every step the boat is inside. Overlapping
## stretches don't stack: the strongest wins.
func set_extra_drift(per_second: float) -> void:
	_extra_drift = maxf(_extra_drift, per_second)


## A hard hit stops the boat (Stop the boat): its speed goes to zero next frame.
func stop() -> void:
	_stop = true


## Whether the boat has to stop this frame, once: cleared when taken.
func take_stop() -> bool:
	var stopped: bool = _stop
	_stop = false
	return stopped


## A hazard snags the paddle on `side` (Snag a paddle): the hull's guy (front first, of those
## aboard) gives no strokes for `seconds`, the same shape as a break; snagged again, he keeps
## the longer time. Returns his seat, or Rescue.NOBODY when nobody is aboard that hull.
func snag(side: Rescue.Hull, seconds: float) -> int:
	var seat: int = _hull_guy(side)
	if seat != Rescue.NOBODY:
		_snag_left[seat] = maxf(_snag_left[seat], seconds)
	return seat


## Seconds this seat's paddle stays snagged; 0 when free.
func snag_left(seat: int) -> float:
	return _snag_left[seat]


func is_snagged(seat: int) -> bool:
	return _snag_left[seat] > 0.0


## The hit guy on `side` takes a stamina break on the spot (Force a stamina break): his break is
## called now, warning first as any break. Returns his seat, or Rescue.NOBODY.
func force_break(side: Rescue.Hull) -> int:
	var seat: int = _hull_guy(side)
	if seat != Rescue.NOBODY:
		stamina.call_break(seat)
	return seat


## A hazard's warning has started (GDD › Systems › Hazards: every hazard is announced before it
## matters): `kind` names it (a Lines.KINDS entry) and `hull` is the side it comes from, or
## Rescue.NOBODY for none in particular. Only emits telegraphed; the bubbles do the rest.
func telegraph(kind: StringName, hull: int = Rescue.NOBODY) -> void:
	telegraphed.emit(kind, hull)


## One of the Swedish lines for `kind` (GDD › World and Narrative), drawn with the RNG here so
## no screen rolls one; "" for a kind without lines.
func pick_line(kind: StringName) -> String:
	return lines.pick(kind, rng)


## Water comes in on `side` (Water aboard): `amount` of it, which that hull's guy bails at
## BoatTuning.bail_rate per second while his seat gives no strokes, until it is out. More
## water, longer bailing; with nobody aboard that hull it waits for him.
func water_aboard(side: Rescue.Hull, amount: float) -> void:
	_water[side] += maxf(amount, 0.0)


## Water still aboard this hull.
func water_of(side: Rescue.Hull) -> float:
	return _water[side]


## Who bails `side` now: its guy (front first, of those aboard) while it has water, else NOBODY.
func bailer_of(side: Rescue.Hull) -> int:
	if _water[side] <= 0.0:
		return Rescue.NOBODY
	return _hull_guy(side)


func is_bailing(seat: int) -> bool:
	for side: int in Rescue.Hull.size():
		if bailer_of(side as Rescue.Hull) == seat:
			return true
	return false


## Whether this seat gives strokes now: aboard, not on a break, not busy with an antic that
## takes his paddle, not snagged and not bailing.
func can_paddle(seat: int) -> bool:
	return guys[seat].aboard and stamina.can_stroke(seat) and antics.can_stroke(seat) \
			and not is_snagged(seat) and not is_bailing(seat)


## One key released: `seat` is the key's owner, `hold_time` how long it was held, `backwards`
## whether it was his reverse key. Nothing happens if he is on a break, snagged, bailing, in the
## water, or the attempt is over. He burns stamina for the stroke's forward power at once, the
## same for either key (GDD › Presentation and Platforms); the stroke then lands after his
## drunkenness's lag, or misses, unless he goes overboard before it lands. On the timing bar
## (drunkenness.uses_bar) a release outside the green zone flips the stroke's direction: a
## forward key paddles backwards and a reverse key forwards (an XOR), so a miss is always the
## stroke he didn't ask for.
func stroke(seat: int, hold_time: float, backwards: bool = false) -> void:
	if phase == Phase.WON:
		return
	if not can_paddle(seat):
		return
	var level: float = drunkenness.level_of(seat)
	stamina.burn(seat, paddling.stroke_force(hold_time))
	guys[seat].stamina = stamina.level_of(seat)
	if drunkenness.misses(level, rng):
		stroke_fumbled.emit(seat)
		return
	var bar_missed: bool = drunkenness.uses_bar(seat) and not drunkenness.bar_hit(hold_time)
	var pending: Paddling.Stroke = Paddling.Stroke.new(seat, hold_time, backwards != bar_missed)
	_pending.append(PendingStroke.new(pending, drunkenness.stroke_delay(level)))


## One physics frame with the boat at `boat_at`: the loose beers, the swimmers and their beers
## move with the wind (loose_drift_speed, faster than the boat's current), and a guy whose
## wind-up ends this frame jumps in from `boat_at`, is no
## longer aboard and loses his strokes still waiting to land (while launching, a guy washed up
## at the shoreline climbs back aboard with whatever beer he has); every guy drinks (a floating
## guy with his beer at the water rate; one without a beer not at all) and every guy aboard
## recovers or breaks (a guy in the water keeps his stamina, state and time left until he is
## picked up, GDD › Systems › Stamina), every guy aboard runs his antics at his drunkenness
## level (a jump ends one; a swimmer's crossings wait until he is back aboard), the levels are
## mirrored into the guys, the snags count down and the bailers bail, elapsed advances, and the
## strokes that land this frame become the boat's Motion, its turn plus the rock of any guy
## standing up, its drift the current's plus any headwind set for this step (set_extra_drift).
## With nobody aboard (after this frame's jumps) the current's part of the drift is multiplied by
## BoatTuning.empty_drift_multiplier, and the headwind's extra drift is added as it is (T47). The
## beer-loss cooldown counts down (T46). Nothing moves once the attempt is won.
func step(delta: float, boat_at: Vector2) -> Paddling.Motion:
	if phase == Phase.WON:
		return Paddling.Motion.new()
	elapsed += delta
	_boat_at = boat_at
	_beer_loss_left = maxf(_beer_loss_left - delta, 0.0)
	for seat: int in GUY_COUNT:
		_snag_left[seat] = maxf(_snag_left[seat] - delta, 0.0)
	for side: int in Rescue.Hull.size():
		if bailer_of(side as Rescue.Hull) != Rescue.NOBODY:
			_water[side] = maxf(_water[side] - paddling.tuning.bail_rate * delta, 0.0)
	# Beers and swimmers drift faster than the boat (GDD › Systems › Catamaran and paddling).
	var loose_drift: Vector2 = Vector2.DOWN * paddling.tuning.loose_drift_speed
	for seat: int in rescue.step(delta, loose_drift, paddling.tuning, boat_at):
		guys[seat].aboard = false
		antics.interrupt(seat)
		_drop_pending(seat)
		guy_jumped.emit(seat)
	if phase == Phase.LAUNCH:
		# The boat rests at the shore, so the launch shore never traps the player (B2).
		for seat: int in rescue.washed_up():
			pickup(seat)
	for seat: int in GUY_COUNT:
		var guy: Guy = guys[seat]
		var swimmer: Rescue.Swimmer = rescue.swimmer_of(seat)
		var in_water: bool = swimmer != null
		# In the water he neither recovers nor rolls a random break: the rule class is not stepped.
		if not in_water:
			stamina.step(seat, delta, rng)
		var drinking: bool = not in_water or swimmer.has_beer
		drunkenness.drink(seat, delta, guy.aboard and stamina.on_break(seat), in_water, drinking)
		if guy.aboard:
			antics.step(seat, delta, drunkenness.level_of(seat), rng)
		guy.stamina = stamina.level_of(seat)
		guy.drunkenness = drunkenness.level_of(seat)
	var motion: Paddling.Motion = paddling.step(_land_strokes(delta), delta)
	if _seats_aboard().is_empty():
		motion.drift_to_shore *= paddling.tuning.empty_drift_multiplier
	for seat: int in GUY_COUNT:
		motion.turn += antics.rock(seat) * delta
	motion.drift_to_shore += _extra_drift * delta
	_extra_drift = 0.0
	return motion


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


## The guy a hazard on `side` hits: the aboard guy on that hull, front first; NOBODY if the hull
## is empty.
func _hull_guy(side: Rescue.Hull) -> int:
	for seat: int in Rescue.seats_on(side):
		if guys[seat].aboard:
			return seat
	return Rescue.NOBODY


## Drops the strokes of `seat` still waiting to land. He went overboard before they landed, so
## they never do, not even if he is picked up again first.
func _drop_pending(seat: int) -> void:
	var waiting: Array[PendingStroke] = []
	for pending: PendingStroke in _pending:
		if pending.stroke.seat != seat:
			waiting.append(pending)
	_pending = waiting


## Counts the pending strokes down by `delta` and returns the ones that land now.
func _land_strokes(delta: float) -> Array[Paddling.Stroke]:
	var landed: Array[Paddling.Stroke] = []
	var waiting: Array[PendingStroke] = []
	for pending: PendingStroke in _pending:
		pending.time_left -= delta
		if pending.time_left <= 0.0:
			landed.append(pending.stroke)
			stroke_landed.emit(pending.stroke.seat)
		else:
			waiting.append(pending)
	_pending = waiting
	return landed
