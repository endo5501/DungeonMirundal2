extends GutTest

const TEST_SEED: int = 42


# Tests that monster casts route through _resolve_cast and fire the expected
# signals (actor_action_started / actor_spent_mp / actor_dealt_damage /
# actor_healed / actor_status_inflicted).

class _StubParty extends CombatActor:
	var _hp: int
	var _max: int
	var _mp: int = 0
	var _mp_max: int = 0
	var _row: int = Row.FRONT

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

	var original_row: int:
		get:
			return _row


func _make_rng(seed_value: int = TEST_SEED) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _make_monster_data(
	id: StringName,
	row: int,
	range_value: int,
	mp_min: int,
	mp_max: int,
	spells: Array,
	atk: int = 5,
	def_value: int = 2,
	agi: int = 5,
) -> MonsterData:
	var data := MonsterData.new()
	data.monster_id = id
	data.monster_name = String(id)
	data.max_hp_min = 20
	data.max_hp_max = 20
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


func _make_monster_combatant(data: MonsterData) -> MonsterCombatant:
	return MonsterCombatant.new(Monster.new(data, _make_rng()))


func _build_spell(id: StringName, target_type: int, mp_cost: int, effect: SpellEffect) -> SpellData:
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


func _make_repo(spells: Array) -> SpellRepository:
	var repo := SpellRepository.new()
	for s in spells:
		repo.register(s)
	return repo


# --- 4.1: witch casts fire on Fighter ---

func test_witch_casts_fire_on_fighter():
	var fire_effect := DamageSpellEffect.new()
	fire_effect.base_damage = 6
	fire_effect.spread = 0
	var fire := _build_spell(&"fire", SpellData.TargetType.ENEMY_ONE, 2, fire_effect)
	var data := _make_monster_data(&"witch", Row.BACK, WeaponRange.RANGED, 5, 5, [&"fire"], 1, 1, 99)
	var witch := _make_monster_combatant(data)
	var fighter := _StubParty.new("Fighter", 50, Row.FRONT)

	var engine := TurnEngine.new()
	engine.spell_repo = _make_repo([fire])
	engine.start_battle([fighter], [witch])
	engine.resolve_turn(_make_rng())

	# Fighter should have taken damage (cast actually fired)
	assert_lt(fighter.current_hp, 50, "Fighter should take fire damage")
	# Witch should have spent 2 MP
	assert_eq(witch.current_mp, 3, "Witch should have 5-2 = 3 MP after casting")


# --- 4.6 actor_spent_mp fires for monster casts ---

func test_monster_cast_emits_actor_spent_mp():
	var fire_effect := DamageSpellEffect.new()
	fire_effect.base_damage = 6
	fire_effect.spread = 0
	var fire := _build_spell(&"fire", SpellData.TargetType.ENEMY_ONE, 2, fire_effect)
	var data := _make_monster_data(&"witch", Row.FRONT, WeaponRange.MELEE, 5, 5, [&"fire"], 1, 1, 99)
	var witch := _make_monster_combatant(data)
	var fighter := _StubParty.new("Fighter", 50, Row.FRONT)

	var engine := TurnEngine.new()
	engine.spell_repo = _make_repo([fire])
	engine.start_battle([fighter], [witch])
	var spent_mp_events: Array = []
	engine.actor_spent_mp.connect(func(a, c): spent_mp_events.append([a, c]))
	engine.resolve_turn(_make_rng())

	assert_eq(spent_mp_events.size(), 1, "should have emitted actor_spent_mp once")
	if spent_mp_events.size() >= 1:
		assert_eq(spent_mp_events[0][0], witch)
		assert_eq(spent_mp_events[0][1], 2)


# --- 4.8 actor_dealt_damage fires with monster as source ---

func test_monster_cast_dealt_damage_signal_has_monster_as_source():
	var fire_effect := DamageSpellEffect.new()
	fire_effect.base_damage = 6
	fire_effect.spread = 0
	var fire := _build_spell(&"fire", SpellData.TargetType.ENEMY_ONE, 2, fire_effect)
	var data := _make_monster_data(&"witch", Row.FRONT, WeaponRange.MELEE, 5, 5, [&"fire"], 1, 1, 99)
	var witch := _make_monster_combatant(data)
	var fighter := _StubParty.new("Fighter", 50, Row.FRONT)

	var engine := TurnEngine.new()
	engine.spell_repo = _make_repo([fire])
	engine.start_battle([fighter], [witch])
	var dealt: Array = []
	engine.actor_dealt_damage.connect(func(t, a, s): dealt.append([t, a, s]))
	engine.resolve_turn(_make_rng())

	assert_gte(dealt.size(), 1)
	# Filter for the cast-damage event with witch as source
	var matching := dealt.filter(func(e): return e[2] == witch)
	assert_eq(matching.size(), 1, "witch should be source of one damage event")


# --- 4.7 actor_healed fires when monster heals an ally ---

func test_monster_heal_emits_actor_healed_with_monster_source():
	var heal_effect := HealSpellEffect.new()
	heal_effect.base_heal = 5
	heal_effect.spread = 0
	var heal := _build_spell(&"heal", SpellData.TargetType.ALLY_ONE, 2, heal_effect)
	var caster_data := _make_monster_data(&"dark_priest", Row.FRONT, WeaponRange.MELEE, 5, 5, [&"heal"], 1, 1, 99)
	var caster := _make_monster_combatant(caster_data)
	# Wounded peer
	var peer_data := _make_monster_data(&"imp", Row.FRONT, WeaponRange.MELEE, 0, 0, [], 1, 1, 1)
	var peer := _make_monster_combatant(peer_data)
	peer.current_hp = 5
	var fighter := _StubParty.new("Fighter", 50, Row.FRONT)

	var engine := TurnEngine.new()
	engine.spell_repo = _make_repo([heal])
	engine.start_battle([fighter], [caster, peer])
	var healed: Array = []
	engine.actor_healed.connect(func(t, a, s): healed.append([t, a, s]))
	engine.resolve_turn(_make_rng())

	assert_gte(healed.size(), 1)
	var by_caster := healed.filter(func(e): return e[2] == caster)
	assert_eq(by_caster.size(), 1, "should have one heal event sourced by caster")
	if by_caster.size() >= 1:
		assert_eq(by_caster[0][0], peer)


# --- side-relative: monster's ENEMY_ONE targets a party member ---

func test_monster_cast_enemy_one_targets_party_not_monster():
	var fire_effect := DamageSpellEffect.new()
	fire_effect.base_damage = 6
	fire_effect.spread = 0
	var fire := _build_spell(&"fire", SpellData.TargetType.ENEMY_ONE, 2, fire_effect)
	var data := _make_monster_data(&"witch", Row.FRONT, WeaponRange.MELEE, 5, 5, [&"fire"], 1, 1, 99)
	var witch := _make_monster_combatant(data)
	var fighter := _StubParty.new("Fighter", 50, Row.FRONT)

	var engine := TurnEngine.new()
	engine.spell_repo = _make_repo([fire])
	engine.start_battle([fighter], [witch])
	engine.resolve_turn(_make_rng())

	assert_lt(fighter.current_hp, 50, "fire should reduce party HP")
	assert_eq(witch.current_hp, 20, "monster caster should not damage itself")
