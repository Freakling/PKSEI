extends Node2D
## Lake · the level (GDD › Systems › Lake and island): the shore strip at the bottom of the
## screen, open water, and the island up-screen. Places the island by LakeTuning.island_distance
## and sizes it by LakeTuning.island_radius; sizes the water and the shore to the lake by
## lake_width and island_distance. It reports the boat's progress to RunState every physics
## frame, and calls RunState.arrive() when the boat enters the island's area; the island also has a
## solid body a little smaller than that area, so the boat stops at the shore instead of sailing
## over it (T97). Once RunState's
## phase is WON it puts the win cutscene (scenes/win.tscn, GDD › Win and Loss) at the island
## and hands it the boat and the camera (the camera's follow is off while it plays), and the
## hazards stop for it (their processing is disabled and their telegraph loops end, B4); when the
## cutscene asks to go again it is taken down, RunState.new_attempt() starts the next attempt,
## and the boat and the hazards are placed as after a shore reset, the hazards running again.
## A reset (GDD › Presentation and Platforms, Reset: R on the keyboard, the `reset` action, or
## the touch button's hold, scripts/ui/reset_button.gd, under the HUD) takes the same path in
## any phase, taking the cutscene down first if it is up (T62).
## The play log (T70) hears the views ("lake", "win") and the player's resets from here (action.reset,
## action.again); RunState logs the rest.
##
## The art is pixel art from assets/sprites/ (drawn by tools/gen_sprites.gd): the water and the
## shore are tiles repeated over their polygons, the island a sprite scaled to its radius.
##
## The rescue (GDD › Systems › Setbacks) shows here: a beer bobbing away while its guy winds up
## aboard (T34) gets a beer sprite under Visual/Swimmers, and each guy in the water his seat's
## swimming sprite there at Rescue's position for him, with the beer while his is still loose; a
## floating guy bobs and is tinted, and holds his beer beside his head only while he has it (a
## guy who fell in beerless shows none). When the boat comes within
## BoatTuning.pickup_radius of a floating guy the lake calls RunState.pickup(); whenever the boat
## touches the shore it calls RunState.shore_touched(), and puts the boat back at its start when
## RunState answers with a shore reset. The hazards (GDD › Systems › Hazards) are fixed where
## Hazards.plan() put them for RunState.lake_seed, objects beside the path and events' triggers on
## it: they are placed under the Hazards node on start and again after each shore reset (the seed
## stays, so the same lake comes back), each scene handed its HazardSpec and the lake's
## LakeTuning, and none moves or comes back once it is placed. The Loch-Brez beast is not
## planned: exactly one beast scene (scenes/hazards/beast.tscn) is placed with them each time,
## handed the LakeTuning only, and watches the boat from the whole lake. No rules and no
## randomness live here: the plan is Hazards'.
##
## Debug builds only (the gate is _debug_tools): PathOverlay under Visual draws the corridor the
## objects keep clear, for tuning path_width and path_wander by eye, with a small magenta diamond
## under it at every event's trigger point. Both are filled when the hazards are placed, so they
## follow the attempt's seed, and F7 (debug_toggle_path) shows or hides them together. In release
## builds the overlay stays hidden and empty.

