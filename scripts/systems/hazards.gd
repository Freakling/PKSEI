class_name Hazards
extends RefCounted
## Hazards · where the lake's hazards go (GDD › Systems › Hazards, Placement).
##
## A plain rule class: it receives its LakeTuning and a seed and never touches the scene tree or
## RunState. The planned water is the open stretch between the launch margin (y = -launch_margin,
## clear of the beach and the boat at launch) and the island's near edge
## (y = -(island_distance - island_radius)), split up-screen into bands of band_length pixels,
## the last one possibly shorter. Each band draws round(density_curve) hazards from
## tuning.hazards, in proportion to HazardSpec.weight among the specs whose first_band allows the
## band, each at a position inside the band and outside the path.
##
## The path (GDD: "a guaranteed path winds through every band") is a corridor path_width wide
## that no object is placed in. Its centre is a random walk across the lake, one step per band:
## path_center(tuning, seed, band) is the centre's x at the band's near edge, 0 at the launch
## (band 0) and 0 again at the island's near edge (band band_count, the far edge of the last
## band), each step in between drawn from an RNG seeded with band_seed(seed, band,
## PATH_GENERATION), at most path_wander from the centre before it, kept far enough inside
## lake_width for the whole corridor to fit, and pulled home: within (bands left) * path_wander
## of 0, so the remaining steps can always bring it back to the island. Between two centres the
## corridor's x is the straight line from one to the next (corridor_x(tuning, seed, y)), so the
## corridor is continuous across band edges; off the shore it sits at 0 (the launch) and so does
## the island. A placement's x is drawn from the water outside the corridor at its y; a band
## that is all corridor (path_width at or above lake_width) places nothing.
##
## The attempt's seed is the one truth. Each band is planned on its own
## (plan_band(tuning, seed, band, generation)) from a RandomNumberGenerator seeded with
## band_seed(): a hash of the seed, the band and the band's generation, so the same seed and
## tuning always give the same lake, and a band can be re-planned at a later generation without
## touching the others (for the path and future events; the lake itself plans generation 0 only).
## plan() is the whole lake at generation 0, band by band. Hazards are objects and stay where they
## are placed. lake.gd instances the placements under its Hazards node.
##
## The effects palette (GDD › Systems › Hazards, Effects) lives on RunState, which the boat and
## the guys answer to; a hazard scene calls beer_overboard(hull, at), shove(impulse),
## snag(hull, seconds), stop(), force_break(hull) and water_aboard(hull, amount).

## The generation the path's draws are hashed with: objects use 0 and up, so the path never
## shares a band's RNG with them.
const PATH_GENERATION: int = -1


## One hazard to place: which spec (index into LakeTuning.hazards), which band, and where in
## lake pixels.
class Placement extends RefCounted:
	var spec: int = 0
	var band: int = 0
	var position: Vector2 = Vector2.ZERO

	func _init(spec_index: int, band_index: int, at: Vector2) -> void:
		spec = spec_index
		band = band_index
		position = at


## Distance from the shore line to the island's near edge, where the planned water ends.
static func far_edge(tuning: LakeTuning) -> float:
	return tuning.island_distance - tuning.island_radius


## Pixels of planned water: from the launch margin to the island's near edge.
static func span(tuning: LakeTuning) -> float:
	return far_edge(tuning) - tuning.launch_margin


## Bands across the planned water: the span in band_lengths, rounded up, so the last band ends at
## the island's near edge. None when there is no water to plan.
static func band_count(tuning: LakeTuning) -> int:
	if tuning.band_length <= 0.0 or span(tuning) <= 0.0:
		return 0
	return ceili(span(tuning) / tuning.band_length)


## Distance from the shore line to a band's near edge (the one toward the shore): the launch
## margin for the first band, a band_length further for each band after it.
static func near_edge(tuning: LakeTuning, band: int) -> float:
	return tuning.launch_margin + band * tuning.band_length


## Hazards a band draws: density_curve sampled at the band's place in the lake (0 the first
## band, 1 the island band), rounded, never negative.
static func density(tuning: LakeTuning, band: int) -> int:
	if tuning.density_curve == null:
		return 0
	var bands: int = band_count(tuning)
	var t: float = float(band) / float(bands - 1) if bands > 1 else 0.0
	return maxi(roundi(tuning.density_curve.sample(t)), 0)


## The spec indices a band may draw: a weight above zero and a first_band at or before it.
static func allowed(tuning: LakeTuning, band: int) -> Array[int]:
	var specs: Array[int] = []
	for i: int in tuning.hazards.size():
		var spec: HazardSpec = tuning.hazards[i]
		if spec != null and spec.weight > 0.0 and spec.first_band <= band:
			specs.append(i)
	return specs


## The RNG seed a band's plan is drawn from: a hash of the attempt's seed, the band and its
## generation (0 the lake as launched, one more for each later re-plan of the band), so each triple
## has its own reproducible draw.
static func band_seed(lake_seed: int, band: int, generation: int) -> int:
	return hash("%d:%d:%d" % [lake_seed, band, generation])


## Every hazard of the lake for this seed as launched: each band's generation 0, band by band
## from the launch margin.
static func plan(tuning: LakeTuning, lake_seed: int) -> Array[Placement]:
	var placements: Array[Placement] = []
	for band: int in band_count(tuning):
		placements.append_array(plan_band(tuning, lake_seed, band, 0))
	return placements


