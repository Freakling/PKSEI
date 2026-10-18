extends "res://tools/test_case.gd"
## T72 · The dev menu (tools/dev_menu.gd) registers RunState, Rescue, Antics, Stamina and Drunkenness
## with their debug hooks: the Run inspector lists the phase, the progress and the four guys, and
## each debug action reaches the attempt (rules.md › Agent-visible state, Every action is drivable).
## The menu is the DevMenu autoload, as the check runs it; it is available in a debug build.


## The DevMenu autoload from the tree (null if it isn't there).
func _menu() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("/root/DevMenu") if tree != null else null


## A fresh attempt on the RunState autoload, the menu's system.
func before_each() -> void:
	RunState.new_attempt()


func _has_action(menu: Node, system_name: String, method: String) -> bool:
	var actions: Array[Dictionary] = menu.actions_of(system_name)
	for action: Dictionary in actions:
		if str(action["method"]) == method:
			return true
	return false


func test_the_menu_is_available_in_a_debug_build_and_registers_its_systems() -> void:
	var menu: Node = _menu()
	expect(menu != null, "the DevMenu autoload is in the tree")
	if menu == null:
		return
	expect(menu.is_available(), "the menu is enabled in a debug build (Dev menu: in game)")
	var names: PackedStringArray = menu.systems()
	for system_name: String in ["Run", "Rescue", "Antics", "Stamina", "Drunkenness"]:
		expect(names.has(system_name), "%s is registered (got %s)" % [system_name, ", ".join(names)])


func test_the_run_inspector_lists_progress_the_phase_and_the_four_guys() -> void:
	var menu: Node = _menu()
	if menu == null:
		fail("the DevMenu autoload is in the tree")
		return
	var text: String = menu.inspect_text("Run")
	expect(text.contains("progress"), "the Run inspector has the progress")
	expect(text.contains("phase: launch"), "the Run inspector has the phase (got %s)" % text)
	var values: Dictionary = menu.inspect("Run")
	for seat: int in RunState.GUY_COUNT:
		var guy_name: String = RunState.name_of(seat)
		expect(not guy_name.is_empty(), "seat %d has a name" % seat)
		expect(text.contains(guy_name), "the inspector names %s" % guy_name)
		expect(values.has("%s (seat %d)" % [guy_name, seat]), "an entry for %s (seat %d)" % [guy_name, seat])
	RunState.set_progress(0.2)
	expect(str(menu.inspect_text("Run")).contains("phase: crossing"), "the phase follows the attempt")


func test_the_run_tab_shows_its_hooks_and_its_public_actions() -> void:
	var menu: Node = _menu()
	if menu == null:
		fail("the DevMenu autoload is in the tree")
		return
	for method: String in ["debug_beer_left", "debug_beer_right", "debug_force_antic", "debug_set_drunkenness",
			"debug_set_stamina", "debug_force_break", "debug_snag", "debug_water", "debug_win",
			"new_attempt", "shore_touched", "pickup"]:
		expect(_has_action(menu, "Run", method), "the Run tab has %s" % method)
	expect(not _has_action(menu, "Run", "debug_inspect"), "debug_inspect is the inspector, not a button")


func test_the_rule_tabs_show_their_state_and_their_actions() -> void:
	var menu: Node = _menu()
	if menu == null:
		fail("the DevMenu autoload is in the tree")
		return
	expect(str(menu.inspect_text("Antics")).contains("seat 3: idle"), "Antics lists each seat")
	expect(str(menu.inspect_text("Stamina")).contains("seat 0: level 1.00"), "Stamina lists each seat")
	expect(str(menu.inspect_text("Drunkenness")).contains("seat 0: level 0.15"), "Drunkenness lists each seat")
	expect(str(menu.inspect_text("Rescue")).contains("nobody"), "Rescue says nobody is in the water")
	expect(_has_action(menu, "Stamina", "call_break"), "Stamina has call_break")
	expect(_has_action(menu, "Antics", "interrupt"), "Antics has interrupt")
	expect(_has_action(menu, "Drunkenness", "relieve"), "Drunkenness has relieve")


func test_the_drunkenness_action_sets_a_guys_level() -> void:
	var menu: Node = _menu()
	if menu == null:
		fail("the DevMenu autoload is in the tree")
		return
	menu.run_action("Run", "debug_set_drunkenness", [0, 0.5])
	var last: String = menu.last_result
	expect_eq(last, "done", "the action ran")
	expect_near(RunState.drunkenness.level_of(0), 0.5, 0.0001, "the rule's level")
	expect_near(RunState.guys[0].drunkenness, 0.5, 0.0001, "the guy's mirrored level")