const TUNING: LakeTuning = preload("res://data/lake_tuning.tres") as LakeTuning
const WIN_SCENE: PackedScene = preload("res://scenes/win.tscn")
## The one beast per attempt (T50), spawned with the plan, not by it.
const BEAST_SCENE: PackedScene = preload("res://scenes/hazards/beast.tscn")
## The dev menu's name for the beast (T84) and where its autoload sits.
const BEAST_SYSTEM: String = "Beast"
const DEV_MENU_PATH: NodePath = ^"/root/DevMenu"
const DEBUG_PATH_ACTION: StringName = &"debug_toggle_path"
const RESET_ACTION: StringName = &"reset"
## Points the debug overlay samples per band of the corridor (the band's edges are among them).
const PATH_OVERLAY_STEPS: int = 4
## The debug overlay's marker at an event's trigger point: a diamond this many pixels from its
## centre to a corner, in this colour.
const TRIGGER_MARKER_SIZE: float = 4.0
const TRIGGER_MARKER_COLOUR: Color = Color(1.0, 0.0, 1.0, 0.8)
const BEER_TEXTURE: Texture2D = preload("res://assets/sprites/beer.png")
## A guy swimming, one per seat in Paddling.Seat order, in the shirt colour of his sprite on the
## boat (both from tools/gen_sprites.gd).
const SWIM_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/guy_swim_0.png"), preload("res://assets/sprites/guy_swim_1.png"),
	preload("res://assets/sprites/guy_swim_2.png"), preload("res://assets/sprites/guy_swim_3.png"),
]
## A floating guy, drinking: a little bluer and wetter than the one on the boat (cosmetic).
const FLOATING_TINT: Color = Color(0.7, 0.8, 1.0, 1.0)
## Where a floating guy holds his beer, from his sprite's centre in lake pixels: beside his head,
## in his right hand, so it bobs with him. Cosmetic: Rescue says only whether he still has it.
const DRINK_OFFSET: Vector2 = Vector2(4.0, -2.0)
## Cosmetic bob of a floating guy: pixels and seconds per cycle.
const BOB_HEIGHT: float = 1.0
const BOB_PERIOD: float = 1.2
## Radius the island sprite's beach reaches at its near edge; it is scaled to
## LakeTuning.island_radius.
const ISLAND_ART_RADIUS: float = 60.0
## Water and shore run this far past the lake's edges and past the island, in pixels, so the
## camera (a 640 by 360 view) never sees the end of the water.
const WATER_MARGIN: float = 400.0
## The shore strip's depth in pixels, from the shore line (y = 0) down to the water's bottom edge.
const SHORE_DEPTH: float = 400.0
## The island stops the boat (T97): its solid body is this much smaller than the island's area, so
## a boat held at the body's edge still overlaps the area and arrive() is called.
const ISLAND_STOP_INSET: float = 2.0

@onready var _boat: CharacterBody2D = $Catamaran
@onready var _water: Polygon2D = $Visual/Water
@onready var _shore: StaticBody2D = $Shore
@onready var _shore_visual: Polygon2D = $Shore/Visual
@onready var _island: Area2D = $Island
@onready var _island_shape: CollisionShape2D = $Island/CollisionShape2D
@onready var _island_visual: Node2D = $Island/Visual
@onready var _island_body: StaticBody2D = $IslandBody
@onready var _island_body_shape: CollisionShape2D = $IslandBody/CollisionShape2D
@onready var _swimmers: Node2D = $Visual/Swimmers
@onready var _hazards: Node2D = $Hazards
@onready var _path_overlay: Line2D = $Visual/PathOverlay
@onready var _camera: Camera2D = $Camera

## Debug tools (the debug overlay, the F5/F6-style keys) exist only in debug builds and when the
## dev_tools feature is set; release builds never read them.
var _debug_tools: bool = OS.is_debug_build() or OS.has_feature("dev_tools")

## Where the boat starts (progress 0) and the island's near edge (progress 1).
var _start: Vector2 = Vector2.ZERO
var _edge_y: float = 0.0
## One marker per seat in the water: a Node2D holding a "Guy" and a "Beer" sprite.
var _markers: Dictionary[int, Node2D] = {}
## One beer sprite per seat winding up, at the loose beer's position.
var _loose_beers: Dictionary[int, Sprite2D] = {}
var _bob_clock: float = 0.0
## The win cutscene while it plays; null otherwise.
var _win: WinCutscene = null


