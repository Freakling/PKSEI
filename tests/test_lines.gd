extends "res://tools/test_case.gd"
## T56 · Lines: data/lines.tres has at least one Swedish line for every telegraph and every hazard
## in Lines.KINDS, pick() returns one of that kind's lines, and RunState hands them out: pick_line()
## draws one with its RNG and telegraph() emits telegraphed with the kind and the hull, and
## pick_line(kind, seat) emits spoke with the seat and the kind (T94: the babble), never for a kind
## without lines (GDD › World and Narrative).

const RunStateScript: GDScript = preload("res://scripts/autoload/run_state.gd")
const LINES: Lines = preload("res://data/lines.tres")

## What the last telegraphed signal carried.
var _heard_kind: StringName = &""
var _heard_hull: int = -99
var _heard_count: int = 0
## What the last spoke signal carried (T94), and how many came.
var _spoke_seat: int = -99
var _spoke_kind: StringName = &""
var _spoke_count: int = 0


func before_each() -> void:
	_heard_kind = &""
	_heard_hull = -99
	_heard_count = 0
	_spoke_seat = -99
	_spoke_kind = &""
	_spoke_count = 0


func test_every_kind_has_at_least_one_line() -> void:
	for kind: StringName in Lines.KINDS:
		expect(LINES.lines_of(kind).size() >= 1, "data/lines.tres has a line for %s" % kind)
		for line: String in LINES.lines_of(kind):
			expect_false(line.strip_edges().is_empty(), "no blank line for %s" % kind)


func test_the_swimmers_kinds_have_three_lines_each_and_the_two_quoted_ones() -> void:
	for kind: StringName in [&"swim_fetch", &"swim_drink", &"swim_fell", &"swim_back"]:
		expect(Lines.KINDS.has(kind), "%s is a Lines.KINDS entry" % kind)
		expect(LINES.lines_of(kind).size() >= 3, "%s has at least three lines" % kind)
	expect(LINES.lines_of(&"swim_drink").has("Ska bara dricka sen kommer jag"))
	expect(LINES.lines_of(&"swim_back").has("Kom och hämta mig dåååå!"))


func test_left_behind_has_six_lines_each_with_one_name_slot() -> void:
	expect(Lines.KINDS.has(&"left_behind"), "left_behind is a Lines.KINDS entry")
	var lines: PackedStringArray = LINES.lines_of(&"left_behind")
	expect(lines.size() >= 6, "at least six dark jokes")
	for line: String in lines:
		expect_eq(line.count("%s"), 1, "exactly one %%s in: %s" % line)
		expect_eq(line % "Göras", line.replace("%s", "Göras"), "the name goes in")


func test_the_resource_lists_no_kind_outside_kinds() -> void:
	for kind: StringName in LINES.lines.keys():
		expect(Lines.KINDS.has(kind), "%s in data/lines.tres is a Lines.KINDS entry" % kind)


func test_pick_returns_one_of_the_kinds_lines() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	for kind: StringName in Lines.KINDS:
		for _draw: int in 8:
			var line: String = LINES.pick(kind, rng)
			expect(LINES.lines_of(kind).has(line), "pick(%s) gave %s, one of its lines" % [kind, line])


func test_pick_of_an_unknown_kind_is_empty() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	expect_eq(LINES.pick(&"no_such_kind", rng), "")


func test_run_state_pick_line_draws_from_its_lines() -> void:
	var state: Node = RunStateScript.new()
	state.rng.seed = 7
	state.reset()
	var line: String = state.pick_line(&"gust")
	expect(state.lines.lines_of(&"gust").has(line), "pick_line(gust) gave %s" % line)
	expect_eq(state.pick_line(&"no_such_kind"), "", "nothing for an unknown kind")
	state.free()


func test_pick_line_with_a_seat_emits_spoke_with_that_seat_and_kind() -> void:
	var state: Node = RunStateScript.new()
	state.rng.seed = 11
	state.reset()
	state.spoke.connect(_on_spoke)
	var line: String = state.pick_line(&"gust", 2)
	expect(line != "", "pick_line(gust) gave a line")
	expect_eq(_spoke_seat, 2, "spoke carries the seat that says the line")
	expect_eq(_spoke_kind, &"gust", "spoke carries the kind")
	expect_eq(_spoke_count, 1, "one spoke per line")
	state.free()


func test_pick_line_of_an_unknown_kind_emits_no_spoke() -> void:
	var state: Node = RunStateScript.new()
	state.reset()
	state.spoke.connect(_on_spoke)
	expect_eq(state.pick_line(&"no_such_kind", 1), "")
	expect_eq(_spoke_count, 0, "no spoke for a kind without lines")
	state.free()


func test_telegraph_emits_telegraphed_with_the_kind_and_the_hull() -> void:
	var state: Node = RunStateScript.new()
	state.reset()
	state.telegraphed.connect(_on_telegraphed)
	state.telegraph(&"geese", Rescue.Hull.RIGHT)
	expect_eq(_heard_kind, &"geese")
	expect_eq(_heard_hull, Rescue.Hull.RIGHT)
	state.telegraph(&"headwind")
	expect_eq(_heard_kind, &"headwind")
	expect_eq(_heard_hull, Rescue.NOBODY, "no hull in particular by default")
	expect_eq(_heard_count, 2, "one signal per call")
	state.free()


func _on_telegraphed(kind: StringName, hull: int) -> void:
	_heard_kind = kind
	_heard_hull = hull
	_heard_count += 1


func _on_spoke(seat: int, kind: StringName) -> void:
	_spoke_seat = seat
	_spoke_kind = kind
	_spoke_count += 1
