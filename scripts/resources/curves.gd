class_name Curves
extends RefCounted
## Curves · helpers that build the Curve values the tunings hold (GDD › Systems › Drunkenness,
## GDD › Systems › Stamina, GDD › Systems › Lake and island).
##
## Pure helpers: no state and no scene tree. A curve maps a 0..1 input (x) to an effect (y).


## A straight line from (0, y_start) to (1, y_end): linear tangents, so sample(x) is the lerp.
## The curve's value range widens to hold 0 and 1 as well as both ends.
static func ramp(y_start: float, y_end: float) -> Curve:
	var curve: Curve = Curve.new()
	curve.min_value = minf(0.0, minf(y_start, y_end))
	curve.max_value = maxf(1.0, maxf(y_start, y_end))
	var slope: float = y_end - y_start
	curve.add_point(Vector2(0.0, y_start), slope, slope, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	curve.add_point(Vector2(1.0, y_end), slope, slope, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	return curve
