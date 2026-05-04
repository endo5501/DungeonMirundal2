extends GutTest

const TEST_SEED: int = 12345


var _loader: DataLoader
var _guild: Guild
var _provider: DummyEquipmentProvider


func before_each():
	_loader = DataLoader.new()
	_provider = DummyEquipmentProvider.new()
	_guild = _make_guild_with_party()


func _make_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = TEST_SEED
	return rng


func _make_monster_data(id: StringName, display_name: String, atk: int = 3, def: int = 1, agi: int = 4) -> MonsterData:
	var data := MonsterData.new()
	data.monster_id = id
	data.monster_name = display_name
	data.max_hp_min = 8
	data.max_hp_max = 8
	data.attack = atk
	data.defense = def
	data.agility = agi
	data.experience = 40
	return data


func _make_monster_party(species_counts: Dictionary) -> MonsterParty:
	var party := MonsterParty.new()
	for id in species_counts.keys():
		var display_name := String(id).capitalize()
		var data := _make_monster_data(id, display_name)
		for i in range(species_counts[id]):
			party.add(Monster.new(data, _make_rng()))
	return party


func _make_character(name: String, job_name: String) -> Character:
	var human: RaceData
	for r in _loader.load_all_races():
		if r.race_name == "Human":
			human = r
	var job: JobData
	for j in _loader.load_all_jobs():
		if j.job_name == job_name:
			job = j
	var ch := Character.new()
	ch.character_name = name
	ch.race = human
	ch.job = job
	ch.level = 1
	ch.base_stats = {&"STR": 14, &"INT": 12, &"PIE": 10, &"VIT": 12, &"AGI": 10, &"LUC": 10}
	ch.max_hp = 20
	ch.current_hp = 20
	ch.max_mp = 0
	ch.current_mp = 0
	return ch


func _make_potion() -> Item:
	var it := Item.new()
	it.item_id = &"potion"
	it.item_name = "Potion"
	it.category = Item.ItemCategory.CONSUMABLE
	it.equip_slot = Item.EquipSlot.NONE
	var e := HealHpEffect.new()
	e.power = 5
	it.effect = e
	var tc: Array[TargetCondition] = [AliveOnly.new()]
	it.target_conditions = tc
	return it


func _make_wounded_only_potion() -> Item:
	var it := _make_potion()
	var tc: Array[TargetCondition] = [AliveOnly.new(), NotFullHp.new()]
	it.target_conditions = tc
	return it


func _make_leather_armor() -> Item:
	var it := Item.new()
	it.item_id = &"leather_armor"
	it.item_name = "Leather Armor"
	it.category = Item.ItemCategory.ARMOR
	it.equip_slot = Item.EquipSlot.ARMOR
	return it


func _make_guild_with_party() -> Guild:
	var g := Guild.new()
	var c1 := _make_character("P1", "Fighter")
	var c2 := _make_character("P2", "Mage")
	g.register(c1)
	g.register(c2)
	g.assign_to_party(c1, 0, 0)  # front row 0
	g.assign_to_party(c2, 1, 0)  # back row 0
	return g


func _make_guild_solo(job_name: String, char_name: String = "Caster") -> Guild:
	var g := Guild.new()
	var c := _make_character(char_name, job_name)
	g.register(c)
	g.assign_to_party(c, 0, 0)
	return g


func _set_initial_mp(g: Guild, current_mp: int, max_mp: int = -1) -> void:
	for ch in g.get_all_characters():
		ch.max_mp = max_mp if max_mp > 0 else current_mp
		ch.current_mp = current_mp


# --- structural ---

func test_combat_overlay_is_encounter_overlay():
	var overlay := CombatOverlay.new()
	assert_is(overlay, EncounterOverlay)
	overlay.free()


func test_combat_overlay_is_canvas_layer():
	var overlay := CombatOverlay.new()
	assert_is(overlay, CanvasLayer)
	overlay.free()


func test_combat_overlay_layer_matches_encounter_overlay():
	var overlay := CombatOverlay.new()
	assert_eq(overlay.layer, 10)
	overlay.free()


func test_combat_overlay_initially_hidden():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	assert_false(overlay.visible)


# --- setup_dependencies + start_encounter ---

func test_start_encounter_makes_overlay_visible():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 2}))
	assert_true(overlay.visible)


func test_start_encounter_activates_overlay():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 2}))
	assert_true(overlay.is_active())


