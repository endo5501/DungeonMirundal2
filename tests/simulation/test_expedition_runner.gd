extends GutTest

const TEST_SEED: int = 12345
const RUN_INDEX: int = 7


func _make_rng(seed_value: int = TEST_SEED) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _spec(name: String, race: String, job: String, level: int, row: String = "front") -> Dictionary:
	return {"name": name, "race": race, "job": job, "level": level, "row": row}


func _make_config(
	party: Array,
	patterns: Array,
	max_battles: int,
	heal_threshold: float = 0.6
) -> ExpeditionConfig:
	var cfg := ExpeditionConfig.new()
	cfg.max_battles = max_battles
	cfg.party = party
	cfg.encounter_mode = "fixed"
	cfg.encounter_patterns = patterns
	cfg.ai_heal_hp_threshold = heal_threshold
	return cfg


func _make_monster_data(id: StringName, atk: int, defn: int, agi: int, hp: int, exp: int) -> MonsterData:
	var data := MonsterData.new()
	data.monster_id = id
	data.monster_name = String(id)
	data.max_hp_min = hp
	data.max_hp_max = hp
	data.attack = atk
	data.defense = defn
	data.agility = agi
	data.experience = exp
	return data


func _make_monster_repo(datas: Array) -> MonsterRepository:
	var repo := MonsterRepository.new()
	for d in datas:
		repo.register(d)
	return repo


# Overwhelming boss: one-shots a level-1 member and cannot realistically be killed.
func _dragon() -> MonsterData:
	return _make_monster_data(&"dragon", 999, 50, 50, 9999, 0)


# Trivial fodder: dies to one hit, all but harmless.
func _slime() -> MonsterData:
	return _make_monster_data(&"slime", 1, 0, 1, 1, 1)


# Unkillable-in-one-turn wall that deals no meaningful damage.
func _tank() -> MonsterData:
	return _make_monster_data(&"tank", 1, 200, 1, 9999, 0)


# Fast chip-damage attacker: AGI 40 caps its hit chance at 0.99 and it acts
# before the party, so it reliably lands a few points of damage before dying.
func _rat() -> MonsterData:
	return _make_monster_data(&"rat", 3, 0, 40, 1, 1)


# One-hit-kill fodder worth 600 exp (fighter needs 1000 exp for level 2).
func _xp_slime() -> MonsterData:
	return _make_monster_data(&"xp_slime", 0, 0, 1, 1, 600)


func _make_heal_spell(id: StringName, mp_cost: int, base_heal: int) -> SpellData:
	var effect := HealSpellEffect.new()
	effect.base_heal = base_heal
	effect.spread = 0
	var spell := SpellData.new()
	spell.id = id
	spell.display_name = String(id)
	spell.school = SpellData.SCHOOL_PRIEST
	spell.level = 1
	spell.mp_cost = mp_cost
	spell.target_type = SpellData.TargetType.ALLY_ONE
	spell.scope = SpellData.Scope.OUTSIDE_OK
	spell.effect = effect
	return spell


func _make_spell_repo(spells: Array = []) -> SpellRepository:
	var repo := SpellRepository.new()
	for s in spells:
		repo.register(s)
	return repo


# --- WIPED end condition ---

func test_expedition_ends_wiped_and_counts_battles_entered():
	var cfg := _make_config([_spec("F1", "human", "fighter", 1)], [{"dragon": 1}], 50)
	var result: ExpeditionResult = ExpeditionRunner.run_expedition(
		cfg, RUN_INDEX, _make_rng(), 100, _make_monster_repo([_dragon()]), _make_spell_repo()
	)
	assert_not_null(result)
	if result == null:
		return
	assert_eq(result.end_cause, "WIPED")
	assert_eq(result.battle_rows.size(), 1, "a wipe in battle 1 records exactly 1 row")
	if result.battle_rows.size() != 1:
		return
	var row: Dictionary = result.battle_rows[0]
	assert_eq(row["outcome"], "WIPED")
	assert_eq(int(row["run"]), RUN_INDEX)
	assert_eq(int(row["battle"]), 1)
	assert_eq(int(row["deaths_cum"]), 1)
	assert_eq(float(row["party_hp_pct"]), 0.0, "solo member dead → party HP total is 0")
	assert_eq(
		float(row["party_hp_pct"]), float(row["hp_pct_before_heal"]),
		"no healing happens after a wipe: post-heal pcts equal pre-heal values"
	)
	var stats: Dictionary = result.to_run_stats()
	assert_eq(int(stats["battles_survived"]), 1, "battles_survived counts battles entered")
	assert_eq(int(stats["first_death_battle"]), 1)
	assert_eq(String(stats["end_cause"]), "WIPED")


# --- MAX_BATTLES end condition ---

