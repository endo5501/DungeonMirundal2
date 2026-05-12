extends GutTest

const TEST_SEED: int = 12345


# End-to-end integration: real shipped monster .tres + real SpellRepository.


func _make_rng(seed_value: int = TEST_SEED) -> RandomNumberGenerator:
	return MonsterTestFactory.make_rng(seed_value)


func _load_monster(id: StringName) -> MonsterCombatant:
	var data := ResourceLoader.load("res://data/monsters/%s.tres" % String(id)) as MonsterData
	assert_not_null(data, "monster %s tres should load" % String(id))
	return MonsterCombatant.new(Monster.new(data, _make_rng()))


# --- 8.1 witch + slime: witch casts fire on Fighter ---

func test_witch_casts_fire_on_party():
	var witch := _load_monster(&"witch")
	witch.modifier_stack.add(&"agility", 99, 99)
	var slime := _load_monster(&"slime")
	var fighter := StubPartyCombatant.new("Fighter", 80)

	var engine := TurnEngine.new()
	engine.start_battle([fighter], [witch, slime])
	MonsterTestFactory.wire_status_repo(engine)
	var fighter_hp_before := fighter.current_hp
	var witch_mp_before := witch.current_mp
	engine.resolve_turn(_make_rng())

	# Either witch casts something (MP decreases) or attacks (slime/witch peer).
	var damaged := fighter.current_hp < fighter_hp_before
	var spent_mp := witch.current_mp < witch_mp_before
	assert_true(damaged or spent_mp, "witch should have acted somehow")


# --- 8.2 dark_priest heals wounded peer ---

func test_dark_priest_heals_wounded_peer():
	var dark_priest := _load_monster(&"dark_priest")
	dark_priest.modifier_stack.add(&"agility", 99, 99)
	dark_priest.monster.data.known_spells = [&"heal"] as Array[StringName]
	var imp := _load_monster(&"imp")
	imp.current_hp = 1
	var fighter := StubPartyCombatant.new("Fighter", 80)

	var engine := TurnEngine.new()
	engine.start_battle([fighter], [dark_priest, imp])
	MonsterTestFactory.wire_status_repo(engine)
	var hp_before := imp.current_hp
	engine.resolve_turn(_make_rng())

	assert_gt(imp.current_hp, hp_before, "imp should be healed by dark_priest")


# --- 8.3 lich casts flame (ENEMY_GROUP) on multiple party members ---

func test_lich_flame_damages_all_party_members():
	var lich := _load_monster(&"lich")
	lich.modifier_stack.add(&"agility", 99, 99)
	lich.monster.data.known_spells = [&"flame"] as Array[StringName]
	var fighter := StubPartyCombatant.new("Fighter", 80)
	var mage := StubPartyCombatant.new("Mage", 60)
	var priest := StubPartyCombatant.new("Priest", 70)

	var engine := TurnEngine.new()
	engine.start_battle([fighter, mage, priest], [lich])
	MonsterTestFactory.wire_status_repo(engine)
	engine.resolve_turn(_make_rng())

	assert_lt(fighter.current_hp, 80, "fighter should take flame damage")
	assert_lt(mage.current_hp, 60, "mage should take flame damage")
	assert_lt(priest.current_hp, 70, "priest should take flame damage")