## One band's hazards at one generation: its density's worth of weighted draws, each placed
## inside the band and outside the path, from an RNG seeded with band_seed(). Nothing for a band
## outside the planned water, one no spec may be drawn in, or one the corridor fills.
static func plan_band(tuning: LakeTuning, lake_seed: int, band: int, generation: int) -> Array[Placement]:
	var placements: Array[Placement] = []
	if band < 0 or band >= band_count(tuning):
		return placements
	var specs: Array[int] = allowed(tuning, band)
	if specs.is_empty() or open_width(tuning) <= 0.0:
		return placements
	var centers: PackedFloat64Array = path_centers(tuning, lake_seed)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = band_seed(lake_seed, band, generation)
	for i: int in density(tuning, band):
		var spec: int = draw(tuning, specs, rng)
		placements.append(Placement.new(spec, band, place(tuning, centers, band, rng)))
	return placements


## One weighted draw among `specs`: each is picked in proportion to its weight.
static func draw(tuning: LakeTuning, specs: Array[int], rng: RandomNumberGenerator) -> int:
	var total: float = 0.0
	for spec: int in specs:
		total += tuning.hazards[spec].weight
	var roll: float = rng.randf() * total
	for spec: int in specs:
		roll -= tuning.hazards[spec].weight
		if roll < 0.0:
			return spec
	return specs[specs.size() - 1]


## A position inside the band and outside the path: between the band's near and far edges (the
## first band starting at the launch margin and the island band ending at the island's near
## edge), then anywhere across the water left once the corridor at that y is taken out: an x is
## drawn over the open width from the lake's left edge and moved past the corridor when it lands
## at or beyond the corridor's left edge, so every point outside the corridor is as likely as any
## other. `centers` is path_centers() for the lake.
static func place(tuning: LakeTuning, centers: PackedFloat64Array, band: int, rng: RandomNumberGenerator) -> Vector2:
	var half: float = tuning.lake_width * 0.5
	var near: float = near_edge(tuning, band)
	var far: float = minf(near + tuning.band_length, far_edge(tuning))
	var y: float = -rng.randf_range(near, far)
	var x: float = rng.randf_range(-half, -half + open_width(tuning))
	var left_of_path: float = corridor_at(tuning, centers, y) - tuning.path_width * 0.5
	if x >= left_of_path:
		x += tuning.path_width
	return Vector2(x, y)


# --- the path -----------------------------------------------------------------------------------

## Pixels of water across the lake left for objects once the corridor is taken out; nothing when
## the corridor is as wide as the lake or wider.
static func open_width(tuning: LakeTuning) -> float:
	return maxf(tuning.lake_width - tuning.path_width, 0.0)


## Furthest the corridor's centre may sit from x = 0 with the whole corridor inside the lake.
static func path_reach(tuning: LakeTuning) -> float:
	return open_width(tuning) * 0.5


## The corridor's centre x at every band edge: entry `band` is the centre at that band's near
## edge, for band 0 (the launch, 0) up to band_count (the island's near edge, 0). Each centre
## in between is the one before it plus a step in [-path_wander, path_wander] drawn from the
## band's path RNG (band_seed(seed, band, PATH_GENERATION)), clamped to path_reach() and to
## (band_count - band) * path_wander so the last step to the island is at most path_wander too.
## One entry, 0, when there are no bands.
static func path_centers(tuning: LakeTuning, lake_seed: int) -> PackedFloat64Array:
	var bands: int = band_count(tuning)
	var centers: PackedFloat64Array = PackedFloat64Array()
	centers.resize(bands + 1)
	centers[0] = 0.0
	var wander: float = maxf(tuning.path_wander, 0.0)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for band: int in range(1, bands):
		rng.seed = band_seed(lake_seed, band, PATH_GENERATION)
		var reach: float = minf(path_reach(tuning), float(bands - band) * wander)
		var step: float = rng.randf_range(-wander, wander)
		centers[band] = clampf(centers[band - 1] + step, -reach, reach)
	if bands > 0:
		centers[bands] = 0.0
	return centers


## The corridor's centre x at a band's near edge (see path_centers()); band_count gives the
## island's near edge. 0 for a band outside the planned water.
static func path_center(tuning: LakeTuning, lake_seed: int, band: int) -> float:
	var centers: PackedFloat64Array = path_centers(tuning, lake_seed)
	if band < 0 or band >= centers.size():
		return 0.0
	return centers[band]


## The corridor's centre x at a lake y (negative up-screen, like a Placement's position): 0 from
## the shore line to the launch margin and from the island's near edge on, and in a band the
## straight line from its centre at the near edge to the next band's at the far edge.
static func corridor_x(tuning: LakeTuning, lake_seed: int, y: float) -> float:
	return corridor_at(tuning, path_centers(tuning, lake_seed), y)


## corridor_x() with the centres already drawn (path_centers()).
static func corridor_at(tuning: LakeTuning, centers: PackedFloat64Array, y: float) -> float:
	var bands: int = centers.size() - 1
	var distance: float = -y
	if bands <= 0 or distance <= tuning.launch_margin or distance >= far_edge(tuning):
		return 0.0
	var band: int = clampi(floori((distance - tuning.launch_margin) / tuning.band_length), 0, bands - 1)
	var near: float = near_edge(tuning, band)
	var far: float = minf(near + tuning.band_length, far_edge(tuning))
	var t: float = (distance - near) / (far - near) if far > near else 0.0
	return lerpf(centers[band], centers[band + 1], clampf(t, 0.0, 1.0))