func test_start_encounter_initializes_turn_engine_in_command_input():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 2, &"goblin": 1}))
	var engine: TurnEngine = overlay.get_turn_engine()
	assert_not_null(engine)
	assert_eq(engine.state, TurnEngine.State.COMMAND_INPUT)


func test_turn_engine_is_seeded_with_party_and_monsters():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 2, &"goblin": 1}))
	var engine: TurnEngine = overlay.get_turn_engine()
	assert_eq(engine.party.size(), 2)  # two party members assigned
	assert_eq(engine.monsters.size(), 3)  # 2 slimes + 1 goblin


# --- MonsterPanel content ---

func test_monster_panel_shows_species_names_and_counts():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 2, &"goblin": 1}))
	var text := overlay.get_monster_panel_text()
	assert_true(text.contains("Slime"), "text should contain Slime: %s" % text)
	assert_true(text.contains("Goblin"), "text should contain Goblin: %s" % text)
	assert_true(text.contains("2"), "text should mention count 2: %s" % text)


func test_monster_panel_reflects_killed_monster():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 2}))
	# Kill one slime
	overlay.get_turn_engine().monsters[0].take_damage(100)
	overlay.refresh_monster_panel()
	var text := overlay.get_monster_panel_text()
	# Two initial, one alive → count should be 1
	assert_true(text.contains("1"), "text should show remaining count: %s" % text)


func test_monster_panel_does_not_show_per_individual_hp():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	var text := overlay.get_monster_panel_text()
	# Individual HP is "current/max" like "8/8". Panel shouldn't show that.
	assert_false(text.contains("8/8"), "text should not show individual HP: %s" % text)


# --- party_state_changed signal (replaces PartyStatusPanel; dungeon UI refreshes instead) ---

func test_start_encounter_emits_party_state_changed():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	watch_signals(overlay)
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	assert_signal_emitted(overlay, "party_state_changed")


# --- combat log reset on new encounter ---

func test_combat_log_clears_on_new_encounter():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	overlay.get_combat_log().append_line("Previous-battle noise")
	assert_gte(overlay.get_combat_log_lines().size(), 1)
	# New encounter must start with an empty log.
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	assert_eq(overlay.get_combat_log_lines().size(), 0)


# --- Command phase routing ---

func test_start_encounter_begins_with_command_menu_phase():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	assert_eq(overlay.get_current_phase(), CombatOverlay.Phase.COMMAND_MENU)


func test_current_command_actor_is_first_living_party_member():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	var current: CombatActor = overlay.get_current_command_actor()
	assert_not_null(current)
	assert_eq(current.actor_name, "P1")


func test_dead_party_member_is_skipped_in_command_input():
	# Kill P1 before starting
	var chars: Array = _guild.get_all_characters()
	chars[0].current_hp = 0
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	var current: CombatActor = overlay.get_current_command_actor()
	assert_eq(current.actor_name, "P2")


func test_command_menu_has_four_options():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	var options := overlay.get_command_menu_options()
	assert_eq(options.size(), 4)
	assert_true("こうげき" in options)
	assert_true("ぼうぎょ" in options)
	assert_true("アイテム" in options)
	assert_true("にげる" in options)


# --- add-magic-system: command menu omits/inserts magic entries by job ---

func test_command_menu_for_fighter_omits_magic_entries():
	# Default _guild has Fighter at index 0, so this also covers the no-magic case.
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	var options := overlay.get_command_menu_options()
	assert_false("魔術" in options, "fighter menu should not include 魔術")
	assert_false("祈り" in options, "fighter menu should not include 祈り")


func test_command_menu_for_mage_includes_only_magic():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_make_guild_solo("Mage"), _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	var options := overlay.get_command_menu_options()
	assert_true("魔術" in options, "mage menu should include 魔術: %s" % str(options))
	assert_false("祈り" in options, "mage menu should not include 祈り")
	assert_eq(options.size(), 5)


func test_command_menu_for_priest_includes_only_priest():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_make_guild_solo("Priest"), _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	var options := overlay.get_command_menu_options()
	assert_false("魔術" in options, "priest menu should not include 魔術")
	assert_true("祈り" in options, "priest menu should include 祈り")
	assert_eq(options.size(), 5)


