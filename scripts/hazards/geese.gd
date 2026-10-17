extends HazardBase
## Geese · a flock of angry geese guarding its goslings (GDD › Systems › Hazards, the Angry
## geese row). The nest is an object: it is fixed on the map where the lake placed it, and the
## goslings (Visual/Nest) stay there. The charge is the event: the geese (Visual/Geese) follow
## the GeeseFlock rule's position, which flies to the boat and back. The rule decides everything;
## this script steps it each physics frame with the boat's position and heading, applies its
## pecks through RunState.beer_overboard() on the hull it names, and shows the state at a glance:
## hissing = wings up (the Wings marker) and a bob, charging = the geese fly at the boat tinted
## angry, returning = they fly back. No rules and no randomness here; the tunables are the geese_*
## fields on LakeTuning, which the lake sets as `tuning` before the node enters the tree.

## How fast and how far the geese bob while hissing (cosmetic).
const HISS_BOB_RATE: float = 30.0
const HISS_BOB_PIXELS: float = 1.0
const CALM_TINT: Color = Color(1.0, 1.0, 1.0, 1.0)
const ANGRY_TINT: Color = Color(1.0, 0.7, 0.6, 1.0)

@onready var _geese: Node2D = $Visual/Geese
@onready var _wings: Node2D = $Visual/Geese/Wings

var _flock: GeeseFlock
## The boat: the only CharacterBody2D on the lake, found in _setup().
var _boat: CharacterBody2D
var _bob_time: float = 0.0


## Runs once HazardBase has checked the lake's tunables.
func _setup() -> void:
	_flock = GeeseFlock.new(tuning, global_position)
	_boat = _find_boat()
	_wings.visible = false


func _physics_process(delta: float) -> void:
	if _boat == null:
		return
	var pecks: Array[GeeseFlock.Peck] = _flock.step(delta, _boat.global_position, _boat.global_rotation)
	for peck: GeeseFlock.Peck in pecks:
		RunState.beer_overboard(peck.hull, _boat.global_position)
	_show_state(delta)


## The geese squares follow the flock; the state reads from the wings, the tint and the bob.
func _show_state(delta: float) -> void:
	var hissing: bool = _flock.state == GeeseFlock.State.HISSING
	_bob_time = _bob_time + delta if hissing else 0.0
	var bob: Vector2 = Vector2(0.0, -absf(sin(_bob_time * HISS_BOB_RATE)) * HISS_BOB_PIXELS) if hissing else Vector2.ZERO
	_geese.position = to_local(_flock.position) + bob
	_wings.visible = hissing
	_geese.modulate = ANGRY_TINT if _flock.state == GeeseFlock.State.CHARGING else CALM_TINT
