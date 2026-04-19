extends GutTest

var _formation
var _guild: Guild
var _human: RaceData
var _fighter_job: JobData

func _make_character(char_name: String) -> Character:
	var allocation := {&"STR": 5, &"INT": 0, &"PIE": 0, &"VIT": 0, &"AGI": 0, &"LUC": 0}
	return Character.create(char_name, _human, _fighter_job, allocation)

func before_each():
	_guild = Guild.new()

	_human = RaceData.new()
	_human.race_name = "Human"
	_human.base_str = 8
	_human.base_int = 8
	_human.base_pie = 8
	_human.base_vit = 8
	_human.base_agi = 8
	_human.base_luc = 8

	_fighter_job = JobData.new()
	_fighter_job.job_name = "Fighter"
	_fighter_job.base_hp = 10
	_fighter_job.has_magic = false
	_fighter_job.base_mp = 0
	_fighter_job.required_str = 0
	_fighter_job.required_int = 0
	_fighter_job.required_pie = 0
	_fighter_job.required_vit = 0
	_fighter_job.required_agi = 0
	_fighter_job.required_luc = 0

	_formation = PartyFormation.new()
	_formation.setup(_guild)
	add_child_autofree(_formation)

# --- Signals ---

func test_has_back_requested_signal():
	assert_has_signal(_formation, "back_requested")

# --- Party grid ---

func test_get_party_slots_returns_6():
	var slots = _formation.get_party_slots()
	assert_eq(slots.size(), 6)

func test_empty_party_all_null():
	var slots = _formation.get_party_slots()
	for slot in slots:
		assert_null(slot)

func test_party_slot_shows_assigned_character():
	var ch := _make_character("Hero")
	_guild.register(ch)
	_guild.assign_to_party(ch, 0, 0)
	_formation.refresh()
	var slots = _formation.get_party_slots()
	assert_not_null(slots[0])
	assert_eq(slots[0].character_name, "Hero")

# --- Waiting list ---

func test_get_waiting_characters_empty():
	assert_eq(_formation.get_waiting_characters().size(), 0)

func test_get_waiting_characters_with_unassigned():
	var ch := _make_character("Hero")
	_guild.register(ch)
	_formation.refresh()
	assert_eq(_formation.get_waiting_characters().size(), 1)

# --- Add to party ---

func test_add_character_to_slot():
	var ch := _make_character("Hero")
	_guild.register(ch)
	_formation.refresh()
	_formation.add_to_slot(0, 0, 0)  # row, position, waiting list index
	_formation.refresh()
	var slots = _formation.get_party_slots()
	assert_not_null(slots[0])
	assert_eq(slots[0].character_name, "Hero")
	assert_eq(_formation.get_waiting_characters().size(), 0)

func test_add_to_slot_with_no_waiting_does_nothing():
	_formation.refresh()
	_formation.add_to_slot(0, 0, 0)  # no waiting characters
	_formation.refresh()
	var slots = _formation.get_party_slots()
	assert_null(slots[0])

# --- Remove from party ---

func test_remove_from_slot():
	var ch := _make_character("Hero")
	_guild.register(ch)
	_guild.assign_to_party(ch, 0, 0)
	_formation.refresh()
	_formation.remove_from_slot(0, 0)
	_formation.refresh()
	var slots = _formation.get_party_slots()
	assert_null(slots[0])
	assert_eq(_formation.get_waiting_characters().size(), 1)

# --- Party name ---

func test_default_party_name():
	assert_eq(_formation.get_party_name(), "")

func test_set_party_name():
	_formation.set_party_name("勇者たち")
	assert_eq(_formation.get_party_name(), "勇者たち")

# --- Back ---

# --- Party name persisted in Guild ---

func test_party_name_persists_across_instances():
	_formation.set_party_name("勇者たち")
	# Create a new PartyFormation with the same guild
	var formation2 = PartyFormation.new()
	formation2.setup(_guild)
	add_child_autofree(formation2)
	assert_eq(formation2.get_party_name(), "勇者たち")

# --- Back ---

func test_go_back_emits_signal():
	watch_signals(_formation)
	_formation.go_back()
	assert_signal_emitted(_formation, "back_requested")

# --- Layout centering ---

func _find_center_container(node: Node) -> CenterContainer:
	for child in node.get_children():
		if child is CenterContainer:
			return child as CenterContainer
	return null

func test_uses_center_container_for_layout():
	assert_not_null(_find_center_container(_formation), "PartyFormation should use CenterContainer for centering")