func test_command_menu_for_bishop_includes_both_schools():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_make_guild_solo("Bishop"), _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	var options := overlay.get_command_menu_options()
	assert_true("魔術" in options, "bishop menu should include 魔術")
	assert_true("祈り" in options, "bishop menu should include 祈り")
	# Order: 攻撃, 防御, 魔術, 祈り, アイテム, 逃げる
	assert_eq(options[0], "こうげき")
	assert_eq(options[1], "ぼうぎょ")
	assert_eq(options[2], "魔術")
	assert_eq(options[3], "祈り")
	assert_eq(options[4], "アイテム")
	assert_eq(options[5], "にげる")


# --- add-magic-system: spell-cast smoke ---

func test_mage_cast_fire_damages_slime():
	var g := _make_guild_solo("Mage")
	# Pre-populate the lone Mage's known_spells and MP so the cast can resolve.
	for ch in g.get_all_characters():
		ch.known_spells = [&"fire"] as Array[StringName]
		ch.max_mp = 10
		ch.current_mp = 10
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(g, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	var slime: CombatActor = overlay.get_turn_engine().monsters[0]
	var slime_hp_before := slime.current_hp

	# Drive: 魔術 → ファイア → スライム
	overlay.command_menu_select(CombatCommandMenu.OPT_CAST_MAGE)
	assert_eq(overlay.get_current_phase(), CombatOverlay.Phase.SPELL_SELECT)
	overlay.get_spell_selector().confirm_current()
	assert_eq(overlay.get_current_phase(), CombatOverlay.Phase.SPELL_TARGET)
	overlay.target_select(0)

	# After resolution the mage's MP is consumed and the slime took damage.
	# (Slime may have died, but it must have lost HP regardless.)
	assert_lt(slime.current_hp, slime_hp_before, "slime should have taken cast damage")
	for ch in g.get_all_characters():
		assert_lt(ch.current_mp, 10, "mage MP should be consumed by the cast")


func test_spell_target_cancel_returns_to_spell_selector():
	var g := _make_guild_solo("Mage")
	for ch in g.get_all_characters():
		ch.known_spells = [&"fire"] as Array[StringName]
		ch.max_mp = 10
		ch.current_mp = 10
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(g, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	# 魔術 → ファイア → SPELL_TARGET
	overlay.command_menu_select(CombatCommandMenu.OPT_CAST_MAGE)
	overlay.get_spell_selector().confirm_current()
	assert_eq(overlay.get_current_phase(), CombatOverlay.Phase.SPELL_TARGET)
	# Back input emitted via the input router routes to request_cancel().
	overlay._unhandled_input(TestHelpers.make_action_event(&"ui_cancel"))
	assert_eq(overlay.get_current_phase(), CombatOverlay.Phase.SPELL_SELECT)
	# MP not consumed.
	for ch in g.get_all_characters():
		assert_eq(ch.current_mp, 10)


func test_spell_select_cancel_returns_to_command_menu():
	var g := _make_guild_solo("Mage")
	for ch in g.get_all_characters():
		ch.known_spells = [&"fire"] as Array[StringName]
		ch.max_mp = 10
		ch.current_mp = 10
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(g, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	overlay.command_menu_select(CombatCommandMenu.OPT_CAST_MAGE)
	assert_eq(overlay.get_current_phase(), CombatOverlay.Phase.SPELL_SELECT)
	overlay._unhandled_input(TestHelpers.make_action_event(&"ui_cancel"))
	assert_eq(overlay.get_current_phase(), CombatOverlay.Phase.COMMAND_MENU)


func test_attack_selection_advances_to_target_select_phase():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	overlay.command_menu_select(0)  # こうげき
	assert_eq(overlay.get_current_phase(), CombatOverlay.Phase.TARGET_SELECT)


func test_defend_selection_advances_to_next_actor():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	overlay.command_menu_select(1)  # ぼうぎょ
	# Still COMMAND_MENU, but on P2 now (since monster is alive, not yet resolved)
	assert_eq(overlay.get_current_phase(), CombatOverlay.Phase.COMMAND_MENU)
	var current: CombatActor = overlay.get_current_command_actor()
	assert_eq(current.actor_name, "P2")


func test_item_command_shows_item_use_flow():
	GameState.inventory = Inventory.new()
	GameState.inventory.add(ItemInstance.new(_make_potion(), true))
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	overlay.command_menu_select(CombatCommandMenu.OPT_ITEM)
	assert_eq(overlay.get_current_phase(), CombatOverlay.Phase.ITEM_SELECT)
	assert_true(overlay._item_use_panel.visible)
	assert_true(overlay.get_item_use_flow().visible)


func test_item_command_hides_non_consumable_items():
	GameState.inventory = Inventory.new()
	GameState.inventory.add(ItemInstance.new(_make_leather_armor(), true))
	GameState.inventory.add(ItemInstance.new(_make_potion(), true))
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	overlay.command_menu_select(CombatCommandMenu.OPT_ITEM)
	var items := overlay.get_item_use_flow()._list_items()
	assert_eq(items.size(), 1)
	assert_eq(items[0].item.item_name, "Potion")


func test_item_target_selection_lists_only_valid_targets_in_combat():
	GameState.inventory = Inventory.new()
	GameState.inventory.add(ItemInstance.new(_make_wounded_only_potion(), true))
	var chars: Array = _guild.get_all_characters()
	chars[0].current_hp = 10
	chars[1].current_hp = chars[1].max_hp
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	overlay.command_menu_select(CombatCommandMenu.OPT_ITEM)
	overlay.get_item_use_flow().handle_input(TestHelpers.make_action_event(&"ui_accept"))
	var targets := overlay.get_item_use_flow()._list_targets()
	assert_eq(targets.size(), 1)
	assert_eq(targets[0].character_name, "P1")


func test_item_use_flow_cancel_returns_to_command_menu():
	GameState.inventory = Inventory.new()
	GameState.inventory.add(ItemInstance.new(_make_potion(), true))
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	overlay.command_menu_select(CombatCommandMenu.OPT_ITEM)
	overlay.get_item_use_flow().flow_completed.emit("")
	assert_eq(overlay.get_current_phase(), CombatOverlay.Phase.COMMAND_MENU)
	assert_false(overlay.get_item_use_flow().visible)
	assert_eq(overlay.get_current_command_actor().actor_name, "P1")


func test_item_use_flow_selection_queues_command_and_advances_to_next_actor():
	GameState.inventory = Inventory.new()
	var potion_inst := ItemInstance.new(_make_potion(), true)
	GameState.inventory.add(potion_inst)
	var chars: Array = _guild.get_all_characters()
	chars[0].current_hp = 10
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	overlay.command_menu_select(CombatCommandMenu.OPT_ITEM)
	overlay.get_item_use_flow().handle_input(TestHelpers.make_action_event(&"ui_accept"))
	overlay.get_item_use_flow().handle_input(TestHelpers.make_action_event(&"ui_accept"))
	overlay.get_item_use_flow().handle_input(TestHelpers.make_action_event(&"ui_accept"))
	assert_eq(overlay.get_current_phase(), CombatOverlay.Phase.COMMAND_MENU)
	assert_false(overlay.get_item_use_flow().visible)
	assert_eq(overlay.get_current_command_actor().actor_name, "P2")
	assert_eq(chars[0].current_hp, 10)
	assert_true(GameState.inventory.contains(potion_inst))


func test_target_select_then_remaining_defend_triggers_resolution():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1, &"goblin": 1}))
	overlay.command_menu_select(0)  # P1 attack
	overlay.target_select(0)  # target first monster
	overlay.command_menu_select(1)  # P2 defend
	# After all commands, TurnEngine should have resolved at least one turn
	assert_gte(overlay.get_turn_engine().turn_number, 2,
		"turn_number should advance after resolution")


