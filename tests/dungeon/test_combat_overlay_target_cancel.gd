extends GutTest

# Verifies that ui_cancel during the attack TARGET_SELECT phase returns
# to COMMAND_MENU for the same actor without committing a command, while
# preserving the existing SPELL_TARGET → SPELL_SELECT cancel path. See:
#   openspec/changes/add-combat-command-undo/specs/combat-overlay/spec.md

const TEST_SEED: int = 12345


var _loader: DataLoader
var _provider: DummyEquipmentProvider


func before_each():
	_loader = DataLoader.new()
	_provider = DummyEquipmentProvider.new()


func _make_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = TEST_SEED
	return rng


func _find_human() -> RaceData:
	for r in _loader.load_all_races():
		if r.race_name == "Human":
			return r
	return null


func _find_job(name: String) -> JobData:
	for j in _loader.load_all_jobs():
		if j.job_name == name:
			return j
	return null


func _make_character(name: String, job_name: String, mp: int = 0) -> Character:
	var ch := Character.new()
	ch.character_name = name
	ch.race = _find_human()
	ch.job = _find_job(job_name)
	ch.level = 1
	ch.base_stats = {&"STR": 14, &"INT": 14, &"PIE": 10, &"VIT": 12, &"AGI": 10, &"LUC": 10}
	ch.max_hp = 20
	ch.current_hp = 20
	ch.max_mp = mp
	ch.current_mp = mp
	return ch


func _make_guild_with_fighter() -> Guild:
	var g := Guild.new()
	var c := _make_character("Hero", "Fighter")
	g.register(c)
	g.assign_to_party(c, 0, 0)
	return g


func _make_monster_party() -> MonsterParty:
	var data := MonsterData.new()
	data.monster_id = &"slime"
	data.monster_name = "Slime"
	data.max_hp_min = 8
	data.max_hp_max = 8
	data.attack = 2
	data.defense = 0
	data.agility = 2
	data.experience = 1
	var party := MonsterParty.new()
	party.add(Monster.new(data, _make_rng()))
	return party


func _start_overlay(guild: Guild) -> CombatOverlay:
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party())
	return overlay


# --- 4.1 TARGET_SELECT cancel returns to COMMAND_MENU without submit ---
func test_target_select_cancel_returns_to_command_menu():
	var overlay := _start_overlay(_make_guild_with_fighter())
	var engine: TurnEngine = overlay.get_turn_engine()

	# Drive: Attack → TARGET_SELECT.
	overlay.command_menu_select(CombatCommandMenu.OPT_ATTACK)
	assert_eq(overlay.get_current_phase(), CombatOverlay.Phase.TARGET_SELECT)
	assert_true(overlay._target_selector.visible, "selector visible before cancel")

	# Simulate the cancel arriving on the selector.
	overlay._target_selector.request_cancel()

	assert_eq(overlay.get_current_phase(), CombatOverlay.Phase.COMMAND_MENU)
	assert_false(overlay._target_selector.visible, "selector hidden after cancel")
	assert_true(overlay._command_menu.visible, "command menu re-shown")
	assert_eq(overlay._current_actor_index, 0, "still on the same actor")
	assert_false(engine.has_pending_command(0), "no command was submitted")


# --- 4.2 SPELL_TARGET cancel still returns to SPELL_SELECT (regression) ---
func test_spell_target_cancel_still_returns_to_spell_select():
	# Use a fighter party for setup convenience; we're stubbing the SPELL_TARGET
	# state directly to test the handler in isolation, not the spell flow.
	var overlay := _start_overlay(_make_guild_with_fighter())
	var engine: TurnEngine = overlay.get_turn_engine()

	var spell := SpellData.new()
	spell.id = &"fire_test"
	spell.display_name = "Fire (test)"
	spell.school = SpellData.SCHOOL_MAGE
	spell.level = 1
	spell.mp_cost = 0
	spell.target_type = SpellData.TargetType.ENEMY_ONE

	# Manually place the overlay into SPELL_TARGET as if a spell was just chosen.
	overlay._command_menu.hide_menu()
	overlay._pending_cast_spell = spell
	overlay._current_phase = CombatOverlay.Phase.SPELL_TARGET
	overlay._target_selector.show_with(engine.monsters)

	overlay._target_selector.request_cancel()

	assert_eq(overlay.get_current_phase(), CombatOverlay.Phase.SPELL_SELECT,
		"SPELL_TARGET cancel should return to SPELL_SELECT, not COMMAND_MENU")
	assert_false(engine.has_pending_command(0), "no command was submitted")
