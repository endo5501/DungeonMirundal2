extends GutTest

# Tests force a known width via _layout_panels(width) so layout assertions
# work without depending on parent-driven anchor resolution.

const TEST_WIDTH := 1280.0


func _make_display(width: float = TEST_WIDTH) -> PartyDisplay:
	var d := PartyDisplay.new()
	add_child_autofree(d)
	d._layout_panels(width)
	return d


func test_anchors_are_full_bottom():
	var d := _make_display()
	assert_eq(d.anchor_left, 0.0, "anchor_left should be 0.0")
	assert_eq(d.anchor_right, 1.0, "anchor_right should be 1.0")
	assert_eq(d.anchor_top, 1.0, "anchor_top should be 1.0")
	assert_eq(d.anchor_bottom, 1.0, "anchor_bottom should be 1.0")


func test_front_panels_left_aligned_increasing_x():
	var d := _make_display()
	var p0: PartyMemberPanel = d._front_panels[0]
	var p1: PartyMemberPanel = d._front_panels[1]
	var p2: PartyMemberPanel = d._front_panels[2]
	assert_true(p0.position.x < p1.position.x, "F0.x < F1.x")
	assert_true(p1.position.x < p2.position.x, "F1.x < F2.x")


func test_leftmost_front_panel_within_margin_of_left_edge():
	var d := _make_display()
	var leftmost_x: float = d._front_panels[0].position.x
	assert_true(leftmost_x <= float(PartyDisplay.MARGIN),
		"leftmost front panel x (%f) should be <= MARGIN (%d)" % [leftmost_x, PartyDisplay.MARGIN])


func test_back_panels_right_aligned_increasing_x():
	var d := _make_display()
	var p0: PartyMemberPanel = d._back_panels[0]
	var p1: PartyMemberPanel = d._back_panels[1]
	var p2: PartyMemberPanel = d._back_panels[2]
	assert_true(p0.position.x < p1.position.x, "B0.x < B1.x")
	assert_true(p1.position.x < p2.position.x, "B1.x < B2.x")


func test_rightmost_back_panel_right_edge_within_margin_of_display_right_edge():
	var d := _make_display()
	var rightmost: PartyMemberPanel = d._back_panels[2]
	var rightmost_right: float = rightmost.position.x + float(PartyMemberPanel.PANEL_WIDTH)
	var distance_from_right: float = TEST_WIDTH - rightmost_right
	assert_true(distance_from_right >= 0.0,
		"rightmost back panel right edge (%f) should not exceed display width (%f)" % [rightmost_right, TEST_WIDTH])
	assert_true(distance_from_right <= float(PartyDisplay.MARGIN),
		"rightmost back panel right edge should be within MARGIN of right edge; got distance=%f" % distance_from_right)


func test_all_panels_share_position_y():
	var d := _make_display()
	var y: float = d._front_panels[0].position.y
	for panel in d._front_panels:
		assert_eq(panel.position.y, y, "front panel y mismatch")
	for panel in d._back_panels:
		assert_eq(panel.position.y, y, "back panel y mismatch")


func test_center_gap_between_front_right_and_back_left():
	var d := _make_display()
	var front_right: float = d._front_panels[2].position.x + float(PartyMemberPanel.PANEL_WIDTH)
	var back_left: float = d._back_panels[0].position.x
	assert_true(back_left > front_right,
		"back row should start after front row ends; front_right=%f back_left=%f" % [front_right, back_left])


func test_no_color_rect_background_child():
	var d := _make_display()
	for child in d.get_children():
		assert_false(child is ColorRect,
			"PartyDisplay should not have ColorRect children (no global background bar)")