func test_center_container_covers_full_rect():
	var center := _find_center_container(_formation)
	assert_not_null(center)
	assert_eq(center.anchor_right, 1.0, "CenterContainer should span full width")
	assert_eq(center.anchor_bottom, 1.0, "CenterContainer should span full height")

# --- Cursor glyph consistency (▶) ---

func _find_cursor_rows(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is CursorMenuRow:
			out.append(child)
		if child.get_child_count() > 0:
			_find_cursor_rows(child, out)

func _find_grid_slots(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is HBoxContainer and child.has_meta("grid_slot_idx"):
			out.append(child)
		if child.get_child_count() > 0:
			_find_grid_slots(child, out)

func test_waiting_list_uses_cursor_menu_row():
	var ch1 := _make_character("A")
	var ch2 := _make_character("B")
	_guild.register(ch1)
	_guild.register(ch2)
	_formation.refresh()
	_formation._rebuild_display()
	var rows: Array = []
	_find_cursor_rows(_formation, rows)
	assert_true(rows.size() >= 2, "waiting list should render each character as a CursorMenuRow (found %d)" % rows.size())

func test_waiting_row_text_excludes_cursor_glyph():
	var ch := _make_character("Hero")
	_guild.register(ch)
	_formation.refresh()
	# Switch to waiting mode so the first waiting entry is "selected"
	_formation._mode = 1
	_formation._wait_index = 0
	_formation._rebuild_display()
	var rows: Array = []
	_find_cursor_rows(_formation, rows)
	assert_gt(rows.size(), 0, "at least one CursorMenuRow should exist for the waiting list")
	for r in rows:
		var row: CursorMenuRow = r
		var text := row.get_text_label().text
		assert_false(text.contains("▶"), "waiting row text should not embed the cursor glyph: '%s'" % text)

func test_selected_waiting_row_is_marked_selected():
	var ch1 := _make_character("A")
	var ch2 := _make_character("B")
	_guild.register(ch1)
	_guild.register(ch2)
	_formation.refresh()
	_formation._mode = 1
	_formation._wait_index = 1
	_formation._rebuild_display()
	var rows: Array = []
	_find_cursor_rows(_formation, rows)
	# Find the two waiting rows (there may be none from the grid since grid uses labels)
	assert_eq(rows.size(), 2, "expected exactly 2 CursorMenuRow entries for 2 waiting characters")
	assert_false((rows[0] as CursorMenuRow).is_selected(), "first waiting row should not be selected")
	assert_true((rows[1] as CursorMenuRow).is_selected(), "second waiting row should be selected (wait_index=1)")

func test_grid_renders_six_slots():
	_formation._mode = 0
	_formation._grid_index = 0
	_formation._rebuild_display()
	var slots: Array = []
	_find_grid_slots(_formation, slots)
	assert_eq(slots.size(), 6, "grid should render 6 slots (2 rows x 3 positions)")

func test_grid_slots_have_fixed_width_cursor_column():
	_formation._mode = 0
	_formation._grid_index = 0
	_formation._rebuild_display()
	var slots: Array = []
	_find_grid_slots(_formation, slots)
	assert_eq(slots.size(), 6)
	var widths: Array = []
	for slot in slots:
		var cursor_slot: Control = slot.get_meta("cursor_slot")
		widths.append(cursor_slot.custom_minimum_size.x)
	for w in widths:
		assert_eq(w, widths[0], "all grid slots should share the same cursor column width (got %s)" % str(widths))
	assert_gt(widths[0], 0.0, "cursor column width should be non-zero")

func test_grid_selected_slot_shows_cursor_glyph():
	_formation._mode = 0
	_formation._grid_index = 2
	_formation._rebuild_display()
	var slots: Array = []
	_find_grid_slots(_formation, slots)
	for i in range(slots.size()):
		var cursor_label: Label = slots[i].get_meta("cursor_label")
		if i == 2:
			assert_true(cursor_label.visible, "slot %d should show cursor glyph" % i)
			assert_eq(cursor_label.text, CursorMenuRow.CURSOR_GLYPH, "cursor label should display ▶ glyph")
		else:
			assert_false(cursor_label.visible, "slot %d should not show cursor glyph" % i)

func test_grid_no_cursor_visible_when_in_waiting_mode():
	_formation._mode = 1
	_formation._grid_index = 0
	_formation._rebuild_display()
	var slots: Array = []
	_find_grid_slots(_formation, slots)
	for i in range(slots.size()):
		var cursor_label: Label = slots[i].get_meta("cursor_label")
		assert_false(cursor_label.visible, "no grid slot should show cursor when mode is waiting-list")