func _ready() -> void:
	_island.position = Vector2(0.0, -TUNING.island_distance)
	var circle: CircleShape2D = _island_shape.shape as CircleShape2D
	if circle != null:
		circle.radius = TUNING.island_radius
	_island_body.position = _island.position
	var body_circle: CircleShape2D = _island_body_shape.shape as CircleShape2D
	if body_circle != null:
		body_circle.radius = TUNING.island_radius - ISLAND_STOP_INSET
	_island_visual.scale = Vector2.ONE * (TUNING.island_radius / ISLAND_ART_RADIUS)
	_size_water()
	_start = _boat.position
	_edge_y = _island.position.y + TUNING.island_radius
	RunState.shore_reset_done.connect(_on_shore_reset_done)
	_spawn_hazards()
	PlayLog.log_view("lake")


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
	_show_loose_beers()
	if RunState.phase == RunState.Phase.WON and _win == null:
		_start_win()
	if _debug_tools and Input.is_action_just_pressed(DEBUG_PATH_ACTION):
		_path_overlay.visible = not _path_overlay.visible


## R starts a new attempt at once, in any phase. Taken here, before the win cutscene's
## _unhandled_input, and marked handled, so its "any key" does not go again on top of it.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed(RESET_ACTION):
		PlayLog.log_event("action", "action.reset", "reset with R, back to the shore with a new lake",
				{"phase": str(RunState.Phase.keys()[RunState.phase]).to_lower(), "progress": snappedf(RunState.progress, 0.001)})
		_new_attempt()
		get_viewport().set_input_as_handled()


## Sizes the water and the shore to the lake: the water runs from the shore line up past the
## island, and both run across lake_width plus WATER_MARGIN on each side of x = 0. Their tiles
## repeat over the polygons (Polygon2D maps an unset uv from the points, one tile per texture
## size, and texture_repeat is on in the scene).
func _size_water() -> void:
	var half_width: float = TUNING.lake_width * 0.5 + WATER_MARGIN
	var top: float = -(TUNING.island_distance + TUNING.island_radius + WATER_MARGIN)
	_water.polygon = _rect(half_width, top, SHORE_DEPTH)
	_shore_visual.polygon = _rect(half_width, 0.0, SHORE_DEPTH)


func _on_island_body_entered(body: Node2D) -> void:
	if body == _boat:
		RunState.arrive()


func _on_shore_reset_done() -> void:
	_restart()


## The boat back at its start and this attempt's hazards placed: after a shore reset, and for
## a new attempt after the win. The hazards run again first (the win cutscene quiets them).
func _restart() -> void:
	_boat.place(_start)
	_hazards.process_mode = Node.PROCESS_MODE_INHERIT
	_spawn_hazards()


## The attempt is won: the cutscene plays at the island (it draws the boys from the boat's
## seats, so it goes in the frame the boat stops showing them) and takes the camera over.
func _start_win() -> void:
	_win = WIN_SCENE.instantiate() as WinCutscene
	_win.position = _island.position
	_win.again.connect(_on_win_again)
	PlayLog.log_view("win")
	_camera.set_physics_process(false)
	_quiet_hazards()
	add_child(_win)
	_win.begin(_boat, _camera, TUNING.island_radius, _island_visual.scale.x)


## The hazards stop for the win cutscene (B4): the Hazards node is disabled, so no hazard steps,
## calls RunState's effects or plays on; each telegraph loop is ended here, since a disabled
## node would never end its own. The Area2D hazards (log, rock) also stop watching for the boat,
## as their contact calls RunState's effects directly. _restart() turns the node back on.
func _quiet_hazards() -> void:
	_hazards.process_mode = Node.PROCESS_MODE_DISABLED
	for hazard: Node in _hazards.get_children():
		if hazard is HazardBase:
			(hazard as HazardBase).stop_telegraph()
		elif hazard is Area2D:
			hazard.set_deferred(&"monitoring", false)


## The player goes again from the win cutscene.
func _on_win_again() -> void:
	PlayLog.log_event("action", "action.again", "went again from the win screen")
	_new_attempt()


