extends GutTest

const TEST_SEED: int = 42


# --- helpers ---

class _StubParty extends CombatActor:
	var _hp: int
	var _max: int
	var _row: int
	var _mp: int = 0
	var _mp_max: int = 0

	func _init(p_name: String, p_hp: int, p_row: int = Row.FRONT) -> void:
		actor_name = p_name
		_hp = p_hp
		_max = p_hp
		_row = p_row

	func _read_current_hp() -> int:
		return _hp

	func _write_current_hp(value: int) -> void:
		_hp = value

	func _read_max_hp() -> int:
		return _max

	func _read_current_mp() -> int:
		return _mp

	func _write_current_mp(value: int) -> void:
		_mp = value

	func _read_max_mp() -> int:
		return _mp_max

	# Used by TurnEngine.effective_row / can_reach
	var original_row: int:
		get:
			return _row


func _make_rng(seed_value: int = TEST_SEED) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _make_monster_data(
	id: StringName,
	row: int = Row.FRONT,
	range_value: int = WeaponRange.MELEE,
	mp_min: int = 0,
	mp_max: int = 0,
	spells: Array = [],
) -> MonsterData:
	var data := MonsterData.new()
	data.monster_id = id
	data.monster_name = String(id)
	data.max_hp_min = 20
	data.max_hp_max = 20
	data.max_mp_min = mp_min
	data.max_mp_max = mp_max
	data.attack = 5
	data.defense = 2
	data.agility = 5
	data.experience = 10
	data.default_row = row
	data.attack_range = range_value
	var typed_spells: Array[StringName] = []
	for s in spells:
		typed_spells.append(s)
	data.known_spells = typed_spells
	return data


func _make_monster_combatant(data: MonsterData) -> MonsterCombatant:
	var m := Monster.new(data, _make_rng())
	return MonsterCombatant.new(m)


func _build_spell(
	id: StringName,
	target_type: int,
	mp_cost: int,
	effect: SpellEffect,
) -> SpellData:
	var spell := SpellData.new()
	spell.id = id
	spell.display_name = String(id)
	spell.school = SpellData.SCHOOL_MAGE
	spell.level = 1
	spell.mp_cost = mp_cost
	spell.target_type = target_type
	spell.scope = SpellData.Scope.BATTLE_ONLY
	spell.effect = effect
	return spell


func _build_damage_spell(id: StringName, target_type: int, mp_cost: int, damage: int = 6) -> SpellData:
	var effect := DamageSpellEffect.new()
	effect.base_damage = damage
	effect.spread = 0
	return _build_spell(id, target_type, mp_cost, effect)


func _build_heal_spell(id: StringName, mp_cost: int = 2) -> SpellData:
	var effect := HealSpellEffect.new()
	effect.base_heal = 5
	effect.spread = 0
	return _build_spell(id, SpellData.TargetType.ALLY_ONE, mp_cost, effect)


func _build_cure_spell(id: StringName, status_id: StringName, mp_cost: int = 2) -> SpellData:
	var effect := CureStatusSpellEffect.new()
	effect.status_id = status_id
	return _build_spell(id, SpellData.TargetType.ALLY_ONE, mp_cost, effect)


func _build_ctx(party: Array, monsters: Array, spells: Array) -> MonsterAiContext:
	var spell_repo := SpellRepository.new()
	for s in spells:
		spell_repo.register(s)
	var engine := TurnEngine.new()
	engine.start_battle(party, monsters)
	# AI does not need a real status_repo for most cases
	return MonsterAiContext.new(party, monsters, spell_repo, null, engine)


# --- 3.3 / 3.4: empty known_spells -> AttackCommand ---

