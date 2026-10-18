extends "res://tools/ui_catalog.gd"
## The screen catalog · project-owned: edit freely.
##
## Every screen the game has, and how to put it on screen in a representative state, for
## `bash tools/ui_capture.sh`. Add or update an entry whenever you add or change a view. The entry
## format, and reset(), open_view(), wait_frames() and focus_default(), are in tools/ui_catalog.gd.
## A setup builds its state through the game's public APIs and debug hooks, never player data, then
## returns the node to show, or opens the screen through the game's own navigation and returns null.
##
## The views are the ids the autoplay adapter reports (tools/autoplay_adapter.gd › current_view()) and
## the play log logs (view.changed), so the ids are fixed: "lake" and "win".
##
## "lake" is the first view: the game starts there (scenes/main.tscn holds scenes/lake.tscn), and
## smoke counts it as opened at the start, with no action. Its HUD, touch pads with the reset
## button, speech bubbles and off-screen arrows are children of the lake scene's own HUD CanvasLayer,
## so the scene draws them and the entry names no overlays (an overlay is an autoload's node path or
## a scene outside the screen). The touch pads and the reset button show only where the machine has a
## touchscreen (touch_pads.gd), so a desktop capture doesn't show them.
##
## "win" is reached by winning, not by a button: no adapter action opens it, so smoke skips it
## (tools/autoplay_scenarios.gd › skip_views). It has no overlays either: the HUD, pads, bubbles and
## arrows all hide once the attempt is won.
##
## Example:
##	{"id": "hero_room", "title": "Hero room", "scene": "res://scenes/shell/HeroRoomView.tscn",
##		"states": {"default": _hero_room, "exhausted": _hero_room_exhausted}},


## The seed of every capture's attempt: the same as [capture] seed in tools/ui_capture.cfg, so the
## lake and the crew repeat from one capture to the next.
const ATTEMPT_SEED: int = 12345


func screens() -> Array[Dictionary]:
	return [
		{"id": "lake", "title": "Lake", "scene": "res://scenes/lake.tscn"},
		{"id": "win", "title": "Win", "scene": "res://scenes/win.tscn", "setup": _win},
	]


## Before each screen: a new attempt drawn from a fixed seed. RunState's _ready starts no attempt
## during a capture (the check and capture meta), and the lake needs one (its guys, its lake_seed),
## so the catalog starts it through RunState.new_attempt(), as a player's first launch does.
func reset() -> void:
	RunState.rng.seed = ATTEMPT_SEED
	RunState.new_attempt()


## The win, as the lake shows it: the attempt is won at the island through RunState.arrive(), which
## the boat does when all four are aboard (the lake then puts the cutscene up). The setup waits until
## the cutscene's title has faded in, so the capture shows the camp and the crew's names, not the walk.
func _win() -> Node:
	var lake: Node = open_view("res://scenes/lake.tscn")
	if lake == null:
		return null
	await wait_frames(2)
	RunState.arrive()
	var title_box: Control = null
	while title_box == null or title_box.modulate.a < 1.0:
		await wait_frames(1)
		var win: Node = lake.get_node_or_null("Win")
		if win != null and win.get_node_or_null("Title") != null and (win.get_node("Title") as CanvasLayer).visible:
			title_box = win.get_node("Title/TitleBox") as Control
	return null
