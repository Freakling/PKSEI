extends Node2D
## Lake · the level (GDD › Systems › Lake and island): the shore strip at the bottom of the
## screen, open water, and the island up-screen. Places the island by LakeTuning.island_distance,
## reports the boat's progress to RunState every physics frame, and calls RunState.arrive() when
## the boat enters the island's area. No rules live here.

const TUNING: LakeTuning = preload("res://data/lake_tuning.tres") as LakeTuning

@onready var _boat: CharacterBody2D = $Catamaran
@onready var _island: Area2D = $Island
@onready var _island_shape: CollisionShape2D = $Island/CollisionShape2D

## Where the boat starts (progress 0) and the island's near edge (progress 1), in y.
var _start_y: float = 0.0
var _edge_y: float = 0.0


func _ready() -> void:
	_island.position = Vector2(0.0, -TUNING.island_distance)
	var circle: CircleShape2D = _island_shape.shape as CircleShape2D
	_start_y = _boat.position.y
	_edge_y = _island.position.y + (circle.radius if circle != null else 0.0)


func _physics_process(_delta: float) -> void:
	var travel: float = _start_y - _edge_y
	if travel > 0.0:
		RunState.set_progress((_start_y - _boat.position.y) / travel)


func _on_island_body_entered(body: Node2D) -> void:
	if body == _boat:
		RunState.arrive()