func test_expedition_ends_at_max_battles_when_party_clears_everything():
	var cfg := _make_config([_spec("F1", "human", "fighter", 3)], [{"slime": 1}], 3)
	var result: ExpeditionResult = ExpeditionRunner.run_expedition(
		cfg, RUN_INDEX, _make_rng(), 100, _make_monster_repo([_slime()]), _make_spell_repo()
	)
	assert_not_null(result)
	if result == null:
		return
	assert_eq(result.end_cause, "MAX_BATTLES")
	assert_eq(result.battle_rows.size(), 3)
	if result.battle_rows.size() != 3:
		return
	var total_turns := 0
	for i in range(3):
		var row: Dictionary = result.battle_rows[i]
		assert_eq(row["outcome"], "CLEARED", "battle %d should be CLEARED" % (i + 1))
		assert_eq(int(row["run"]), RUN_INDEX)
		assert_eq(int(row["battle"]), i + 1, "battle indices are 1-based and sequential")
		assert_gt(int(row["turns"]), 0)
		assert_eq(int(row["deaths_cum"]), 0)
		assert_eq(
			float(row["party_mp_pct"]), 0.0,
			"party with total max_mp == 0 reports party_mp_pct = 0.0"
		)
		total_turns += int(row["turns"])
	assert_eq(result.battle_rows[0]["encounter"], "pattern_0:slime_x1",
		"encounter label comes from EncounterSource.describe() after next()")
	var stats: Dictionary = result.to_run_stats()
	assert_eq(int(stats["battles_survived"]), 3)
	assert_eq(int(stats["total_turns"]), total_turns, "total_turns sums per-battle turns")
	assert_eq(int(stats["first_death_battle"]), -1, "-1 when nobody died")
	assert_eq(int(stats["mp_exhausted_battle"]), -1, "-1 for a casterless party")
	assert_eq(String(stats["end_cause"]), "MAX_BATTLES")


func test_fixed_patterns_cycle_across_battles():
	var cfg := _make_config([_spec("F1", "human", "fighter", 3)], [{"slime": 1}, {"rat": 1}], 3)
	var result: ExpeditionResult = ExpeditionRunner.run_expedition(
		cfg, 0, _make_rng(), 100, _make_monster_repo([_slime(), _rat()]), _make_spell_repo()
	)
	assert_not_null(result)
	if result == null or result.battle_rows.size() != 3:
		assert_eq(result.battle_rows.size() if result != null else -1, 3)
		return
	assert_eq(result.battle_rows[0]["encounter"], "pattern_0:slime_x1")
	assert_eq(result.battle_rows[1]["encounter"], "pattern_1:rat_x1")
	assert_eq(result.battle_rows[2]["encounter"], "pattern_0:slime_x1", "patterns wrap around")


# --- STALLED end condition ---

func test_expedition_stalls_when_turn_limit_is_hit():
	var cfg := _make_config([_spec("F1", "human", "fighter", 3)], [{"tank": 1}], 5)
	var result: ExpeditionResult = ExpeditionRunner.run_expedition(
		cfg, RUN_INDEX, _make_rng(), 1, _make_monster_repo([_tank()]), _make_spell_repo()
	)
	assert_not_null(result)
	if result == null:
		return
	assert_eq(result.end_cause, "STALLED")
	assert_eq(result.battle_rows.size(), 1, "the stalled battle ends the expedition")
	if result.battle_rows.size() != 1:
		return
	var row: Dictionary = result.battle_rows[0]
	assert_eq(row["outcome"], "STALLED")
	assert_eq(int(row["turns"]), 1, "turn_limit=1 cuts the battle after one turn")
	var stats: Dictionary = result.to_run_stats()
	assert_eq(String(stats["end_cause"]), "STALLED")
	assert_eq(int(stats["battles_survived"]), 1)


# --- Party state persistence ---

func test_hp_carries_over_between_battles_without_a_healer():
	var cfg := _make_config([_spec("F1", "human", "fighter", 3)], [{"rat": 1}], 2)
	var result: ExpeditionResult = ExpeditionRunner.run_expedition(
		cfg, 0, _make_rng(), 100, _make_monster_repo([_rat()]), _make_spell_repo()
	)
	assert_not_null(result)
	if result == null:
		return
	assert_eq(result.end_cause, "MAX_BATTLES")
	assert_eq(result.battle_rows.size(), 2)
	if result.battle_rows.size() != 2:
		return
	var row1: Dictionary = result.battle_rows[0]
	var row2: Dictionary = result.battle_rows[1]
	assert_eq(
		float(row1["party_hp_pct"]), float(row1["hp_pct_before_heal"]),
		"no caster in the party: post-heal pct equals pre-heal pct"
	)
	assert_lt(float(row1["party_hp_pct"]), 1.0, "the rat should have landed chip damage")
	assert_true(
		float(row2["hp_pct_before_heal"]) <= float(row1["party_hp_pct"]),
		"battle 2 starts from battle 1's HP and can only lose more without heals"
	)
	assert_eq(result.characters.size(), 1)
	if result.characters.size() == 1:
		var ch: Character = result.characters[0]
		assert_lt(ch.current_hp, ch.max_hp, "damage persists on the Character after the run")


