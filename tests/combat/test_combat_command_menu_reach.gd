extends GutTest


var _loader: DataLoader
var _human: RaceData
var _fighter_job: JobData
var _mage_job: JobData


func before_each():
	_loader = DataLoader.new()
	for race in _loader.load_all_races():
		if race.race_name == "Human":
			_human = race
	for job in _loader.load_all_jobs():
		if job.job_name == "Fighter":
			_fighter_job = job
		elif job.job_name == "Mage":
			_mage_job = job


func _make_character(name: String, job: JobData) -> Character:
	var ch := Character.new()
	ch.character_name = name
	ch.race = _human
	ch.job = job
	ch.level = 1
	ch.base_stats = {&"STR": 14, &"INT": 12, &"PIE": 12, &"VIT": 12, &"AGI": 10, &"LUC": 10}
	ch.max_hp = 30
	ch.current_hp = 30
	return ch


func _make_menu() -> CombatCommandMenu:
	var menu := CombatCommandMenu.new()
	add_child_autofree(menu)
	return menu


func _attack_index(menu: CombatCommandMenu) -> int:
	return menu.get_option_ids().find(CombatCommandMenu.OPT_ATTACK)


func test_attack_row_enabled_when_reachable_default():
	var menu := _make_menu()
	var pc := PartyCombatant.new(_make_character("F", _fighter_job), DummyEquipmentProvider.new(), Row.FRONT)
	menu.show_for(pc)  # default attack_reachable = true
	var idx := _attack_index(menu)
	assert_false(menu.is_row_disabled(idx))


func test_attack_row_disabled_when_not_reachable():
	var menu := _make_menu()
	var pc := PartyCombatant.new(_make_character("M", _mage_job), DummyEquipmentProvider.new(), Row.BACK)
	menu.show_for(pc, false)
	var idx := _attack_index(menu)
	assert_true(menu.is_row_disabled(idx))


func test_attack_label_includes_unreachable_suffix_when_disabled():
	var menu := _make_menu()
	var pc := PartyCombatant.new(_make_character("M", _mage_job), DummyEquipmentProvider.new(), Row.BACK)
	menu.show_for(pc, false)
	var idx := _attack_index(menu)
	var labels := menu.get_options()
	assert_string_contains(labels[idx], "届かない")


func test_disabled_attack_does_not_emit_command_selected():
	var menu := _make_menu()
	var pc := PartyCombatant.new(_make_character("M", _mage_job), DummyEquipmentProvider.new(), Row.BACK)
	menu.show_for(pc, false)
	var idx := _attack_index(menu)
	# Move cursor to the attack row
	for i in range(idx):
		menu.move_down()
	watch_signals(menu)
	menu.confirm_current()
	assert_signal_not_emitted(menu, "command_selected")


func test_attack_row_position_preserved_when_disabled():
	# When Attack is disabled, the row stays at index 0 (it doesn't get omitted
	# like the magic-school omission pattern).
	var menu := _make_menu()
	var pc := PartyCombatant.new(_make_character("M", _mage_job), DummyEquipmentProvider.new(), Row.BACK)
	menu.show_for(pc, false)
	var ids := menu.get_option_ids()
	assert_eq(ids[0], CombatCommandMenu.OPT_ATTACK, "Attack should remain at index 0 even when disabled")
