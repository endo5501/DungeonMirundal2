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


func _make_guild_with_party() -> Guild:
	var g := Guild.new()
	var c1 := _make_character("P1", "Fighter")
	var c2 := _make_character("P2", "Mage")
	g.register(c1)
	g.register(c2)
	g.assign_to_party(c1, 0, 0)  # front row 0
	g.assign_to_party(c2, 1, 0)  # back row 0
	return g


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


# --- ResultPanel ---

func test_result_panel_shows_cleared_message_and_exp():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	# Force CLEARED outcome with known exp
	var outcome := EncounterOutcome.new(EncounterOutcome.Result.CLEARED)
	outcome.gained_experience = 40
	overlay.show_result(outcome, [])
	var text := overlay.get_result_panel_text()
	assert_true(text.contains("40"), "result text should mention exp: %s" % text)


# --- items-and-economy: gold drop + result display ---

func test_result_panel_cleared_shows_gold():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	var outcome := EncounterOutcome.new(EncounterOutcome.Result.CLEARED)
	outcome.gained_experience = 10
	outcome.gained_gold = 25
	overlay.show_result(outcome, [])
	var text := overlay.get_result_panel_text()
	assert_true(text.contains("25"), "result text should mention gold: %s" % text)


func test_result_panel_wiped_hides_gold():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	var outcome := EncounterOutcome.new(EncounterOutcome.Result.WIPED)
	outcome.gained_gold = 99  # should still not display anything gold-related on WIPED
	overlay.show_result(outcome, [])
	var text := overlay.get_result_panel_text()
	assert_false(text.contains("99"), "wiped result should not display gold: %s" % text)


func test_result_panel_escaped_hides_gold():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	var outcome := EncounterOutcome.new(EncounterOutcome.Result.ESCAPED)
	outcome.gained_gold = 77
	overlay.show_result(outcome, [])
	var text := overlay.get_result_panel_text()
	assert_false(text.contains("77"), "escaped result should not display gold: %s" % text)


func test_compute_gold_drop_sums_per_monster_rolls():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	var rng := RandomNumberGenerator.new()
	rng.seed = TEST_SEED
	overlay.setup_dependencies(_guild, _provider, rng)
	# Build dead monsters with known gold ranges
	var md_a := MonsterData.new()
	md_a.monster_id = &"a"
	md_a.monster_name = "A"
	md_a.max_hp_min = 1
	md_a.max_hp_max = 1
	md_a.gold_min = 3
	md_a.gold_max = 3  # always 3
	var md_b := MonsterData.new()
	md_b.monster_id = &"b"
	md_b.monster_name = "B"
	md_b.max_hp_min = 1
	md_b.max_hp_max = 1
	md_b.gold_min = 10
	md_b.gold_max = 10  # always 10
	var m_a := Monster.new(md_a, rng)
	var m_b := Monster.new(md_b, rng)
	var total: int = overlay._compute_gold_drop([m_a, m_b])
	assert_eq(total, 13)


func test_result_panel_shows_wiped_message():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	var outcome := EncounterOutcome.new(EncounterOutcome.Result.WIPED)
	overlay.show_result(outcome, [])
	var text := overlay.get_result_panel_text()
	assert_true(text.length() > 0, "result text should not be empty")


func test_result_panel_shows_escape_message():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	var outcome := EncounterOutcome.new(EncounterOutcome.Result.ESCAPED)
	overlay.show_result(outcome, [])
	var text := overlay.get_result_panel_text()
	assert_true(text.length() > 0)


func test_result_panel_lists_level_ups():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	var outcome := EncounterOutcome.new(EncounterOutcome.Result.CLEARED)
	outcome.gained_experience = 100
	# Simulate P1 leveled up from 1 to 2
	overlay.show_result(outcome, [{"name": "P1", "new_level": 2}])
	var text := overlay.get_result_panel_text()
	assert_true(text.contains("P1"), "should mention leveled character: %s" % text)
	assert_true(text.contains("2"), "should mention new level: %s" % text)


func test_result_confirm_emits_encounter_resolved():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	var outcome := EncounterOutcome.new(EncounterOutcome.Result.CLEARED)
	outcome.gained_experience = 0
	watch_signals(overlay)
	overlay.show_result(outcome, [])
	overlay.confirm_result()
	assert_signal_emitted(overlay, "encounter_resolved")


# --- input control / regression ---

func test_enter_during_command_phase_does_not_resolve_encounter():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party({&"slime": 1}))
	watch_signals(overlay)
	# Simulate Enter
	var ev := InputEventKey.new()
	ev.keycode = KEY_ENTER
	ev.pressed = true
	overlay._unhandled_input(ev)
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
	overlay.show_result(EncounterOutcome.new(EncounterOutcome.Result.CLEARED), [])
	var ev := InputEventKey.new()
	ev.keycode = KEY_ENTER
	ev.pressed = true
	overlay._unhandled_input(ev)
	assert_signal_emitted(overlay, "encounter_resolved")