func test_no_spells_returns_attack_command_for_reachable_target():
	var data := _make_monster_data(&"slime", Row.FRONT, WeaponRange.MELEE)
	var monster := _make_monster_combatant(data)
	var fighter := _StubParty.new("Fighter", 30, Row.FRONT)
	var ctx := _build_ctx([fighter], [monster], [])
	var cmd: RefCounted = MonsterAi.choose(monster, ctx, _make_rng())
	assert_true(cmd is AttackCommand, "expected AttackCommand, got %s" % typeof(cmd))
	assert_eq((cmd as AttackCommand).target, fighter)


# --- 3.5: MELEE BACK + all FRONT party alive -> null (wait) ---

func test_melee_back_monster_with_no_reach_returns_null():
	var data := _make_monster_data(&"slime", Row.BACK, WeaponRange.MELEE)
	var monster := _make_monster_combatant(data)
	# Place a FRONT-living monster peer so monster's row is NOT promoted.
	var peer := _make_monster_combatant(_make_monster_data(&"goblin", Row.FRONT, WeaponRange.MELEE))
	var fighter := _StubParty.new("Fighter", 30, Row.FRONT)
	var ctx := _build_ctx([fighter], [peer, monster], [])
	var cmd: RefCounted = MonsterAi.choose(monster, ctx, _make_rng())
	assert_null(cmd, "MELEE BACK monster should return null when no reachable target")


# --- 3.6: all party dead -> null ---

func test_all_party_dead_returns_null():
	var data := _make_monster_data(&"slime", Row.FRONT, WeaponRange.MELEE)
	var monster := _make_monster_combatant(data)
	var fighter := _StubParty.new("Fighter", 0, Row.FRONT) # already dead
	var ctx := _build_ctx([fighter], [monster], [])
	var cmd: RefCounted = MonsterAi.choose(monster, ctx, _make_rng())
	assert_null(cmd)


# --- 3.7 / 3.8 / 3.10: candidate filter & ENEMY_ONE cast ---

func test_with_one_spell_returns_cast_command():
	var fire := _build_damage_spell(&"fire", SpellData.TargetType.ENEMY_ONE, 2)
	var data := _make_monster_data(&"witch", Row.BACK, WeaponRange.RANGED, 5, 5, [&"fire"])
	var monster := _make_monster_combatant(data)
	var fighter := _StubParty.new("Fighter", 30, Row.FRONT)
	var ctx := _build_ctx([fighter], [monster], [fire])
	var cmd: RefCounted = MonsterAi.choose(monster, ctx, _make_rng())
	assert_true(cmd is CastCommand, "expected CastCommand")
	var cast := cmd as CastCommand
	assert_eq(cast.spell_id, &"fire")
	assert_eq(cast.target, fighter)


func test_insufficient_mp_excludes_spell_from_candidates():
	var fire := _build_damage_spell(&"fire", SpellData.TargetType.ENEMY_ONE, 5)
	var data := _make_monster_data(&"witch", Row.BACK, WeaponRange.RANGED, 2, 2, [&"fire"])
	var monster := _make_monster_combatant(data)
	var fighter := _StubParty.new("Fighter", 30, Row.FRONT)
	var ctx := _build_ctx([fighter], [monster], [fire])
	var cmd: RefCounted = MonsterAi.choose(monster, ctx, _make_rng())
	# MP unavailable -> fall through to attack
	assert_true(cmd is AttackCommand, "should fall back to AttackCommand when no MP")


func test_silenced_monster_falls_back_to_attack():
	var fire := _build_damage_spell(&"fire", SpellData.TargetType.ENEMY_ONE, 2)
	var data := _make_monster_data(&"witch", Row.FRONT, WeaponRange.MELEE, 5, 5, [&"fire"])
	var monster := _make_monster_combatant(data)
	var status_repo := DataLoader.new().load_status_repository()
	monster.set_status_repo_for_testing(status_repo)
	monster.statuses.apply(&"silence", 3)
	var fighter := _StubParty.new("Fighter", 30, Row.FRONT)
	var ctx := _build_ctx([fighter], [monster], [fire])
	ctx.status_repo = status_repo
	var cmd: RefCounted = MonsterAi.choose(monster, ctx, _make_rng())
	assert_true(cmd is AttackCommand, "silenced monster should fall back to attack")


