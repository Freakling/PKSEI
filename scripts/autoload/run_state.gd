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
## pees knocks him in through guy_overboard() at the boat's last stepped position. Drunkenness
## also comes down (T63): a guy aboard and idle whose level reaches DrinkTuning.puke_level is
## started on the puke antic (Antics.Kind.PUKE, never drawn at a threshold), and once he has
## puked his level drops by puke_relief (Drunkenness.relieve); a finished pee drops it by
## pee_relief, a pee cut short by a knock-in not at all (Antics.just_finished). He pukes again
## only once his level has dipped below puke_level and reached it again (_puke_armed); a finished
## puke emits `puked` (T64: the beast may hear it). The boat scene calls
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
## one. The crew's names (T68, GDD › Characters and Units) live here too: new_attempt() draws four
## distinct ones from data/names.tres with the RNG (guy_names, name_of(seat)) and a shore reset
## keeps them. Screens only read. Reads and writes no player data.
##
## The play log (T70, tools/play_log.gd): every player action and every step of the run is one
## PlayLog line with a stable event id, written from here by _log(): run.* (the attempt, the
## crossing, a shore reset, the win), action.* (strokes), rescue.*, hazard.* (effects) and guy.*
## (antics, breaks, the timing bar). snapshot() and block_reason() are what PlayLog's hooks
## report; a new attempt and a shore reset also log a snapshot. Nothing is logged per frame
## except where a state actually changes (_log_changes, once per step).
##
## The dev menu (T72, tools/dev_menu.gd) reads debug_inspect() and calls the debug_* hooks at the
## end of this file; each is a one-liner over the API above and its effects log their own lines.

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
	## Whether the timing bar flipped its direction (only for the play log).
	var flipped: bool = false

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
## A guy's puke ran its course in step() (T64: the beast listens, scripts/hazards/beast.gd).
signal puked(seat: int)
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
## The crossing's counters for the win title (T86): every play-log event _log() writes is handed
## to it, and step() adds the drunkenness the guys gain. new_attempt() starts it over; a shore
## reset keeps it (the same attempt).
var stats: Stats = Stats.new()
## What the guys say at each telegraph (T56), per kind; pick_line() draws from it.
var lines: Lines = preload("res://data/lines.tres") as Lines
## The crew's nicknames (T68, GDD › Characters and Units); new_attempt() draws four.
var names: Names = preload("res://data/names.tres") as Names
## This attempt's names per seat (Paddling.Seat order), drawn at new_attempt() and kept across
## its shore resets; name_of(seat) reads them.
var guy_names: PackedStringArray = PackedStringArray()
## Rolls the misses and the random breaks, and each attempt's lake_seed; tests seed it.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Seed of this attempt's hazard plan, drawn from rng at new_attempt(): the lake differs between
## attempts, stays the same across the attempt's shore resets, and is the same again for a logged
## seed.
var lake_seed: int = 0
## The attempts begun in the open play-log run (new_attempt()): 1 at its first attempt. Counted
## again when the run changes, so a run begun after the boot's counts from 1 (T83).
var attempt: int = 0

## The play-log run id `attempt` is counted in (new_attempt() resets the count when it changes).
var _counted_run: String = ""

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
## Whether each seat may puke when his level next reaches DrinkTuning.puke_level: armed at the
## start and whenever his level is below it, spent when his puke starts, so a guy still at the
## top after the drop waits for the next crossing instead of puking on a loop (T63).
var _puke_armed: Array[bool] = []
## The PlayLog autoload, found once by _log(); null where there is none.
var _play_log: Node = null
## What was last logged per seat (antic state, stamina state, timing-bar tier, swim state), so
## _log_changes() writes a line only when one changes. Synced silently by reset().
var _logged_antic: Array[int] = []
var _logged_stamina: Array[int] = []
var _logged_bar: Array[int] = []
var _logged_swim: Array[int] = []
## Whether a sustained push or a headwind is in progress, so each is logged once at its start
## and once at its end, not every frame.
var _push_on: bool = false
var _headwind_on: bool = false


func _ready() -> void:
	if Engine.has_meta("godot_director_check"):
		return
	new_attempt()


