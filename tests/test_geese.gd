extends "res://tools/test_case.gd"
## T15 · Angry geese: a flock on its nest hisses when the boat enters geese_radius, charges and
## pecks for geese_attack_time (a beer overboard on the hull nearest the flock, every
## geese_peck_interval while in peck range), then returns to the nest and cools down before it
## can hiss again (GDD › Systems › Hazards, the Angry geese row). No reaction outside the radius;
## same inputs, same pecks.
##
## The tick is 1/64 s and the speeds and times are multiples of it, so every timer sum is exact:
## the geese fly 1 px per tick and the peck ticks can be named.

const TICK: float = 1.0 / 64.0
const RADIUS: float = 100.0
const WARNING: float = 1.0
const ATTACK: float = 2.5
const SPEED: float = 64.0
const INTERVAL: float = 0.5
const RANGE: float = 10.0
const COOLDOWN: float = 2.0
const NEST: Vector2 = Vector2(0.0, 0.0)
## Inside the radius, 58 px to the right of the nest: the geese are in range after 48 ticks.
const NEAR: Vector2 = Vector2(58.0, 0.0)
const FAR: Vector2 = Vector2(200.0, 0.0)
## Ticks of the charge on which a peck lands: in range at tick 48, then every 0.5 s (32 ticks).
const PECK_TICKS: Array[int] = [48, 80, 112, 144]
const WARNING_TICKS: int = 64
const ATTACK_TICKS: int = 160
const RETURN_TICKS: int = 58
const COOLDOWN_TICKS: int = 128

var tuning: LakeTuning
var flock: GeeseFlock


func before_each() -> void:
	tuning = LakeTuning.new()
	tuning.geese_radius = RADIUS
	tuning.geese_warning = WARNING
	tuning.geese_attack_time = ATTACK
	tuning.geese_speed = SPEED
	tuning.geese_peck_interval = INTERVAL
	tuning.geese_peck_range = RANGE
	tuning.geese_cooldown = COOLDOWN
	flock = GeeseFlock.new(tuning, NEST)


## Steps the flock for some ticks with the boat still; returns the ticks (1-based) that pecked.
func run(ticks: int, boat: Vector2, rotation: float = 0.0) -> Array[int]:
	var pecked: Array[int] = []
	for tick: int in ticks:
		for peck: GeeseFlock.Peck in flock.step(TICK, boat, rotation):
			pecked.append(tick + 1)
	return pecked


## Brings the flock to the first tick of its charge.
func start_charge() -> void:
	run(1, NEAR)
	run(WARNING_TICKS, NEAR)
	expect_eq(flock.state, GeeseFlock.State.CHARGING, "charging after the warning")


func test_no_reaction_outside_the_radius() -> void:
	var pecked: Array[int] = run(400, FAR)
	expect_eq(flock.state, GeeseFlock.State.NESTING, "still nesting")
	expect_eq(flock.position, NEST, "still on the nest")
	expect_eq(flock.time_left, 0.0, "no timer running")
	expect_eq(pecked.size(), 0, "no pecks")


func test_hisses_for_the_warning_then_charges() -> void:
	run(1, NEAR)
	expect_eq(flock.state, GeeseFlock.State.HISSING, "hissing once the boat is inside the radius")
	expect_eq(flock.time_left, WARNING, "the warning starts")
	var pecked: Array[int] = run(WARNING_TICKS - 1, NEAR)
	expect_eq(flock.state, GeeseFlock.State.HISSING, "still hissing one tick before the charge")
	expect_eq(flock.position, NEST, "the geese stay on the nest while they hiss")
	expect_eq(pecked.size(), 0, "no pecks while hissing")
	run(1, NEAR)
	expect_eq(flock.state, GeeseFlock.State.CHARGING, "charging when the warning is over")
	expect_eq(flock.time_left, ATTACK, "the charge timer starts")


