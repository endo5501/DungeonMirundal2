extends GutTest

# Verifies CombatOverlay.request_undo_actor steps back through the
# COMMAND_INPUT phase, withdrawing pending commands and re-showing the
# prior actor's command menu. See spec:
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


func _make_character(name: String, hp: int = 20) -> Character:
	var ch := Character.new()
	ch.character_name = name
	ch.race = _find_human()
	ch.job = _find_job("Fighter")
	ch.level = 1
	ch.base_stats = {&"STR": 14, &"INT": 12, &"PIE": 10, &"VIT": 12, &"AGI": 10, &"LUC": 10}
	ch.max_hp = hp
	ch.current_hp = hp
	ch.max_mp = 0
	ch.current_mp = 0
	return ch


# Build a guild whose party members fill the front row in the given order.
# `dead_indices` (within the slots array) get hp=0 so PartyCombatant.is_alive() returns false.
func _make_guild(slot_names: Array[String], dead_indices: Array[int] = []) -> Guild:
	var g := Guild.new()
	for i in range(slot_names.size()):
		var ch := _make_character(slot_names[i])
		if dead_indices.has(i):
			ch.current_hp = 0
		g.register(ch)
		# Lay out: front row (row 0) col 0..2, then back row (row 1) col 0..2
		if i < 3:
			g.assign_to_party(ch, 0, i)
		else:
			g.assign_to_party(ch, 1, i - 3)
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


# --- 3.1 single-step back from B → A ---
func test_undo_from_second_actor_steps_back_to_first():
	var guild := _make_guild(["A", "B", "C"])
	var overlay := _start_overlay(guild)
	var engine: TurnEngine = overlay.get_turn_engine()
	assert_eq(overlay._current_actor_index, 0, "starts at A")

	# Simulate A confirming a command, advance to B.
	engine.submit_command(0, DefendCommand.new())
	overlay._advance_to_next_actor()
	assert_eq(overlay._current_actor_index, 1, "now at B")
	assert_true(engine._pending_commands.has(0), "A's pending command exists")

	overlay.request_undo_actor()

	assert_eq(overlay._current_actor_index, 0, "returns to A")
	assert_false(engine._pending_commands.has(0), "A's pending command is withdrawn")
	assert_eq(overlay.get_current_phase(), CombatOverlay.Phase.COMMAND_MENU)
	assert_true(overlay._command_menu.visible, "command menu re-shown")
	assert_eq(overlay._command_menu._current_actor, engine.party[0], "menu bound to A")


# --- 3.2 triple cancel from D walks D → C → B → A ---
func test_repeated_undo_walks_back_to_first():
	var guild := _make_guild(["A", "B", "C", "D"])
	var overlay := _start_overlay(guild)
	var engine: TurnEngine = overlay.get_turn_engine()

	# Drive A, B, C through; overlay lands on D's COMMAND_MENU.
	for i in range(3):
		engine.submit_command(i, DefendCommand.new())
		overlay._advance_to_next_actor()
	assert_eq(overlay._current_actor_index, 3, "at D")
	assert_eq(engine._pending_commands.size(), 3)

	overlay.request_undo_actor()  # → C
	assert_eq(overlay._current_actor_index, 2)
	assert_false(engine._pending_commands.has(2))

	overlay.request_undo_actor()  # → B
	assert_eq(overlay._current_actor_index, 1)
	assert_false(engine._pending_commands.has(1))

	overlay.request_undo_actor()  # → A
	assert_eq(overlay._current_actor_index, 0)
	assert_false(engine._pending_commands.has(0))
	assert_eq(engine._pending_commands.size(), 0)


# --- 3.3 dead member B is skipped on the way back ---
func test_undo_skips_dead_party_member_backwards():
	# Party: A alive, B dead, C alive, D alive. B is at engine.party[1].
	var guild := _make_guild(["A", "B", "C", "D"], [1])
	var overlay := _start_overlay(guild)
	var engine: TurnEngine = overlay.get_turn_engine()

	assert_false(engine.party[1].is_alive(), "B is dead")
	# Forward path skips B too: A → C → D
	engine.submit_command(0, DefendCommand.new())
	overlay._advance_to_next_actor()
	assert_eq(overlay._current_actor_index, 2, "advances over B to C")
	engine.submit_command(2, DefendCommand.new())
	overlay._advance_to_next_actor()
	assert_eq(overlay._current_actor_index, 3, "now at D")

	overlay.request_undo_actor()  # D → C (no skip needed)
	assert_eq(overlay._current_actor_index, 2)
	assert_false(engine._pending_commands.has(2), "C's command withdrawn")

	overlay.request_undo_actor()  # C → A (skipping dead B)
	assert_eq(overlay._current_actor_index, 0, "skips dead B and lands on A")
	assert_false(engine._pending_commands.has(0), "A's command withdrawn")


# --- 3.4 first-living member: undo is a no-op ---
func test_undo_on_first_living_actor_is_noop():
	var guild := _make_guild(["A", "B", "C"])
	var overlay := _start_overlay(guild)
	var engine: TurnEngine = overlay.get_turn_engine()
	assert_eq(overlay._current_actor_index, 0)

	overlay.request_undo_actor()

	assert_eq(overlay._current_actor_index, 0, "index unchanged")
	assert_eq(engine._pending_commands.size(), 0, "no pending commands touched")
	assert_eq(overlay.get_current_phase(), CombatOverlay.Phase.COMMAND_MENU)


# --- 3.5 outside COMMAND_MENU phase: undo is a no-op ---
func test_undo_outside_command_menu_phase_is_noop():
	var guild := _make_guild(["A", "B"])
	var overlay := _start_overlay(guild)
	var engine: TurnEngine = overlay.get_turn_engine()

	# A submits, advance to B, then enter TARGET_SELECT artificially.
	engine.submit_command(0, DefendCommand.new())
	overlay._advance_to_next_actor()
	overlay._current_phase = CombatOverlay.Phase.TARGET_SELECT

	overlay.request_undo_actor()

	# Index unchanged, A's pending command still present.
	assert_eq(overlay._current_actor_index, 1)
	assert_true(engine._pending_commands.has(0))
	assert_eq(overlay.get_current_phase(), CombatOverlay.Phase.TARGET_SELECT)


# --- 3.6 sub-panels are hidden when stepping back ---
func test_undo_hides_subpanels_before_showing_command_menu():
	var guild := _make_guild(["A", "B"])
	var overlay := _start_overlay(guild)
	var engine: TurnEngine = overlay.get_turn_engine()

	engine.submit_command(0, DefendCommand.new())
	overlay._advance_to_next_actor()
	# Pretend a sub-panel got left visible.
	overlay._target_selector.visible = true
	overlay._spell_selector.visible = true
	overlay._item_use_flow.visible = true

	overlay.request_undo_actor()

	assert_false(overlay._target_selector.visible, "target_selector hidden")
	assert_false(overlay._spell_selector.visible, "spell_selector hidden")
	assert_false(overlay._item_use_flow.visible, "item_use_flow hidden")
	assert_true(overlay._command_menu.visible, "command_menu re-shown")