## A new attempt at the crossing: a fresh lake_seed is drawn and the four guys get their names
## (T68: four distinct ones from data/names.tres), then the starting conditions are restored
## with reset(). Called at start, and by the win flow (T28) once there is one; a shore reset is
## not a new attempt and keeps the seed and the names.
##
## The play log keeps one run per process (T83): the first attempt begins the run's files, and a
## later attempt (an R press, the touch hold, the autoplay's reset) is another attempt of that run,
## so a person's session or an autoplay run stays one .log/.jsonl pair. `attempt` counts the
## attempts of the open run (1 for its first) and is in run.attempt_started's data.
func new_attempt() -> void:
	lake_seed = rng.randi()
	guy_names = names.pick_four(rng)
	var play_log: Node = _log_node()
	if play_log != null and play_log.run_id.is_empty():
		play_log.begin_run()
	var open_run: String = play_log.run_id if play_log != null else ""
	if open_run != _counted_run:
		_counted_run = open_run
		attempt = 0
	attempt += 1
	stats.reset()
	reset()
	_log("run", "run.attempt_started", "attempt %d: %s" % [attempt, ", ".join(guy_names)],
			{"lake_seed": lake_seed, "names": Array(guy_names), "attempt": attempt})
	_log_snapshot()


## Restores the starting conditions (also the shore reset, GDD › Setbacks): four guys at
## DrinkTuning.start_level, all aboard, stamina full, zero progress, phase `launch`, and no
## hazard effect left pending. lake_seed and guy_names stay: the same lake and crew again.
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
	_puke_armed.clear()
	guys.clear()
	for seat: int in GUY_COUNT:
		guys.append(Guy.new(seat, drunkenness.level_of(seat)))
		_snag_left.append(0.0)
		_puke_armed.append(true)
	for side: int in Rescue.Hull.size():
		_water.append(0.0)
	progress = 0.0
	elapsed = 0.0
	phase = Phase.LAUNCH
	_push_on = false
	_headwind_on = false
	_sync_logged()
	run_reset.emit()


## The boat touched the shore. Once it is under way (CROSSING) that is the shore reset
## (GDD › Setbacks, Shore reset), with or without anyone in the water: the attempt returns to
## its starting conditions, then shore_reset_done tells the lake to replace the boat. While
## launching the boat rests against the shore, so nothing happens; nor after the win.
func shore_touched() -> void:
	if phase != Phase.CROSSING:
		return
	_log("run", "run.shore_reset", "the boat touched the shore at %d%% after %.1fs: back to the start" % [
			roundi(progress * 100.0), elapsed],
			{"progress": snappedf(progress, 0.001), "elapsed": snappedf(elapsed, 0.1),
			"in_water": rescue.swimmers().size()})
	reset()
	_log_snapshot()
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
		_log("rescue", "rescue.beer_ignored", "a beer on the %s hull was held back by the cooldown" % _hull_name(side),
				{"hull": _hull_name(side), "reason": "cooldown"})
		return Rescue.NOBODY
	var toss: float = paddling.tuning.beer_toss
	var beer_at: Vector2 = at_position + Vector2(-toss if side == Rescue.Hull.LEFT else toss, 0.0)
	var seat: int = rescue.beer_overboard(side, _seats_aboard(), beer_at, paddling.tuning.jump_delay)
	if seat != Rescue.NOBODY:
		_beer_loss_left = paddling.tuning.beer_loss_cooldown
		beer_overboard_started.emit(side)
		_log("rescue", "rescue.beer_overboard", "a beer went over on the %s hull, %s winds up to jump" % [
				_hull_name(side), _who(seat)], {"hull": _hull_name(side), "seat": seat})
	else:
		_log("rescue", "rescue.beer_ignored", "a beer on the %s hull, but nobody was free to jump" % _hull_name(side),
				{"hull": _hull_name(side), "reason": "nobody free"})
	return seat


## A guy fell in some other way than a jump (GDD › Drunkenness: the pee antic): he is off the
## boat, whatever antic he was busy with is over, and his strokes still waiting to land are
## dropped. With no beer loose for him he floats from the start and doesn't drink; caught
## winding up, he swims for his beer anyway (Rescue.guy_overboard). Nothing happens if he is
## already in the water. Emits guy_fell_in: his splash.
func guy_overboard(seat: int, at_position: Vector2, cause: String = "fell") -> void:
	if _take_off(seat, at_position):
		guy_fell_in.emit(seat)
		_log("rescue", "rescue.fell_in", "%s fell in (%s)" % [_who(seat), cause], {"seat": seat, "cause": cause})


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
	_log("rescue", "rescue.grabbed", "the beast grabbed %s on the %s hull" % [_who(seat), _hull_name(side)],
			{"seat": seat, "hull": _hull_name(side)})
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
	_log("rescue", "rescue.picked_up", "%s is back aboard%s" % [_who(seat), " with his beer" if had_beer else " without a beer"],
			{"seat": seat, "had_beer": had_beer})
	return had_beer


