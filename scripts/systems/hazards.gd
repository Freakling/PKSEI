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
## band, each at a position inside the band.
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
## inside the band, from an RNG seeded with band_seed(). Nothing for a band outside the planned
## water, or one no spec may be drawn in.
static func plan_band(tuning: LakeTuning, lake_seed: int, band: int, generation: int) -> Array[Placement]:
	var placements: Array[Placement] = []
	if band < 0 or band >= band_count(tuning):
		return placements
	var specs: Array[int] = allowed(tuning, band)
	if specs.is_empty():
		return placements
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = band_seed(lake_seed, band, generation)
	for i: int in density(tuning, band):
		var spec: int = draw(tuning, specs, rng)
		placements.append(Placement.new(spec, band, place(tuning, band, rng)))
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


## A position inside the band: anywhere across lake_width (centred on x = 0), and between the
## band's near and far edges, the first band starting at the launch margin and the island band
## ending at the island's near edge.
static func place(tuning: LakeTuning, band: int, rng: RandomNumberGenerator) -> Vector2:
	var half: float = tuning.lake_width * 0.5
	var near: float = near_edge(tuning, band)
	var far: float = minf(near + tuning.band_length, far_edge(tuning))
	return Vector2(rng.randf_range(-half, half), -rng.randf_range(near, far))
