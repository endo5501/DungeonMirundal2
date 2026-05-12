extends GutTest

const TEST_SEED: int = 42


func _make_rng(seed_value: int = TEST_SEED) -> RandomNumberGenerator:
	return MonsterTestFactory.make_rng(seed_value)


func _make_monster(
	id: StringName,
	row: int = Row.FRONT,
	range_value: int = WeaponRange.MELEE,
	mp_min: int = 0,
	mp_max: int = 0,
	spells: Array = [],
) -> MonsterCombatant:
	var data := MonsterTestFactory.make_monster_data(id, row, range_value, mp_min, mp_max, spells)
	return MonsterTestFactory.make_monster_combatant(data, _make_rng())


func _build_ctx(party: Array, monsters: Array, spells: Array) -> MonsterAiContext:
	var engine := TurnEngine.new()
	engine.start_battle(party, monsters)
	return MonsterAiContext.new(party, monsters, MonsterTestFactory.make_repo(spells), engine)


# --- 3.3 / 3.4: empty known_spells -> AttackCommand ---

func test_no_spells_returns_attack_command_for_reachable_target():
	var monster := _make_monster(&"slime", Row.FRONT, WeaponRange.MELEE)
	var fighter := StubPartyCombatant.new("Fighter", 30, 0, Row.FRONT)
	var ctx := _build_ctx([fighter], [monster], [])
	var cmd: RefCounted = MonsterAi.choose(monster, ctx, _make_rng())
	assert_true(cmd is AttackCommand, "expected AttackCommand, got %s" % typeof(cmd))
	assert_eq((cmd as AttackCommand).target, fighter)


# --- 3.5: MELEE BACK + all FRONT party alive -> null (wait) ---

func test_melee_back_monster_with_no_reach_returns_null():
	var monster := _make_monster(&"slime", Row.BACK, WeaponRange.MELEE)
	# Place a FRONT-living monster peer so monster's row is NOT promoted.
	var peer := _make_monster(&"goblin", Row.FRONT, WeaponRange.MELEE)
	var fighter := StubPartyCombatant.new("Fighter", 30, 0, Row.FRONT)
	var ctx := _build_ctx([fighter], [peer, monster], [])
	var cmd: RefCounted = MonsterAi.choose(monster, ctx, _make_rng())
	assert_null(cmd, "MELEE BACK monster should return null when no reachable target")


# --- 3.6: all party dead -> null ---

func test_all_party_dead_returns_null():
	var monster := _make_monster(&"slime", Row.FRONT, WeaponRange.MELEE)
	var fighter := StubPartyCombatant.new("Fighter", 0, 0, Row.FRONT)
	var ctx := _build_ctx([fighter], [monster], [])
	var cmd: RefCounted = MonsterAi.choose(monster, ctx, _make_rng())
	assert_null(cmd)


# --- 3.7 / 3.8 / 3.10: candidate filter & ENEMY_ONE cast ---

func test_with_one_spell_returns_cast_command():
	var fire := MonsterTestFactory.build_damage_spell(&"fire", SpellData.TargetType.ENEMY_ONE, 2)
	var monster := _make_monster(&"witch", Row.BACK, WeaponRange.RANGED, 5, 5, [&"fire"])
	var fighter := StubPartyCombatant.new("Fighter", 30, 0, Row.FRONT)
	var ctx := _build_ctx([fighter], [monster], [fire])
	var cmd: RefCounted = MonsterAi.choose(monster, ctx, _make_rng())
	assert_true(cmd is CastCommand, "expected CastCommand")
	var cast := cmd as CastCommand
	assert_eq(cast.spell_id, &"fire")
	assert_eq(cast.target, fighter)


func test_insufficient_mp_excludes_spell_from_candidates():
	var fire := MonsterTestFactory.build_damage_spell(&"fire", SpellData.TargetType.ENEMY_ONE, 5)
	var monster := _make_monster(&"witch", Row.BACK, WeaponRange.RANGED, 2, 2, [&"fire"])
	var fighter := StubPartyCombatant.new("Fighter", 30, 0, Row.FRONT)
	var ctx := _build_ctx([fighter], [monster], [fire])
	var cmd: RefCounted = MonsterAi.choose(monster, ctx, _make_rng())
	assert_true(cmd is AttackCommand, "should fall back to AttackCommand when no MP")


