extends HazardBase
## Beast · the Loch-Brez beast (GDD › Systems › Hazards, the Loch-Brez beast row). Not planned
## by Hazards: the lake spawns one of these per attempt at its origin and hands it `tuning`
## (no spec). The Beast rule decides everything; this script steps it each physics frame with
## the boat's position and heading and the beast's own RNG (Beast.rng_for(RunState.lake_seed),
## made in _setup(), for the rare random visit: the crew's RunState.rng stream is untouched and
## the same lake gives the same visits), and applies its hit through RunState: shove() back
## toward the lake's middle and beast_grab() of the guy on the hull it hit, spat out
## beast_spit_distance toward the shore. A guy's puke (RunState.puked, T64) is passed to the rule
## as Beast.hear_puke() with the boat's position and the same RNG: its roll may start a random
## visit. The warning band (T69): on the step the rule's check_approach() says the boat came into
## it from inside, _warn_approach() calls `edge` once, on the hull facing that edge. Once the attempt
## is won (RunState.Phase.WON) it stops where it is: no hit lands during the win cutscene, and a
## puke there is not heard.
## It shows the state at a glance: while the beast circles, the fin sprite (Visual/Fin) rides
## the rule's position pointing the way it goes over widening ripple rings (Visual/Ripples,
## T24); while it rams, the head sprite (Visual/Head) charges at the boat; under water nothing
## shows. Each sprite flips between its two frames (assets/sprites/beast_*.png and
## assets/sprites/hazards/beast_ripple_*.png, from tools/gen_sprites.gd). No rules and no
## randomness here.

const FIN_FRAMES: Array[Texture2D] = [
	preload("res://assets/sprites/beast_fin_0.png"), preload("res://assets/sprites/beast_fin_1.png"),
]
const HEAD_FRAMES: Array[Texture2D] = [
	preload("res://assets/sprites/beast_head_0.png"), preload("res://assets/sprites/beast_head_1.png"),
]
const RIPPLE_FRAMES: Array[Texture2D] = [
	preload("res://assets/sprites/hazards/beast_ripple_0.png"),
	preload("res://assets/sprites/hazards/beast_ripple_1.png"),
]
## Seconds each frame shows (cosmetic).
const FRAME_PERIOD: float = 0.3
## Pixels from the boat the point the edge warning comes from lies at, on the side it faces or
## dead ahead (only which hull it lies beside matters; cosmetic).
const WARN_REACH: float = 100.0

@onready var _ripples: Sprite2D = $Visual/Ripples
@onready var _fin: Sprite2D = $Visual/Fin
@onready var _head: Sprite2D = $Visual/Head

var _rule: Beast
## The beast's own RNG for this attempt, from the lake's seed.
var _rng: RandomNumberGenerator
## The boat: the only CharacterBody2D on the lake, found in _setup().
var _boat: CharacterBody2D
## Seconds into the two-frame cycle.
var _clock: float = 0.0
## Whether the beast was up (circling or ramming) on the last step, to catch it rising and
## diving for the sound.
var _was_up: bool = false
## Debug builds only (the gate is _debug_tools, as in lake.gd): each rise is printed with its cause.
var _debug_tools: bool = OS.is_debug_build() or OS.has_feature("dev_tools")


## Runs once HazardBase has checked the lake's tunables.
func _setup() -> void:
	_rule = Beast.new(tuning)
	_rng = Beast.rng_for(RunState.lake_seed)
	_boat = _find_boat()
	_ripples.visible = false
	_fin.visible = false
	_head.visible = false
	RunState.puked.connect(_on_puked)


func _physics_process(delta: float) -> void:
	if _boat == null:
		return
	if RunState.phase == RunState.Phase.WON:
		_stop_loop()
		return
	var hit: Beast.Hit = _rule.step(delta, _boat.global_position, _boat.global_rotation, _rng)
	if hit != null:
		RunState.shove(hit.shove)
		RunState.beast_grab(hit.hull, _boat.global_position, tuning.beast_spit_distance)
	if _rule.check_approach(_boat.global_position):
		_warn_approach()
	_sound_state()
	_show_state(delta)


## A guy puked (T64): the rule hears it where the boat is, with the beast's own RNG. The rise it
## may start shows and sounds on the next step like any other.
func _on_puked(_seat: int) -> void:
	if _boat == null or RunState.phase == RunState.Phase.WON:
		return
	_rule.hear_puke(_boat.global_position, _rng)


## The boat has come into the beast's warning band from inside (T69): the guy on the hull facing the
## edge it is nearing calls it out (`edge`); beyond the island, the point ahead of the boat, so the
## guy on the hull that faces the island's far side speaks.
func _warn_approach() -> void:
	var boat_at: Vector2 = _boat.global_position
	var side: int = _rule.edge_side(boat_at)
	var from: Vector2 = boat_at
	if side != 0:
		from += Vector2.RIGHT * float(side) * WARN_REACH
	else:
		from += Vector2.UP.rotated(_boat.global_rotation) * WARN_REACH
	_telegraph(&"edge", from)


## Sound and the call-out (T26, T56): the low rumble loops from the moment the beast rises
## (CIRCLING), through the ram, until it dives, and the guy on the fin's side calls it out. The
## grab's chomp is the Audio autoload's, from RunState.guy_grabbed. The rise (the only way up,
## out of SUBMERGED) is printed in debug builds with its cause (rule.rise_cause).
func _sound_state() -> void:
	var up: bool = _rule.state == Beast.State.CIRCLING or _rule.state == Beast.State.RAMMING
	if up == _was_up:
		return
	_was_up = up
	if up:
		_start_loop(&"beast_rumble")
		_telegraph(&"beast", _rule.position)
		if _debug_tools:
			print("beast rises: %s at %s (boat %s)" % [_rule.rise_cause, Engine.get_physics_frames(), _boat.global_position])
	else:
		_stop_loop()


## Visual only: the fin over its ripples while circling, the head while ramming, each where
## the rule puts the beast and turned the way it moves (the sprites are drawn pointing up; the
## ripples are not turned); nothing otherwise.
func _show_state(delta: float) -> void:
	var frame: int = _frame_at(_clock, 2, FRAME_PERIOD)
	_clock += delta
	var circling: bool = _rule.state == Beast.State.CIRCLING
	var ramming: bool = _rule.state == Beast.State.RAMMING
	_ripples.visible = circling
	_fin.visible = circling
	_head.visible = ramming
	if not (circling or ramming):
		return
	if circling:
		_ripples.position = to_local(_rule.position)
		_ripples.texture = RIPPLE_FRAMES[frame]
	var sprite: Sprite2D = _fin if circling else _head
	sprite.texture = FIN_FRAMES[frame] if circling else HEAD_FRAMES[frame]
	sprite.position = to_local(_rule.position)
	sprite.rotation = _rule.direction.angle() + PI * 0.5
