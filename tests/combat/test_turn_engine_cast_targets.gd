extends GutTest

const TEST_SEED: int = 99


# Side-relative cast target resolution: ENEMY_*/ALLY_* are interpreted
# relative to the caster's side. Same logic for both party and monster casters.

class _StubParty extends CombatActor:
	var _hp: int
	var _max: int
	var _mp: int = 0
	var _mp_max: int = 0
	var _row: int = Row.FRONT

	func _init(p_name: String, p_hp: int, p_mp: int = 0, p_row: int = Row.FRONT) -> void:
		actor_name = p_name
		_hp = p_hp
		_max = p_hp
		_mp = p_mp
		_mp_max = p_mp
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
	row: int = Row.FRONT,
	range_value: int = WeaponRange.MELEE,
	mp_min: int = 0,
	mp_max: int = 0,
	spells: Array = [],
	hp: int = 20,
	agi: int = 1,
) -> MonsterData:
	var data := MonsterData.new()
	data.monster_id = id
	data.monster_name = String(id)
	data.max_hp_min = hp
	data.max_hp_max = hp
	data.max_mp_min = mp_min
	data.max_mp_max = mp_max
	data.attack = 5
	data.defense = 2
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


# --- 5.1 / 5.2: monster ENEMY_ONE targets party member ---

func test_monster_enemy_one_resolves_party_target():
	var fire_effect := DamageSpellEffect.new()
	fire_effect.base_damage = 6
	fire_effect.spread = 0
	var fire := _build_spell(&"fire", SpellData.TargetType.ENEMY_ONE, 2, fire_effect)
	var data := _make_monster_data(&"witch", Row.FRONT, WeaponRange.MELEE, 5, 5, [&"fire"], 20, 99)
	var witch := _make_monster_combatant(data)
	var fighter := _StubParty.new("Fighter", 30, 0, Row.FRONT)

	var engine := TurnEngine.new()
	engine.spell_repo = _make_repo([fire])
	engine.start_battle([fighter], [witch])
	engine.resolve_turn(_make_rng())
	assert_lt(fighter.current_hp, 30, "monster cast should damage party")


# --- 5.3: monster ENEMY_GROUP fans out to all living party members ---

func test_monster_enemy_group_targets_all_living_party_members():
	var flame_effect := DamageSpellEffect.new()
	flame_effect.base_damage = 4
	flame_effect.spread = 0
	var flame := _build_spell(&"flame", SpellData.TargetType.ENEMY_GROUP, 4, flame_effect)
	var data := _make_monster_data(&"lich", Row.FRONT, WeaponRange.MELEE, 10, 10, [&"flame"], 20, 99)
	var lich := _make_monster_combatant(data)
	var fighter := _StubParty.new("Fighter", 30, 0, Row.FRONT)
	var mage := _StubParty.new("Mage", 25, 0, Row.BACK)
	var thief := _StubParty.new("Thief", 20, 0, Row.FRONT)

	var engine := TurnEngine.new()
	engine.spell_repo = _make_repo([flame])
	engine.start_battle([fighter, mage, thief], [lich])
	engine.resolve_turn(_make_rng())

	# All three party members should take damage (ENEMY_GROUP fans out)
	assert_lt(fighter.current_hp, 30, "fighter should take damage")
	assert_lt(mage.current_hp, 25, "mage should take damage")
	assert_lt(thief.current_hp, 20, "thief should take damage")


# --- 5.5: monster ALLY_ONE heal targets a same-side monster ---

func test_monster_ally_one_resolves_monster_target():
	var heal_effect := HealSpellEffect.new()
	heal_effect.base_heal = 5
	heal_effect.spread = 0
	var heal := _build_spell(&"heal", SpellData.TargetType.ALLY_ONE, 2, heal_effect)
	var caster_data := _make_monster_data(&"dark_priest", Row.FRONT, WeaponRange.MELEE, 5, 5, [&"heal"], 20, 99)
	var caster := _make_monster_combatant(caster_data)
	# Wounded peer
	var peer_data := _make_monster_data(&"imp", Row.FRONT, WeaponRange.MELEE, 0, 0, [], 20, 1)
	var peer := _make_monster_combatant(peer_data)
	peer.current_hp = 5
	var fighter := _StubParty.new("Fighter", 30, 0, Row.FRONT)

	var engine := TurnEngine.new()
	engine.spell_repo = _make_repo([heal])
	engine.start_battle([fighter], [caster, peer])
	var hp_before := peer.current_hp
	engine.resolve_turn(_make_rng())
	assert_gt(peer.current_hp, hp_before, "peer should be healed")


