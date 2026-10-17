extends "res://tools/test_case.gd"
## T68 · Names: data/names.tres holds at least four distinct nicknames, pick_four() draws four
## distinct ones from the list with the RNG it is given (the same seed gives the same four; a
## repeated entry counts once), and RunState hands them out per seat with name_of()
## (GDD › Characters and Units).

const RunStateScript: GDScript = preload("res://scripts/autoload/run_state.gd")
const NAMES: Names = preload("res://data/names.tres")


func test_the_list_holds_at_least_four_distinct_names() -> void:
	expect(NAMES.names.size() >= Names.CREW, "data/names.tres has at least %d names" % Names.CREW)
	expect(NAMES.distinct().size() >= Names.CREW, "at least %d of them distinct" % Names.CREW)
	for entry: String in NAMES.names:
		expect_false(entry.strip_edges().is_empty(), "no blank name")


func test_pick_four_gives_four_distinct_names_from_the_list() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for draw: int in 16:
		rng.seed = draw
		var four: PackedStringArray = NAMES.pick_four(rng)
		expect_eq(four.size(), Names.CREW, "four names for seed %d" % draw)
		for i: int in four.size():
			expect(NAMES.names.has(four[i]), "%s is in the list" % four[i])
			for j: int in four.size():
				if i != j:
					expect_ne(four[i], four[j], "names %d and %d differ for seed %d" % [i, j, draw])


func test_the_same_seed_gives_the_same_four() -> void:
	var first: RandomNumberGenerator = RandomNumberGenerator.new()
	var second: RandomNumberGenerator = RandomNumberGenerator.new()
	first.seed = 11
	second.seed = 11
	expect(NAMES.pick_four(first) == NAMES.pick_four(second), "same seed, same four")


func test_another_seed_can_give_another_four() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 0
	var first: PackedStringArray = NAMES.pick_four(rng)
	var differs: bool = false
	for draw: int in range(1, 32):
		rng.seed = draw
		if NAMES.pick_four(rng) != first:
			differs = true
	expect(differs, "some seed draws another four")


func test_a_repeated_entry_counts_once_and_a_short_list_gives_all_it_has() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1
	var crew: Names = Names.new()
	crew.names = PackedStringArray(["Danne!", "Danne!", "Matte", "Matte", "Bibbe", "Ryggen"])
	var four: PackedStringArray = crew.pick_four(rng)
	expect_eq(four.size(), Names.CREW, "four from six entries, four of them distinct")
	for i: int in four.size():
		for j: int in four.size():
			if i != j:
				expect_ne(four[i], four[j], "no repeat from a list with repeats")
	crew.names = PackedStringArray(["Vajking", "Skrattet"])
	expect_eq(crew.pick_four(rng).size(), 2, "a short list gives all it has")


func test_run_state_hands_each_seat_its_name() -> void:
	var state: Node = RunStateScript.new()
	expect_eq(state.name_of(0), "", "no name before the first attempt")
	state.rng.seed = 7
	state.new_attempt()
	for seat: int in RunStateScript.GUY_COUNT:
		expect_eq(state.name_of(seat), state.guy_names[seat], "seat %d reads guy_names" % seat)
		expect(NAMES.names.has(state.name_of(seat)), "seat %d has a name from the list" % seat)
	expect_eq(state.name_of(RunStateScript.GUY_COUNT), "", "no such seat, no name")
	state.free()
