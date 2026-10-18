extends "res://tools/play_log_base.gd"
## The play log · project-owned: edit freely.
##
## The PlayLog autoload, registered first under [autoload] in project.godot:
##     PlayLog="*res://tools/play_log.gd"
## tools/play_log_base.gd writes the files (user://logs/play/run-<datetime>.log and .jsonl), the
## session header, engine errors, input actions, focus, hitches and the progress button's state, and
## scrubs every line. This file fills the hooks. Then wire the game to it:
## - a new run: `var id: String = PlayLog.begin_run()`, and keep the id in the run save; a loaded
##   save: `PlayLog.continue_run(id)`. Until one of them, lines are held and stamped T-.
## - each turn: `PlayLog.set_turn(turn)`, and `PlayLog.log_snapshot()` wherever the player may act.
## - every player action and every turn step's outcome: one line with a stable event id, from the
##   system that does it, such as `PlayLog.log_event("gold", "gold.spent", "hired Ada: -40", {"amount": 40})`.
## - the shell: `PlayLog.watch_views(self)` for its view_changed(name) signal, and
##   `PlayLog.watch_progress_button(%EndTurn)`.
## A test asserts on the lines through PlayLog.start_capture() and stop_capture().


func _init() -> void:
	keep_files = 20   ## PLACEHOLDER: how many runs' logs to keep
	hitch_threshold_ms = 250   ## PLACEHOLDER: a frame slower than this is logged as a hitch


## What the session header adds: the game. The lake seed is per attempt, so it is in each run's
## run.attempt_started line and snapshot, not here. The game has no settings to list yet.
func _session_extras() -> Dictionary:
	return {"game": "PKSEI"}


## The state at a point worth a full picture (an attempt's start, a shore reset): the phase,
## progress, elapsed time, the lake seed and per guy his seat, name, whether he is aboard, his
## drunkenness, stamina and its state, his antic and where he is in the water. RunState builds it.
func _build_snapshot() -> Dictionary:
	return RunState.snapshot()


## Why the player can't act right now, or "" while someone is aboard (the launch shore included):
## "nobody aboard" with all four in the water, "won" at the island.
func progress_block_reason() -> String:
	return RunState.block_reason()


## The game has no install id: nothing identifying is kept.
func _install_id() -> String:
	return ""
