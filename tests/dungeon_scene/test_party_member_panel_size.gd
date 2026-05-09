extends GutTest

# Verifies the enlarged size constants on PartyMemberPanel.


func test_panel_width_is_240():
	assert_eq(PartyMemberPanel.PANEL_WIDTH, 240,
		"PANEL_WIDTH should be 240 to fit six panels in the 1600 design canvas")


func test_panel_height_is_at_least_200():
	assert_true(PartyMemberPanel.PANEL_HEIGHT >= 200,
		"PANEL_HEIGHT should be at least 200 for the bumped portrait-forward cards; got %d" % PartyMemberPanel.PANEL_HEIGHT)


func test_body_font_size_is_enlarged_for_readability():
	assert_true(PartyMemberPanel.FONT_SIZE >= 21 and PartyMemberPanel.FONT_SIZE <= 30,
		"FONT_SIZE should be in [21, 30] under the new design canvas; got %d" % PartyMemberPanel.FONT_SIZE)


func test_portrait_rect_is_larger_than_old_icon():
	var panel := PartyMemberPanel.new()
	add_child_autofree(panel)
	if not panel.has_method("get_portrait_rect"):
		fail_test("PartyMemberPanel should expose get_portrait_rect")
		return
	var r: Rect2 = panel.get_portrait_rect()
	assert_gt(r.size.x, 100.0)
	assert_gt(r.size.y, 80.0)


func test_portrait_rect_is_centered_in_panel():
	var panel := PartyMemberPanel.new()
	add_child_autofree(panel)
	var r: Rect2 = panel.get_portrait_rect()
	var panel_center_x := float(PartyMemberPanel.PANEL_WIDTH) * 0.5
	assert_almost_eq(r.position.x + r.size.x * 0.5, panel_center_x, 0.001)


func test_level_badge_sits_in_portrait_upper_right():
	var panel := PartyMemberPanel.new()
	add_child_autofree(panel)
	if not panel.has_method("get_portrait_rect") or not panel.has_method("get_level_badge_rect"):
		fail_test("PartyMemberPanel should expose portrait and level badge rect helpers")
		return
	var portrait: Rect2 = panel.get_portrait_rect()
	var badge: Rect2 = panel.get_level_badge_rect()
	assert_gte(badge.position.x, portrait.position.x + portrait.size.x - badge.size.x - 2.0)
	assert_lte(badge.position.y, portrait.position.y + 4.0)


func test_name_badge_overlays_portrait():
	var panel := PartyMemberPanel.new()
	add_child_autofree(panel)
	if not panel.has_method("get_name_badge_rect"):
		fail_test("PartyMemberPanel should expose get_name_badge_rect")
		return
	var portrait: Rect2 = panel.get_portrait_rect()
	var badge: Rect2 = panel.get_name_badge_rect()
	assert_true(portrait.encloses(badge), "name badge should be inside the portrait area")
	assert_gte(badge.position.y, portrait.position.y + portrait.size.y - badge.size.y - 4.0,
		"name badge should sit over the lower portrait area")


func test_portrait_bottom_sits_close_to_hp_bar():
	var panel := PartyMemberPanel.new()
	add_child_autofree(panel)
	var portrait: Rect2 = panel.get_portrait_rect()
	var hp_bar: Rect2 = panel.get_hp_bar_rect()
	assert_lte(hp_bar.position.y - (portrait.position.y + portrait.size.y), 8.0,
		"portrait should use the vertical space above the HP bar")


func test_hp_and_mp_ratios_are_clamped_and_zero_safe():
	var panel := PartyMemberPanel.new()
	add_child_autofree(panel)
	if not panel.has_method("stat_bar_ratio"):
		fail_test("PartyMemberPanel should expose stat_bar_ratio")
		return
	assert_almost_eq(panel.stat_bar_ratio(8, 10), 0.8, 0.001)
	assert_almost_eq(panel.stat_bar_ratio(5, 20), 0.25, 0.001)
	assert_eq(panel.stat_bar_ratio(5, 0), 0.0)
	assert_eq(panel.stat_bar_ratio(12, 10), 1.0)
	assert_eq(panel.stat_bar_ratio(-2, 10), 0.0)