func test_the_stamina_action_sets_a_guys_level() -> void:
	var menu: Node = _menu()
	if menu == null:
		fail("the DevMenu autoload is in the tree")
		return
	menu.run_action("Run", "debug_set_stamina", [1, 0.25])
	expect_near(RunState.stamina.level_of(1), 0.25, 0.0001, "the rule's stamina")
	expect_near(RunState.guys[1].stamina, 0.25, 0.0001, "the guy's mirrored stamina")


func test_the_beer_actions_put_a_beer_over_on_their_hull() -> void:
	var menu: Node = _menu()
	if menu == null:
		fail("the DevMenu autoload is in the tree")
		return
	menu.run_action("Run", "debug_beer_left", [])
	var left: Array[Rescue.LooseBeer] = RunState.rescue.loose_beers()
	expect_eq(left.size(), 1, "a beer goes over on the left hull")
	if left.size() == 1:
		expect(Rescue.seats_on(Rescue.Hull.LEFT).has(left[0].seat), "the jumper is on the left hull")
	RunState.new_attempt()
	menu.run_action("Run", "debug_beer_right", [])
	var right: Array[Rescue.LooseBeer] = RunState.rescue.loose_beers()
	expect_eq(right.size(), 1, "a beer goes over on the right hull")
	if right.size() == 1:
		expect(Rescue.seats_on(Rescue.Hull.RIGHT).has(right[0].seat), "the jumper is on the right hull")


func test_the_force_antic_action_starts_the_antic_of_that_kind() -> void:
	var menu: Node = _menu()
	if menu == null:
		fail("the DevMenu autoload is in the tree")
		return
	menu.run_action("Run", "debug_force_antic", [1, Antics.Kind.PEE])
	expect_eq(RunState.antics.state_of(1), Antics.State.WINDING_UP, "seat 1 winds up")
	expect_eq(RunState.antics.kind_of(1), Antics.Kind.PEE, "for a pee")
	expect_eq(RunState.antics.state_of(0), Antics.State.IDLE, "the other guys are untouched")


func test_the_snag_action_holds_that_guys_paddle() -> void:
	var menu: Node = _menu()
	if menu == null:
		fail("the DevMenu autoload is in the tree")
		return
	menu.run_action("Run", "debug_snag", [2])
	expect(RunState.is_snagged(2), "seat 2's paddle is snagged")
	expect_near(RunState.snag_left(2), RunState.DEBUG_SNAG_SECONDS, 0.0001, "for the debug snag's seconds")
	expect_false(RunState.is_snagged(0), "the others are free")


func test_the_water_action_puts_water_on_that_hull() -> void:
	var menu: Node = _menu()
	if menu == null:
		fail("the DevMenu autoload is in the tree")
		return
	menu.run_action("Run", "debug_water", [1])
	expect(RunState.water_of(Rescue.Hull.RIGHT) > 0.0, "the right hull takes water")
	expect_near(RunState.water_of(Rescue.Hull.LEFT), 0.0, 0.0001, "the left hull stays dry")


func test_the_break_action_calls_a_break_on_that_guy() -> void:
	var menu: Node = _menu()
	if menu == null:
		fail("the DevMenu autoload is in the tree")
		return
	menu.run_action("Run", "debug_force_break", [3])
	expect_eq(RunState.stamina.state_of(3), Stamina.State.WARNING, "seat 3's break is called (warning first)")
	expect_eq(RunState.stamina.state_of(0), Stamina.State.PADDLING, "the others keep paddling")


func test_the_win_action_arrives_with_all_four_aboard() -> void:
	var menu: Node = _menu()
	if menu == null:
		fail("the DevMenu autoload is in the tree")
		return
	menu.run_action("Run", "debug_win", [])
	expect_eq(RunState.phase, RunState.Phase.WON, "the attempt is won with all four aboard")


func test_the_win_action_is_refused_with_someone_in_the_water() -> void:
	var menu: Node = _menu()
	if menu == null:
		fail("the DevMenu autoload is in the tree")
		return
	RunState.guy_overboard(0, Vector2.ZERO)
	menu.run_action("Run", "debug_win", [])
	expect(RunState.phase != RunState.Phase.WON, "the island isn't reached with a guy in the water")


func test_the_guy_lines_show_aboard_and_idle() -> void:
	var menu: Node = _menu()
	if menu == null:
		fail("the DevMenu autoload is in the tree")
		return
	var values: Dictionary = menu.inspect("Run")
	var line: String = str(values["%s (seat 0)" % RunState.name_of(0)])
	expect(line.contains("aboard"), "seat 0 is aboard (got %s)" % line)
	expect(line.contains("antic idle"), "seat 0 has no antic (got %s)" % line)
	RunState.guy_overboard(0, Vector2.ZERO)
	values = menu.inspect("Run")
	line = str(values["%s (seat 0)" % RunState.name_of(0)])
	expect(line.contains("in the water"), "a guy in the water says so (got %s)" % line)
