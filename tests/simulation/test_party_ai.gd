extends GutTest

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


func _find_job(name: String) -> JobData:
	for j in _loader.load_all_jobs():
		if j.job_name == name:
			return j
	return null


func _find_human() -> RaceData:
	for r in _loader.load_all_races():
		if r.race_name == "Human":
			return r
	return null


func _make_character(
	name: String,
	job_name: String,
	hp: int = 30,
	mp: int = 0,
	spells: Array = [],
) -> Character:
	var ch := Character.new()
	ch.character_name = name
	ch.race = _find_human()
	ch.job = _find_job(job_name)
	ch.level = 1
	ch.base_stats = {&"STR": 14, &"INT": 10, &"PIE": 10, &"VIT": 14, &"AGI": 10, &"LUC": 10}
	ch.max_hp = hp
	ch.current_hp = hp
	ch.max_mp = mp
	ch.current_mp = mp
	ch.accumulated_exp = 0
	var typed: Array[StringName] = []
	for s in spells:
		typed.append(s)
	ch.known_spells = typed
	return ch


func _combatant(ch: Character, row: int = Row.FRONT) -> PartyCombatant:
	return PartyCombatant.new(ch, _provider, row)


func _make_monsters(count: int, tier: int = 1, row: int = Row.FRONT) -> Array:
	var result: Array = []
	for i in range(count):
		var data := MonsterTestFactory.make_monster_data(
			StringName("mon_%d" % i), row, WeaponRange.MELEE, 0, 0, [], 20
		)
		data.tier = tier
		result.append(MonsterTestFactory.make_monster_combatant(data))
	return result


func _make_ctx(party: Array, monsters: Array, repo: SpellRepository = null) -> PartyAiContext:
	var engine := TurnEngine.new()
	engine.start_battle(party, monsters)
	return PartyAiContext.new(party, monsters, repo, engine)


func _default_repo() -> SpellRepository:
	return MonsterTestFactory.make_repo([
		MonsterTestFactory.build_heal_spell(&"heal", 8, 2),
		MonsterTestFactory.build_heal_spell(&"heala", 30, 5),
		MonsterTestFactory.build_damage_spell(&"fire", SpellData.TargetType.ENEMY_ONE, 2),
		MonsterTestFactory.build_damage_spell(&"flame", SpellData.TargetType.ENEMY_GROUP, 4),
	])


# --- PartyAiConfig defaults ---

func test_config_defaults():
	var config := PartyAiConfig.new()
	assert_almost_eq(config.heal_hp_threshold, 0.6, 0.0001)
	assert_eq(config.attack_magic_min_enemies, 2)
	assert_eq(config.attack_magic_min_tier, 0)


# --- Physical attack / defend fallback ---

func test_fighter_attacks_first_living_enemy():
	var fighter := _combatant(_make_character("F1", "Fighter"))
	var monsters := _make_monsters(2)
	monsters[0].current_hp = 0
	var ctx := _make_ctx([fighter], monsters, _default_repo())
	var cmd = PartyAi.choose(fighter, ctx, PartyAiConfig.new(), _make_rng())
	assert_true(cmd is AttackCommand, "expected AttackCommand")
	if cmd is AttackCommand:
		assert_eq((cmd as AttackCommand).target, monsters[1])


func test_no_reachable_enemy_returns_defend():
	# BACK-row MELEE fighter behind a living FRONT ally cannot reach anyone.
	var front := _combatant(_make_character("F1", "Fighter"))
	var back := _combatant(_make_character("F2", "Fighter"), Row.BACK)
	var monsters := _make_monsters(1)
	var ctx := _make_ctx([front, back], monsters, _default_repo())
	var cmd = PartyAi.choose(back, ctx, PartyAiConfig.new(), _make_rng())
	assert_true(cmd is DefendCommand, "expected DefendCommand")


func test_choose_does_not_mutate_state():
	var fighter := _combatant(_make_character("F1", "Fighter"))
	var monsters := _make_monsters(2)
	var ctx := _make_ctx([fighter], monsters, _default_repo())
	PartyAi.choose(fighter, ctx, PartyAiConfig.new(), _make_rng())
	assert_eq(fighter.current_hp, fighter.max_hp)
	assert_eq(monsters[0].current_hp, monsters[0].max_hp)
	assert_eq(monsters[1].current_hp, monsters[1].max_hp)


# --- Priest healing ---

