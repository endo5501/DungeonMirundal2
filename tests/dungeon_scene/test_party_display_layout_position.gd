extends GutTest

# After layout, PartyDisplay must set each panel's _layout_position to its
# current position so shake/lift Tweens can snap back to a known anchor
# even after the previous Tween was killed mid-flight.


const TEST_WIDTH := 1600.0


func _make_display(width: float = TEST_WIDTH) -> PartyDisplay:
	var d := PartyDisplay.new()
	add_child_autofree(d)
	d._layout_panels(width)
	return d


func test_each_front_panel_layout_position_matches_current_position():
	var d := _make_display()
	for i in range(3):
		var panel: PartyMemberPanel = d._front_panels[i]
		assert_eq(panel._layout_position, panel.position,
			"front panel %d _layout_position must mirror position" % i)


func test_each_back_panel_layout_position_matches_current_position():
	var d := _make_display()
	for i in range(3):
		var panel: PartyMemberPanel = d._back_panels[i]
		assert_eq(panel._layout_position, panel.position,
			"back panel %d _layout_position must mirror position" % i)


func test_layout_position_updates_on_resize():
	var d := _make_display(1600.0)
	d._layout_panels(1280.0)
	for i in range(3):
		var p: PartyMemberPanel = d._back_panels[i]
		assert_eq(p._layout_position, p.position,
			"back panel %d _layout_position must follow re-layout" % i)
