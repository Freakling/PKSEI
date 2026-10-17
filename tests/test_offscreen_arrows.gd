extends "res://tools/test_case.gd"
## T45 · Off-screen arrows: for a swimmer outside the view, the arrow's screen position is the
## clamped projection of his position, where the ray from the view centre to him leaves the
## view inset by a margin, and it points at him (GDD › Systems › Setbacks).

const CENTER: Vector2 = Vector2(320.0, 180.0)
const HALF: Vector2 = Vector2(320.0, 180.0)
const MARGIN: float = 8.0
const INSET: Vector2 = Vector2(312.0, 172.0)


func test_target_above_sits_on_the_top_edge_pointing_up() -> void:
	var target: Vector2 = Vector2(320.0, -500.0)
	expect(OffscreenArrows.is_offscreen(target, CENTER, HALF), "above the view is off-screen")
	var point: Vector2 = OffscreenArrows.edge_point(target, CENTER, HALF, MARGIN)
	expect_near(point.y, CENTER.y - INSET.y, 0.001, "on the top edge, inset by the margin")
	expect_near(point.x, CENTER.x, 0.001, "straight above the centre")
	expect_near(OffscreenArrows.angle(target, CENTER), -PI / 2.0, 0.001, "pointing up")


func test_target_to_the_lower_right_sits_in_the_corner_region() -> void:
	var target: Vector2 = Vector2(3000.0, 2000.0)
	expect(OffscreenArrows.is_offscreen(target, CENTER, HALF))
	var point: Vector2 = OffscreenArrows.edge_point(target, CENTER, HALF, MARGIN)
	expect_near(point.y, CENTER.y + INSET.y, 0.001, "on the bottom edge")
	expect(point.x > CENTER.x + INSET.x / 2.0, "in the right-hand part of it: %s" % point)
	expect(point.x <= CENTER.x + INSET.x, "not past the corner: %s" % point)
	var direction: float = OffscreenArrows.angle(target, CENTER)
	expect(direction > 0.0 and direction < PI / 2.0, "pointing down and right: %s" % direction)


func test_target_to_the_left_sits_on_the_left_edge_pointing_left() -> void:
	var target: Vector2 = Vector2(-50.0, 180.0)
	var point: Vector2 = OffscreenArrows.edge_point(target, CENTER, HALF, MARGIN)
	expect_eq(point, Vector2(CENTER.x - INSET.x, CENTER.y))
	expect_near(absf(OffscreenArrows.angle(target, CENTER)), PI, 0.001, "pointing left")


func test_on_screen_target_is_reported_on_screen() -> void:
	expect_false(OffscreenArrows.is_offscreen(Vector2(400.0, 200.0), CENTER, HALF), "inside")
	expect_false(OffscreenArrows.is_offscreen(CENTER, CENTER, HALF), "the centre")
	expect_false(OffscreenArrows.is_offscreen(Vector2(640.0, 180.0), CENTER, HALF), "on the edge")
	expect(OffscreenArrows.is_offscreen(Vector2(641.0, 180.0), CENTER, HALF), "just past it")
	expect(OffscreenArrows.is_offscreen(Vector2(320.0, 361.0), CENTER, HALF), "just below")


## Whatever the direction and distance, the point is inside the inset rectangle, and for an
## off-screen target it is on that rectangle's edge.
func test_point_is_always_inside_the_inset_rectangle() -> void:
	var steps: int = 24
	for i: int in steps:
		var direction: Vector2 = Vector2.from_angle(TAU * float(i) / float(steps))
		for distance: float in [1.0, 50.0, 400.0, 5000.0]:
			var target: Vector2 = CENTER + direction * distance
			var offset: Vector2 = OffscreenArrows.edge_point(target, CENTER, HALF, MARGIN) - CENTER
			expect(absf(offset.x) <= INSET.x + 0.001 and absf(offset.y) <= INSET.y + 0.001,
					"inside for %s" % target)
			var reach: float = maxf(absf(offset.x) / INSET.x, absf(offset.y) / INSET.y)
			expect_near(reach, 1.0, 0.001, "on the edge for %s" % target)


func test_target_at_the_centre_gives_the_centre() -> void:
	expect_eq(OffscreenArrows.edge_point(CENTER, CENTER, HALF, MARGIN), CENTER)
