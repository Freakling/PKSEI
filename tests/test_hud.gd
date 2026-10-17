extends "res://tools/test_case.gd"
## T79 · HUD status line: Hud.status_text() names what a guy is doing, the first that applies
## of the water, his antic (wind-up by kind, then state), the jump after a beer, a snag, the
## break then its warning, bailing and the timing bar, and is empty while he just paddles
## (GDD › Core Loop › Moment to moment).


func _idle(swim: StringName = &"", antic: Antics.State = Antics.State.IDLE,
		kind: Antics.Kind = Antics.Kind.STAND, jump: bool = false, snagged: bool = false,
		stamina: Stamina.State = Stamina.State.PADDLING, bailing: bool = false,
		bar: bool = false) -> String:
	return Hud.status_text(swim, antic, kind, jump, snagged, stamina, bailing, bar)


func test_a_paddling_guy_has_no_status() -> void:
	expect_eq(_idle(), "")


func test_every_state_has_words_and_they_differ() -> void:
	var seen: Dictionary[String, bool] = {}
	var texts: Array[String] = [
		_idle(SpeechBubbles.SWIM_FETCH_KIND), _idle(SpeechBubbles.SWIM_DRINK_KIND),
		_idle(SpeechBubbles.SWIM_FELL_KIND), _idle(SpeechBubbles.SWIM_BACK_KIND), _idle(Hud.WASHED_UP),
		_idle(&"", Antics.State.WINDING_UP, Antics.Kind.STAND),
		_idle(&"", Antics.State.WINDING_UP, Antics.Kind.DROP_PADDLE),
		_idle(&"", Antics.State.WINDING_UP, Antics.Kind.NOD_OFF),
		_idle(&"", Antics.State.WINDING_UP, Antics.Kind.PEE),
		_idle(&"", Antics.State.WINDING_UP, Antics.Kind.PUKE),
		_idle(&"", Antics.State.STANDING), _idle(&"", Antics.State.PADDLE_DROPPED),
		_idle(&"", Antics.State.NODDED_OFF), _idle(&"", Antics.State.PEEING),
		_idle(&"", Antics.State.PUKING), _idle(&"", Antics.State.RECOVERING),
		_idle(&"", Antics.State.IDLE, Antics.Kind.STAND, true),
		_idle(&"", Antics.State.IDLE, Antics.Kind.STAND, false, true),
		_idle(&"", Antics.State.IDLE, Antics.Kind.STAND, false, false, Stamina.State.BREAK),
		_idle(&"", Antics.State.IDLE, Antics.Kind.STAND, false, false, Stamina.State.WARNING),
		_idle(&"", Antics.State.IDLE, Antics.Kind.STAND, false, false, Stamina.State.PADDLING, true),
		_idle(&"", Antics.State.IDLE, Antics.Kind.STAND, false, false, Stamina.State.PADDLING, false, true),
	]
	for text: String in texts:
		expect_false(text.is_empty(), "a state has words")
		expect_false(seen.has(text), "%s is said for one state only" % text)
		seen[text] = true
	expect_eq(_idle(&"", Antics.State.PEEING), "taking a piss")
	expect_eq(_idle(&"", Antics.State.PUKING), "puking")
	expect_eq(_idle(SpeechBubbles.SWIM_DRINK_KIND), "drinking in the lake")


func test_the_water_beats_everything_and_the_antic_beats_the_rest() -> void:
	expect_eq(_idle(SpeechBubbles.SWIM_BACK_KIND, Antics.State.PEEING, Antics.Kind.PEE, true, true,
			Stamina.State.BREAK, true, true), Hud.WATER_TEXT[SpeechBubbles.SWIM_BACK_KIND])
	expect_eq(_idle(&"", Antics.State.PEEING, Antics.Kind.PEE, true, true, Stamina.State.BREAK, true, true),
			"taking a piss")
	expect_eq(_idle(&"", Antics.State.WINDING_UP, Antics.Kind.PUKE, true, true, Stamina.State.BREAK),
			Hud.WINDUP_TEXT[Antics.Kind.PUKE], "the wind-up names its kind")


func test_then_the_jump_the_snag_the_break_its_warning_bailing_and_the_bar() -> void:
	expect_eq(_idle(&"", Antics.State.IDLE, Antics.Kind.STAND, true, true, Stamina.State.BREAK, true, true), Hud.JUMP_TEXT)
	expect_eq(_idle(&"", Antics.State.IDLE, Antics.Kind.STAND, false, true, Stamina.State.BREAK, true, true), Hud.SNAG_TEXT)
	expect_eq(_idle(&"", Antics.State.IDLE, Antics.Kind.STAND, false, false, Stamina.State.BREAK, true, true), Hud.BREAK_TEXT)
	expect_eq(_idle(&"", Antics.State.IDLE, Antics.Kind.STAND, false, false, Stamina.State.WARNING, true, true), Hud.WARNING_TEXT)
	expect_eq(_idle(&"", Antics.State.IDLE, Antics.Kind.STAND, false, false, Stamina.State.PADDLING, true, true), Hud.BAILING_TEXT)
	expect_eq(_idle(&"", Antics.State.IDLE, Antics.Kind.STAND, false, false, Stamina.State.PADDLING, false, true), Hud.BAR_TEXT)


func test_an_unknown_swim_kind_still_says_he_is_in_the_water() -> void:
	expect_eq(_idle(&"no_such_kind"), "in the water")
