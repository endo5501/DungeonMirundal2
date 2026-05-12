extends GutTest

const TEST_SEED: int = 12345


func _make_monster_data(id: StringName, display_name: String, atk: int, def: int, agi: int, hp: int = 10) -> MonsterData:
	var data := MonsterData.new()
	data.monster_id = id
	data.monster_name = display_name
	data.max_hp_min = hp
	data.max_hp_max = hp
	data.attack = atk
	data.defense = def
	data.agility = agi
	data.experience = 0
	return data


func _make_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = TEST_SEED
	return rng


# --- structure ---

func test_monster_combatant_is_combat_actor():
	var data := _make_monster_data(&"slime", "Slime", 3, 2, 4)
	var m := Monster.new(data, _make_rng())
	var mc := MonsterCombatant.new(m)
	assert_is(mc, CombatActor)


# --- actor_name ---

func test_actor_name_comes_from_monster_name():
	var data := _make_monster_data(&"slime", "スライム", 3, 2, 4)
	var m := Monster.new(data, _make_rng())
	var mc := MonsterCombatant.new(m)
	assert_eq(mc.actor_name, "スライム")


# --- derived stats ---

func test_get_attack_returns_monster_data_attack():
	var data := _make_monster_data(&"orc", "Orc", 7, 3, 5)
	var m := Monster.new(data, _make_rng())
	var mc := MonsterCombatant.new(m)
	assert_eq(mc.get_attack(), 7)


func test_get_defense_returns_monster_data_defense():
	var data := _make_monster_data(&"orc", "Orc", 7, 3, 5)
	var m := Monster.new(data, _make_rng())
	var mc := MonsterCombatant.new(m)
	assert_eq(mc.get_defense(), 3)


func test_get_agility_returns_monster_data_agility():
	var data := _make_monster_data(&"orc", "Orc", 7, 3, 5)
	var m := Monster.new(data, _make_rng())
	var mc := MonsterCombatant.new(m)
	assert_eq(mc.get_agility(), 5)


# --- hp proxy ---

func test_current_hp_reads_monster_current_hp():
	var data := _make_monster_data(&"slime", "Slime", 3, 2, 4, 8)
	var m := Monster.new(data, _make_rng())
	var mc := MonsterCombatant.new(m)
	assert_eq(mc.current_hp, 8)


func test_max_hp_reads_monster_max_hp():
	var data := _make_monster_data(&"slime", "Slime", 3, 2, 4, 8)
	var m := Monster.new(data, _make_rng())
	var mc := MonsterCombatant.new(m)
	assert_eq(mc.max_hp, 8)


func test_take_damage_writes_back_to_monster():
	var data := _make_monster_data(&"slime", "Slime", 3, 2, 4, 10)
	var m := Monster.new(data, _make_rng())
	var mc := MonsterCombatant.new(m)
	mc.take_damage(3)
	assert_eq(m.current_hp, 7)
	assert_eq(mc.current_hp, 7)


func test_is_alive_becomes_false_when_hp_depleted():
	var data := _make_monster_data(&"slime", "Slime", 3, 2, 4, 5)
	var m := Monster.new(data, _make_rng())
	var mc := MonsterCombatant.new(m)
	mc.take_damage(100)
	assert_false(mc.is_alive())


# --- add-monster-magic: MP proxies to wrapped Monster ---

func _make_monster_data_with_mp(id: StringName, mp_min: int, mp_max: int) -> MonsterData:
	var data := _make_monster_data(id, String(id), 3, 2, 4)
	data.max_mp_min = mp_min
	data.max_mp_max = mp_max
	return data


func test_monster_combatant_zero_mp_data_yields_zero_mp():
	var data := _make_monster_data(&"slime", "Slime", 3, 2, 4)
	var m := Monster.new(data, _make_rng())
	var mc := MonsterCombatant.new(m)
	assert_eq(mc.current_mp, 0)
	assert_eq(mc.max_mp, 0)


func test_monster_combatant_zero_mp_rejects_positive_spend():
	var data := _make_monster_data(&"slime", "Slime", 3, 2, 4)
	var m := Monster.new(data, _make_rng())
	var mc := MonsterCombatant.new(m)
	assert_false(mc.spend_mp(1))


func test_monster_combatant_spend_mp_zero_returns_true():
	var data := _make_monster_data(&"slime", "Slime", 3, 2, 4)
	var m := Monster.new(data, _make_rng())
	var mc := MonsterCombatant.new(m)
	assert_true(mc.spend_mp(0))


func test_monster_combatant_max_mp_reads_monster_max_mp():
	var data := _make_monster_data_with_mp(&"witch", 8, 8)
	var m := Monster.new(data, _make_rng())
	var mc := MonsterCombatant.new(m)
	assert_eq(mc.max_mp, 8)
	assert_eq(mc.current_mp, 8)


func test_monster_combatant_spend_mp_succeeds_when_sufficient():
	var data := _make_monster_data_with_mp(&"witch", 5, 5)
	var m := Monster.new(data, _make_rng())
	var mc := MonsterCombatant.new(m)
	assert_true(mc.spend_mp(2))
	assert_eq(mc.current_mp, 3)
	assert_eq(m.current_mp, 3)


func test_monster_combatant_spend_mp_fails_when_insufficient():
	var data := _make_monster_data_with_mp(&"witch", 2, 2)
	var m := Monster.new(data, _make_rng())
	var mc := MonsterCombatant.new(m)
	assert_false(mc.spend_mp(3))
	assert_eq(mc.current_mp, 2)


func test_monster_combatant_mp_write_propagates_to_monster():
	var data := _make_monster_data_with_mp(&"witch", 6, 6)
	var m := Monster.new(data, _make_rng())
	var mc := MonsterCombatant.new(m)
	mc.current_mp = 4
	assert_eq(m.current_mp, 4)
