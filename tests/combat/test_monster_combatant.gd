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