# --- CombatLog ---

func test_combat_log_initially_empty():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	var lines := overlay.get_combat_log_lines()
	assert_eq(lines.size(), 0)


func test_combat_log_retains_recent_lines_after_many_appends():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	for i in range(10):
		overlay.get_combat_log().append_line("L%d" % i)
	var lines := overlay.get_combat_log_lines()
	# Should keep at least 4, last one should be L9
	assert_gte(lines.size(), 4)
	assert_eq(lines[lines.size() - 1], "L9")


func test_combat_log_formats_attack_action():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	var report := TurnReport.new()
	var log := overlay.get_combat_log()
	log.append_from_report_action({
		"type": "attack",
		"attacker_name": "P1",
		"target_name": "スライム",
		"damage": 8,
		"defended": false,
	})
	var text := log.get_display_text()
	assert_true(text.contains("P1"), "log should mention attacker: %s" % text)
	assert_true(text.contains("スライム"), "log should mention target: %s" % text)
	assert_true(text.contains("8"), "log should mention damage: %s" % text)


func test_cancel_log_playback_prevents_pending_lines():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.log_line_delay = 0.05
	overlay._is_active = true
	var report := TurnReport.new()
	report.actions = [
		{"type": "defend", "attacker_name": "P1"},
		{"type": "defend", "attacker_name": "P2"},
	]
	overlay._play_log_sequentially(report)
	assert_eq(overlay.get_combat_log_lines().size(), 1)
	overlay.cancel_log_playback()
	await get_tree().create_timer(0.08).timeout
	assert_eq(overlay.get_combat_log_lines().size(), 1)


