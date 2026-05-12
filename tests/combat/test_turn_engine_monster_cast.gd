extends GutTest

const TEST_SEED: int = 42


func _make_rng(seed_value: int = TEST_SEED) -> RandomNumberGenerator:
	return MonsterTestFactory.make_rng(seed_value)


# --- 4.1: witch casts fire on Fighter ---

func test_witch_casts_fire_on_fighter():
	var fire := MonsterTestFactory.build_damage_spell(&"fire", SpellData.TargetType.ENEMY_ONE, 2, 6)
	var data := MonsterTestFactory.make_monster_data(
		&"witch", Row.BACK, WeaponRange.RANGED, 5, 5, [&"fire"], 20, 1, 1, 99
	)
	var witch := MonsterTestFactory.make_monster_combatant(data, _make_rng())
	var fighter := StubPartyCombatant.new("Fighter", 50, 0, Row.FRONT)

	var engine := TurnEngine.new()
	engine.spell_repo = MonsterTestFactory.make_repo([fire])
	engine.start_battle([fighter], [witch])
	engine.resolve_turn(_make_rng())

	assert_lt(fighter.current_hp, 50, "Fighter should take fire damage")
	assert_eq(witch.current_mp, 3, "Witch should have 5-2 = 3 MP after casting")


# --- 4.6 actor_spent_mp fires for monster casts ---

func test_monster_cast_emits_actor_spent_mp():
	var fire := MonsterTestFactory.build_damage_spell(&"fire", SpellData.TargetType.ENEMY_ONE, 2, 6)
	var data := MonsterTestFactory.make_monster_data(
		&"witch", Row.FRONT, WeaponRange.MELEE, 5, 5, [&"fire"], 20, 1, 1, 99
	)
	var witch := MonsterTestFactory.make_monster_combatant(data, _make_rng())
	var fighter := StubPartyCombatant.new("Fighter", 50, 0, Row.FRONT)

	var engine := TurnEngine.new()
	engine.spell_repo = MonsterTestFactory.make_repo([fire])
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
	var fire := MonsterTestFactory.build_damage_spell(&"fire", SpellData.TargetType.ENEMY_ONE, 2, 6)
	var data := MonsterTestFactory.make_monster_data(
		&"witch", Row.FRONT, WeaponRange.MELEE, 5, 5, [&"fire"], 20, 1, 1, 99
	)
	var witch := MonsterTestFactory.make_monster_combatant(data, _make_rng())
	var fighter := StubPartyCombatant.new("Fighter", 50, 0, Row.FRONT)

	var engine := TurnEngine.new()
	engine.spell_repo = MonsterTestFactory.make_repo([fire])
	engine.start_battle([fighter], [witch])
	var dealt: Array = []
	engine.actor_dealt_damage.connect(func(t, a, s): dealt.append([t, a, s]))
	engine.resolve_turn(_make_rng())

	assert_gte(dealt.size(), 1)
	var matching := dealt.filter(func(e): return e[2] == witch)
	assert_eq(matching.size(), 1, "witch should be source of one damage event")


# --- 4.7 actor_healed fires when monster heals an ally ---

func test_monster_heal_emits_actor_healed_with_monster_source():
	var heal := MonsterTestFactory.build_heal_spell(&"heal", 5, 2)
	var caster_data := MonsterTestFactory.make_monster_data(
		&"dark_priest", Row.FRONT, WeaponRange.MELEE, 5, 5, [&"heal"], 20, 1, 1, 99
	)
	var caster := MonsterTestFactory.make_monster_combatant(caster_data, _make_rng())
	var peer_data := MonsterTestFactory.make_monster_data(
		&"imp", Row.FRONT, WeaponRange.MELEE, 0, 0, [], 20, 1, 1, 1
	)
	var peer := MonsterTestFactory.make_monster_combatant(peer_data, _make_rng())
	peer.current_hp = 5
	var fighter := StubPartyCombatant.new("Fighter", 50, 0, Row.FRONT)

	var engine := TurnEngine.new()
	engine.spell_repo = MonsterTestFactory.make_repo([heal])
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
	var fire := MonsterTestFactory.build_damage_spell(&"fire", SpellData.TargetType.ENEMY_ONE, 2, 6)
	var data := MonsterTestFactory.make_monster_data(
		&"witch", Row.FRONT, WeaponRange.MELEE, 5, 5, [&"fire"], 20, 1, 1, 99
	)
	var witch := MonsterTestFactory.make_monster_combatant(data, _make_rng())
	var fighter := StubPartyCombatant.new("Fighter", 50, 0, Row.FRONT)

	var engine := TurnEngine.new()
	engine.spell_repo = MonsterTestFactory.make_repo([fire])
	engine.start_battle([fighter], [witch])
	engine.resolve_turn(_make_rng())

	assert_lt(fighter.current_hp, 50, "fire should reduce party HP")
	assert_eq(witch.current_hp, 20, "monster caster should not damage itself")