## A hazard pushes the boat (GDD › Systems › Hazards, Shove): `impulse` in lake pixels per
## second, which the boat adds to its speed next frame. Shoves in the same frame add up. A guy
## peeing at the edge loses his balance to a shove of DrinkTuning.pee_fall_shove or more
## (Antics.knocked_in) and goes in without his beer where the boat last stepped.
func shove(impulse: Vector2) -> void:
	_shove += impulse
	_log("hazard", "hazard.shove", "a shove of %d" % roundi(impulse.length()),
			{"x": snappedf(impulse.x, 0.1), "y": snappedf(impulse.y, 0.1), "strength": snappedf(impulse.length(), 0.1)})
	for seat: int in GUY_COUNT:
		if guys[seat].aboard and antics.knocked_in(seat, impulse.length()):
			guy_overboard(seat, _boat_at, "shove")


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
	if not _push_on:
		_push_on = true
		_log("hazard", "hazard.push", "the boat is pushed sideways at %d" % roundi(velocity.length()),
				{"x": snappedf(velocity.x, 0.1), "y": snappedf(velocity.y, 0.1)})


## The push waiting for the boat this frame, once: cleared when taken.
func take_push() -> Vector2:
	var velocity: Vector2 = _push
	_push = Vector2.ZERO
	if _push_on and velocity == Vector2.ZERO:
		_push_on = false
		_log("hazard", "hazard.push_ended", "the push stopped")
	return velocity


## A headwind makes the current stronger this step (the Harsh wind row): `per_second` pixels
## per second more of drift toward the shore, added to the next step()'s Motion.drift_to_shore
## and then forgotten, so a stretch sets it every step the boat is inside. Overlapping
## stretches don't stack: the strongest wins.
func set_extra_drift(per_second: float) -> void:
	_extra_drift = maxf(_extra_drift, per_second)
	if not _headwind_on and per_second > 0.0:
		_headwind_on = true
		_log("hazard", "hazard.headwind", "a headwind drives the boat back at %d" % roundi(per_second),
				{"per_second": snappedf(per_second, 0.1)})


## A hard hit stops the boat (Stop the boat): its speed goes to zero next frame.
func stop() -> void:
	_stop = true
	_log("hazard", "hazard.stop", "the boat is stopped dead")


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
		_log("hazard", "hazard.snag", "%s's paddle is snagged for %.1fs" % [_who(seat), seconds],
				{"seat": seat, "hull": _hull_name(side), "seconds": snappedf(seconds, 0.1)})
	else:
		_log("hazard", "hazard.snag", "a paddle snag on the %s hull found nobody" % _hull_name(side),
				{"seat": Rescue.NOBODY, "hull": _hull_name(side), "seconds": snappedf(seconds, 0.1)})
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
		_log("hazard", "hazard.forced_break", "%s is forced to take a break" % _who(seat),
				{"seat": seat, "hull": _hull_name(side)})
	return seat


## A hazard's warning has started (GDD › Systems › Hazards: every hazard is announced before it
## matters): `kind` names it (a Lines.KINDS entry) and `hull` is the side it comes from, or
## Rescue.NOBODY for none in particular. Only emits telegraphed; the bubbles do the rest.
func telegraph(kind: StringName, hull: int = Rescue.NOBODY) -> void:
	telegraphed.emit(kind, hull)
	_log("hazard", "hazard.telegraphed", "warning: %s from %s" % [kind, _hull_name(hull)],
			{"kind": str(kind), "hull": _hull_name(hull)})


## One of the Swedish lines for `kind` (GDD › World and Narrative), drawn with the RNG here so
## no screen rolls one; "" for a kind without lines.
func pick_line(kind: StringName) -> String:
	return lines.pick(kind, rng)


## The name of `seat`'s guy this attempt (T68, GDD › Characters and Units: the HUD shows it, not
## the key); "" before the first new_attempt() or for no such seat.
func name_of(seat: int) -> String:
	if seat < 0 or seat >= guy_names.size():
		return ""
	return guy_names[seat]


