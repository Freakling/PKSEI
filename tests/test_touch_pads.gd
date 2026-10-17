extends "res://tools/test_case.gd"
## T54, T58 · Touch pads: a touch's x position picks the seat (left/right half of the screen →
## hull; within a half, the outer quarter toward the screen edge → back seat, the inner part
## toward the middle → front seat; the whole height counts), and its release motion picks the
## direction (a flick down of at least flick_distance → reverse; a wobble, a flick up or a
## sideways one → forward) (GDD › Presentation and Platforms, Touch).

const VIEW: Vector2 = Vector2(640.0, 360.0)
const FLICK: float = 24.0


## Each quarter of the screen is one seat: the outer two are the back seats.
func test_the_quarters_are_the_four_seats() -> void:
	expect_eq(TouchPads.seat_for(Vector2(80.0, 252.0), VIEW), Paddling.Seat.LEFT_BACK, "12.5%")
	expect_eq(TouchPads.seat_for(Vector2(240.0, 252.0), VIEW), Paddling.Seat.LEFT_FRONT, "37.5%")
	expect_eq(TouchPads.seat_for(Vector2(400.0, 252.0), VIEW), Paddling.Seat.RIGHT_FRONT, "62.5%")
	expect_eq(TouchPads.seat_for(Vector2(560.0, 252.0), VIEW), Paddling.Seat.RIGHT_BACK, "87.5%")


## The whole height of a half counts: the top, the middle and the bottom pick the same seat.
func test_the_whole_height_counts() -> void:
	var heights: Array[float] = [0.0, 180.0, 359.0]
	for y: float in heights:
		expect_eq(TouchPads.seat_for(Vector2(80.0, y), VIEW), Paddling.Seat.LEFT_BACK, "outer left at %s" % y)
		expect_eq(TouchPads.seat_for(Vector2(240.0, y), VIEW), Paddling.Seat.LEFT_FRONT, "inner left at %s" % y)
		expect_eq(TouchPads.seat_for(Vector2(400.0, y), VIEW), Paddling.Seat.RIGHT_FRONT, "inner right at %s" % y)
		expect_eq(TouchPads.seat_for(Vector2(560.0, y), VIEW), Paddling.Seat.RIGHT_BACK, "outer right at %s" % y)


## The corners are in the outer seats.
func test_the_corners() -> void:
	expect_eq(TouchPads.seat_for(Vector2(0.0, 0.0), VIEW), Paddling.Seat.LEFT_BACK, "top left")
	expect_eq(TouchPads.seat_for(Vector2(0.0, 359.0), VIEW), Paddling.Seat.LEFT_BACK, "bottom left")
	expect_eq(TouchPads.seat_for(Vector2(639.0, 0.0), VIEW), Paddling.Seat.RIGHT_BACK, "top right")
	expect_eq(TouchPads.seat_for(Vector2(639.0, 359.0), VIEW), Paddling.Seat.RIGHT_BACK, "bottom right")


## The quarter lines: x = w/4 is inner, just short of it outer; x = 3w/4 is outer, just short of
## it inner.
func test_the_quarter_lines() -> void:
	expect_eq(TouchPads.seat_for(Vector2(159.0, 180.0), VIEW), Paddling.Seat.LEFT_BACK, "left of w/4")
	expect_eq(TouchPads.seat_for(Vector2(160.0, 180.0), VIEW), Paddling.Seat.LEFT_FRONT, "on w/4")
	expect_eq(TouchPads.seat_for(Vector2(479.0, 180.0), VIEW), Paddling.Seat.RIGHT_FRONT, "left of 3w/4")
	expect_eq(TouchPads.seat_for(Vector2(480.0, 180.0), VIEW), Paddling.Seat.RIGHT_BACK, "on 3w/4")


## The midline counts as right; a pixel before it is left.
func test_the_midline() -> void:
	expect_eq(TouchPads.seat_for(Vector2(320.0, 180.0), VIEW), Paddling.Seat.RIGHT_FRONT, "the centre")
	expect_eq(TouchPads.seat_for(Vector2(319.0, 180.0), VIEW), Paddling.Seat.LEFT_FRONT, "left of it")
	expect_eq(TouchPads.seat_for(Vector2(319.0, 0.0), VIEW), Paddling.Seat.LEFT_FRONT, "left of it, at the top")
	expect_eq(TouchPads.seat_for(Vector2(320.0, 359.0), VIEW), Paddling.Seat.RIGHT_FRONT, "the centre, at the bottom")


## The mapping follows the view size, not the 640×360 canvas: the quarters move with it.
func test_another_view_size() -> void:
	var view: Vector2 = Vector2(1280.0, 720.0)
	expect_eq(TouchPads.seat_for(Vector2(319.0, 719.0), view), Paddling.Seat.LEFT_BACK, "left of w/4")
	expect_eq(TouchPads.seat_for(Vector2(320.0, 0.0), view), Paddling.Seat.LEFT_FRONT, "on w/4")
	expect_eq(TouchPads.seat_for(Vector2(640.0, 359.0), view), Paddling.Seat.RIGHT_FRONT, "the midline")
	expect_eq(TouchPads.seat_for(Vector2(960.0, 359.0), view), Paddling.Seat.RIGHT_BACK, "on 3w/4")


## A portrait phone: the same rule, the screen narrower than it is tall.
func test_a_portrait_view() -> void:
	var view: Vector2 = Vector2(360.0, 640.0)
	expect_eq(TouchPads.seat_for(Vector2(89.0, 600.0), view), Paddling.Seat.LEFT_BACK, "left of w/4")
	expect_eq(TouchPads.seat_for(Vector2(90.0, 600.0), view), Paddling.Seat.LEFT_FRONT, "on w/4")
	expect_eq(TouchPads.seat_for(Vector2(179.0, 40.0), view), Paddling.Seat.LEFT_FRONT, "left of the midline")
	expect_eq(TouchPads.seat_for(Vector2(180.0, 40.0), view), Paddling.Seat.RIGHT_FRONT, "the midline")
	expect_eq(TouchPads.seat_for(Vector2(270.0, 600.0), view), Paddling.Seat.RIGHT_BACK, "on 3w/4")


func test_a_flick_down_is_reverse_and_a_wobble_is_not() -> void:
	var press: Vector2 = Vector2(100.0, 100.0)
	expect(TouchPads.is_reverse(press, press + Vector2(0.0, FLICK), FLICK), "exactly the distance")
	expect(TouchPads.is_reverse(press, press + Vector2(0.0, 60.0), FLICK), "well past it")
	expect(TouchPads.is_reverse(press, press + Vector2(15.0, 30.0), FLICK), "down and a bit sideways")
	expect_false(TouchPads.is_reverse(press, press, FLICK), "no move")
	expect_false(TouchPads.is_reverse(press, press + Vector2(3.0, 5.0), FLICK), "a wobble")
	expect_false(TouchPads.is_reverse(press, press + Vector2(0.0, FLICK - 1.0), FLICK), "just short")


func test_a_flick_up_or_sideways_is_not_reverse() -> void:
	var press: Vector2 = Vector2(100.0, 100.0)
	expect_false(TouchPads.is_reverse(press, press + Vector2(0.0, -60.0), FLICK), "up")
	expect_false(TouchPads.is_reverse(press, press + Vector2(60.0, 0.0), FLICK), "right")
	expect_false(TouchPads.is_reverse(press, press + Vector2(-60.0, 0.0), FLICK), "left")
	expect_false(TouchPads.is_reverse(press, press + Vector2(60.0, 10.0), FLICK), "mostly sideways")