func test_silenced_monster_falls_back_to_attack():
	var fire := MonsterTestFactory.build_damage_spell(&"fire", SpellData.TargetType.ENEMY_ONE, 2)
	var monster := _make_monster(&"witch", Row.FRONT, WeaponRange.MELEE, 5, 5, [&"fire"])
	var status_repo := DataLoader.new().load_status_repository()
	monster.set_status_repo_for_testing(status_repo)
	monster.statuses.apply(&"silence", 3)
	var fighter := StubPartyCombatant.new("Fighter", 30, 0, Row.FRONT)
	var ctx := _build_ctx([fighter], [monster], [fire])
	var cmd: RefCounted = MonsterAi.choose(monster, ctx, _make_rng())
	assert_true(cmd is AttackCommand, "silenced monster should fall back to attack")


# --- ENEMY_GROUP precondition: need >=2 living party members ---

func test_enemy_group_requires_two_or_more_party_members():
	var flame := MonsterTestFactory.build_damage_spell(&"flame", SpellData.TargetType.ENEMY_GROUP, 4, 5)
	var monster := _make_monster(&"lich", Row.BACK, WeaponRange.RANGED, 10, 10, [&"flame"])
	var fighter := StubPartyCombatant.new("Fighter", 30, 0, Row.FRONT)
	var ctx := _build_ctx([fighter], [monster], [flame])
	var cmd: RefCounted = MonsterAi.choose(monster, ctx, _make_rng())
	assert_true(cmd is AttackCommand, "single-party-member should disqualify ENEMY_GROUP")


func test_enemy_group_allowed_with_two_party_members():
	var flame := MonsterTestFactory.build_damage_spell(&"flame", SpellData.TargetType.ENEMY_GROUP, 4, 5)
	var monster := _make_monster(&"lich", Row.BACK, WeaponRange.RANGED, 10, 10, [&"flame"])
	var fighter := StubPartyCombatant.new("Fighter", 30, 0, Row.FRONT)
	var mage := StubPartyCombatant.new("Mage", 20, 0, Row.BACK)
	var ctx := _build_ctx([fighter, mage], [monster], [flame])
	var cmd: RefCounted = MonsterAi.choose(monster, ctx, _make_rng())
	assert_true(cmd is CastCommand, "two party members satisfy ENEMY_GROUP precondition")


# --- 3.11: ALLY_ONE heal targets lowest-HP wounded ally ---

func test_heal_targets_lowest_hp_wounded_ally():
	var heal := MonsterTestFactory.build_heal_spell(&"heal", 5, 2)
	var caster := _make_monster(&"dark_priest", Row.BACK, WeaponRange.MELEE, 5, 5, [&"heal"])
	var wounded := _make_monster(&"imp_a", Row.FRONT)
	wounded.current_hp = 5
	var full := _make_monster(&"imp_b", Row.FRONT)
	var fighter := StubPartyCombatant.new("Fighter", 30, 0, Row.FRONT)
	var ctx := _build_ctx([fighter], [caster, wounded, full], [heal])
	var cmd: RefCounted = MonsterAi.choose(caster, ctx, _make_rng())
	assert_true(cmd is CastCommand)
	assert_eq((cmd as CastCommand).target, wounded, "heal should target the wounded ally")


func test_heal_filtered_out_when_no_wounded_ally():
	var heal := MonsterTestFactory.build_heal_spell(&"heal", 5, 2)
	var caster := _make_monster(&"dark_priest", Row.FRONT, WeaponRange.MELEE, 5, 5, [&"heal"])
	var fighter := StubPartyCombatant.new("Fighter", 30, 0, Row.FRONT)
	var ctx := _build_ctx([fighter], [caster], [heal])
	var cmd: RefCounted = MonsterAi.choose(caster, ctx, _make_rng())
	assert_true(cmd is AttackCommand, "heal should be filtered out when no wounded ally")


