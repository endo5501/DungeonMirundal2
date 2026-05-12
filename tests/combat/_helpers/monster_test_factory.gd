class_name MonsterTestFactory
extends RefCounted

# Factory helpers for combat tests that need MonsterData / MonsterCombatant /
# SpellData / SpellRepository instances without going through .tres files.

const DEFAULT_SEED: int = 12345


static func make_rng(seed_value: int = DEFAULT_SEED) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


static func make_monster_data(
	id: StringName,
	row: int = Row.FRONT,
	range_value: int = WeaponRange.MELEE,
	mp_min: int = 0,
	mp_max: int = 0,
	spells: Array = [],
	hp: int = 20,
	atk: int = 5,
	def_value: int = 2,
	agi: int = 5,
) -> MonsterData:
	var data := MonsterData.new()
	data.monster_id = id
	data.monster_name = String(id)
	data.max_hp_min = hp
	data.max_hp_max = hp
	data.max_mp_min = mp_min
	data.max_mp_max = mp_max
	data.attack = atk
	data.defense = def_value
	data.agility = agi
	data.experience = 10
	data.default_row = row
	data.attack_range = range_value
	var typed: Array[StringName] = []
	for s in spells:
		typed.append(s)
	data.known_spells = typed
	return data


static func make_monster_combatant(data: MonsterData, rng: RandomNumberGenerator = null) -> MonsterCombatant:
	var seeded_rng: RandomNumberGenerator = rng if rng != null else make_rng()
	return MonsterCombatant.new(Monster.new(data, seeded_rng))


static func build_spell(id: StringName, target_type: int, mp_cost: int, effect: SpellEffect) -> SpellData:
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


static func build_damage_spell(id: StringName, target_type: int, mp_cost: int, damage: int = 6) -> SpellData:
	var effect := DamageSpellEffect.new()
	effect.base_damage = damage
	effect.spread = 0
	return build_spell(id, target_type, mp_cost, effect)


static func build_heal_spell(id: StringName, heal: int = 5, mp_cost: int = 2) -> SpellData:
	var effect := HealSpellEffect.new()
	effect.base_heal = heal
	effect.spread = 0
	return build_spell(id, SpellData.TargetType.ALLY_ONE, mp_cost, effect)


static func build_cure_spell(id: StringName, status_id: StringName, mp_cost: int = 2) -> SpellData:
	var effect := CureStatusSpellEffect.new()
	effect.status_id = status_id
	return build_spell(id, SpellData.TargetType.ALLY_ONE, mp_cost, effect)


static func make_repo(spells: Array) -> SpellRepository:
	var repo := SpellRepository.new()
	for s in spells:
		repo.register(s)
	return repo


# Reset the DataLoader status_repo cache and wire a fresh StatusRepository into
# the given engine + every combatant. Use at the start of any test that asserts
# status-flag behavior via TurnEngine.
static func wire_status_repo(engine: TurnEngine) -> StatusRepository:
	DataLoader._status_repo_cache = null
	var repo := DataLoader.new().load_status_repository()
	engine.status_repo = repo
	for a in engine.party + engine.monsters:
		if a != null:
			a.set_status_repo_for_testing(repo)
	return repo
