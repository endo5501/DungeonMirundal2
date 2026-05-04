extends GutTest


# Drives the CombatCommandMenu directly with synthetic actors to assert that
# silence (any status with blocks_cast=true) disables the Cast row and that
# Enter on a disabled row does not advance.

const _PROVIDER_PATH := "res://src/combat/dummy_equipment_provider.gd"
const _SLEEP_PATH := "res://data/statuses/sleep.tres"
const _SILENCE_PATH := "res://data/statuses/silence.tres"


func _load_status(path: String) -> StatusData:
	return load(path) as StatusData


func _make_repo_with_real_statuses() -> StatusRepository:
	var repo := StatusRepository.new()
	repo.register(_load_status(_SLEEP_PATH))
	repo.register(_load_status(_SILENCE_PATH))
	return repo


func _make_human() -> RaceData:
	return load("res://data/races/human.tres") as RaceData


func _make_mage_character() -> Character:
	var ch := Character.new()
	ch.character_name = "Alice"
	ch.race = _make_human()
	ch.job = load("res://data/jobs/mage.tres") as JobData
	ch.level = 1
	ch.base_stats = {&"STR": 8, &"INT": 12, &"PIE": 8, &"VIT": 8, &"AGI": 8, &"LUC": 8}
	ch.max_hp = 10
	ch.current_hp = 10
	ch.max_mp = 5
	ch.current_mp = 5
	return ch


func _attach(menu: CombatCommandMenu) -> CombatCommandMenu:
	add_child_autofree(menu)
	return menu


func test_silenced_mage_has_cast_row_disabled():
	var menu := _attach(CombatCommandMenu.new())
	var ch := _make_mage_character()
	var actor := PartyCombatant.new(ch, DummyEquipmentProvider.new())
	actor.set_status_repo_for_testing(_make_repo_with_real_statuses())
	actor.statuses.apply(&"silence", 4)
	assert_true(actor.has_silence_flag(), "fixture sanity: actor should be silenced")

	menu.show_for(actor)
	var cast_idx := menu.get_option_ids().find(CombatCommandMenu.OPT_CAST_MAGE)
	assert_gte(cast_idx, 0, "Mage menu should have a Cast row")
	assert_true(menu.is_row_disabled(cast_idx), "Cast row should be disabled when silenced")
	# Other rows remain selectable.
	for opt in [CombatCommandMenu.OPT_ATTACK, CombatCommandMenu.OPT_DEFEND,
				CombatCommandMenu.OPT_ITEM, CombatCommandMenu.OPT_ESCAPE]:
		var idx := menu.get_option_ids().find(opt)
		assert_gte(idx, 0)
		assert_false(menu.is_row_disabled(idx),
			"row %d (%s) should remain enabled" % [opt, CombatCommandMenu.OPTION_LABELS[opt]])


func test_disabled_cast_row_does_not_emit_command_selected():
	var menu := _attach(CombatCommandMenu.new())
	var ch := _make_mage_character()
	var actor := PartyCombatant.new(ch, DummyEquipmentProvider.new())
	actor.set_status_repo_for_testing(_make_repo_with_real_statuses())
	actor.statuses.apply(&"silence", 4)
	menu.show_for(actor)
	var cast_idx := menu.get_option_ids().find(CombatCommandMenu.OPT_CAST_MAGE)
	# Move cursor onto Cast row.
	while menu.get_selected_index() != cast_idx:
		menu.move_down()
	watch_signals(menu)
	menu.confirm_current()
	assert_signal_not_emitted(menu, "command_selected",
		"silenced Cast row should swallow the Enter press")


func test_unsilenced_mage_has_cast_row_enabled():
	var menu := _attach(CombatCommandMenu.new())
	var ch := _make_mage_character()
	var actor := PartyCombatant.new(ch, DummyEquipmentProvider.new())
	actor.set_status_repo_for_testing(_make_repo_with_real_statuses())
	# No silence applied.
	menu.show_for(actor)
	var cast_idx := menu.get_option_ids().find(CombatCommandMenu.OPT_CAST_MAGE)
	assert_gte(cast_idx, 0)
	assert_false(menu.is_row_disabled(cast_idx),
		"un-silenced Mage's Cast row must stay enabled")


func test_silenced_cast_label_includes_suffix():
	var menu := _attach(CombatCommandMenu.new())
	var ch := _make_mage_character()
	var actor := PartyCombatant.new(ch, DummyEquipmentProvider.new())
	actor.set_status_repo_for_testing(_make_repo_with_real_statuses())
	actor.statuses.apply(&"silence", 4)
	menu.show_for(actor)
	var labels := menu.get_options()
	var cast_idx := menu.get_option_ids().find(CombatCommandMenu.OPT_CAST_MAGE)
	assert_true(labels[cast_idx].contains("沈黙"),
		"silenced Cast row label should contain 沈黙: %s" % labels[cast_idx])