# --- ALLY_ONE cure: requires a same-side ally with the named status ---

func test_cure_filtered_out_when_no_ally_has_status():
	var dios := MonsterTestFactory.build_cure_spell(&"dios", &"sleep", 2)
	var caster := _make_monster(&"dark_priest", Row.FRONT, WeaponRange.MELEE, 5, 5, [&"dios"])
	var fighter := StubPartyCombatant.new("Fighter", 30, 0, Row.FRONT)
	var ctx := _build_ctx([fighter], [caster], [dios])
	var cmd: RefCounted = MonsterAi.choose(caster, ctx, _make_rng())
	assert_true(cmd is AttackCommand, "cure should be filtered out when no ally has the status")


# --- 3.12: ALLY_ALL cast leaves target null ---

func test_ally_all_cast_target_is_null():
	var allheal_effect := HealSpellEffect.new()
	allheal_effect.base_heal = 5
	var allheal := MonsterTestFactory.build_spell(&"allheal", SpellData.TargetType.ALLY_ALL, 4, allheal_effect)
	var caster := _make_monster(&"dark_priest", Row.FRONT, WeaponRange.MELEE, 8, 8, [&"allheal"])
	var ally := _make_monster(&"imp", Row.FRONT)
	ally.current_hp = 5
	var fighter := StubPartyCombatant.new("Fighter", 30, 0, Row.FRONT)
	var ctx := _build_ctx([fighter], [caster, ally], [allheal])
	var cmd: RefCounted = MonsterAi.choose(caster, ctx, _make_rng())
	assert_true(cmd is CastCommand)
	assert_eq((cmd as CastCommand).target, null)


# --- 3.9: deterministic under fixed seed ---

func test_deterministic_under_fixed_seed():
	var fire := MonsterTestFactory.build_damage_spell(&"fire", SpellData.TargetType.ENEMY_ONE, 2)
	var frost := MonsterTestFactory.build_damage_spell(&"frost", SpellData.TargetType.ENEMY_ONE, 2)
	var data := MonsterTestFactory.make_monster_data(&"witch", Row.BACK, WeaponRange.RANGED, 5, 5, [&"fire", &"frost"])
	var fighter := StubPartyCombatant.new("Fighter", 30, 0, Row.FRONT)
	var monster_a := MonsterTestFactory.make_monster_combatant(data, _make_rng())
	var ctx_a := _build_ctx([fighter], [monster_a], [fire, frost])
	var cmd_a: RefCounted = MonsterAi.choose(monster_a, ctx_a, _make_rng(99))
	var fighter_b := StubPartyCombatant.new("Fighter", 30, 0, Row.FRONT)
	var monster_b := MonsterTestFactory.make_monster_combatant(data, _make_rng())
	var ctx_b := _build_ctx([fighter_b], [monster_b], [fire, frost])
	var cmd_b: RefCounted = MonsterAi.choose(monster_b, ctx_b, _make_rng(99))
	assert_eq(typeof(cmd_a), typeof(cmd_b))
	if cmd_a is CastCommand and cmd_b is CastCommand:
		assert_eq((cmd_a as CastCommand).spell_id, (cmd_b as CastCommand).spell_id)


# --- 3.10: ENEMY_ONE cast does NOT apply reach gating ---

func test_cast_target_ignores_reach():
	var fire := MonsterTestFactory.build_damage_spell(&"fire", SpellData.TargetType.ENEMY_ONE, 2)
	# MELEE BACK monster - normally cannot reach
	var monster := _make_monster(&"witch", Row.BACK, WeaponRange.MELEE, 5, 5, [&"fire"])
	var peer := _make_monster(&"goblin", Row.FRONT, WeaponRange.MELEE)
	var fighter := StubPartyCombatant.new("Fighter", 30, 0, Row.FRONT)
	var ctx := _build_ctx([fighter], [peer, monster], [fire])
	var cmd: RefCounted = MonsterAi.choose(monster, ctx, _make_rng())
	assert_true(cmd is CastCommand, "cast bypasses reach gating")
	assert_eq((cmd as CastCommand).target, fighter)
