class_name Stats
extends RefCounted
## Stats · the crossing's counters for the win title (T86, GDD › Win and Loss): everything the
## run counted, from strokes to the drunkest moment.
##
## Pure counters, no rules. RunState owns one and hands it every play-log event it writes
## (count(event, data)), so a counted event is always one the log has and there is no second list
## of call sites; the drunkenness a guy gains is added per step (add_drunk). A new attempt starts
## the counters over (reset); a shore reset is the same attempt and keeps them. The title reads
## rows(): label/value Strings in a stable order, zero rows kept.
##
## The hazard hits are counted by their effect (shoves, stops, snags, pushes), because the log
## lines do not say which hazard sent them. Water is the amount put aboard, whether or not it
## was bailed in the end.

var strokes: int = 0
var fumbles: int = 0
var reverse_strokes: int = 0
var beers_overboard: int = 0
var beers_rescued: int = 0
var jumps: int = 0
var falls: int = 0
var grabs: int = 0
var pickups: int = 0
var pukes: int = 0
var pisses: int = 0
var naps: int = 0
var stand_ups: int = 0
var paddles_dropped: int = 0
var breaks: int = 0
var snags: int = 0
var water: float = 0.0
var shoves: int = 0
var stops: int = 0
var pushes: int = 0
var shore_resets: int = 0
## The guys left in the water when the boat landed (T97).
var left_behind: int = 0
## The positive changes of every guy's level, summed (what the beers drunk are estimated from).
var drunk_gained: float = 0.0
## The highest level any guy reached.
var max_drunkenness: float = 0.0


func reset() -> void:
	strokes = 0
	fumbles = 0
	reverse_strokes = 0
	beers_overboard = 0
	beers_rescued = 0
	jumps = 0
	falls = 0
	grabs = 0
	pickups = 0
	pukes = 0
	pisses = 0
	naps = 0
	stand_ups = 0
	paddles_dropped = 0
	breaks = 0
	snags = 0
	water = 0.0
	shoves = 0
	stops = 0
	pushes = 0
	shore_resets = 0
	left_behind = 0
	drunk_gained = 0.0
	max_drunkenness = 0.0


## Counts one play-log event by its id; ids that are not counted are ignored. `data` is the
## line's data (what RunState._log wrote).
func count(event: StringName, data: Dictionary = {}) -> void:
	match event:
		&"action.stroke":
			match str(data.get("outcome", "")):
				"landed":
					strokes += 1
					if data.get("backwards", false):
						reverse_strokes += 1
				"fumbled":
					fumbles += 1
		&"rescue.beer_overboard":
			beers_overboard += 1
		&"rescue.jumped":
			jumps += 1
		&"rescue.fell_in":
			falls += 1
		&"rescue.grabbed":
			grabs += 1
		&"rescue.picked_up":
			pickups += 1
			if data.get("had_beer", false):
				beers_rescued += 1
		&"guy.puked":
			pukes += 1
		&"guy.antic":
			match str(data.get("state", "")):
				"standing":
					stand_ups += 1
				"paddle_dropped":
					paddles_dropped += 1
				"nodded_off":
					naps += 1
				"peeing":
					pisses += 1
		&"guy.break":
			if str(data.get("state", "")) == "break":
				breaks += 1
		&"hazard.snag":
			# A snag that found nobody is no hit (its seat is Rescue.NOBODY).
			if int(data.get("seat", Rescue.NOBODY)) != Rescue.NOBODY:
				snags += 1
		&"hazard.water_aboard":
			water += float(data.get("amount", 0.0))
		&"hazard.shove":
			shoves += 1
		&"hazard.stop":
			stops += 1
		&"hazard.push":
			pushes += 1
		&"run.shore_reset":
			shore_resets += 1
		&"run.won":
			left_behind = (data.get("left_behind", []) as Array).size()


## One guy's level moved up by `gained` (never negative: relief is not counted) and stands at
## `level` now.
func add_drunk(gained: float, level: float) -> void:
	drunk_gained += maxf(gained, 0.0)
	max_drunkenness = maxf(max_drunkenness, level)


## The beers drunk, estimated: the drunkenness gained over the level a beer is worth, rounded.
func beers_drunk(level_per_beer: float) -> int:
	if level_per_beer <= 0.0:
		return 0
	return roundi(drunk_gained / level_per_beer)


## Jumps, falls and beast grabs: every time a guy went in the water.
func times_in_water() -> int:
	return jumps + falls + grabs


## The crossing time as m:ss.
static func format_time(seconds: float) -> String:
	var whole: int = int(floorf(maxf(seconds, 0.0)))
	@warning_ignore("integer_division")
	return "%d:%02d" % [whole / 60, whole % 60]


## The title's rows, in a stable order with the zero ones kept: {"label", "value"} Strings.
## `elapsed` is the crossing time in seconds and `level_per_beer` DrinkTuning's.
func rows(elapsed: float, level_per_beer: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_row(out, "Time", format_time(elapsed))
	_row(out, "Shore resets", str(shore_resets))
	_row(out, "Left behind", str(left_behind))
	_row(out, "Strokes", str(strokes))
	_row(out, "Fumbles", str(fumbles))
	_row(out, "Reverse strokes", str(reverse_strokes))
	_row(out, "Beers drunk", str(beers_drunk(level_per_beer)))
	_row(out, "Beers overboard", str(beers_overboard))
	_row(out, "Beers rescued", str(beers_rescued))
	_row(out, "Times in the water", str(times_in_water()))
	_row(out, "Jumps", str(jumps))
	_row(out, "Fell in", str(falls))
	_row(out, "Beast grabs", str(grabs))
	_row(out, "Pukes", str(pukes))
	_row(out, "Pisses", str(pisses))
	_row(out, "Naps", str(naps))
	_row(out, "Stand-ups", str(stand_ups))
	_row(out, "Paddles dropped", str(paddles_dropped))
	_row(out, "Breaks", str(breaks))
	_row(out, "Snags", str(snags))
	_row(out, "Water bailed", "%.1f" % water)
	_row(out, "Shoves", str(shoves))
	_row(out, "Stops", str(stops))
	_row(out, "Pushes", str(pushes))
	_row(out, "Drunkest", "%d%%" % roundi(max_drunkenness * 100.0))
	return out


func _row(out: Array[Dictionary], label: String, value: String) -> void:
	out.append({"label": label, "value": value})
