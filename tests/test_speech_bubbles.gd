extends "res://tools/test_case.gd"
## T56 · Speech bubbles: windup_kind() names the Lines kind for each guy wind-up catamaran.gd
## shows (antic first, then the jump, the break warning, the bar's wind-up; none otherwise), every
## kind it can name has lines; speaker_for() picks the guy on the hazard's hull front first, any
## aboard guy when it is empty or unknown, and nobody with nobody aboard; bubble_position() centres
## the bubble over the guy with its tail's tip lifted above him. HazardBase.hull_of() is the hull a
## warning comes from in the boat's own frame, and HazardBase.ahead_of() the log's and rock's
## "ahead on the path" (GDD › World and Narrative; GDD › Systems › Hazards).

const ALL: Array[int] = [0, 1, 2, 3]


func test_an_antic_wind_up_names_its_kinds_line() -> void:
	expect_eq(SpeechBubbles.windup_kind(Antics.State.WINDING_UP, Antics.Kind.PEE, false,
			Stamina.State.PADDLING, false), &"antic_pee")
	expect_eq(SpeechBubbles.windup_kind(Antics.State.WINDING_UP, Antics.Kind.STAND, false,
			Stamina.State.PADDLING, false), &"antic_stand")
	expect_eq(SpeechBubbles.windup_kind(Antics.State.WINDING_UP, Antics.Kind.DROP_PADDLE, false,
			Stamina.State.PADDLING, false), &"antic_paddle")
	expect_eq(SpeechBubbles.windup_kind(Antics.State.WINDING_UP, Antics.Kind.NOD_OFF, false,
			Stamina.State.PADDLING, false), &"antic_nap")


func test_the_antic_itself_is_not_a_wind_up() -> void:
	expect_eq(SpeechBubbles.windup_kind(Antics.State.PEEING, Antics.Kind.PEE, false,
			Stamina.State.PADDLING, false), &"", "the bubble goes away at the effect")
	expect_eq(SpeechBubbles.windup_kind(Antics.State.IDLE, Antics.Kind.PEE, false,
			Stamina.State.PADDLING, false), &"")


func test_the_jump_the_warning_and_the_bar_in_priority_order() -> void:
	expect_eq(SpeechBubbles.windup_kind(Antics.State.IDLE, Antics.Kind.STAND, true,
			Stamina.State.WARNING, true), &"jump_windup", "the jump first")
	expect_eq(SpeechBubbles.windup_kind(Antics.State.IDLE, Antics.Kind.STAND, false,
			Stamina.State.WARNING, true), &"stamina_warning", "then the break warning")
	expect_eq(SpeechBubbles.windup_kind(Antics.State.IDLE, Antics.Kind.STAND, false,
			Stamina.State.PADDLING, true), &"bar_windup", "then the bar's wind-up")
	expect_eq(SpeechBubbles.windup_kind(Antics.State.WINDING_UP, Antics.Kind.STAND, true,
			Stamina.State.WARNING, true), &"antic_stand", "an antic's wind-up over all")
	expect_eq(SpeechBubbles.windup_kind(Antics.State.IDLE, Antics.Kind.STAND, false,
			Stamina.State.BREAK, false), &"", "the break itself is the effect, not a wind-up")


func test_every_wind_up_kind_the_screen_names_has_lines() -> void:
	var lines: Lines = preload("res://data/lines.tres")
	var named: Array[StringName] = [SpeechBubbles.STAMINA_KIND, SpeechBubbles.BAR_KIND, SpeechBubbles.JUMP_KIND]
	for kind: StringName in SpeechBubbles.ANTIC_KINDS.values():
		named.append(kind)
	for kind: StringName in named:
		expect(Lines.KINDS.has(kind), "%s is a Lines.KINDS entry" % kind)
		expect(lines.lines_of(kind).size() >= 1, "%s has a line" % kind)


func test_the_hulls_front_guy_speaks_first() -> void:
	expect_eq(SpeechBubbles.speaker_for(Rescue.Hull.LEFT, ALL), Paddling.Seat.LEFT_FRONT)
	expect_eq(SpeechBubbles.speaker_for(Rescue.Hull.RIGHT, ALL), Paddling.Seat.RIGHT_FRONT)
	expect_eq(SpeechBubbles.speaker_for(Rescue.Hull.RIGHT, [0, 1, 3]), Paddling.Seat.RIGHT_BACK,
			"the back guy with the front one in the water")


func test_an_empty_or_unknown_hull_gives_any_guy_aboard() -> void:
	expect_eq(SpeechBubbles.speaker_for(Rescue.Hull.RIGHT, [1]), Paddling.Seat.LEFT_BACK,
			"the other hull when this one is empty")
	expect_eq(SpeechBubbles.speaker_for(Rescue.NOBODY, ALL), Paddling.Seat.LEFT_FRONT)
	expect_eq(SpeechBubbles.speaker_for(Rescue.NOBODY, [3]), Paddling.Seat.RIGHT_BACK)
	expect_eq(SpeechBubbles.speaker_for(Rescue.Hull.LEFT, []), Rescue.NOBODY, "nobody aboard")


func test_the_bubble_is_centred_over_the_guy_with_its_tail_lifted() -> void:
	var at: Vector2 = SpeechBubbles.bubble_position(Vector2(100.0, 50.0), Vector2(40.0, 10.0), 11.0)
	expect_eq(at, Vector2(80.0, 29.0), "left edge half the width left, top the height plus the lift up")
	var rounded: Vector2 = SpeechBubbles.bubble_position(Vector2(100.4, 50.4), Vector2(41.0, 10.0), 11.0)
	expect_eq(rounded, rounded.round(), "on whole pixels")


func test_hull_of_is_the_side_in_the_boats_own_frame() -> void:
	var boat: Node2D = Node2D.new()
	boat.position = Vector2(0.0, -300.0)
	expect_eq(HazardBase.hull_of(boat, Vector2(-50.0, -300.0)), Rescue.Hull.LEFT)
	expect_eq(HazardBase.hull_of(boat, Vector2(50.0, -300.0)), Rescue.Hull.RIGHT)
	# Facing down-screen (turned half round) the lake's left is the boat's right.
	boat.rotation = PI
	expect_eq(HazardBase.hull_of(boat, Vector2(-50.0, -300.0)), Rescue.Hull.RIGHT)
	expect_eq(HazardBase.hull_of(null, Vector2.ZERO), Rescue.NOBODY, "no boat, no hull")
	boat.free()


func test_ahead_of_needs_the_target_close_and_in_front() -> void:
	var boat: Vector2 = Vector2(0.0, -300.0)
	expect(HazardBase.ahead_of(boat, 0.0, Vector2(20.0, -400.0), 160.0), "up-screen, close: ahead")
	expect_false(HazardBase.ahead_of(boat, 0.0, Vector2(20.0, -200.0), 160.0), "behind the boat")
	expect_false(HazardBase.ahead_of(boat, 0.0, Vector2(0.0, -600.0), 160.0), "too far")
	expect(HazardBase.ahead_of(boat, PI, Vector2(20.0, -200.0), 160.0),
			"turned round, what was behind is ahead")
	expect(HazardBase.ahead_of(boat, -PI / 2.0, Vector2(-100.0, -300.0), 160.0),
			"facing the lake's left, something to the left is ahead")
	expect_false(HazardBase.ahead_of(boat, -PI / 2.0, Vector2(100.0, -300.0), 160.0))
