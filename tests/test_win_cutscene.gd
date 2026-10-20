extends "res://tools/test_case.gd"
## T97 · Landing short-handed is a win (GDD › Win and Loss): the win title's heading says how many
## made it, each guy left in the water gets one dark joke with his name (the pure helpers on
## WinCutscene), and the island is solid: the lake has a body at the island, a little smaller than
## its area, so the boat stops at the shore instead of sailing over it.

const LakeScene: PackedScene = preload("res://scenes/lake.tscn")
const LINES: Lines = preload("res://data/lines.tres")


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_the_heading_is_they_made_it_for_a_full_crew_and_a_count_otherwise() -> void:
	expect_eq(WinCutscene.heading_text(4), "They made it")
	expect_eq(WinCutscene.heading_text(3), "3 of 4 made it")
	expect_eq(WinCutscene.heading_text(1), "1 of 4 made it")


func test_each_left_behind_guy_gets_a_line_holding_his_name() -> void:
	var names: Array[String] = ["Göras", "Lill-Pelle"]
	var lines: Array[String] = WinCutscene.left_behind_lines(names, LINES.lines_of(&"left_behind"), _rng(5))
	expect_eq(lines.size(), 2, "one line per guy")
	expect(lines[0].contains("Göras"), "the first line names the first guy: %s" % lines[0])
	expect(lines[1].contains("Lill-Pelle"), "the second names the second: %s" % lines[1])
	expect_false(lines[0].contains("%s"), "no slot is left unfilled")
	var names_none: Array[String] = []
	expect_eq(WinCutscene.left_behind_lines(names_none, LINES.lines_of(&"left_behind"), _rng(5)).size(), 0, "nobody left, no lines")


func test_two_left_behind_guys_do_not_get_the_same_joke() -> void:
	var names: Array[String] = ["A", "B", "C"]
	for seed_value: int in 20:
		var lines: Array[String] = WinCutscene.left_behind_lines(names, LINES.lines_of(&"left_behind"), _rng(seed_value))
		var unmade: Array[String] = []
		for i: int in lines.size():
			unmade.append(lines[i].replace(names[i], "%s"))
		var seen: Dictionary = {}
		for line: String in unmade:
			seen[line] = true
		expect_eq(seen.size(), 3, "three different jokes (seed %d)" % seed_value)


func test_no_lines_give_no_jokes_and_a_line_without_a_slot_is_used_as_it_is() -> void:
	var names: Array[String] = ["Göras"]
	expect_eq(WinCutscene.left_behind_lines(names, PackedStringArray(), _rng(1)).size(), 0, "no lines, no jokes")
	var plain: Array[String] = WinCutscene.left_behind_lines(names, PackedStringArray(["Gone."]), _rng(1))
	expect_eq(plain[0], "Gone.")


func test_the_island_has_a_solid_body_just_inside_its_area() -> void:
	var lake: Node = LakeScene.instantiate()
	Engine.get_main_loop().root.add_child(lake)
	var body: StaticBody2D = lake.get_node("IslandBody") as StaticBody2D
	var area: Area2D = lake.get_node("Island") as Area2D
	expect(body != null, "the lake has an IslandBody")
	expect(body.position.is_equal_approx(area.position), "the body is at the island")
	var body_circle: CircleShape2D = (body.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	var area_circle: CircleShape2D = (area.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	expect(body_circle.radius > 0.0, "the body has a shape")
	expect(body_circle.radius < area_circle.radius, "smaller than the area, so a stopped boat still touches it")
	expect_near(area_circle.radius - body_circle.radius, 2.0, 0.001, "by the stop inset")
	var boat: CharacterBody2D = lake.get_node("Catamaran") as CharacterBody2D
	expect(boat.collision_mask & body.collision_layer != 0, "the boat's mask hits the island's layer")
	Engine.get_main_loop().root.remove_child(lake)
	lake.free()
