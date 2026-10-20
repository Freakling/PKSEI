extends "res://tools/test_case.gd"
## T92 · The splash (GDD › Presentation and Platforms, Splash; design/ui/splash.md): the scene opens
## with its named elements and a playing, looping stream on the Music bus; the prompt says "Tap to
## start" on a touchscreen; an input before INPUT_GUARD does nothing and after it starts the fade;
## the fade ends with the splash freed and the tree running again; while it is up the tree is
## paused, so nothing reaches the boat; and it shows once per launch (main.tscn holds it and
## nothing reloads main.tscn: a reset or the win's "again" doesn't bring it back).
## The splash pauses the tree, so every test puts it back.

const SplashScene: PackedScene = preload("res://scenes/splash.tscn")
const MainScene: PackedScene = preload("res://scenes/main.tscn")


func after_each() -> void:
	_tree().paused = false
	RunState.reset()


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## The splash scene in the test's tree.
func _add_splash() -> Splash:
	var splash: Splash = SplashScene.instantiate() as Splash
	_tree().root.add_child(splash)
	return splash


func _remove(node: Node) -> void:
	node.get_parent().remove_child(node)
	node.free()
	_tree().paused = false


func _key(pressed: bool = true, echo: bool = false) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_SPACE
	event.pressed = pressed
	event.echo = echo
	return event


func test_the_scene_has_its_named_elements_and_the_text_the_spec_gives() -> void:
	var splash: Splash = _add_splash()
	for element: String in ["Backdrop", "Title", "Subtitle", "Prompt", "Music", "Boat", "Island"]:
		expect(splash.get_node_or_null("%" + element) != null, "%" + element + " exists")
	expect_eq((splash.get_node("%Title") as Label).text, "PKSEI")
	expect_eq((splash.get_node("%Subtitle") as Label).text, "Paddla Kanot Som En Idiot")
	for seat: int in 4:
		expect(splash.get_node("%Boat").get_node_or_null("Guy%d" % seat) != null, "guy %d aboard" % seat)
	_remove(splash)


func test_the_prompt_text_depends_on_a_touchscreen() -> void:
	expect_eq(Splash.prompt_text(false), "Press any key")
	expect_eq(Splash.prompt_text(true), "Tap to start")
	var splash: Splash = _add_splash()
	expect_eq((splash.get_node("%Prompt") as Label).text, Splash.prompt_text(DisplayServer.is_touchscreen_available()))
	_remove(splash)


func test_the_theme_plays_on_the_music_bus_and_is_one_exported_stream() -> void:
	var splash: Splash = _add_splash()
	var player: AudioStreamPlayer = splash.get_node("%Music") as AudioStreamPlayer
	expect(player.stream != null, "a stream")
	expect(splash.music == player.stream, "the Music node plays the splash's exported stream")
	expect(player.playing, "it is playing")
	expect_eq(player.bus, &"Music")
	expect(AudioServer.get_bus_index(&"Music") >= 0, "the Music bus exists")
	var wav: AudioStreamWAV = splash.music as AudioStreamWAV
	expect(wav != null and wav.loop_mode == AudioStreamWAV.LOOP_FORWARD, "the music loops by itself")
	_remove(splash)


func test_the_game_is_paused_while_it_is_up_and_the_splash_still_runs() -> void:
	expect_false(_tree().paused, "before")
	var splash: Splash = _add_splash()
	expect(_tree().paused, "paused under the splash")
	expect_eq(splash.process_mode, Node.PROCESS_MODE_ALWAYS)
	_remove(splash)
	expect_false(_tree().paused, "a splash that leaves the tree doesn't leave it paused")


func test_only_a_key_press_a_click_a_pad_button_or_a_touch_starts_it() -> void:
	expect(Splash.is_start_event(_key()), "a key")
	expect_false(Splash.is_start_event(_key(false)), "a key coming up")
	expect_false(Splash.is_start_event(_key(true, true)), "a key repeating")
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.pressed = true
	expect(Splash.is_start_event(click), "a click")
	click.pressed = false
	expect_false(Splash.is_start_event(click), "a click released")
	var pad: InputEventJoypadButton = InputEventJoypadButton.new()
	pad.pressed = true
	expect(Splash.is_start_event(pad), "a pad button")
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.pressed = true
	expect(Splash.is_start_event(touch), "a tap")
	expect_false(Splash.is_start_event(InputEventMouseMotion.new()), "a mouse move")


func test_an_input_inside_the_guard_does_nothing_and_after_it_starts_the_fade() -> void:
	var splash: Splash = _add_splash()
	splash._process(Splash.INPUT_GUARD * 0.5)
	splash._input(_key())
	expect_false(splash.is_fading(), "inside the guard")
	splash._process(Splash.INPUT_GUARD)
	splash._input(_key(false))
	expect_false(splash.is_fading(), "a release is no start")
	splash._input(_key())
	expect(splash.is_fading(), "after the guard")
	_remove(splash)