# --- ResultPanel ---

func test_result_panel_shows_cleared_message_and_exp():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	# Force CLEARED outcome with known exp
	var outcome := EncounterOutcome.new(EncounterOutcome.Result.CLEARED)
	overlay.show_result(outcome, BattleSummary.new(40, 0, []))
	var text := overlay.get_result_panel_text()
	assert_true(text.contains("40"), "result text should mention exp: %s" % text)


# --- items-and-economy: gold drop + result display ---

func test_result_panel_cleared_shows_gold():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	var outcome := EncounterOutcome.new(EncounterOutcome.Result.CLEARED)
	overlay.show_result(outcome, BattleSummary.new(10, 25, []))
	var text := overlay.get_result_panel_text()
	assert_true(text.contains("25"), "result text should mention gold: %s" % text)


func test_result_panel_wiped_hides_gold():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	var outcome := EncounterOutcome.new(EncounterOutcome.Result.WIPED)
	outcome.gained_gold = 99  # should still not display anything gold-related on WIPED
	overlay.show_result(outcome, BattleSummary.new(0, 99, []))
	var text := overlay.get_result_panel_text()
	assert_false(text.contains("99"), "wiped result should not display gold: %s" % text)


func test_result_panel_escaped_hides_gold():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	var outcome := EncounterOutcome.new(EncounterOutcome.Result.ESCAPED)
	outcome.gained_gold = 77
	overlay.show_result(outcome, BattleSummary.new(0, 77, []))
	var text := overlay.get_result_panel_text()
	assert_false(text.contains("77"), "escaped result should not display gold: %s" % text)


func test_result_panel_shows_wiped_message():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	var outcome := EncounterOutcome.new(EncounterOutcome.Result.WIPED)
	overlay.show_result(outcome, BattleSummary.empty())
	var text := overlay.get_result_panel_text()
	assert_true(text.length() > 0, "result text should not be empty")


func test_result_panel_shows_escape_message():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	var outcome := EncounterOutcome.new(EncounterOutcome.Result.ESCAPED)
	overlay.show_result(outcome, BattleSummary.empty())
	var text := overlay.get_result_panel_text()
	assert_true(text.length() > 0)


func test_result_panel_lists_level_ups():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	var outcome := EncounterOutcome.new(EncounterOutcome.Result.CLEARED)
	# Simulate P1 leveled up from 1 to 2
	overlay.show_result(outcome, BattleSummary.new(100, 0, [{"name": "P1", "new_level": 2}]))
	var text := overlay.get_result_panel_text()
	assert_true(text.contains("P1"), "should mention leveled character: %s" % text)
	assert_true(text.contains("2"), "should mention new level: %s" % text)


func test_result_confirm_emits_encounter_resolved():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	var outcome := EncounterOutcome.new(EncounterOutcome.Result.CLEARED)
	watch_signals(overlay)
	overlay.show_result(outcome, BattleSummary.empty())
	overlay.confirm_result()
	assert_signal_emitted(overlay, "encounter_resolved")


# --- input control / regression ---

func test_enter_during_command_phase_does_not_resolve_encounter():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	watch_signals(overlay)
	overlay._unhandled_input(TestHelpers.make_action_event(&"ui_accept"))
	# No encounter_resolved emitted because we're in COMMAND_MENU phase
	assert_signal_not_emitted(overlay, "encounter_resolved")


func test_combat_overlay_remains_active_during_battle():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	# Blocker for DungeonScreen / ESC menu is is_active()
	assert_true(overlay.is_active())


func test_enter_at_result_phase_resolves_encounter():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	watch_signals(overlay)
	overlay.show_result(EncounterOutcome.new(EncounterOutcome.Result.CLEARED), BattleSummary.empty())
	overlay._unhandled_input(TestHelpers.make_action_event(&"ui_accept"))
	assert_signal_emitted(overlay, "encounter_resolved")
