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


func scenarios() -> Array[Dictionary]:
	return [
		# The catalog (tools/ui_screens.gd) lists only the main scene, whose views ("lake", "win") the
		# adapter names itself, so there is nothing for smoke to open. The island is out of reach in 3 turns.
		{"id": "smoke", "title": "Start, play 3 turns", "kind": "smoke", "turns": 3, "skip_views": ["main"]},
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
			# Every stroke key the player has, as real input (a tap each). Not R: a reset starts a new play-log
			# run (a new file), and the review reads only the newest file.
			{"do": "stroke_left_front"}, {"do": "stroke_left_back"}, {"do": "stroke_right_front"}, {"do": "stroke_right_back"},
			{"do": "reverse_left_front"}, {"do": "reverse_left_back"}, {"do": "reverse_right_front"}, {"do": "reverse_right_back"},
			{"do": "back_paddle_left_back"},
		]},
	]
