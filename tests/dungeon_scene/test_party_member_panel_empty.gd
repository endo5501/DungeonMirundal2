extends GutTest

# has_visible_content() mirrors _draw()'s early-return branch so we can verify
# "renders nothing" without invoking the live draw context.

const TEST_WIDTH := 1600.0


func _make_character(name: String, hp: int) -> Character:
	var ch := Character.new()
	ch.character_name = name
	ch.level = 1
	ch.max_hp = hp
	ch.current_hp = hp
	ch.max_mp = 0
	ch.current_mp = 0
	return ch


func _make_panel() -> PartyMemberPanel:
	var p := PartyMemberPanel.new()
	add_child_autofree(p)
	return p


func _make_display() -> PartyDisplay:
	var d := PartyDisplay.new()
	add_child_autofree(d)
	d._layout_panels(TEST_WIDTH)
	return d


func test_empty_panel_reports_no_visible_content():
	var p := _make_panel()
	# Default state: no bind_character, no set_member.
	assert_null(p._data, "panel _data should start null")
	assert_null(p._character, "panel _character should start null")
	assert_false(p.has_visible_content(),
		"empty panel must report no visible content (early return)")


func test_panel_with_bound_character_has_visible_content():
	var p := _make_panel()
	p.bind_character(_make_character("Hero", 10))
	assert_true(p.has_visible_content(),
		"panel bound to a Character should report visible content")


func test_panel_unbound_to_null_loses_visible_content():
	var p := _make_panel()
	p.bind_character(_make_character("Hero", 10))
	p.bind_character(null)
	assert_false(p.has_visible_content(),
		"panel unbound (bind_character(null)) should report no visible content")


func test_null_middle_slot_does_not_pack_third_panel_left():
	var d := _make_display()
	var a := _make_character("Alice", 10)
	var b := _make_character("Bob", 12)
	d.bind_party_characters([a, null, b], [null, null, null])
	# F2 stays in its third slot regardless of F1 being null.
	var f0_x: float = d._front_panels[0].position.x
	var f2_x: float = d._front_panels[2].position.x
	var step: float = float(PartyMemberPanel.PANEL_WIDTH + PartyDisplay.MARGIN)
	assert_eq(f2_x - f0_x, step * 2.0,
		"F2 should be two slot-widths away from F0; null F1 must not shift F2 left")
	assert_false(d._front_panels[1].has_visible_content(),
		"F1 (null) should report no visible content")
	assert_true(d._front_panels[2].has_visible_content(),
		"F2 (Bob) should have visible content")