## The touch button's hold reached reset_hold_time.
func _on_reset_requested() -> void:
	PlayLog.log_event("action", "action.reset", "reset with the touch button's hold, back to the shore with a new lake",
			{"phase": str(RunState.Phase.keys()[RunState.phase]).to_lower(), "progress": snappedf(RunState.progress, 0.001)})
	_new_attempt()


## The next attempt (a new lake) starts from the shore at once: the cutscene, if it is up,
## leaves and the camera follows the boat again (freeing it ends its tweens), then
## RunState.new_attempt() draws the lake and the boat and the hazards are placed.
func _new_attempt() -> void:
	if _win != null:
		remove_child(_win)
		_win.queue_free()
		_win = null
		_camera.set_physics_process(true)
	RunState.new_attempt()
	PlayLog.log_view("lake")
	_restart()


## Replaces the hazards with this attempt's as launched: the whole plan for RunState.lake_seed,
## and one beast under water. The old ones leave the tree at once, not at queue_free's deferred
## time, so only the new ones are in it. Debug builds print the seed, so a lake can be had
## again, and fill the path overlay and its trigger markers.
func _spawn_hazards() -> void:
	unregister_beast()
	for child: Node in _hazards.get_children():
		_hazards.remove_child(child)
		child.queue_free()
	var placements: Array[Hazards.Placement] = Hazards.plan(TUNING, RunState.lake_seed)
	if _debug_tools:
		print("lake seed %d" % RunState.lake_seed)
		_fill_path_overlay()
		_mark_triggers(placements)
	for placement: Hazards.Placement in placements:
		var spec: HazardSpec = TUNING.hazards[placement.spec]
		if spec.scene == null:
			continue
		var hazard: Node2D = spec.scene.instantiate() as Node2D
		hazard.position = placement.position
		# Both before add_child, so the hazard's _ready sees them. A hazard that doesn't declare
		# a field ignores the set (Object.set on an unknown property does nothing).
		hazard.set(&"spec", spec)
		hazard.set(&"tuning", TUNING)
		_hazards.add_child(hazard)
	var beast: Node2D = BEAST_SCENE.instantiate() as Node2D
	beast.set(&"tuning", TUNING)
	_hazards.add_child(beast)
	register_beast(beast)


## The dev menu's Beast tab (T84) shows the beast this lake spawned. It replaces the last lake's
## registration: the old one is unregistered first, so a new lake never leaves a stale node.
## Harmless where the dev menu isn't there (a release build), as it is looked up, not named.
static func register_beast(beast: Node2D) -> void:
	var menu: Node = _dev_menu()
	if menu != null:
		menu.unregister_system(BEAST_SYSTEM)
		menu.register_system(BEAST_SYSTEM, beast)


## Takes the Beast tab down, if the dev menu is there.
static func unregister_beast() -> void:
	var menu: Node = _dev_menu()
	if menu != null:
		menu.unregister_system(BEAST_SYSTEM)


## The DevMenu autoload (tools/dev_menu.gd), or null where it isn't there. Looked up through the
## main loop, as RunState looks up PlayLog, so the lake works without it.
static func _dev_menu() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null(DEV_MENU_PATH) if tree != null else null


## Debug only: the overlay's centre line, from the launch margin to the island's near edge, with
## PATH_OVERLAY_STEPS points per band, so it bends where Hazards' corridor does. The corridor's
## centres are drawn once for the attempt's seed (corridor_at, the same values corridor_x gives).
## The overlay is drawn at path_width, so its strip is the corridor.
func _fill_path_overlay() -> void:
	var bands: int = Hazards.band_count(TUNING)
	var points: PackedVector2Array = PackedVector2Array()
	if bands > 0:
		var centers: PackedFloat64Array = Hazards.path_centers(TUNING, RunState.lake_seed)
		var launch: float = TUNING.launch_margin
		var far: float = Hazards.far_edge(TUNING)
		var steps: int = bands * PATH_OVERLAY_STEPS
		for i: int in steps + 1:
			var distance: float = lerpf(launch, far, float(i) / float(steps))
			points.append(Vector2(Hazards.corridor_at(TUNING, centers, -distance), -distance))
	_path_overlay.width = TUNING.path_width
	_path_overlay.points = points