# --- ENEMY_GROUP precondition: need >=2 living party members ---

func test_enemy_group_requires_two_or_more_party_members():
	var flame := _build_damage_spell(&"flame", SpellData.TargetType.ENEMY_GROUP, 4, 5)
	var data := _make_monster_data(&"lich", Row.BACK, WeaponRange.RANGED, 10, 10, [&"flame"])
	var monster := _make_monster_combatant(data)
	var fighter := _StubParty.new("Fighter", 30, Row.FRONT)
	var ctx := _build_ctx([fighter], [monster], [flame])
	var cmd: RefCounted = MonsterAi.choose(monster, ctx, _make_rng())
	# Only 1 party member alive — ENEMY_GROUP filtered out, fall back to attack
	assert_true(cmd is AttackCommand, "single-party-member should disqualify ENEMY_GROUP")


func test_enemy_group_allowed_with_two_party_members():
	var flame := _build_damage_spell(&"flame", SpellData.TargetType.ENEMY_GROUP, 4, 5)
	var data := _make_monster_data(&"lich", Row.BACK, WeaponRange.RANGED, 10, 10, [&"flame"])
	var monster := _make_monster_combatant(data)
	var fighter := _StubParty.new("Fighter", 30, Row.FRONT)
	var mage := _StubParty.new("Mage", 20, Row.BACK)
	var ctx := _build_ctx([fighter, mage], [monster], [flame])
	var cmd: RefCounted = MonsterAi.choose(monster, ctx, _make_rng())
	assert_true(cmd is CastCommand, "two party members satisfy ENEMY_GROUP precondition")


# --- 3.11: ALLY_ONE heal targets lowest-HP wounded ally ---

func test_heal_targets_lowest_hp_wounded_ally():
	var heal := _build_heal_spell(&"heal", 2)
	var caster_data := _make_monster_data(&"dark_priest", Row.BACK, WeaponRange.MELEE, 5, 5, [&"heal"])
	var caster := _make_monster_combatant(caster_data)
	# Two ally peers: one wounded (5/20), one full (20/20)
	var wounded_data := _make_monster_data(&"imp_a", Row.FRONT)
	var wounded := _make_monster_combatant(wounded_data)
	wounded.current_hp = 5
	var full_data := _make_monster_data(&"imp_b", Row.FRONT)
	var full := _make_monster_combatant(full_data)
	var fighter := _StubParty.new("Fighter", 30, Row.FRONT)
	var ctx := _build_ctx([fighter], [caster, wounded, full], [heal])
	var cmd: RefCounted = MonsterAi.choose(caster, ctx, _make_rng())
	assert_true(cmd is CastCommand)
	var cast := cmd as CastCommand
	assert_eq(cast.target, wounded, "heal should target the wounded ally")


func test_heal_filtered_out_when_no_wounded_ally():
	var heal := _build_heal_spell(&"heal", 2)
	var caster_data := _make_monster_data(&"dark_priest", Row.FRONT, WeaponRange.MELEE, 5, 5, [&"heal"])
	var caster := _make_monster_combatant(caster_data)
	# All allies full HP
	var fighter := _StubParty.new("Fighter", 30, Row.FRONT)
	var ctx := _build_ctx([fighter], [caster], [heal])
	var cmd: RefCounted = MonsterAi.choose(caster, ctx, _make_rng())
	# heal filtered out -> fall back to attack
	assert_true(cmd is AttackCommand, "heal should be filtered out when no wounded ally")


# --- ALLY_ONE cure: requires a same-side ally with the named status ---