## Water comes in on `side` (Water aboard): `amount` of it, which that hull's guy bails at
## BoatTuning.bail_rate per second while his seat gives no strokes, until it is out. More
## water, longer bailing; with nobody aboard that hull it waits for him.
func water_aboard(side: Rescue.Hull, amount: float) -> void:
	_water[side] += maxf(amount, 0.0)
	_log("hazard", "hazard.water_aboard", "water comes in on the %s hull" % _hull_name(side),
			{"hull": _hull_name(side), "amount": snappedf(amount, 0.01)})


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
		var why: String = _block_of(seat)
		_log("action", "action.stroke_blocked", "%s tried to paddle but is %s" % [_who(seat), why],
				{"seat": seat, "hold_time": snappedf(hold_time, 0.01), "backwards": backwards, "reason": why})
		return
	var level: float = drunkenness.level_of(seat)
	stamina.burn(seat, paddling.stroke_force(hold_time))
	guys[seat].stamina = stamina.level_of(seat)
	if drunkenness.misses(level, rng):
		stroke_fumbled.emit(seat)
		_log("action", "action.stroke", "%s fumbled his stroke" % _who(seat),
				{"seat": seat, "hold_time": snappedf(hold_time, 0.01), "backwards": backwards, "outcome": "fumbled"})
		return
	var bar_missed: bool = drunkenness.uses_bar(seat) and not drunkenness.bar_hit(hold_time)
	var pending: Paddling.Stroke = Paddling.Stroke.new(seat, hold_time, backwards != bar_missed)
	var waiting: PendingStroke = PendingStroke.new(pending, drunkenness.stroke_delay(level))
	waiting.flipped = bar_missed
	_pending.append(waiting)


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
		_log("rescue", "rescue.jumped", "%s jumped in after his beer" % _who(seat), {"seat": seat})
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
		var before_drinking: float = drunkenness.level_of(seat)
		drunkenness.drink(seat, delta, guy.aboard and stamina.on_break(seat), in_water, drinking)
		stats.add_drunk(drunkenness.level_of(seat) - before_drinking, drunkenness.level_of(seat))
		if guy.aboard:
			antics.step(seat, delta, drunkenness.level_of(seat), rng)
			_relieve_after_antic(seat)
			_puke_if_at_top(seat)
		guy.stamina = stamina.level_of(seat)
		guy.drunkenness = drunkenness.level_of(seat)
	var motion: Paddling.Motion = paddling.step(_land_strokes(delta), delta)
	if _seats_aboard().is_empty():
		motion.drift_to_shore *= paddling.tuning.empty_drift_multiplier
	for seat: int in GUY_COUNT:
		motion.turn += antics.rock(seat) * delta
	motion.drift_to_shore += _extra_drift * delta
	if _headwind_on and _extra_drift <= 0.0:
		_headwind_on = false
		_log("hazard", "hazard.headwind_ended", "the headwind died down")
	_extra_drift = 0.0
	_log_changes()
	return motion


## A pee or a puke that ran its full course this step lowers his level by pee_relief or
## puke_relief (T63); a pee cut short by a knock-in never gets here (Antics.just_finished). A
## finished puke is announced with `puked` (T64), for the beast.
func _relieve_after_antic(seat: int) -> void:
	if not antics.just_finished(seat):
		return
	match antics.kind_of(seat):
		Antics.Kind.PEE:
			drunkenness.relieve(seat, drunkenness.tuning.pee_relief)
			_log("guy", "guy.peed", "%s finished peeing" % _who(seat), {"seat": seat})
		Antics.Kind.PUKE:
			drunkenness.relieve(seat, drunkenness.tuning.puke_relief)
			puked.emit(seat)
			_log("guy", "guy.puked", "%s puked" % _who(seat), {"seat": seat})


## At DrinkTuning.puke_level an idle guy aboard starts the puke's wind-up, once per crossing:
## below it he is armed again, so he pukes next when his level has reached the top anew (T63).
func _puke_if_at_top(seat: int) -> void:
	if drunkenness.level_of(seat) < drunkenness.tuning.puke_level:
		_puke_armed[seat] = true
	elif _puke_armed[seat] and antics.state_of(seat) == Antics.State.IDLE:
		_puke_armed[seat] = false
		antics.start(seat, Antics.Kind.PUKE)


