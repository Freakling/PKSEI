extends RefCounted
## The game's autoplay invariants · project-owned: edit freely.
##
## tools/autoplay.gd calls check() after every step, with the adapter's state() (RunState.snapshot(),
## plus "view", the current view's catalog id) and the adapter itself, next to the framework's own
## invariants. Return one line per broken rule; each becomes a finding with a screenshot and a repro.


func check(state: Dictionary, _adapter: Object) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	var progress: float = float(state.get("progress", 0.0))
	if progress < 0.0 or progress > 1.0:
		problems.append("progress is outside 0..1: %f" % progress)
	var guys: Array = state.get("guys", [])
	if guys.size() != 4:
		problems.append("the crew is %d guys, not four" % guys.size())
	for item: Variant in guys:
		var guy: Dictionary = item
		var seat: int = int(guy.get("seat", -1))
		# Accounted for: aboard, or in the water (a swimmer), never both and never neither.
		if bool(guy.get("aboard", false)) == bool(guy.get("in_water", false)):
			problems.append("seat %d is %s" % [seat, "both aboard and in the water" if bool(guy.get("aboard", false)) else "neither aboard nor in the water"])
		for key: String in ["drunkenness", "stamina"]:
			var value: float = float(guy.get(key, 0.0))
			if value < 0.0 or value > 1.0:
				problems.append("seat %d's %s is outside 0..1: %f" % [seat, key, value])
	return problems
