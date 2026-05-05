extends GutTest

# Verifies PartyMemberPanel resolves persistent_statuses on its bound
# Character into a list of status icons (color + short label) consumed by
# _draw(). When the panel is in PartyMemberData snapshot mode, no icons
# are produced.


func _make_character(p_name: String, statuses: Array[StringName] = []) -> Character:
	var ch := Character.new()
	ch.character_name = p_name
	ch.level = 1
	ch.max_hp = 10
	ch.current_hp = 10
	ch.max_mp = 0
	ch.current_mp = 0
	ch.persistent_statuses = statuses
	return ch


func _make_panel() -> PartyMemberPanel:
	var p := PartyMemberPanel.new()
	add_child_autofree(p)
	return p


# --- Single status ---

func test_single_status_yields_one_icon():
	var ch := _make_character("Alice", [&"poison"])
	var panel := _make_panel()
	panel.bind_character(ch)
	var icons: Array = panel.get_status_icons()
	assert_eq(icons.size(), 1, "single persistent status should yield one icon")
	assert_eq(icons[0]["id"], &"poison")
	# poison color per design.md D5: purple Color(0.6, 0.2, 0.7).
	assert_almost_eq(icons[0]["color"].r, 0.6, 0.001)
	assert_almost_eq(icons[0]["color"].g, 0.2, 0.001)
	assert_almost_eq(icons[0]["color"].b, 0.7, 0.001)
	assert_true(icons[0]["label"] is String)
	assert_true(icons[0]["label"].length() >= 1 and icons[0]["label"].length() <= 2,
		"icon label should be 1-2 characters")


# --- Multiple statuses ---

func test_multiple_statuses_yield_one_icon_each():
	var ch := _make_character("Bob", [&"poison", &"blind", &"sleep"])
	var panel := _make_panel()
	panel.bind_character(ch)
	var icons: Array = panel.get_status_icons()
	assert_eq(icons.size(), 3)
	var ids: Array = []
	for icon in icons:
		ids.append(icon["id"])
	assert_eq(ids, [&"poison", &"blind", &"sleep"])


# --- Empty statuses ---

func test_no_statuses_yield_zero_icons():
	var ch := _make_character("Carol", [])
	var panel := _make_panel()
	panel.bind_character(ch)
	assert_eq(panel.get_status_icons().size(), 0)


# --- statuses_changed updates icon list ---

func test_status_icons_update_when_statuses_change():
	var ch := _make_character("Dave", [])
	var panel := _make_panel()
	panel.bind_character(ch)
	assert_eq(panel.get_status_icons().size(), 0)
	ch.persistent_statuses = [&"sleep"]
	var icons: Array = panel.get_status_icons()
	assert_eq(icons.size(), 1)
	assert_eq(icons[0]["id"], &"sleep")


# --- PartyMemberData snapshot path: no icons ---

func test_snapshot_mode_yields_no_icons():
	var data := PartyMemberData.new("Snap", 1, 5, 10, 0, 0)
	var panel := _make_panel()
	panel.set_member(data)
	assert_eq(panel.get_status_icons().size(), 0,
		"PartyMemberData snapshot path should not produce status icons")


# --- All seven status colors are mapped ---

func test_all_seven_status_ids_have_color_mappings():
	var all_ids: Array[StringName] = [
		&"poison", &"blind", &"sleep", &"paralysis",
		&"petrify", &"confusion", &"silence",
	]
	var ch := _make_character("Multi", all_ids)
	var panel := _make_panel()
	panel.bind_character(ch)
	var icons: Array = panel.get_status_icons()
	assert_eq(icons.size(), 7)
	for icon in icons:
		# Color must not equal the panel's BG color; that would mean an
		# unmapped status fell through to a default.
		assert_false(icon["color"] == PartyMemberPanel.BG_COLOR,
			"status %s should have a distinct color mapping" % icon["id"])
		assert_true(icon["label"].length() >= 1)


# --- Smoke: _draw() runs without errors when statuses are present ---

func test_draw_runs_with_statuses():
	var ch := _make_character("Drawer", [&"poison", &"sleep"])
	var panel := _make_panel()
	panel.bind_character(ch)
	# Forcing a redraw exercises the icon-drawing branch. We assert the
	# panel is still alive and has the expected data afterwards rather
	# than inspecting the rendered pixels.
	panel.queue_redraw()
	await get_tree().process_frame
	assert_eq(panel.get_status_icons().size(), 2)