## Where the boat is between the shore (0) and the island (1). Leaving the shore starts the
## crossing.
func set_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	if phase == Phase.LAUNCH and progress > 0.0:
		phase = Phase.CROSSING
		_log("run", "run.crossing_started", "the boat left the shore", {"elapsed": snappedf(elapsed, 0.1)})


## The boat has touched the island: the attempt is won if all four are aboard
## (GDD › Win and Loss); otherwise nothing happens and the boat can come back for them.
func arrive() -> void:
	if phase == Phase.WON:
		return
	if all_aboard():
		phase = Phase.WON
		_log("run", "run.won", "the boys reached the island in %.1fs" % elapsed,
				{"elapsed": snappedf(elapsed, 0.1), "lake_seed": lake_seed})
	else:
		var missing: Array[int] = []
		for guy: Guy in guys:
			if not guy.aboard:
				missing.append(guy.seat)
		_log("run", "run.arrived_short", "the boat reached the island with %d in the water" % missing.size(),
				{"missing": missing})


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
		else:
			_log("action", "action.stroke_dropped", "%s's stroke never landed" % _who(seat), {"seat": seat})
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
			_log("action", "action.stroke", "%s's stroke landed%s" % [_who(pending.stroke.seat),
					" backwards" if pending.stroke.backwards else ""],
					{"seat": pending.stroke.seat, "hold_time": snappedf(pending.stroke.hold_time, 0.01),
					"backwards": pending.stroke.backwards, "outcome": "landed", "bar_flipped": pending.flipped})
		else:
			waiting.append(pending)
	_pending = waiting
	return landed


# --- play log (T70) -------------------------------------------------------------------------------

## The state at a point worth a full picture, for PlayLog's _build_snapshot(): plain values only.
func snapshot() -> Dictionary:
	var crew: Array = []
	for guy: Guy in guys:
		var swimmer: Rescue.Swimmer = rescue.swimmer_of(guy.seat)
		var swim: String = "aboard"
		if swimmer != null:
			swim = str(Rescue.State.keys()[swimmer.state]).to_lower()
		crew.append({
			"seat": guy.seat,
			"name": name_of(guy.seat),
			"aboard": guy.aboard,
			"drunkenness": snappedf(guy.drunkenness, 0.001),
			"stamina": snappedf(guy.stamina, 0.001),
			"stamina_state": str(Stamina.State.keys()[stamina.state_of(guy.seat)]).to_lower(),
			"antic_state": str(Antics.State.keys()[antics.state_of(guy.seat)]).to_lower(),
			"antic_kind": str(Antics.Kind.keys()[antics.kind_of(guy.seat)]).to_lower(),
			"in_water": swimmer != null,
			"swim": swim,
			"has_beer": swimmer != null and swimmer.has_beer,
		})
	return {
		"phase": str(Phase.keys()[phase]).to_lower(),
		"progress": snappedf(progress, 0.001),
		"elapsed": snappedf(elapsed, 0.1),
		"lake_seed": lake_seed,
		"guys": crew,
	}


## Why the player can't act now, for PlayLog's progress_block_reason(): "" while someone is aboard
## (at the launch shore too: the strokes are what leave it), "won" once the island is reached,
## "nobody aboard" when all four are in the water.
func block_reason() -> String:
	if phase == Phase.WON:
		return "won"
	if _seats_aboard().is_empty():
		return "nobody aboard"
	return ""


## The PlayLog autoload (tools/play_log.gd), or null where it isn't there. Looked up through the
## main loop, so a RunState outside the tree (a test) finds it too.
func _log_node() -> Node:
	if _play_log == null or not is_instance_valid(_play_log):
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		_play_log = tree.root.get_node_or_null("PlayLog") if tree != null else null
	return _play_log


## One play-log line (category, a stable snake_case event id, a sentence and its data); a no-op
## without the PlayLog autoload.
func _log(category: String, event: String, text: String, data: Dictionary = {}) -> void:
	stats.count(StringName(event), data)
	var play_log: Node = _log_node()
	if play_log != null:
		play_log.log_event(category, event, text, data)


func _log_snapshot() -> void:
	var play_log: Node = _log_node()
	if play_log != null:
		play_log.log_snapshot()


## "left" or "right"; "none" for a hazard that comes from nowhere in particular.
func _hull_name(side: int) -> String:
	if side < 0 or side >= Rescue.Hull.size():
		return "none"
	return str(Rescue.Hull.keys()[side]).to_lower()


