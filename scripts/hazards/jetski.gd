extends Node2D
## Jet-ski · loud from offscreen, then a jet-ski crosses the boat's path on a straight line at
## speed (GDD › Systems › Hazards, the Jet-ski idiot row). An event: the lake places this node
## where the plan put it, but the placement is only the trigger and nothing shows there. When
## the boat comes near, the warning shows as a flashing marker at the screen's edge on the side
## the jet-ski will come from (Visual/Warning/Marker, a stand-in for the sound until T26's audio;
## Visual-only), then the jet-ski (Visual/JetSki: a small bright rectangle with a white spray
## trail) crosses at the JetSki rule's position. The rule decides everything; this script steps
## it each physics frame with the boat's position and heading, and applies its one hit through
## RunState: shove() along the jet-ski's travel and beer_overboard() on the hull it came from.
## No rules and no randomness here; the tunables are the jetski_* fields on LakeTuning, which the lake
## sets as `tuning` before the node enters the tree.

## The warning marker (cosmetic): pixels in from the screen's edge, and its flash period in
## seconds (on for the first half).
const MARKER_INSET: float = 12.0
const FLASH_PERIOD: float = 0.3

@onready var _jetski: Node2D = $Visual/JetSki
@onready var _marker: Polygon2D = $Visual/Warning/Marker

## The lake's tunables, set by the lake before the node enters the tree. If it is null, _ready
## reports that and the node stays still.
var tuning: LakeTuning
var _rule: JetSki
## The boat: the only CharacterBody2D on the lake, found among the lake's children.
var _boat: CharacterBody2D
## Seconds the warning has shown, for the flash.
var _flash: float = 0.0


func _ready() -> void:
	if tuning == null:
		push_error("JetSki: no LakeTuning; lake.gd sets it before adding the hazard")
		set_physics_process(false)
		return
	_rule = JetSki.new(tuning, global_position)
	_boat = _find_boat()
	_jetski.visible = false
	_marker.visible = false


func _physics_process(delta: float) -> void:
	if _boat == null:
		return
	var hit: JetSki.Hit = _rule.step(delta, _boat.global_position, _boat.global_rotation)
	if hit != null:
		RunState.shove(hit.shove)
		RunState.beer_overboard(hit.hull, _boat.global_position)
	_show_state(delta)


## Visual only: the marker flashes at the screen's edge on the jet-ski's side while the warning
## lasts; the jet-ski shows while it crosses, pointing the way it goes.
func _show_state(delta: float) -> void:
	var warning: bool = _rule.state == JetSki.State.WARNING
	if warning:
		_flash += delta
		var view: Vector2 = get_viewport().get_visible_rect().size
		var edge_x: float = MARKER_INSET if _rule.direction > 0.0 else view.x - MARKER_INSET
		_marker.position = Vector2(edge_x, view.y * 0.5)
		_marker.scale.x = _rule.direction
	else:
		_flash = 0.0
	_marker.visible = warning and fmod(_flash, FLASH_PERIOD) < FLASH_PERIOD * 0.5
	_jetski.visible = _rule.state == JetSki.State.CROSSING
	_jetski.position = to_local(_rule.jetski)
	_jetski.scale.x = _rule.direction


## The boat is the lake's CharacterBody2D; the hazards sit under the lake's Hazards node.
func _find_boat() -> CharacterBody2D:
	var hazards: Node = get_parent()
	if hazards == null or hazards.get_parent() == null:
		return null
	for child: Node in hazards.get_parent().get_children():
		if child is CharacterBody2D:
			return child as CharacterBody2D
	return null
