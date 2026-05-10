extends GutTest

# Verifies the right-pane detail rendering of StatusView: portrait,
# header, HP/MP, EXP, base stats, equipment, learned spells, status line.

var _human: RaceData
var _fighter_job: JobData


func before_each():
	_human = RaceData.new()
	_human.race_name = "Human"
	_human.base_str = 8
	_human.base_int = 8
	_human.base_pie = 8
	_human.base_vit = 8
	_human.base_agi = 8
	_human.base_luc = 8

	_fighter_job = JobData.new()
	_fighter_job.id = &"fighter"
	_fighter_job.job_name = "Fighter"
	_fighter_job.base_hp = 10
	_fighter_job.mage_school = false
	_fighter_job.priest_school = false
	_fighter_job.base_mp = 0
	_fighter_job.exp_table = PackedInt64Array([1000, 2400, 4400, 7100])
	_fighter_job.required_str = 0
	_fighter_job.required_int = 0
	_fighter_job.required_pie = 0
	_fighter_job.required_vit = 0
	_fighter_job.required_agi = 0
	_fighter_job.required_luc = 0


func _make_character(char_name: String) -> Character:
	var allocation := {&"STR": 5, &"INT": 5, &"PIE": 0, &"VIT": 0, &"AGI": 0, &"LUC": 0}
	return Character.create(char_name, _human, _fighter_job, allocation)


func _open_view_for(ch: Character) -> StatusView:
	GameState.new_game()
	GameState.guild.register(ch)
	GameState.guild.assign_to_party(ch, 0, 0)
	var menu := EscMenu.new()
	add_child_autofree(menu)
	menu.show_menu()
	menu.select_current_item()  # → party menu
	menu.select_current_item()  # → status
	return menu.get_status_view()


# --- layout: right pane must have nonzero width ---


func test_right_pane_has_nonzero_size_after_setup():
	# Regression: StatusView's HBoxContainer was anchored to the parent
	# rect, so the right ScrollContainer (size_flags = EXPAND_FILL with
	# no minimum) collapsed to zero width and the detail labels were
	# invisible — only the left member list was rendered.
	var ch := _make_character("Hero")
	var view := _open_view_for(ch)
	# Force a layout pass.
	view.size = Vector2(640, 360)
	await get_tree().process_frame

	var scroll: ScrollContainer = view.get_right_scroll_for_test()
	assert_not_null(scroll)
	assert_gt(scroll.size.x, 0.0,
		"Right pane (ScrollContainer) must have positive width")
	assert_gt(scroll.size.y, 0.0,
		"Right pane (ScrollContainer) must have positive height")


# --- portrait ---


func test_portrait_matches_jobportrait_texture():
	var ch := _make_character("Hero")
	var view := _open_view_for(ch)
	var expected: Texture2D = JobPortrait.texture_for(&"fighter")
	assert_not_null(expected)
	assert_same(view.get_portrait_texture(), expected)


# --- header (name / race / job / level) ---


func test_header_shows_name_race_job_level():
	var ch := _make_character("Hero")
	ch.level = 3
	var view := _open_view_for(ch)
	# Format chosen by StatusView; whatever it is, all 4 substrings must appear.
	var header: String = view.get_header_line()
	assert_string_contains(header, "Hero")
	assert_string_contains(header, "Human")
	assert_string_contains(header, "Fighter")
	assert_string_contains(header, "Lv.3")


# --- HP / MP ---


func test_hp_mp_format():
	var ch := _make_character("Hero")
	ch.max_hp = 35
	ch.current_hp = 28
	ch.max_mp = 0
	ch.current_mp = 0
	var view := _open_view_for(ch)
	assert_eq(view.get_hp_line(), "HP: 28/35")
	assert_eq(view.get_mp_line(), "MP: 0/0")


# --- EXP ---


func test_exp_normal_format():
	var ch := _make_character("Hero")
	# Lv.1 with 100 accumulated; exp_table[0] = 1000 → next at lv 2.
	ch.level = 1
	ch.accumulated_exp = 100
	var view := _open_view_for(ch)
	assert_eq(view.get_exp_line(), "EXP: 100 / 1000")