## The guy's name for a log sentence ("seat 2" before names are drawn).
func _who(seat: int) -> String:
	var guy_name: String = name_of(seat)
	return guy_name if not guy_name.is_empty() else "seat %d" % seat


## Why `seat` gives no strokes, for the log: the first of can_paddle()'s reasons that holds.
func _block_of(seat: int) -> String:
	if not guys[seat].aboard:
		return "in the water"
	if not stamina.can_stroke(seat):
		return "on a break"
	if not antics.can_stroke(seat):
		return "busy with an antic"
	if is_snagged(seat):
		return "snagged"
	return "bailing"


## The timing bar's tier for the log: 0 off, 1 winding up, 2 on.
func _bar_tier(seat: int) -> int:
	if drunkenness.uses_bar(seat):
		return 2
	return 1 if drunkenness.bar_winding_up(seat) else 0


## The swim state for the log: 0 aboard, 1 swimming for his beer, 2 floating, 3 swimming back to
## the boat, 4 washed up at the shoreline.
func _swim_tier(seat: int) -> int:
	var swimmer: Rescue.Swimmer = rescue.swimmer_of(seat)
	if swimmer == null:
		return 0
	if swimmer.washed_up:
		return 4
	if swimmer.state == Rescue.State.SWIMMING:
		return 1
	return 3 if swimmer.adrift > paddling.tuning.swim_back_delay else 2


## Records what each seat's log state is now without writing a line (after reset()).
func _sync_logged() -> void:
	_logged_antic.clear()
	_logged_stamina.clear()
	_logged_bar.clear()
	_logged_swim.clear()
	for seat: int in GUY_COUNT:
		_logged_antic.append(antics.state_of(seat))
		_logged_stamina.append(stamina.state_of(seat))
		_logged_bar.append(_bar_tier(seat))
		_logged_swim.append(_swim_tier(seat))


## One line per state change since the last step: an antic winding up or running, a stamina
## warning, break and its end, the timing bar's tier, and a swimmer reaching his beer, swimming
## back or washing up. A few comparisons per seat per step; nothing is written otherwise.
func _log_changes() -> void:
	for seat: int in GUY_COUNT:
		var antic: int = antics.state_of(seat)
		if antic != _logged_antic[seat]:
			_logged_antic[seat] = antic
			if antic != Antics.State.IDLE and antic != Antics.State.RECOVERING:
				var antic_state: String = str(Antics.State.keys()[antic]).to_lower()
				var kind: String = str(Antics.Kind.keys()[antics.kind_of(seat)]).to_lower()
				_log("guy", "guy.antic", "%s: %s (%s)" % [_who(seat), kind, antic_state],
						{"seat": seat, "kind": kind, "state": antic_state})
		var energy: int = stamina.state_of(seat)
		if energy != _logged_stamina[seat]:
			_logged_stamina[seat] = energy
			var energy_state: String = str(Stamina.State.keys()[energy]).to_lower()
			_log("guy", "guy.break", "%s: stamina %s" % [_who(seat), energy_state],
					{"seat": seat, "state": energy_state})
		var tier: int = _bar_tier(seat)
		if tier != _logged_bar[seat]:
			_logged_bar[seat] = tier
			var tier_name: String = ["off", "wind_up", "on"][tier]
			_log("guy", "guy.bar", "%s: timing bar %s" % [_who(seat), tier_name.replace("_", " ")],
					{"seat": seat, "tier": tier_name})
		var swim: int = _swim_tier(seat)
		if swim != _logged_swim[seat]:
			var before: int = _logged_swim[seat]
			_logged_swim[seat] = swim
			# Into the water is logged by its jump or fall, and out of it by the pickup.
			if before != 0 and swim > 1:
				var swim_name: String = ["", "", "floating", "swimming_back", "washed_up"][swim]
				_log("rescue", "rescue.%s" % swim_name, "%s is %s" % [_who(seat), swim_name.replace("_", " ")],
						{"seat": seat})


# --- dev menu hooks (T72) -------------------------------------------------------------------------
# Each debug_* method is a button on the dev menu's Run tab (tools/dev_menu.gd); debug_inspect() is
# its inspector. They reach a state by hand for the assistant; the menu logs each call as
# devmenu.action, and the effects they start log their own lines.

