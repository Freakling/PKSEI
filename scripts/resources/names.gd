class_name Names
extends Resource
## Names · the crew's nicknames (GDD › Characters and Units: each attempt gives the four guys
## four distinct names drawn from the crew's list; the HUD shows the names, not the keys).
##
## Schema only. The instance the human edits is data/names.tres: the list of nicknames, at
## least CREW of them. RunState.new_attempt() draws the attempt's four with its RNG
## (pick_four) and hands them out per seat (name_of); a shore reset keeps them.
## tests/test_names.gd checks the list and the draw.

## How many names an attempt needs: one per seat.
const CREW: int = 4

## The nicknames; an attempt draws CREW distinct ones.
@export var names: PackedStringArray = PackedStringArray()


## CREW distinct names drawn from the list with `rng` (a partial shuffle, so the same seed gives
## the same four); a repeated entry counts once. Fewer than CREW distinct names gives all there
## are.
func pick_four(rng: RandomNumberGenerator) -> PackedStringArray:
	var pool: PackedStringArray = distinct()
	var count: int = mini(CREW, pool.size())
	for i: int in count:
		var j: int = rng.randi_range(i, pool.size() - 1)
		var drawn: String = pool[j]
		pool[j] = pool[i]
		pool[i] = drawn
	return pool.slice(0, count)


## The list without repeats, in its order.
func distinct() -> PackedStringArray:
	var seen: PackedStringArray = PackedStringArray()
	for entry: String in names:
		if not seen.has(entry):
			seen.append(entry)
	return seen
