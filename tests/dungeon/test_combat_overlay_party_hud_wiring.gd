extends GutTest

# CombatOverlay must attach the PartyHud autoload to its TurnEngine when an
# encounter starts and detach when the result is confirmed (battle over).
# This wiring is what gives the HUD its lift / die / stat-modifier reactions.


const TEST_SEED: int = 12345


var _loader: DataLoader
var _guild: Guild
var _provider: DummyEquipmentProvider
var _saved_guild: Guild


func before_each() -> void:
	_loader = DataLoader.new()
	_provider = DummyEquipmentProvider.new()
	_guild = _make_guild_with_party()
	_saved_guild = GameState.guild
	GameState.guild = _guild
	# bind the autoload to this guild so panels are populated
	TestHelpers.get_party_hud().bind_active_party()


func after_each() -> void:
	# Defensively detach in case a test failed before reaching confirm_result.
	var hud := TestHelpers.get_party_hud()
	if hud != null and hud.has_method("detach_from_turn_engine"):
		hud.detach_from_turn_engine()
	GameState.guild = _saved_guild


func _make_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = TEST_SEED
	return rng


func _make_monster_data(id: StringName, display_name: String) -> MonsterData:
	var data := MonsterData.new()
	data.monster_id = id
	data.monster_name = display_name
	data.max_hp_min = 8
	data.max_hp_max = 8
	data.attack = 1
	data.defense = 0
	data.agility = 4
	data.experience = 40
	return data


func _make_monster_party() -> MonsterParty:
	var party := MonsterParty.new()
	var data := _make_monster_data(&"slime", "Slime")
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
	var c2 := _make_character("P2", "Fighter")
	g.register(c1)
	g.register(c2)
	g.assign_to_party(c1, 0, 0)
	g.assign_to_party(c2, 1, 0)
	return g


# --- attach happens at start_encounter ---

func test_start_encounter_attaches_party_hud_to_turn_engine():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party())
	var engine: TurnEngine = overlay.get_turn_engine()
	# PartyHud connects all five UI signals on attach.
	assert_gt(engine.actor_action_started.get_connections().size(), 0,
		"PartyHud should be subscribed to actor_action_started after start_encounter")
	assert_gt(engine.actor_died.get_connections().size(), 0,
		"PartyHud should be subscribed to actor_died after start_encounter")


# --- detach happens at result confirmation ---

func test_confirm_result_detaches_party_hud_from_turn_engine():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party())
	var engine: TurnEngine = overlay.get_turn_engine()
	# Force the overlay to RESULT phase so confirm_result is honored.
	overlay.show_result(EncounterOutcome.new(EncounterOutcome.Result.CLEARED), BattleSummary.new())
	overlay.confirm_result()
	assert_eq(engine.actor_action_started.get_connections().size(), 0,
		"PartyHud should be unsubscribed after confirm_result")
	assert_eq(engine.actor_died.get_connections().size(), 0,
		"PartyHud should be unsubscribed after confirm_result")


# --- 7.x: monster panel registration with PartyHud at battle start ---

func test_start_encounter_initializes_monster_panel_displayed_alive():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party())
	var monster_panel: CombatMonsterPanel = overlay._monster_panel
	# After setup_for_battle, _displayed_alive must contain every engine monster.
	for mc in overlay.get_turn_engine().monsters:
		assert_true(monster_panel._displayed_alive.get(mc, false),
			"every spawned monster should be displayed-alive after start_encounter")


func test_start_encounter_attaches_monster_panel_to_party_hud():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party())
	var hud := TestHelpers.get_party_hud()
	assert_same(hud._attached_monster_panel, overlay._monster_panel,
		"PartyHud should reference overlay's monster panel after start_encounter")


func test_confirm_result_releases_monster_panel_reference():
	var overlay := CombatOverlay.new()
	add_child_autofree(overlay)
	overlay.setup_dependencies(_guild, _provider, _make_rng())
	overlay.start_encounter(_make_monster_party())
	overlay.show_result(EncounterOutcome.new(EncounterOutcome.Result.CLEARED), BattleSummary.new())
	overlay.confirm_result()
	var hud := TestHelpers.get_party_hud()
	assert_null(hud._attached_monster_panel,
		"detach_from_turn_engine in confirm_result must clear the monster panel ref")