## Seconds debug_snag() holds a paddle: the snag hazard's default (data/lake_tuning.tres, snag_time).
const DEBUG_SNAG_SECONDS: float = 3.0
## Water debug_water() puts in: the wake's water (data/lake_tuning.tres, wake_water).
const DEBUG_WATER: float = 3.0


## A beer overboard on the left hull at the boat's last stepped position.
func debug_beer_left() -> void:
	beer_overboard(Rescue.Hull.LEFT, _boat_at)


## A beer overboard on the right hull at the boat's last stepped position.
func debug_beer_right() -> void:
	beer_overboard(Rescue.Hull.RIGHT, _boat_at)


## Starts the antic of Antics.Kind `kind` on `seat` now: 0 stand, 1 drop the paddle, 2 nod off,
## 3 pee, 4 puke. A wind-up as at a threshold; nothing happens while he is busy with another.
func debug_force_antic(seat: int, kind: int) -> void:
	if _is_seat(seat):
		antics.start(seat, clampi(kind, 0, Antics.Kind.size() - 1) as Antics.Kind)


## One guy's drunkenness set to `level` (0..1), mirrored into his Guy.
func debug_set_drunkenness(seat: int, level: float) -> void:
	if _is_seat(seat):
		drunkenness.set_level(seat, level)
		guys[seat].drunkenness = drunkenness.level_of(seat)


## One guy's stamina set to `level` (0..1), mirrored into his Guy.
func debug_set_stamina(seat: int, level: float) -> void:
	if _is_seat(seat):
		stamina.set_level(seat, level)
		guys[seat].stamina = stamina.level_of(seat)


## One guy's stamina break called now, its warning first as any break.
func debug_force_break(seat: int) -> void:
	if _is_seat(seat):
		stamina.call_break(seat)


## One guy's paddle snagged for DEBUG_SNAG_SECONDS. By seat, where snag() takes a hull, so it
## holds the guy named rather than the hull's front guy.
func debug_snag(seat: int) -> void:
	if _is_seat(seat):
		_snag_left[seat] = maxf(_snag_left[seat], DEBUG_SNAG_SECONDS)


## Water comes in on hull `side` (0 left, 1 right): DEBUG_WATER, as the wake puts in.
func debug_water(side: int) -> void:
	if side >= 0 and side < Rescue.Hull.size():
		water_aboard(side as Rescue.Hull, DEBUG_WATER)


## The boat touches the island (arrive): the attempt is won only with all four aboard.
func debug_win() -> void:
	arrive()


## The dev menu's Run inspector: the phase, progress, elapsed time, lake seed and block reason, then
## one line per guy ("<name> (seat n)"): aboard or in the water, drunkenness, stamina and its state,
## and his antic.
func debug_inspect() -> Dictionary:
	var reason: String = block_reason()
	var values: Dictionary = {
		"phase": str(Phase.keys()[phase]).to_lower(),
		"progress": snappedf(progress, 0.001),
		"elapsed": snappedf(elapsed, 0.1),
		"lake_seed": lake_seed,
		"block reason": reason if not reason.is_empty() else "none",
	}
	for guy: Guy in guys:
		var label: String = name_of(guy.seat)
		if label.is_empty():
			label = "guy"
		values["%s (seat %d)" % [label, guy.seat]] = _describe_guy(guy)
	return values


## One guy's line in debug_inspect().
func _describe_guy(guy: Guy) -> String:
	var swimmer: Rescue.Swimmer = rescue.swimmer_of(guy.seat)
	var place: String = "aboard"
	if swimmer != null:
		place = "in the water, %s, %s" % [str(Rescue.State.keys()[swimmer.state]).to_lower(),
				"with his beer" if swimmer.has_beer else "no beer"]
	elif rescue.winding_up(guy.seat):
		place = "aboard, winding up to jump"
	var antic: String = str(Antics.State.keys()[antics.state_of(guy.seat)]).to_lower()
	if antic != "idle":
		antic += " " + str(Antics.Kind.keys()[antics.kind_of(guy.seat)]).to_lower()
	return "%s, drunkenness %.2f, stamina %.2f (%s), antic %s" % [place, drunkenness.level_of(guy.seat),
			stamina.level_of(guy.seat), str(Stamina.State.keys()[stamina.state_of(guy.seat)]).to_lower(), antic]


## Whether `seat` is one of the four guys.
func _is_seat(seat: int) -> bool:
	return seat >= 0 and seat < GUY_COUNT