func test_priest_heals_ally_below_threshold():
	var priest := _combatant(_make_character("P1", "Priest", 30, 10, [&"heal"]))
	var ally := _combatant(_make_character("F1", "Fighter", 30))
	ally.current_hp = 15  # 50%
	var monsters := _make_monsters(1)
	var ctx := _make_ctx([priest, ally], monsters, _default_repo())
	var cmd = PartyAi.choose(priest, ctx, PartyAiConfig.new(), _make_rng())
	assert_true(cmd is CastCommand, "expected CastCommand")
	if cmd is CastCommand:
		assert_eq((cmd as CastCommand).spell_id, &"heal")
		assert_eq((cmd as CastCommand).target, ally)


func test_priest_targets_lowest_hp_ratio_ally():
	var priest := _combatant(_make_character("P1", "Priest", 30, 10, [&"heal"]))
	var ally_a := _combatant(_make_character("F1", "Fighter", 30))
	var ally_b := _combatant(_make_character("F2", "Fighter", 40))
	ally_a.current_hp = 15  # 50%
	ally_b.current_hp = 12  # 30%
	var monsters := _make_monsters(1)
	var ctx := _make_ctx([priest, ally_a, ally_b], monsters, _default_repo())
	var cmd = PartyAi.choose(priest, ctx, PartyAiConfig.new(), _make_rng())
	assert_true(cmd is CastCommand, "expected CastCommand")
	if cmd is CastCommand:
		assert_eq((cmd as CastCommand).target, ally_b)


func test_priest_attacks_when_all_allies_above_threshold():
	var priest := _combatant(_make_character("P1", "Priest", 30, 10, [&"heal"]))
	var ally := _combatant(_make_character("F1", "Fighter", 30))
	ally.current_hp = 27  # 90%
	var monsters := _make_monsters(1)
	var ctx := _make_ctx([priest, ally], monsters, _default_repo())
	var cmd = PartyAi.choose(priest, ctx, PartyAiConfig.new(), _make_rng())
	assert_true(cmd is AttackCommand, "expected AttackCommand, no heal above threshold")


func test_priest_without_mp_falls_through_to_attack():
	var priest := _combatant(_make_character("P1", "Priest", 30, 1, [&"heal"]))
	var ally := _combatant(_make_character("F1", "Fighter", 30))
	ally.current_hp = 15  # 50%, but heal costs 2 MP and priest has 1
	var monsters := _make_monsters(1)
	var ctx := _make_ctx([priest, ally], monsters, _default_repo())
	var cmd = PartyAi.choose(priest, ctx, PartyAiConfig.new(), _make_rng())
	assert_true(cmd is AttackCommand, "expected AttackCommand when MP insufficient")


func test_heal_choice_minimizes_overheal_small_deficit():
	var priest := _combatant(_make_character("P1", "Priest", 30, 20, [&"heal", &"heala"]))
	var ally := _combatant(_make_character("F1", "Fighter", 30))
	ally.current_hp = 22  # missing 8; heal expects 8, heala expects 30
	var monsters := _make_monsters(1)
	var ctx := _make_ctx([priest, ally], monsters, _default_repo())
	var cmd = PartyAi.choose(priest, ctx, PartyAiConfig.new(), _make_rng())
	assert_true(cmd is CastCommand, "expected CastCommand")
	if cmd is CastCommand:
		assert_eq((cmd as CastCommand).spell_id, &"heal")


func test_heal_choice_uses_largest_when_none_sufficient():
	var priest := _combatant(_make_character("P1", "Priest", 30, 20, [&"heal", &"heala"]))
	var ally := _combatant(_make_character("F1", "Fighter", 100))
	ally.current_hp = 40  # missing 60; neither 8 nor 30 covers it -> largest
	var monsters := _make_monsters(1)
	var ctx := _make_ctx([priest, ally], monsters, _default_repo())
	var cmd = PartyAi.choose(priest, ctx, PartyAiConfig.new(), _make_rng())
	assert_true(cmd is CastCommand, "expected CastCommand")
	if cmd is CastCommand:
		assert_eq((cmd as CastCommand).spell_id, &"heala")


# --- Mage attack magic knobs ---

func test_mage_casts_when_enemy_count_met():
	var mage := _combatant(_make_character("M1", "Mage", 30, 10, [&"fire"]))
	var monsters := _make_monsters(3)
	var ctx := _make_ctx([mage], monsters, _default_repo())
	var cmd = PartyAi.choose(mage, ctx, PartyAiConfig.new(), _make_rng())
	assert_true(cmd is CastCommand, "expected attack CastCommand")


func test_mage_conserves_mp_against_single_enemy():
	var mage := _combatant(_make_character("M1", "Mage", 30, 10, [&"fire"]))
	var monsters := _make_monsters(1)
	var ctx := _make_ctx([mage], monsters, _default_repo())
	var cmd = PartyAi.choose(mage, ctx, PartyAiConfig.new(), _make_rng())
	assert_true(cmd is AttackCommand, "expected physical AttackCommand, not a cast")


