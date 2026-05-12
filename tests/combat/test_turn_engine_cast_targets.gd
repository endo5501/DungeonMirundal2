extends GutTest

const TEST_SEED: int = 99


# Side-relative cast target resolution: ENEMY_*/ALLY_* are interpreted
# relative to the caster's side. Same logic for both party and monster casters.


func _make_rng(seed_value: int = TEST_SEED) -> RandomNumberGenerator:
	return MonsterTestFactory.make_rng(seed_value)


# --- 5.1 / 5.2: monster ENEMY_ONE targets party member ---

func test_monster_enemy_one_resolves_party_target():
	var fire := MonsterTestFactory.build_damage_spell(&"fire", SpellData.TargetType.ENEMY_ONE, 2, 6)
	var data := MonsterTestFactory.make_monster_data(
		&"witch", Row.FRONT, WeaponRange.MELEE, 5, 5, [&"fire"], 20, 1, 1, 99
	)
	var witch := MonsterTestFactory.make_monster_combatant(data, _make_rng())
	var fighter := StubPartyCombatant.new("Fighter", 30, 0, Row.FRONT)

	var engine := TurnEngine.new()
	engine.spell_repo = MonsterTestFactory.make_repo([fire])
	engine.start_battle([fighter], [witch])
	engine.resolve_turn(_make_rng())
	assert_lt(fighter.current_hp, 30, "monster cast should damage party")


# --- 5.3: monster ENEMY_GROUP fans out to all living party members ---

func test_monster_enemy_group_targets_all_living_party_members():
	var flame := MonsterTestFactory.build_damage_spell(&"flame", SpellData.TargetType.ENEMY_GROUP, 4, 4)
	var data := MonsterTestFactory.make_monster_data(
		&"lich", Row.FRONT, WeaponRange.MELEE, 10, 10, [&"flame"], 20, 1, 1, 99
	)
	var lich := MonsterTestFactory.make_monster_combatant(data, _make_rng())
	var fighter := StubPartyCombatant.new("Fighter", 30, 0, Row.FRONT)
	var mage := StubPartyCombatant.new("Mage", 25, 0, Row.BACK)
	var thief := StubPartyCombatant.new("Thief", 20, 0, Row.FRONT)

	var engine := TurnEngine.new()
	engine.spell_repo = MonsterTestFactory.make_repo([flame])
	engine.start_battle([fighter, mage, thief], [lich])
	engine.resolve_turn(_make_rng())

	assert_lt(fighter.current_hp, 30, "fighter should take damage")
	assert_lt(mage.current_hp, 25, "mage should take damage")
	assert_lt(thief.current_hp, 20, "thief should take damage")


# --- 5.5: monster ALLY_ONE heal targets a same-side monster ---

func test_monster_ally_one_resolves_monster_target():
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
	var fighter := StubPartyCombatant.new("Fighter", 30, 0, Row.FRONT)

	var engine := TurnEngine.new()
	engine.spell_repo = MonsterTestFactory.make_repo([heal])
	engine.start_battle([fighter], [caster, peer])
	var hp_before := peer.current_hp
	engine.resolve_turn(_make_rng())
	assert_gt(peer.current_hp, hp_before, "peer should be healed")


# --- monster ALLY_ALL targets all living monsters ---

func test_monster_ally_all_resolves_all_living_monsters():
	var allheal := MonsterTestFactory.build_spell(
		&"allheal", SpellData.TargetType.ALLY_ALL, 4, HealSpellEffect.new()
	)
	(allheal.effect as HealSpellEffect).base_heal = 5
	(allheal.effect as HealSpellEffect).spread = 0
	var caster_data := MonsterTestFactory.make_monster_data(
		&"dark_priest", Row.FRONT, WeaponRange.MELEE, 8, 8, [&"allheal"], 20, 1, 1, 99
	)
	var caster := MonsterTestFactory.make_monster_combatant(caster_data, _make_rng())
	caster.current_hp = 10
	var peer_data := MonsterTestFactory.make_monster_data(
		&"imp", Row.FRONT, WeaponRange.MELEE, 0, 0, [], 20, 1, 1, 1
	)
	var peer := MonsterTestFactory.make_monster_combatant(peer_data, _make_rng())
	peer.current_hp = 6
	var fighter := StubPartyCombatant.new("Fighter", 30, 0, Row.FRONT)

	var engine := TurnEngine.new()
	engine.spell_repo = MonsterTestFactory.make_repo([allheal])
	engine.start_battle([fighter], [caster, peer])
	engine.resolve_turn(_make_rng())

	assert_gt(caster.current_hp, 10, "caster should heal itself")
	assert_gt(peer.current_hp, 6, "peer should be healed")


# --- 5.4: monster ENEMY_ONE retargets when target dies mid-turn ---

func test_monster_enemy_one_retargets_when_initial_target_dies():
	var fire := MonsterTestFactory.build_damage_spell(&"fire", SpellData.TargetType.ENEMY_ONE, 2, 6)
	var data := MonsterTestFactory.make_monster_data(
		&"witch", Row.FRONT, WeaponRange.MELEE, 5, 5, [&"fire"], 20, 1, 1, 99
	)
	var witch := MonsterTestFactory.make_monster_combatant(data, _make_rng())
	var dead_fighter := StubPartyCombatant.new("Fighter", 0, 0, Row.FRONT)
	var mage := StubPartyCombatant.new("Mage", 30, 0, Row.FRONT)

	var engine := TurnEngine.new()
	engine.spell_repo = MonsterTestFactory.make_repo([fire])
	engine.start_battle([dead_fighter, mage], [witch])
	engine.resolve_turn(_make_rng())
	assert_lt(mage.current_hp, 30, "Mage (the surviving target) should take damage")


# --- 5.6 regression: party caster ENEMY_ONE still resolves monsters ---

func test_party_caster_enemy_one_still_targets_monsters():
	var fire := MonsterTestFactory.build_damage_spell(&"fire", SpellData.TargetType.ENEMY_ONE, 2, 6)
	var mage := StubPartyCombatant.new("Mage", 30, 5, Row.BACK)
	var data := MonsterTestFactory.make_monster_data(
		&"slime", Row.FRONT, WeaponRange.MELEE, 0, 0, [], 20, 1, 1, 1
	)
	var slime := MonsterTestFactory.make_monster_combatant(data, _make_rng())

	var engine := TurnEngine.new()
	engine.spell_repo = MonsterTestFactory.make_repo([fire])
	engine.start_battle([mage], [slime])
	engine.submit_command(0, CastCommand.new(&"fire", 0, slime))
	engine.resolve_turn(_make_rng())

	assert_lt(slime.current_hp, 20, "party caster's fire should damage the monster")
	assert_eq(mage.current_mp, 3, "mage should have spent 2 MP")
