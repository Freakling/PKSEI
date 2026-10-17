extends "res://tools/test_case.gd"
## T54 · Touch pads: a touch's position picks the seat (left/right half of the screen → hull,
## upper/lower half → front/back seat, the whole half counting), and its release motion picks
## the direction (a flick down of at least flick_distance → reverse; a wobble, a flick up or a
## sideways one → forward) (GDD › Presentation and Platforms, Touch).

const VIEW: Vector2 = Vector2(640.0, 360.0)
const FLICK: float = 24.0


func test_the_corners_are_the_four_seats() -> void:
	expect_eq(TouchPads.seat_for(Vector2(0.0, 0.0), VIEW), Paddling.Seat.LEFT_FRONT, "top left")
	expect_eq(TouchPads.seat_for(Vector2(0.0, 359.0), VIEW), Paddling.Seat.LEFT_BACK, "bottom left")
	expect_eq(TouchPads.seat_for(Vector2(639.0, 0.0), VIEW), Paddling.Seat.RIGHT_FRONT, "top right")
	expect_eq(TouchPads.seat_for(Vector2(639.0, 359.0), VIEW), Paddling.Seat.RIGHT_BACK, "bottom right")


## The whole half counts, not just the pad art: a touch near the middle of the screen still
## picks the quadrant it is in.
func test_the_whole_half_counts() -> void:
	expect_eq(TouchPads.seat_for(Vector2(300.0, 170.0), VIEW), Paddling.Seat.LEFT_FRONT)
	expect_eq(TouchPads.seat_for(Vector2(300.0, 190.0), VIEW), Paddling.Seat.LEFT_BACK)
	expect_eq(TouchPads.seat_for(Vector2(340.0, 170.0), VIEW), Paddling.Seat.RIGHT_FRONT)
	expect_eq(TouchPads.seat_for(Vector2(340.0, 190.0), VIEW), Paddling.Seat.RIGHT_BACK)


## The midlines count as right and back; a pixel before them is left and front.
func test_the_midlines() -> void:
	expect_eq(TouchPads.seat_for(Vector2(320.0, 180.0), VIEW), Paddling.Seat.RIGHT_BACK, "the centre")
	expect_eq(TouchPads.seat_for(Vector2(319.0, 180.0), VIEW), Paddling.Seat.LEFT_BACK, "left of it")
	expect_eq(TouchPads.seat_for(Vector2(320.0, 179.0), VIEW), Paddling.Seat.RIGHT_FRONT, "above it")
	expect_eq(TouchPads.seat_for(Vector2(319.0, 179.0), VIEW), Paddling.Seat.LEFT_FRONT, "both")


## The mapping follows the view size, not the 640×360 canvas.
func test_another_view_size() -> void:
	var view: Vector2 = Vector2(1280.0, 720.0)
	expect_eq(TouchPads.seat_for(Vector2(639.0, 719.0), view), Paddling.Seat.LEFT_BACK)
	expect_eq(TouchPads.seat_for(Vector2(640.0, 359.0), view), Paddling.Seat.RIGHT_FRONT)


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