## Debug only: one marker per event in the plan at its trigger point, as children of the path
## overlay so F7 shows and hides them with it. The last plan's markers go first, at once, so a
## shore reset shows only the current lake's.
func _mark_triggers(placements: Array[Hazards.Placement]) -> void:
	for child: Node in _path_overlay.get_children():
		_path_overlay.remove_child(child)
		child.queue_free()
	for placement: Hazards.Placement in placements:
		var spec: HazardSpec = TUNING.hazards[placement.spec]
		if spec == null or not spec.is_event:
			continue
		var marker: Polygon2D = Polygon2D.new()
		marker.color = TRIGGER_MARKER_COLOUR
		marker.polygon = _diamond(TRIGGER_MARKER_SIZE)
		marker.position = placement.position
		_path_overlay.add_child(marker)


## Whether the boat slid against the shore last frame.
func _touching_shore() -> bool:
	for i: int in _boat.get_slide_collision_count():
		if _boat.get_slide_collision(i).get_collider() == _shore:
			return true
	return false


## Visual only: one marker per guy in the water, where Rescue says he is. A floating guy holds
## his beer at DRINK_OFFSET while has_beer and shows none otherwise; a swimmer's loose beer is
## where Rescue says it is.
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
		var guy: Sprite2D = marker.get_node("Guy") as Sprite2D
		guy.modulate = FLOATING_TINT if floating else Color.WHITE
		var beer: Node2D = marker.get_node("Beer") as Node2D
		if floating:
			# Rescue's beer_position is his own spot once he floats, so the can is placed from him.
			beer.visible = swimmer.has_beer
			beer.position = DRINK_OFFSET
		else:
			beer.visible = true
			beer.global_position = swimmer.beer_position
	for seat: int in _markers.keys():
		if not seen.has(seat):
			_markers[seat].queue_free()
			_markers.erase(seat)


## Visual only: one beer sprite per beer bobbing away while its guy winds up, where Rescue says
## it is; it bobs like a floating guy. Gone once he jumps (his swimmer marker shows it then).
func _show_loose_beers() -> void:
	var seen: Array[int] = []
	var bob: float = BOB_HEIGHT * sin(TAU * _bob_clock / BOB_PERIOD)
	for beer: Rescue.LooseBeer in RunState.rescue.loose_beers():
		seen.append(beer.seat)
		if not _loose_beers.has(beer.seat):
			var can: Sprite2D = _sprite("LooseBeer%d" % beer.seat, BEER_TEXTURE)
			_swimmers.add_child(can)
			_loose_beers[beer.seat] = can
		_loose_beers[beer.seat].position = beer.position + Vector2(0.0, bob)
	for seat: int in _loose_beers.keys():
		if not seen.has(seat):
			_loose_beers[seat].queue_free()
			_loose_beers.erase(seat)


func _make_marker(seat: int) -> Node2D:
	var marker: Node2D = Node2D.new()
	marker.add_child(_sprite("Guy", SWIM_TEXTURES[seat]))
	marker.add_child(_sprite("Beer", BEER_TEXTURE))
	_swimmers.add_child(marker)
	return marker


static func _sprite(sprite_name: String, texture: Texture2D) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = sprite_name
	sprite.texture = texture
	return sprite


## A rectangle centred on x = 0, from top to bottom in lake pixels.
static func _rect(half_width: float, top: float, bottom: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-half_width, top), Vector2(half_width, top),
		Vector2(half_width, bottom), Vector2(-half_width, bottom),
	])


## A diamond: a square on its corner, `radius` from the centre to each corner.
static func _diamond(radius: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0.0, -radius), Vector2(radius, 0.0), Vector2(0.0, radius), Vector2(-radius, 0.0),
	])
