extends "res://tools/autoplay_catalog.gd"
## The autoplay scenarios · project-owned: edit freely.
##
## How `bash tools/autoplay.sh <scenario>` plays the game: a required smoke scenario, scripted ones
## (ordered actions with an expect after each) and strategy ones (random, greedy or end_turn). The
## scenario format and the thresholds (softlock_actions, step_seconds, orphan_turns...) are in
## tools/autoplay_catalog.gd; set a threshold in _init() to change it. Any item that touches the
## shell, a view, the turn loop or a save adds or updates a scenario step that walks the change.
##
## The game is real-time: a "turn" is one forward api stroke (tools/autoplay_adapter.gd).


func _init() -> void:
	# The step that lands on the island waits for the win cutscene's tweens to settle, which takes a
	# little over five seconds on this machine; it is the cutscene, not a hitch.
	step_seconds = 8.0


func scenarios() -> Array[Dictionary]:
	return [
		# The catalog (tools/ui_screens.gd) lists "lake", the view the game starts in (smoke counts it as
		# opened), and "win", which no action opens: it is reached by winning, and the island is out of
		# reach in 3 turns. "splash" (T92) is dismissed by the adapter's start_run(), so no action opens it.
		{"id": "smoke", "title": "Start, play 3 turns", "kind": "smoke", "turns": 3, "skip_views": ["win", "splash"]},
		# The boat leaves the shore: strokes on all four seats, balanced left and right, then a drift.
		{"id": "crossing", "title": "Paddle off the shore on all four seats", "kind": "scripted", "actions": [
			{"do": "paddle_left_back", "repeat": 3},
			{"do": "paddle_right_back", "repeat": 3},
			{"do": "paddle_left_front", "repeat": 3},
			{"do": "paddle_right_front", "repeat": 3},
			{"do": "wait", "repeat": 8},
			{"do": "paddle_left_back", "repeat": 3},
			{"do": "paddle_right_back", "repeat": 3},
			{"do": "wait", "repeat": 8, "expect": func(state: Dictionary) -> bool:
				return float(state["progress"]) > 0.0 and str(state["phase"]) == "crossing"},
			# A reset under way is another attempt of the same play-log run: back at the shore, then strokes again.
			{"do": "reset", "expect": func(state: Dictionary) -> bool:
				return str(state["phase"]) == "launch"},
			{"do": "paddle_left_back", "repeat": 2}, {"do": "paddle_right_back", "repeat": 2},
			# Every stroke key the player has, as real input (a tap each).
			{"do": "stroke_left_front"}, {"do": "stroke_left_back"}, {"do": "stroke_right_front"}, {"do": "stroke_right_back"},
			{"do": "reverse_left_front"}, {"do": "reverse_left_back"}, {"do": "reverse_right_front"}, {"do": "reverse_right_back"},
			{"do": "back_paddle_left_back"},
		]},
		# The full crossing: the adapter's pilot plays like a steady player, beat by beat, until the
		# boat lands on the island (the run is over on WON) or the step cap. Rescues, hazards, antics and
		# shore resets happen as they come; the win screen is the one view only this scenario opens. For
		# recording, it shows the splash with its music for 15 seconds, fades it, holds 3 seconds before
		# the first stroke, and holds 20 on the win title's stats (the adapter's `splash` and `pause`).
		# The splash is in the catalog too, so this scenario opens it.
		{"id": "island", "title": "Shore to island: the pilot plays the whole crossing", "kind": "strategy",
			"strategy": "greedy", "steps": 3000,
			"score": func(action: Dictionary, _state: Dictionary) -> float:
				var id: String = str(action.get("id", ""))
				if id == "splash":
					return 3.0
				if id == "pause":
					return 2.0
				return 1.0 if id in ["pilot", "again"] else 0.0},
	]