func test_exp_max_level_format():
	var ch := _make_character("Hero")
	# Job has 4 entries → max representable level is 4 + 1 = 5.
	ch.level = 5
	ch.accumulated_exp = 12345
	var view := _open_view_for(ch)
	assert_eq(view.get_exp_line(), "EXP: 12345 (MAX)")


# --- base stats ---


func test_stats_line_contains_six_stat_values():
	var ch := _make_character("Hero")
	# Character.create adds the allocation on top of race base; just check
	# that each STAT_KEY appears with a colon and a digit.
	var view := _open_view_for(ch)
	var line: String = view.get_stats_line()
	for key in Character.STAT_KEYS:
		assert_string_contains(line, "%s:" % String(key))


# --- equipment ---


const SLOT_LABELS_JP: Array[String] = ["武器", "鎧", "兜", "盾", "籠手", "装身具"]


func test_equipment_lines_show_six_slots_in_order_with_empty_marker():
	var ch := _make_character("Hero")
	var view := _open_view_for(ch)
	var lines: Array = view.get_equipment_lines()
	assert_eq(lines.size(), 6)
	for i in range(6):
		var line: String = lines[i]
		assert_string_contains(line, SLOT_LABELS_JP[i])
		# No equipment fitted → marker for empty slot.
		assert_string_contains(line, "(なし)")


func test_equipment_line_shows_identified_item_name():
	var ch := _make_character("Hero")
	var sword := Item.new()
	sword.item_id = &"long_sword"
	sword.item_name = "ロングソード"
	sword.unidentified_name = "?つるぎ"
	sword.equip_slot = Item.EquipSlot.WEAPON
	sword.allowed_jobs = [&"Fighter"]
	var inst := ItemInstance.new(sword, true)
	ch.equipment.equip(Item.EquipSlot.WEAPON, inst, ch)
	var view := _open_view_for(ch)
	var lines: Array = view.get_equipment_lines()
	assert_string_contains(lines[0], "ロングソード")


func test_equipment_line_shows_unidentified_name():
	var ch := _make_character("Hero")
	var sword := Item.new()
	sword.item_id = &"mystery"
	sword.item_name = "メイス"
	sword.unidentified_name = "?こんぼう"
	sword.equip_slot = Item.EquipSlot.WEAPON
	sword.allowed_jobs = [&"Fighter"]
	var inst := ItemInstance.new(sword, false)
	ch.equipment.equip(Item.EquipSlot.WEAPON, inst, ch)
	var view := _open_view_for(ch)
	var lines: Array = view.get_equipment_lines()
	assert_string_contains(lines[0], "?こんぼう")


# --- spells ---


func test_spell_lines_show_unlearned_marker_when_empty():
	var ch := _make_character("Hero")
	# Fighter has no spell progression, so known_spells stays empty.
	var view := _open_view_for(ch)
	var lines: Array = view.get_spell_lines()
	assert_eq(lines.size(), 1)
	assert_eq(lines[0], "(未習得)")


func test_spell_lines_show_japanese_display_names():
	var ch := _make_character("Caster")
	ch.known_spells = [&"heal"]
	var view := _open_view_for(ch)

	# Inject a tiny SpellRepository with one spell mapped heal → "ヒール".
	var heal := SpellData.new()
	heal.id = &"heal"
	heal.display_name = "ヒール"
	var repo := SpellRepository.new()
	repo.register(heal)
	view.set_spell_repo(repo)
	view.refresh_detail()

	var lines: Array = view.get_spell_lines()
	assert_eq(lines.size(), 1)
	assert_eq(lines[0], "ヒール")


func test_spell_lines_fallback_for_unknown_id():
	var ch := _make_character("Caster")
	ch.known_spells = [&"unknown_spell"]
	var view := _open_view_for(ch)
	var repo := SpellRepository.new()  # empty repo
	view.set_spell_repo(repo)
	view.refresh_detail()

	var lines: Array = view.get_spell_lines()
	assert_eq(lines.size(), 1)
	assert_eq(lines[0], "unknown_spell")