func test_charge_pecks_at_the_interval_then_returns() -> void:
	start_charge()
	var pecked: Array[int] = run(ATTACK_TICKS, NEAR)
	expect_eq(pecked, PECK_TICKS, "a peck on reaching range, then one per interval")
	expect_eq(flock.position, NEAR, "the geese stop at the boat")
	expect_eq(flock.state, GeeseFlock.State.RETURNING, "they give up after geese_attack_time")
	expect_eq(flock.time_left, 0.0, "the charge is over")
	pecked = run(RETURN_TICKS - 1, NEAR)
	expect_eq(pecked.size(), 0, "no pecks on the way back")
	expect_eq(flock.state, GeeseFlock.State.RETURNING, "still flying home one tick short")
	run(1, NEAR)
	expect_eq(flock.state, GeeseFlock.State.NESTING, "nesting once home")
	expect_eq(flock.position, NEST, "back on the nest")
	expect_eq(flock.time_left, COOLDOWN, "the cooldown starts")


func test_cooldown_before_the_next_hiss() -> void:
	start_charge()
	run(ATTACK_TICKS + RETURN_TICKS, NEAR)
	expect_eq(flock.state, GeeseFlock.State.NESTING, "home")
	run(COOLDOWN_TICKS - 1, NEAR)
	expect_eq(flock.state, GeeseFlock.State.NESTING, "cooling down with the boat still near")
	run(1, NEAR)
	expect_eq(flock.state, GeeseFlock.State.HISSING, "hissing again once the cooldown is over")


func test_pecks_only_while_in_range() -> void:
	start_charge()
	var pecked: Array[int] = run(ATTACK_TICKS, FAR)
	expect_eq(pecked.size(), 0, "the boat outran the geese: no pecks")
	expect_eq(flock.state, GeeseFlock.State.RETURNING, "they give up all the same")
	expect_eq(flock.position, Vector2(ATTACK_TICKS, 0.0), "they flew for the whole charge")


func test_a_boat_leaving_during_the_hiss_calms_them() -> void:
	run(10, NEAR)
	expect_eq(flock.state, GeeseFlock.State.HISSING, "hissing")
	run(1, FAR)
	expect_eq(flock.state, GeeseFlock.State.NESTING, "calm once the boat backs off")
	expect_eq(flock.time_left, 0.0, "no cooldown for a charge that never came")
	run(1, NEAR)
	expect_eq(flock.state, GeeseFlock.State.HISSING, "hissing again at once when it comes back")
	expect_eq(flock.time_left, WARNING, "a full warning again")


func test_peck_lands_on_the_hull_nearest_the_flock() -> void:
	start_charge()
	run(PECK_TICKS[0] - 1, NEAR)
	var facing_up: Array[GeeseFlock.Peck] = flock.step(TICK, NEAR, 0.0)
	expect_eq(facing_up.size(), 1, "one peck on reaching range")
	expect_eq(facing_up[0].hull, Rescue.Hull.LEFT, "the flock is on the boat's left when it faces up")
	flock.reset()
	start_charge()
	run(PECK_TICKS[0] - 1, NEAR)
	var facing_down: Array[GeeseFlock.Peck] = flock.step(TICK, NEAR, PI)
	expect_eq(facing_down.size(), 1, "one peck on reaching range")
	expect_eq(facing_down[0].hull, Rescue.Hull.RIGHT, "the same flock is on its right when it faces down")


func test_same_inputs_same_pecks() -> void:
	var other: GeeseFlock = GeeseFlock.new(tuning, NEST)
	var mine: Array[int] = []
	var theirs: Array[int] = []
	for tick: int in 800:
		var boat: Vector2 = NEAR + Vector2(30.0 * sin(tick * 0.05), 20.0 * cos(tick * 0.03))
		var rotation: float = tick * 0.01
		for peck: GeeseFlock.Peck in flock.step(TICK, boat, rotation):
			mine.append(tick * 2 + int(peck.hull))
		for peck: GeeseFlock.Peck in other.step(TICK, boat, rotation):
			theirs.append(tick * 2 + int(peck.hull))
		expect_eq(flock.state, other.state, "same state at tick %d" % tick)
		expect_eq(flock.position, other.position, "same position at tick %d" % tick)
	expect(mine.size() > 0, "the moving boat got pecked at all")
	expect_eq(mine, theirs, "the same pecks on the same hulls")
