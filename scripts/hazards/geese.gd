extends HazardBase
## Geese · a flock of angry geese guarding its goslings (GDD › Systems › Hazards, the Angry
## geese row). The nest is an object: it is fixed on the map where the lake placed it, and the
## goslings (Visual/Nest) stay there. The charge is the event: the geese (Visual/Geese, three
## goose sprites) follow the GeeseFlock rule's position, which flies to the boat and back. The
## rule decides everything; this script steps it each physics frame with the boat's position
## and heading, applies its pecks through RunState.beer_overboard() on the hull it names, and
## shows the state at a glance with the frames in assets/sprites/hazards/ (T24, drawn by
## tools/gen_sprites.gd): nesting = calm geese facing up; hissing = the two "wings up, beak
## open" frames, facing the boat; charging and returning = the two flapping frames, facing the
## way they fly. Each goose is a beat behind the last, so the flock doesn't flap in lockstep.
## No rules and no randomness here; the tunables are the geese_* fields on LakeTuning, which the
## lake sets as `tuning` before the node enters the tree.

const CALM_FRAME: Texture2D = preload("res://assets/sprites/hazards/goose_calm.png")
const HISS_FRAMES: Array[Texture2D] = [
	preload("res://assets/sprites/hazards/goose_hiss_0.png"),
	preload("res://assets/sprites/hazards/goose_hiss_1.png"),
]
const FLY_FRAMES: Array[Texture2D] = [
	preload("res://assets/sprites/hazards/goose_fly_0.png"),
	preload("res://assets/sprites/hazards/goose_fly_1.png"),
]
## Seconds each frame shows (cosmetic): slow enough to read at 1×.
const FRAME_PERIOD: float = 0.2

@onready var _geese: Node2D = $Visual/Geese

var _flock: GeeseFlock
## The boat: the only CharacterBody2D on the lake, found in _setup().
var _boat: CharacterBody2D
## The goose sprites under Visual/Geese, in tree order.
var _sprites: Array[Sprite2D] = []
## Seconds into the animation.
var _clock: float = 0.0
## Where the flock was on the last step, to face the way it flies.
var _last_position: Vector2 = Vector2.ZERO
## The flock's state on the last step, to catch the hissing's start for the sound.
var _last_state: GeeseFlock.State = GeeseFlock.State.NESTING


## Runs once HazardBase has checked the lake's tunables.
func _setup() -> void:
	_flock = GeeseFlock.new(tuning, global_position)
	_boat = _find_boat()
	_last_position = _flock.position
	for child: Node in _geese.get_children():
		if child is Sprite2D:
			_sprites.append(child as Sprite2D)


func _physics_process(delta: float) -> void:
	if _boat == null:
		return
	var pecks: Array[GeeseFlock.Peck] = _flock.step(delta, _boat.global_position, _boat.global_rotation)
	for peck: GeeseFlock.Peck in pecks:
		RunState.beer_overboard(peck.hull, _boat.global_position)
	_sound_state()
	_show_state(delta)


## Sound only (T26): the geese hiss as the hissing starts, each time it does.
func _sound_state() -> void:
	var state: GeeseFlock.State = _flock.state
	if state == _last_state:
		return
	_last_state = state
	if state == GeeseFlock.State.HISSING:
		Audio.play(&"geese_hiss")


## Visual only: the geese follow the flock, face the boat while hissing and the way they fly
## while charging or returning (the sprites are drawn pointing up), and show the frames of
## their state.
func _show_state(delta: float) -> void:
	_clock += delta
	var state: GeeseFlock.State = _flock.state
	var hissing: bool = state == GeeseFlock.State.HISSING
	var flying: bool = state == GeeseFlock.State.CHARGING or state == GeeseFlock.State.RETURNING
	var facing: float = 0.0
	if flying:
		var moved: Vector2 = _flock.position - _last_position
		facing = moved.angle() + PI * 0.5 if moved.length_squared() > 0.0 else _geese.rotation
	elif hissing:
		facing = (_boat.global_position - _flock.position).angle() + PI * 0.5
	_last_position = _flock.position
	_geese.position = to_local(_flock.position)
	_geese.rotation = facing
	var frame: int = _frame_at(_clock, 2, FRAME_PERIOD)
	for index: int in _sprites.size():
		var own: int = (frame + index) % 2
		var texture: Texture2D = CALM_FRAME
		if hissing:
			texture = HISS_FRAMES[own]
		elif flying:
			texture = FLY_FRAMES[own]
		_sprites[index].texture = texture
