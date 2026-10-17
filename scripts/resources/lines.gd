class_name Lines
extends Resource
## Lines · what the guys say (GDD › World and Narrative: the guys speak Swedish; every telegraph
## gets a speech bubble, so the warning is also the joke).
##
## Schema only. The instance the human edits is data/lines.tres: per kind of telegraph, the
## Swedish lines a bubble may show, short enough for a bubble at 1×. The guys' own wind-ups
## (GDD › Systems › Drunkenness, Stamina; GDD › Systems › Setbacks for the jump) and the hazards'
## warnings (GDD › Systems › Hazards) are the KINDS; RunState.pick_line() draws one with its RNG
## (scripts/ui/speech_bubbles.gd shows it). tests/test_lines.gd checks every kind has a line.

## Every telegraph that gets a bubble, in one list so the test can walk it. The guys' wind-ups:
## the break warning, the five antics' wind-ups (the puke at the top of the meter, T63), the
## timing bar's wind-up and the jump after a beer; then the hazards' warnings, and the log and
## the rock ahead on the path.
const KINDS: Array[StringName] = [
	&"stamina_warning", &"antic_stand", &"antic_paddle", &"antic_nap", &"antic_pee",
	&"antic_puke", &"bar_windup", &"jump_windup",
	&"geese", &"gust", &"headwind", &"wake", &"jetski", &"beast", &"log", &"rock",
]

## The lines per kind (a KINDS entry): a bubble shows one of them, drawn at random.
@export var lines: Dictionary[StringName, PackedStringArray] = {}


## One of `kind`'s lines, drawn with `rng`; "" when the kind has none.
func pick(kind: StringName, rng: RandomNumberGenerator) -> String:
	var choices: PackedStringArray = lines_of(kind)
	if choices.is_empty():
		return ""
	return choices[rng.randi_range(0, choices.size() - 1)]


## All of `kind`'s lines; empty for a kind with none.
func lines_of(kind: StringName) -> PackedStringArray:
	return lines.get(kind, PackedStringArray())