func test_the_fade_dims_the_screen_and_the_music_then_frees_the_splash_and_unpauses() -> void:
	var splash: Splash = _add_splash()
	var root: Control = splash.get_node("%Root") as Control
	var player: AudioStreamPlayer = splash.get_node("%Music") as AudioStreamPlayer
	splash._process(Splash.INPUT_GUARD + 0.01)
	splash._input(_key())
	splash._process(Splash.FADE_TIME * 0.5)
	expect_near(root.modulate.a, 0.5, 0.01, "half way through the fade")
	expect(player.volume_db < 0.0, "the music is going down")
	expect(_tree().paused, "still paused while it fades")
	expect_false(splash.is_queued_for_deletion(), "not gone yet")
	splash._process(Splash.FADE_TIME * 0.5)
	expect_near(root.modulate.a, 0.0, 0.01, "faded out")
	expect(splash.is_queued_for_deletion(), "freed at the end of the fade")
	expect_false(_tree().paused, "the lake runs again")
	expect_false(player.playing, "the music has stopped")
	_remove(splash)


func test_input_during_the_fade_is_ignored() -> void:
	var splash: Splash = _add_splash()
	splash._process(Splash.INPUT_GUARD + 0.01)
	splash._input(_key())
	splash._process(Splash.FADE_TIME * 0.25)
	var before: float = (splash.get_node("%Root") as Control).modulate.a
	splash._input(_key())
	splash._process(0.0)
	expect_near((splash.get_node("%Root") as Control).modulate.a, before, 0.0001, "the fade carries on as it was")
	_remove(splash)


func test_dismissing_it_now_frees_it_and_unpauses_at_once() -> void:
	var splash: Splash = _add_splash()
	expect(_tree().paused)
	splash.dismiss_now()
	expect(splash.is_queued_for_deletion(), "freed")
	expect_false(_tree().paused, "unpaused")
	splash.dismiss_now()
	_remove(splash)


## Main holds the splash once and nothing reloads it: dismissed, it doesn't come back with a new
## attempt (R, the touch hold, the shore reset or the win's "again" all go through the lake).
func test_it_shows_once_per_launch_not_on_a_reset_or_after_the_win() -> void:
	var main: Node = MainScene.instantiate()
	_tree().root.add_child(main)
	expect_eq(_count_splashes(main), 1, "one splash in main.tscn")
	expect(_tree().paused, "the lake is held back under it")
	var splash: Node = main.get_node("Splash")
	splash.call("dismiss_now")
	main.remove_child(splash)
	splash.free()
	var lake: Node = main.get_node("Lake")
	lake.call("_new_attempt")
	expect_eq(_count_splashes(main), 0, "a reset doesn't bring it back")
	RunState.arrive()
	lake.call("_new_attempt")
	expect_eq(_count_splashes(main), 0, "nor does going again after the win")
	expect_false(_tree().paused, "the lake runs")
	_tree().root.remove_child(main)
	main.free()


func _count_splashes(under: Node) -> int:
	var count: int = 0
	for child: Node in under.get_children():
		if child is Splash:
			count += 1
	return count


## B8: on the web the first input only turns the sound on (the music from the top), and the next
## one after the guard fades the splash; off the web there is no such step.
func test_on_the_web_the_first_input_turns_the_sound_on_and_the_next_starts_the_game() -> void:
	expect(Splash.needs_sound_input(true), "the web waits for sound")
	expect_false(Splash.needs_sound_input(false), "the desktop doesn't")
	expect_eq(Splash.prompt_text(false, false), "Press any key for sound")
	expect_eq(Splash.prompt_text(true, false), "Tap for sound")
	var splash: Splash = _add_splash()
	splash.hold_for_sound()
	expect_false(splash.is_sound_on(), "waiting for sound")
	expect_eq((splash.get_node("%Prompt") as Label).text, Splash.prompt_text(DisplayServer.is_touchscreen_available(), false))
	var key: InputEventKey = InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_SPACE
	splash._process(Splash.INPUT_GUARD + 0.1)
	splash._input(key)
	expect(splash.is_sound_on(), "the first press turns the sound on")
	expect_false(splash.is_fading(), "and doesn't start the game")
	expect((splash.get_node("%Music") as AudioStreamPlayer).playing, "the music plays")
	splash._input(key)
	expect_false(splash.is_fading(), "a second press inside the new guard does nothing")
	splash._process(Splash.INPUT_GUARD + 0.1)
	splash._input(key)
	expect(splash.is_fading(), "after the guard the next press starts the game")
	_remove(splash)