func test_between_battle_healing_restores_hp_when_priest_has_mp():
	var cfg := _make_config(
		[_spec("F1", "human", "fighter", 3), _spec("P1", "human", "priest", 1, "back")],
		[{"rat": 1}],
		1,
		0.0  # heal_hp_threshold 0.0 → no in-battle healing; damage survives to the heal phase
	)
	var spell_repo := _make_spell_repo([_make_heal_spell(&"heal", 5, 8)])
	var result: ExpeditionResult = ExpeditionRunner.run_expedition(
		cfg, 0, _make_rng(), 100, _make_monster_repo([_rat()]), spell_repo
	)
	assert_not_null(result)
	if result == null:
		return
	assert_eq(result.battle_rows.size(), 1)
	if result.battle_rows.size() != 1:
		return
	var row: Dictionary = result.battle_rows[0]
	assert_eq(row["outcome"], "CLEARED")
	assert_gt(
		float(row["party_hp_pct"]), float(row["hp_pct_before_heal"]),
		"between-battle healing raises the post-heal party HP pct"
	)
	assert_lt(float(row["party_mp_pct"]), 1.0, "the priest spent MP on the heal")
	var stats: Dictionary = result.to_run_stats()
	assert_eq(
		int(stats["mp_exhausted_battle"]), 1,
		"priest max_mp 5 minus one 5-MP heal → total MP first hits 0 in battle 1"
	)


func test_exp_accumulates_and_level_ups_apply():
	var cfg := _make_config([_spec("F1", "human", "fighter", 1)], [{"xp_slime": 1}], 2)
	var result: ExpeditionResult = ExpeditionRunner.run_expedition(
		cfg, 0, _make_rng(), 100, _make_monster_repo([_xp_slime()]), _make_spell_repo()
	)
	assert_not_null(result)
	if result == null:
		return
	assert_eq(result.end_cause, "MAX_BATTLES")
	assert_eq(result.characters.size(), 1)
	if result.characters.size() != 1:
		return
	var ch: Character = result.characters[0]
	assert_eq(ch.accumulated_exp, 1200, "600 exp per cleared battle x 2 battles, solo share")
	assert_eq(ch.level, 2, "1200 exp crosses the fighter's 1000-exp level-2 threshold")
	var base_hp_at_level_1: int = ch.job.base_hp + int(ch.base_stats[&"VIT"]) / 3
	assert_gt(ch.max_hp, base_hp_at_level_1, "the level-up growth is applied to max HP")


# --- Reproducibility ---

func test_same_config_run_index_and_seed_produce_identical_rows():
	var repo := _make_monster_repo([_rat()])
	var cfg := _make_config([_spec("F1", "human", "fighter", 3)], [{"rat": 1}], 3)
	var first: ExpeditionResult = ExpeditionRunner.run_expedition(
		cfg, 2, _make_rng(), 100, repo, _make_spell_repo()
	)
	var second: ExpeditionResult = ExpeditionRunner.run_expedition(
		cfg, 2, _make_rng(), 100, repo, _make_spell_repo()
	)
	assert_not_null(first)
	assert_not_null(second)
	if first == null or second == null:
		return
	assert_eq(first.end_cause, second.end_cause)
	assert_eq(first.battle_rows, second.battle_rows, "identical seed → byte-identical rows")
	assert_eq(first.to_run_stats(), second.to_run_stats())


# --- Error handling ---

func test_party_factory_errors_return_null():
	var cfg := _make_config([_spec("F1", "human", "paladin", 1)], [{"slime": 1}], 3)
	var result: ExpeditionResult = ExpeditionRunner.run_expedition(
		cfg, 0, _make_rng(), 100, _make_monster_repo([_slime()]), _make_spell_repo()
	)
	assert_null(result, "factory errors are fatal: the runner returns null")
	assert_push_error("paladin")


# --- Production (no-injection) path with a table source ---

func test_table_mode_loads_floor_table_through_data_loader():
	var cfg := ExpeditionConfig.new()
	cfg.max_battles = 1
	cfg.party = [_spec("F1", "human", "fighter", 5)]
	cfg.encounter_mode = "table"
	cfg.encounter_floor = 3
	var result: ExpeditionResult = ExpeditionRunner.run_expedition(cfg, 0, _make_rng())
	assert_not_null(result, "production path must work with just (config, run_index, rng)")
	if result == null:
		return
	assert_eq(result.battle_rows.size(), 1, "max_battles 1 → exactly one battle entered")
	if result.battle_rows.size() == 1:
		assert_eq(result.battle_rows[0]["encounter"], "floor_3")
