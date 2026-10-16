extends Node2D
## Lake · the level (GDD › Systems › Lake and island): the shore strip at the bottom of the
## screen, open water, and the island up-screen. Places the island by LakeTuning.island_distance
## and sizes it by LakeTuning.island_radius, reports the boat's progress to RunState every physics
## frame, and calls RunState.arrive() when the boat enters the island's area.
##
## The rescue (GDD › Systems › Setbacks) shows here: each guy in the water gets a marker under
## Visual/Swimmers at Rescue's position for him, in his square's colour, with a tiny yellow beer
## while his beer is loose; a floating guy bobs and is tinted. When the boat comes within
## BoatTuning.pickup_radius of a floating guy the lake calls RunState.pickup(); whenever the boat
## touches the shore it calls RunState.shore_touched(), and puts the boat back at its start when
## RunState answers with a shore reset. The hazards (GDD › Systems › Hazards) are placed from
## Hazards.plan() at RunState.lake_seed under the Hazards node, on start and again after each
## shore reset (the seed stays, so the same lake comes back), each scene handed its HazardSpec.
## No rules and no randomness live here.

const TUNING: LakeTuning = preload("res://data/lake_tuning.tres") as LakeTuning
const GUY_SIZE: float = 4.0
const BEER_SIZE: float = 1.5
const BEER_COLOUR: Color = Color(0.95, 0.85, 0.2, 1.0)
## A floating guy, drinking: a little bluer and wetter than the one on the boat (cosmetic).
const FLOATING_TINT: Color = Color(0.7, 0.8, 1.0, 1.0)
## Cosmetic bob of a floating guy: pixels and seconds per cycle.
const BOB_HEIGHT: float = 1.0
const BOB_PERIOD: float = 1.2
## Radius the island's placeholder polygon is drawn at; it is scaled to LakeTuning.island_radius.
const ISLAND_ART_RADIUS: float = 60.0

@onready var _boat: CharacterBody2D = $Catamaran
@onready var _shore: StaticBody2D = $Shore
@onready var _island: Area2D = $Island
@onready var _island_shape: CollisionShape2D = $Island/CollisionShape2D
@onready var _island_visual: Node2D = $Island/Visual
@onready var _swimmers: Node2D = $Visual/Swimmers
@onready var _hazards: Node2D = $Hazards

## Where the boat starts (progress 0) and the island's near edge (progress 1).
var _start: Vector2 = Vector2.ZERO
var _edge_y: float = 0.0
## One marker per seat in the water: a Node2D holding a "Guy" and a "Beer" square.
var _markers: Dictionary[int, Node2D] = {}
var _bob_clock: float = 0.0


func _ready() -> void:
	_island.position = Vector2(0.0, -TUNING.island_distance)
	var circle: CircleShape2D = _island_shape.shape as CircleShape2D
	if circle != null:
		circle.radius = TUNING.island_radius
	_island_visual.scale = Vector2.ONE * (TUNING.island_radius / ISLAND_ART_RADIUS)
	_start = _boat.position
	_edge_y = _island.position.y + TUNING.island_radius
	RunState.shore_reset_done.connect(_on_shore_reset_done)
	_spawn_hazards()


func _physics_process(delta: float) -> void:
	if _touching_shore():
		RunState.shore_touched()
	var travel: float = _start.y - _edge_y
	if travel > 0.0:
		RunState.set_progress((_start.y - _boat.position.y) / travel)
	var tuning: BoatTuning = RunState.paddling.tuning
	for seat: int in RunState.rescue.within_reach(_boat.position, tuning.pickup_radius):
		RunState.pickup(seat)
	_show_swimmers(delta)


func _on_island_body_entered(body: Node2D) -> void:
	if body == _boat:
		RunState.arrive()


func _on_shore_reset_done() -> void:
	_boat.place(_start)
	_spawn_hazards()


## Replaces the hazards with this attempt's: the plan for RunState.lake_seed, each placement's
## scene instanced under Hazards at its position with its spec. Debug builds print the seed, so
## a lake can be had again.
func _spawn_hazards() -> void:
	for child: Node in _hazards.get_children():
		child.queue_free()
	var lake_seed: int = RunState.lake_seed
	if OS.is_debug_build() or OS.has_feature("dev_tools"):
		print("lake seed %d" % lake_seed)
	for placement: Hazards.Placement in Hazards.plan(TUNING, lake_seed):
		var spec: HazardSpec = TUNING.hazards[placement.spec]
		if spec.scene == null:
			continue
		var hazard: Node2D = spec.scene.instantiate() as Node2D
		hazard.position = placement.position
		hazard.set(&"spec", spec)
		_hazards.add_child(hazard)


## Whether the boat slid against the shore last frame.
func _touching_shore() -> bool:
	for i: int in _boat.get_slide_collision_count():
		if _boat.get_slide_collision(i).get_collider() == _shore:
			return true
	return false


## Visual only: one marker per guy in the water, where Rescue says he is.
func _show_swimmers(delta: float) -> void:
	_bob_clock = fmod(_bob_clock + delta, BOB_PERIOD)
	var seen: Array[int] = []
	for swimmer: Rescue.Swimmer in RunState.rescue.swimmers():
		seen.append(swimmer.seat)
		if not _markers.has(swimmer.seat):
			_markers[swimmer.seat] = _make_marker(swimmer.seat)
		var marker: Node2D = _markers[swimmer.seat]
		var floating: bool = swimmer.state == Rescue.State.FLOATING
		var bob: float = BOB_HEIGHT * sin(TAU * _bob_clock / BOB_PERIOD) if floating else 0.0
		marker.position = swimmer.position + Vector2(0.0, bob)
		var guy: Polygon2D = marker.get_node("Guy") as Polygon2D
		guy.modulate = FLOATING_TINT if floating else Color.WHITE
		var beer: Node2D = marker.get_node("Beer") as Node2D
		beer.visible = not floating
		beer.global_position = swimmer.beer_position
	for seat: int in _markers.keys():
		if not seen.has(seat):
			_markers[seat].queue_free()
			_markers.erase(seat)


func _make_marker(seat: int) -> Node2D:
	var marker: Node2D = Node2D.new()
	var guy: Polygon2D = Polygon2D.new()
	guy.name = "Guy"
	guy.color = _boat.guy_colour(seat)
	guy.polygon = _square(GUY_SIZE)
	var beer: Polygon2D = Polygon2D.new()
	beer.name = "Beer"
	beer.color = BEER_COLOUR
	beer.polygon = _square(BEER_SIZE)
	marker.add_child(guy)
	marker.add_child(beer)
	_swimmers.add_child(marker)
	return marker


static func _square(half: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half),
	])