func test_mage_without_mp_falls_through_to_attack():
	var mage := _combatant(_make_character("M1", "Mage", 30, 1, [&"fire"]))
	var monsters := _make_monsters(3)
	var ctx := _make_ctx([mage], monsters, _default_repo())
	var cmd = PartyAi.choose(mage, ctx, PartyAiConfig.new(), _make_rng())
	assert_true(cmd is AttackCommand, "expected AttackCommand when MP insufficient")


func test_mage_tier_override_allows_cast_on_single_enemy():
	var mage := _combatant(_make_character("M1", "Mage", 30, 10, [&"fire"]))
	var monsters := _make_monsters(1, 4)
	var config := PartyAiConfig.new()
	config.attack_magic_min_tier = 3
	var ctx := _make_ctx([mage], monsters, _default_repo())
	var cmd = PartyAi.choose(mage, ctx, config, _make_rng())
	assert_true(cmd is CastCommand, "expected CastCommand via tier override")


func test_mage_tier_below_knob_does_not_cast():
	var mage := _combatant(_make_character("M1", "Mage", 30, 10, [&"fire"]))
	var monsters := _make_monsters(1, 2)
	var config := PartyAiConfig.new()
	config.attack_magic_min_tier = 3
	var ctx := _make_ctx([mage], monsters, _default_repo())
	var cmd = PartyAi.choose(mage, ctx, config, _make_rng())
	assert_true(cmd is AttackCommand, "tier 2 < knob 3 with one enemy should not cast")


func test_mage_prefers_group_spell_against_multiple_enemies():
	var mage := _combatant(_make_character("M1", "Mage", 30, 10, [&"fire", &"flame"]))
	var monsters := _make_monsters(3)
	var ctx := _make_ctx([mage], monsters, _default_repo())
	var cmd = PartyAi.choose(mage, ctx, PartyAiConfig.new(), _make_rng())
	assert_true(cmd is CastCommand, "expected CastCommand")
	if cmd is CastCommand:
		assert_eq((cmd as CastCommand).spell_id, &"flame")


func test_mage_uses_single_target_spell_against_one_enemy():
	var mage := _combatant(_make_character("M1", "Mage", 30, 10, [&"fire", &"flame"]))
	var monsters := _make_monsters(1, 4)
	var config := PartyAiConfig.new()
	config.attack_magic_min_tier = 3
	var ctx := _make_ctx([mage], monsters, _default_repo())
	var cmd = PartyAi.choose(mage, ctx, config, _make_rng())
	assert_true(cmd is CastCommand, "expected CastCommand")
	if cmd is CastCommand:
		assert_eq((cmd as CastCommand).spell_id, &"fire")
		assert_eq((cmd as CastCommand).target, monsters[0])


func test_mage_group_spell_targets_only_living_enemies():
	var mage := _combatant(_make_character("M1", "Mage", 30, 10, [&"fire"]))
	var monsters := _make_monsters(3)
	monsters[0].current_hp = 0
	monsters[1].current_hp = 0
	# Only one living enemy remains -> default knobs say conserve MP.
	var ctx := _make_ctx([mage], monsters, _default_repo())
	var cmd = PartyAi.choose(mage, ctx, PartyAiConfig.new(), _make_rng())
	assert_true(cmd is AttackCommand, "one living enemy should not trigger attack magic")


# --- Config knob honored ---

func test_raising_heal_threshold_changes_behavior():
	var priest := _combatant(_make_character("P1", "Priest", 30, 10, [&"heal"]))
	var ally := _combatant(_make_character("F1", "Fighter", 30))
	ally.current_hp = 21  # 70%
	var monsters := _make_monsters(1)
	var ctx := _make_ctx([priest, ally], monsters, _default_repo())

	var low := PartyAiConfig.new()  # threshold 0.6 -> no heal
	var cmd_low = PartyAi.choose(priest, ctx, low, _make_rng())
	assert_true(cmd_low is AttackCommand, "70% HP with threshold 0.6 should attack")

	var high := PartyAiConfig.new()
	high.heal_hp_threshold = 0.8
	var cmd_high = PartyAi.choose(priest, ctx, high, _make_rng())
	assert_true(cmd_high is CastCommand, "70% HP with threshold 0.8 should heal")
	if cmd_high is CastCommand:
		assert_eq((cmd_high as CastCommand).spell_id, &"heal")
		assert_eq((cmd_high as CastCommand).target, ally)