func test_cure_filtered_out_when_no_ally_has_status():
	var dios := _build_cure_spell(&"dios", &"sleep", 2)
	var caster_data := _make_monster_data(&"dark_priest", Row.FRONT, WeaponRange.MELEE, 5, 5, [&"dios"])
	var caster := _make_monster_combatant(caster_data)
	var fighter := _StubParty.new("Fighter", 30, Row.FRONT)
	var ctx := _build_ctx([fighter], [caster], [dios])
	var cmd: RefCounted = MonsterAi.choose(caster, ctx, _make_rng())
	assert_true(cmd is AttackCommand, "cure should be filtered out when no ally has the status")


# --- 3.12: ALLY_ALL cast leaves target null ---

func test_ally_all_cast_target_is_null():
	var allheal_effect := HealSpellEffect.new()
	allheal_effect.base_heal = 5
	var allheal := _build_spell(&"allheal", SpellData.TargetType.ALLY_ALL, 4, allheal_effect)
	var caster_data := _make_monster_data(&"dark_priest", Row.FRONT, WeaponRange.MELEE, 8, 8, [&"allheal"])
	var caster := _make_monster_combatant(caster_data)
	var ally_data := _make_monster_data(&"imp", Row.FRONT)
	var ally := _make_monster_combatant(ally_data)
	ally.current_hp = 5
	var fighter := _StubParty.new("Fighter", 30, Row.FRONT)
	var ctx := _build_ctx([fighter], [caster, ally], [allheal])
	var cmd: RefCounted = MonsterAi.choose(caster, ctx, _make_rng())
	assert_true(cmd is CastCommand)
	assert_eq((cmd as CastCommand).target, null)


# --- 3.9: deterministic under fixed seed ---

func test_deterministic_under_fixed_seed():
	var fire := _build_damage_spell(&"fire", SpellData.TargetType.ENEMY_ONE, 2)
	var frost := _build_damage_spell(&"frost", SpellData.TargetType.ENEMY_ONE, 2)
	var data := _make_monster_data(&"witch", Row.BACK, WeaponRange.RANGED, 5, 5, [&"fire", &"frost"])
	var fighter := _StubParty.new("Fighter", 30, Row.FRONT)
	# Two identical setups with identically-seeded RNG
	var monster_a := _make_monster_combatant(data)
	var ctx_a := _build_ctx([fighter], [monster_a], [fire, frost])
	var cmd_a: RefCounted = MonsterAi.choose(monster_a, ctx_a, _make_rng(99))
	var fighter_b := _StubParty.new("Fighter", 30, Row.FRONT)
	var monster_b := _make_monster_combatant(data)
	var ctx_b := _build_ctx([fighter_b], [monster_b], [fire, frost])
	var cmd_b: RefCounted = MonsterAi.choose(monster_b, ctx_b, _make_rng(99))
	assert_eq(typeof(cmd_a), typeof(cmd_b))
	if cmd_a is CastCommand and cmd_b is CastCommand:
		assert_eq((cmd_a as CastCommand).spell_id, (cmd_b as CastCommand).spell_id)


# --- 3.10: ENEMY_ONE cast does NOT apply reach gating ---

func test_cast_target_ignores_reach():
	var fire := _build_damage_spell(&"fire", SpellData.TargetType.ENEMY_ONE, 2)
	# MELEE BACK monster - normally cannot reach
	var data := _make_monster_data(&"witch", Row.BACK, WeaponRange.MELEE, 5, 5, [&"fire"])
	var monster := _make_monster_combatant(data)
	# Place a peer so monster does not promote to FRONT
	var peer := _make_monster_combatant(_make_monster_data(&"goblin", Row.FRONT, WeaponRange.MELEE))
	var fighter := _StubParty.new("Fighter", 30, Row.FRONT)
	var ctx := _build_ctx([fighter], [peer, monster], [fire])
	var cmd: RefCounted = MonsterAi.choose(monster, ctx, _make_rng())
	# Even though reach is impossible, cast should still target the party
	assert_true(cmd is CastCommand, "cast bypasses reach gating")
	assert_eq((cmd as CastCommand).target, fighter)