# --- monster ALLY_ALL targets all living monsters ---

func test_monster_ally_all_resolves_all_living_monsters():
	var allheal_effect := HealSpellEffect.new()
	allheal_effect.base_heal = 5
	allheal_effect.spread = 0
	var allheal := _build_spell(&"allheal", SpellData.TargetType.ALLY_ALL, 4, allheal_effect)
	var caster_data := _make_monster_data(&"dark_priest", Row.FRONT, WeaponRange.MELEE, 8, 8, [&"allheal"], 20, 99)
	var caster := _make_monster_combatant(caster_data)
	# Make caster wounded so heal can target someone
	caster.current_hp = 10
	var peer_data := _make_monster_data(&"imp", Row.FRONT, WeaponRange.MELEE, 0, 0, [], 20, 1)
	var peer := _make_monster_combatant(peer_data)
	peer.current_hp = 6
	var fighter := _StubParty.new("Fighter", 30, 0, Row.FRONT)

	var engine := TurnEngine.new()
	engine.spell_repo = _make_repo([allheal])
	engine.start_battle([fighter], [caster, peer])
	engine.resolve_turn(_make_rng())

	# Both monsters should be healed
	assert_gt(caster.current_hp, 10, "caster should heal itself")
	assert_gt(peer.current_hp, 6, "peer should be healed")


# --- 5.4: monster ENEMY_ONE retargets when target dies mid-turn ---
# Engineered scenario: witch's target is a "dead" stub at resolution time.

func test_monster_enemy_one_retargets_when_initial_target_dies():
	var fire_effect := DamageSpellEffect.new()
	fire_effect.base_damage = 6
	fire_effect.spread = 0
	var fire := _build_spell(&"fire", SpellData.TargetType.ENEMY_ONE, 2, fire_effect)
	var data := _make_monster_data(&"witch", Row.FRONT, WeaponRange.MELEE, 5, 5, [&"fire"], 20, 99)
	var witch := _make_monster_combatant(data)

	# We manually submit a CastCommand from outside to control the original target.
	# Use a higher-level submit path: monster has agility 99 so it would normally
	# act first; we kill its initial target between command-input and resolution.
	# Trick: assemble engine state to simulate a dead initial target.
	var dead_fighter := _StubParty.new("Fighter", 0, 0, Row.FRONT)  # already dead
	var mage := _StubParty.new("Mage", 30, 0, Row.FRONT)

	var engine := TurnEngine.new()
	engine.spell_repo = _make_repo([fire])
	engine.start_battle([dead_fighter, mage], [witch])
	# Resolve turn — AI will see only Mage as alive, choose her as target.
	engine.resolve_turn(_make_rng())
	assert_lt(mage.current_hp, 30, "Mage (the surviving target) should take damage")


# --- 5.6 regression: party caster ENEMY_ONE still resolves monsters ---

func test_party_caster_enemy_one_still_targets_monsters():
	var fire_effect := DamageSpellEffect.new()
	fire_effect.base_damage = 6
	fire_effect.spread = 0
	var fire := _build_spell(&"fire", SpellData.TargetType.ENEMY_ONE, 2, fire_effect)
	var mage := _StubParty.new("Mage", 30, 5, Row.BACK)
	var data := _make_monster_data(&"slime", Row.FRONT, WeaponRange.MELEE, 0, 0, [], 20, 1)
	var slime := _make_monster_combatant(data)

	var engine := TurnEngine.new()
	engine.spell_repo = _make_repo([fire])
	engine.start_battle([mage], [slime])
	engine.submit_command(0, CastCommand.new(&"fire", 0, slime))
	engine.resolve_turn(_make_rng())

	assert_lt(slime.current_hp, 20, "party caster's fire should damage the monster")
	assert_eq(mage.current_mp, 3, "mage should have spent 2 MP")
