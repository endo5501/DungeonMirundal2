extends GutTest

func test_properties():
	var r = MapRect.new(2, 3, 4, 5)
	assert_eq(r.x, 2)
	assert_eq(r.y, 3)
	assert_eq(r.w, 4)
	assert_eq(r.h, 5)
	assert_eq(r.x2(), 5)  # x + w - 1 = 2 + 4 - 1
	assert_eq(r.y2(), 7)  # y + h - 1 = 3 + 5 - 1

func test_center():
	var r = MapRect.new(0, 0, 4, 4)
	assert_eq(r.center(), Vector2i(2, 2))

	var r2 = MapRect.new(1, 2, 3, 5)
	assert_eq(r2.center(), Vector2i(2, 4))  # 1+3/2=2, 2+5/2=4

func test_contains():
	var r = MapRect.new(2, 2, 3, 3)  # x2=4, y2=4
	assert_true(r.contains(2, 2), "top-left corner")
	assert_true(r.contains(4, 4), "bottom-right corner")
	assert_true(r.contains(3, 3), "center")
	assert_false(r.contains(1, 3), "left of rect")
	assert_false(r.contains(5, 3), "right of rect")
	assert_false(r.contains(3, 1), "above rect")
	assert_false(r.contains(3, 5), "below rect")

func test_intersects_overlap():
	var a = MapRect.new(0, 0, 3, 3)
	var b = MapRect.new(2, 2, 3, 3)
	assert_true(a.intersects(b, 0), "overlapping rects")

func test_intersects_with_margin():
	var a = MapRect.new(0, 0, 3, 3)  # x2=2
	var b = MapRect.new(4, 0, 3, 3)  # x=4, gap of 1
	assert_false(a.intersects(b, 0), "no overlap without margin")
	assert_false(a.intersects(b, 1), "gap=1 equals margin, no overlap")
	# gap=0 (adjacent) with margin=1 should intersect
	var c = MapRect.new(3, 0, 3, 3)  # x=3, gap of 0 from a
	assert_true(a.intersects(c, 1), "adjacent rects overlap with margin=1")

func test_intersects_far_apart():
	var a = MapRect.new(0, 0, 2, 2)
	var b = MapRect.new(10, 10, 2, 2)
	assert_false(a.intersects(b, 1), "far apart rects")
