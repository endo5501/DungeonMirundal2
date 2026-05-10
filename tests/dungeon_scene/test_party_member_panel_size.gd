extends GutTest

# Verifies the size constants on PartyMemberPanel.
# PANEL_WIDTH is matched to PORTRAIT_WIDTH (plus a small frame margin) so the
# HUD does not occlude the central 3D dungeon view.


func test_panel_width_is_174():
	assert_eq(PartyMemberPanel.PANEL_WIDTH, 174,
		"PANEL_WIDTH should be 174 (portrait 170 + 2px frame margin per side) so the HUD does not occlude the 3D dungeon center")


func test_panel_width_matches_portrait_with_margin():
	assert_gte(PartyMemberPanel.PANEL_WIDTH, PartyMemberPanel.PORTRAIT_WIDTH,
		"PANEL_WIDTH should be >= PORTRAIT_WIDTH so the portrait fits inside the panel frame")
	assert_lte(PartyMemberPanel.PANEL_WIDTH - PartyMemberPanel.PORTRAIT_WIDTH, 8,
		"PANEL_WIDTH should hug PORTRAIT_WIDTH (margin <= 8px); got margin=%d" %
			(PartyMemberPanel.PANEL_WIDTH - PartyMemberPanel.PORTRAIT_WIDTH))


func test_panel_height_is_at_least_200():
	assert_true(PartyMemberPanel.PANEL_HEIGHT >= 200,
		"PANEL_HEIGHT should be at least 200 for the bumped portrait-forward cards; got %d" % PartyMemberPanel.PANEL_HEIGHT)


func test_name_badge_font_size_is_enlarged_for_readability():
	# FONT_SIZE is dedicated to the member name badge under the modified spec —
	# the HP/MP rows now use a smaller BAR_FONT_SIZE so two stacked rows fit.
	assert_true(PartyMemberPanel.FONT_SIZE >= 21 and PartyMemberPanel.FONT_SIZE <= 30,
		"FONT_SIZE (name badge) should be in [21, 30] under the new design canvas; got %d" % PartyMemberPanel.FONT_SIZE)


func test_bar_font_size_is_at_least_14():
	assert_true(PartyMemberPanel.BAR_FONT_SIZE >= 14,
		"BAR_FONT_SIZE should be >= 14 so two stacked HP/MP rows fit without overlap; got %d" % PartyMemberPanel.BAR_FONT_SIZE)


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


func test_badge_font_size_fits_lv_99():
	assert_lte(PartyMemberPanel.BADGE_FONT_SIZE, 16,
		"BADGE_FONT_SIZE should be <= 16 so 'LV.99' fits inside a sensible badge width; got %d" %
			PartyMemberPanel.BADGE_FONT_SIZE)
	var panel := PartyMemberPanel.new()
	add_child_autofree(panel)
	var badge: Rect2 = panel.get_level_badge_rect()
	assert_gte(badge.size.x, 48.0,
		"Level badge width should be >= 48 px to accommodate 'LV.99'; got %f" % badge.size.x)


func test_level_badge_fits_lv_99_string():
	var panel := PartyMemberPanel.new()
	add_child_autofree(panel)
	var font := ThemeDB.fallback_font
	var badge: Rect2 = panel.get_level_badge_rect()
	# get_string_size returns the unconstrained pixel size of the rendered string.
	var size: Vector2 = font.get_string_size(
		"LV.99",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		PartyMemberPanel.BADGE_FONT_SIZE,
	)
	# Allow the same 4 px draw inset that _draw_portrait uses on the label.
	assert_lte(size.x, badge.size.x - 4.0,
		"'LV.99' rendered at BADGE_FONT_SIZE=%d should fit inside the badge minus 4 px inset; size.x=%f badge.size.x=%f" %
			[PartyMemberPanel.BADGE_FONT_SIZE, size.x, badge.size.x])


func test_hp_and_mp_value_text_do_not_overlap_vertically():
	var panel := PartyMemberPanel.new()
	add_child_autofree(panel)
	var hp_bar: Rect2 = panel.get_hp_bar_rect()
	var mp_bar: Rect2 = panel.get_mp_bar_rect()
	# _draw_stat_bar draws the value text with baseline at bar.y + BAR_FONT_SIZE - 1,
	# so its visible bottom edge sits roughly at bar.y + BAR_FONT_SIZE.
	var hp_text_bottom: float = hp_bar.position.y + float(PartyMemberPanel.BAR_FONT_SIZE)
	assert_lte(hp_text_bottom, mp_bar.position.y,
		"HP value text bottom (%f) should not extend into the MP row (%f)" %
			[hp_text_bottom, mp_bar.position.y])


func test_hp_value_text_fits_within_panel_horizontally():
	var panel := PartyMemberPanel.new()
	add_child_autofree(panel)
	var bar: Rect2 = panel.get_hp_bar_rect()
	var font := ThemeDB.fallback_font
	# Worst-case text the panel can be asked to render before clipping kicks in.
	var size: Vector2 = font.get_string_size(
		"999 / 999",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		PartyMemberPanel.BAR_FONT_SIZE,
	)
	var space_after_bar: float = float(PartyMemberPanel.PANEL_WIDTH) - (bar.position.x + bar.size.x) - 4.0
	assert_lte(size.x, space_after_bar,
		"HP/MP value text '999 / 999' at BAR_FONT_SIZE=%d (size.x=%f) should fit between the bar end and the panel's right edge (space=%f)" %
			[PartyMemberPanel.BAR_FONT_SIZE, size.x, space_after_bar])


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
