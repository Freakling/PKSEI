extends HazardBase
## Beast · the Loch-Brez beast (GDD › Systems › Hazards, the Loch-Brez beast row). Not planned
## by Hazards: the lake spawns one of these per attempt at its origin and hands it `tuning`
## (no spec). The Beast rule decides everything; this script steps it each physics frame with
## the boat's position and heading and the beast's own RNG (Beast.rng_for(RunState.lake_seed),
## made in _setup(), for the rare random visit: the crew's RunState.rng stream is untouched and
## the same lake gives the same visits), and applies its hit through RunState: shove() back
## toward the lake's middle and beast_grab() of the guy on the hull it hit, spat out
## beast_spit_distance toward the shore. Once the attempt is won (RunState.Phase.WON) it stops
## where it is: no hit lands during the win cutscene.
## It shows the state at a glance: while the beast circles, the fin sprite (Visual/Fin, with its
## ripple ring) rides the rule's position pointing the way it goes; while it rams, the head
## sprite (Visual/Head) charges at the boat; under water nothing shows. Each sprite flips
## between its two frames (assets/sprites/beast_*.png, from tools/gen_sprites.gd). No rules
## and no randomness here.

const FIN_FRAMES: Array[Texture2D] = [
	preload("res://assets/sprites/beast_fin_0.png"), preload("res://assets/sprites/beast_fin_1.png"),
]
const HEAD_FRAMES: Array[Texture2D] = [
	preload("res://assets/sprites/beast_head_0.png"), preload("res://assets/sprites/beast_head_1.png"),
]
## Seconds each frame shows (cosmetic).
const FRAME_PERIOD: float = 0.3

@onready var _fin: Sprite2D = $Visual/Fin
@onready var _head: Sprite2D = $Visual/Head

var _rule: Beast
## The beast's own RNG for this attempt, from the lake's seed.
var _rng: RandomNumberGenerator
## The boat: the only CharacterBody2D on the lake, found in _setup().
var _boat: CharacterBody2D
## Seconds into the two-frame cycle.
var _clock: float = 0.0


## Runs once HazardBase has checked the lake's tunables.
func _setup() -> void:
	_rule = Beast.new(tuning)
	_rng = Beast.rng_for(RunState.lake_seed)
	_boat = _find_boat()
	_fin.visible = false
	_head.visible = false


func _physics_process(delta: float) -> void:
	if _boat == null or RunState.phase == RunState.Phase.WON:
		return
	var hit: Beast.Hit = _rule.step(delta, _boat.global_position, _boat.global_rotation, _rng)
	if hit != null:
		RunState.shove(hit.shove)
		RunState.beast_grab(hit.hull, _boat.global_position, tuning.beast_spit_distance)
	_show_state(delta)


## Visual only: the fin while circling, the head while ramming, each where the rule puts the
## beast and turned the way it moves (the sprites are drawn pointing up); nothing otherwise.
func _show_state(delta: float) -> void:
	_clock = fmod(_clock + delta, FRAME_PERIOD * 2.0)
	var frame: int = 0 if _clock < FRAME_PERIOD else 1
	var circling: bool = _rule.state == Beast.State.CIRCLING
	var ramming: bool = _rule.state == Beast.State.RAMMING
	_fin.visible = circling
	_head.visible = ramming
	if not (circling or ramming):
		return
	var sprite: Sprite2D = _fin if circling else _head
	sprite.texture = FIN_FRAMES[frame] if circling else HEAD_FRAMES[frame]
	sprite.position = to_local(_rule.position)
	sprite.rotation = _rule.direction.angle() + PI * 0.5
