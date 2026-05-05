extends GutTest

# Verifies PartyDisplay renders FRONT / BACK labels above each row group.
# Uses query helpers (FRONT_LABEL/BACK_LABEL constants and
# get_front_label_position / get_back_label_position) so we can verify intent
# without invoking the live draw context.

const TEST_WIDTH := 1280.0


func _make_display() -> PartyDisplay:
	var d := PartyDisplay.new()
	add_child_autofree(d)
	d._layout_panels(TEST_WIDTH)
	return d


func test_front_label_text_constant():
	assert_eq(PartyDisplay.FRONT_LABEL, "FRONT")


func test_back_label_text_constant():
	assert_eq(PartyDisplay.BACK_LABEL, "BACK")


func test_label_font_size_at_least_panel_font_size():
	assert_true(PartyDisplay.LABEL_FONT_SIZE >= PartyMemberPanel.FONT_SIZE,
		"LABEL_FONT_SIZE (%d) should be >= panel FONT_SIZE (%d)" %
			[PartyDisplay.LABEL_FONT_SIZE, PartyMemberPanel.FONT_SIZE])


func test_front_label_position_above_front_row_left():
	var d := _make_display()
	var pos: Vector2 = d.get_front_label_position()
	var front_panel: PartyMemberPanel = d._front_panels[0]
	assert_true(pos.y < front_panel.position.y,
		"FRONT label y (%f) should be above front row y (%f)" % [pos.y, front_panel.position.y])
	# Label baseline is at the front row's left edge (within a few pixels for
	# kerning/padding).
	assert_true(abs(pos.x - front_panel.position.x) <= 4.0,
		"FRONT label x (%f) should align with front row left x (%f)" % [pos.x, front_panel.position.x])


func test_back_label_position_above_back_row_right():
	var d := _make_display()
	var pos: Vector2 = d.get_back_label_position()
	var back_right_panel: PartyMemberPanel = d._back_panels[2]
	assert_true(pos.y < back_right_panel.position.y,
		"BACK label y (%f) should be above back row y (%f)" % [pos.y, back_right_panel.position.y])
	# pos.x is the right edge of the BACK label, aligned to the back row's
	# right edge (within a few pixels).
	var back_right_edge: float = back_right_panel.position.x + float(PartyMemberPanel.PANEL_WIDTH)
	assert_true(abs(pos.x - back_right_edge) <= 4.0,
		"BACK label right-edge x (%f) should align with back row right edge (%f)" %
			[pos.x, back_right_edge])
