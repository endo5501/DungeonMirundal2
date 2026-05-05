extends GutTest

# Verifies the enlarged size constants on PartyMemberPanel.


func test_panel_width_is_180():
	assert_eq(PartyMemberPanel.PANEL_WIDTH, 180,
		"PANEL_WIDTH should remain 180 in this change")


func test_panel_height_at_least_100():
	assert_true(PartyMemberPanel.PANEL_HEIGHT >= 100,
		"PANEL_HEIGHT should be >= 100 to fit enlarged font; got %d" % PartyMemberPanel.PANEL_HEIGHT)


func test_font_size_at_least_20():
	assert_true(PartyMemberPanel.FONT_SIZE >= 20,
		"FONT_SIZE should be >= 20; got %d" % PartyMemberPanel.FONT_SIZE)
