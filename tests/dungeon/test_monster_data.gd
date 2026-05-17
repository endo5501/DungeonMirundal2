extends GutTest

var _slime: MonsterData
var _goblin: MonsterData

func before_each():
	_slime = MonsterData.new()
	_slime.monster_id = &"slime"
	_slime.monster_name = "Slime"
	_slime.max_hp_min = 5
	_slime.max_hp_max = 10
	_slime.attack = 3
	_slime.defense = 1
	_slime.agility = 2
	_slime.experience = 4

	_goblin = MonsterData.new()
	_goblin.monster_id = &"goblin"
	_goblin.monster_name = "Goblin"
	_goblin.max_hp_min = 8
	_goblin.max_hp_max = 12
	_goblin.attack = 5
	_goblin.defense = 2
	_goblin.agility = 4
	_goblin.experience = 7


func test_monster_data_is_resource():
	assert_true(_slime is Resource)


func test_slime_fields_readable():
	assert_eq(_slime.monster_id, &"slime")
	assert_eq(_slime.monster_name, "Slime")
	assert_eq(_slime.max_hp_min, 5)
	assert_eq(_slime.max_hp_max, 10)
	assert_eq(_slime.attack, 3)
	assert_eq(_slime.defense, 1)
	assert_eq(_slime.agility, 2)
	assert_eq(_slime.experience, 4)
	assert_eq(_slime.get("battle_texture"), null)


func test_monster_data_battle_texture_is_writable():
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	var texture := ImageTexture.create_from_image(image)
	_slime.set("battle_texture", texture)
	assert_eq(_slime.get("battle_texture"), texture)


func test_is_valid_accepts_missing_battle_texture():
	_slime.set("battle_texture", null)
	assert_true(_slime.is_valid())


func test_goblin_fields_readable():
	assert_eq(_goblin.monster_id, &"goblin")
	assert_eq(_goblin.max_hp_min, 8)
	assert_eq(_goblin.max_hp_max, 12)


func test_is_valid_returns_true_for_normal_range():
	assert_true(_slime.is_valid())


func test_is_valid_returns_true_when_min_equals_max():
	var fixed := MonsterData.new()
	fixed.monster_id = &"fixed"
	fixed.monster_name = "Fixed"
	fixed.max_hp_min = 10
	fixed.max_hp_max = 10
	assert_true(fixed.is_valid())


func test_is_valid_returns_false_when_min_exceeds_max():
	var broken := MonsterData.new()
	broken.monster_id = &"broken"
	broken.monster_name = "Broken"
	broken.max_hp_min = 15
	broken.max_hp_max = 10
	assert_false(broken.is_valid())


func test_is_valid_returns_false_when_min_is_negative():
	var broken := MonsterData.new()
	broken.monster_id = &"broken"
	broken.monster_name = "Broken"
	broken.max_hp_min = -1
	broken.max_hp_max = 10
	assert_false(broken.is_valid())


func test_is_valid_returns_false_when_monster_id_is_empty():
	var broken := MonsterData.new()
	broken.monster_id = &""
	broken.monster_name = "NoId"
	broken.max_hp_min = 5
	broken.max_hp_max = 10
	assert_false(broken.is_valid())


func test_slime_tres_loads_with_expected_fields():
	var loaded := ResourceLoader.load("res://data/monsters/slime.tres") as MonsterData
	assert_not_null(loaded)
	assert_eq(loaded.monster_id, &"slime")
	assert_eq(loaded.monster_name, "Slime")
	assert_eq(loaded.max_hp_min, 5)
	assert_eq(loaded.max_hp_max, 10)
	assert_true(loaded.is_valid())


func test_goblin_tres_loads_with_expected_fields():
	var loaded := ResourceLoader.load("res://data/monsters/goblin.tres") as MonsterData
	assert_not_null(loaded)
	assert_eq(loaded.monster_id, &"goblin")
	assert_eq(loaded.max_hp_min, 8)
	assert_eq(loaded.max_hp_max, 12)


func test_bat_tres_loads_with_expected_fields():
	var loaded := ResourceLoader.load("res://data/monsters/bat.tres") as MonsterData
	assert_not_null(loaded)
	assert_eq(loaded.monster_id, &"bat")
	assert_eq(loaded.agility, 7)


# --- items-and-economy: gold range ---

func test_gold_fields_default_to_zero():
	var md := MonsterData.new()
	md.monster_id = &"m"
	md.monster_name = "m"
	md.max_hp_min = 1
	md.max_hp_max = 1
	assert_eq(md.gold_min, 0)
	assert_eq(md.gold_max, 0)
	assert_true(md.is_valid())


func test_gold_range_valid_when_min_le_max():
	var md := MonsterData.new()
	md.monster_id = &"m"
	md.monster_name = "m"
	md.max_hp_min = 1
	md.max_hp_max = 1
	md.gold_min = 5
	md.gold_max = 15
	assert_true(md.is_valid())


func test_gold_range_rejects_min_greater_than_max():
	var md := MonsterData.new()
	md.monster_id = &"m"
	md.monster_name = "m"
	md.max_hp_min = 1
	md.max_hp_max = 1
	md.gold_min = 20
	md.gold_max = 5
	assert_false(md.is_valid())


func test_gold_range_rejects_negative_min():
	var md := MonsterData.new()
	md.monster_id = &"m"
	md.monster_name = "m"
	md.max_hp_min = 1
	md.max_hp_max = 1
	md.gold_min = -1
	md.gold_max = 0
	assert_false(md.is_valid())


func test_slime_tres_has_gold_range():
	var loaded := ResourceLoader.load("res://data/monsters/slime.tres") as MonsterData
	assert_gte(loaded.gold_min, 0)
	assert_gte(loaded.gold_max, loaded.gold_min)


func test_goblin_tres_has_gold_range():
	var loaded := ResourceLoader.load("res://data/monsters/goblin.tres") as MonsterData
	assert_eq(loaded.gold_min, 5)
	assert_eq(loaded.gold_max, 15)


func test_bat_tres_has_gold_range():
	var loaded := ResourceLoader.load("res://data/monsters/bat.tres") as MonsterData
	assert_gte(loaded.gold_max, loaded.gold_min)


# --- add-status-effect-infrastructure: resists dictionary ---

func test_monster_data_has_resists_field():
	var md := MonsterData.new()
	assert_typeof(md.resists, TYPE_DICTIONARY)


func test_monster_data_resists_default_is_empty():
	var md := MonsterData.new()
	assert_eq(md.resists.size(), 0)


func test_monster_data_resists_is_writable():
	var md := MonsterData.new()
	md.resists = {&"sleep": 0.5}
	assert_eq(md.resists.get(&"sleep"), 0.5)


func test_loaded_monster_tres_files_have_resists_dictionary():
	var loader := DataLoader.new()
	var monsters := loader.load_all_monsters()
	assert_gt(monsters.size(), 0)
	for m in monsters:
		assert_typeof(m.resists, TYPE_DICTIONARY,
			"monster %s.resists should be Dictionary" % m.resource_path)


# --- add-monster-visual-art: battle textures ---

func test_shipped_monsters_have_battle_textures():
	var required_ids := [&"slime", &"goblin", &"bat", &"skeleton", &"ghost", &"dragon"]
	for id in required_ids:
		var monster := _find_monster(id)
		assert_not_null(monster, "monster %s should be loadable" % String(id))
		assert_not_null(monster.get("battle_texture"),
			"monster %s should reference a generated battle texture" % String(id))


func test_shipped_monster_art_files_exist_at_stable_paths():
	var required_ids := [&"slime", &"goblin", &"bat", &"skeleton", &"ghost", &"dragon"]
	for id in required_ids:
		var path := "res://assets/images/monsters/%s.png" % String(id)
		assert_true(ResourceLoader.exists(path),
			"monster art should exist at %s" % path)


# --- add-status-confusion-blind-paralysis: representative monster resists ---

func _find_monster(id: StringName) -> MonsterData:
	for m in DataLoader.new().load_all_monsters():
		if m.monster_id == id:
			return m
	return null


func _monster_art_bytes(id: StringName) -> PackedByteArray:
	var path := "res://assets/images/monsters/%s.png" % String(id)
	return FileAccess.get_file_as_bytes(path)


func test_loaded_slime_is_fully_poison_immune():
	var slime := _find_monster(&"slime")
	assert_not_null(slime)
	assert_almost_eq(float(slime.resists.get(&"poison", 0.0)), 1.0, 0.001)
	assert_almost_eq(float(slime.resists.get(&"sleep", 0.0)), 0.30, 0.001)


func test_loaded_skeleton_is_immune_to_poison_and_sleep():
	var sk := _find_monster(&"skeleton")
	assert_not_null(sk)
	assert_almost_eq(float(sk.resists.get(&"poison", 0.0)), 1.0, 0.001)
	assert_almost_eq(float(sk.resists.get(&"sleep", 0.0)), 1.0, 0.001)
	assert_almost_eq(float(sk.resists.get(&"paralysis", 0.0)), 0.50, 0.001)


func test_loaded_ghost_is_immune_to_physical_flavored_statuses():
	var g := _find_monster(&"ghost")
	assert_not_null(g)
	assert_almost_eq(float(g.resists.get(&"poison", 0.0)), 1.0, 0.001)
	assert_almost_eq(float(g.resists.get(&"sleep", 0.0)), 1.0, 0.001)
	assert_almost_eq(float(g.resists.get(&"blind", 0.0)), 1.0, 0.001)


func test_loaded_bat_resists_blind_fully_and_poison_partially():
	var b := _find_monster(&"bat")
	assert_not_null(b)
	assert_almost_eq(float(b.resists.get(&"blind", 0.0)), 1.0, 0.001)
	assert_almost_eq(float(b.resists.get(&"poison", 0.0)), 0.30, 0.001)


func test_loaded_dragon_resists_multiple_mind_affecting_statuses():
	var d := _find_monster(&"dragon")
	assert_not_null(d)
	assert_gt(float(d.resists.get(&"sleep", 0.0)), 0.0)
	assert_gt(float(d.resists.get(&"paralysis", 0.0)), 0.0)
	assert_gt(float(d.resists.get(&"confusion", 0.0)), 0.0)


# --- add-monster-magic: MP range + known_spells fields ---

func test_monster_data_has_mp_fields_with_zero_defaults():
	var md := MonsterData.new()
	assert_eq(md.max_mp_min, 0)
	assert_eq(md.max_mp_max, 0)


func test_monster_data_has_known_spells_field_with_empty_default():
	var md := MonsterData.new()
	assert_typeof(md.known_spells, TYPE_ARRAY)
	assert_eq(md.known_spells.size(), 0)


func test_monster_data_mp_fields_are_writable():
	var md := MonsterData.new()
	md.max_mp_min = 4
	md.max_mp_max = 10
	assert_eq(md.max_mp_min, 4)
	assert_eq(md.max_mp_max, 10)


func test_monster_data_known_spells_is_writable():
	var md := MonsterData.new()
	md.known_spells = [&"fire", &"frost"] as Array[StringName]
	assert_eq(md.known_spells.size(), 2)
	assert_eq(md.known_spells[0], &"fire")


func test_is_valid_accepts_valid_mp_range():
	_slime.max_mp_min = 4
	_slime.max_mp_max = 10
	assert_true(_slime.is_valid())


func test_is_valid_accepts_zero_mp_range():
	_slime.max_mp_min = 0
	_slime.max_mp_max = 0
	assert_true(_slime.is_valid())


func test_is_valid_rejects_negative_mp_min():
	_slime.max_mp_min = -1
	_slime.max_mp_max = 4
	assert_false(_slime.is_valid())


func test_is_valid_rejects_mp_min_greater_than_max():
	_slime.max_mp_min = 10
	_slime.max_mp_max = 4
	assert_false(_slime.is_valid())


func test_existing_slime_tres_loads_with_zero_mp_and_empty_spells():
	var loaded := ResourceLoader.load("res://data/monsters/slime.tres") as MonsterData
	assert_not_null(loaded)
	assert_eq(loaded.max_mp_min, 0)
	assert_eq(loaded.max_mp_max, 0)
	assert_eq(loaded.known_spells.size(), 0)


func test_existing_six_monsters_load_with_zero_mp_and_empty_spells():
	var ids := [&"slime", &"goblin", &"bat", &"skeleton", &"ghost", &"dragon"]
	for id in ids:
		var monster := _find_monster(id)
		assert_not_null(monster, "monster %s should load" % String(id))
		assert_eq(monster.max_mp_min, 0,
			"existing monster %s should have max_mp_min == 0" % String(id))
		assert_eq(monster.max_mp_max, 0,
			"existing monster %s should have max_mp_max == 0" % String(id))
		assert_eq(monster.known_spells.size(), 0,
			"existing monster %s should have empty known_spells" % String(id))


# --- add-monster-tier-encounters: tier field ---

func test_monster_data_has_tier_field_with_default_1():
	var md := MonsterData.new()
	assert_eq(md.tier, 1)


func test_monster_data_tier_is_writable():
	var md := MonsterData.new()
	md.tier = 3
	assert_eq(md.tier, 3)


func test_is_valid_accepts_tier_in_range():
	_slime.tier = 3
	assert_true(_slime.is_valid())


func test_is_valid_accepts_tier_1():
	_slime.tier = 1
	assert_true(_slime.is_valid())


func test_is_valid_accepts_tier_5():
	_slime.tier = 5
	assert_true(_slime.is_valid())


func test_is_valid_rejects_tier_zero():
	_slime.tier = 0
	assert_false(_slime.is_valid())


func test_is_valid_rejects_tier_above_5():
	_slime.tier = 6
	assert_false(_slime.is_valid())


func test_is_valid_rejects_negative_tier():
	_slime.tier = -1
	assert_false(_slime.is_valid())


# --- replace-placeholder-monster-art: regression checks ---

func test_spellcasting_monster_art_files_exist_at_stable_paths():
	var ids := [&"dark_priest", &"goblin_shaman", &"imp", &"lich", &"witch", &"wraith"]
	for id in ids:
		var path := "res://assets/images/monsters/%s.png" % String(id)
		assert_true(ResourceLoader.exists(path),
			"replacement monster art should exist at %s" % path)


func test_spellcasting_monster_art_is_not_identical_to_slime():
	var slime_bytes := _monster_art_bytes(&"slime")
	assert_gt(slime_bytes.size(), 0, "slime art should be readable for duplicate detection")
	var ids := [&"dark_priest", &"goblin_shaman", &"imp", &"lich", &"witch", &"wraith"]
	for id in ids:
		var art_bytes := _monster_art_bytes(id)
		assert_gt(art_bytes.size(), 0, "monster %s art should be readable" % String(id))
		assert_ne(art_bytes, slime_bytes,
			"monster %s art should not be identical to slime placeholder content" % String(id))


func test_spellcasting_monsters_still_resolve_non_null_battle_textures():
	var ids := [&"dark_priest", &"goblin_shaman", &"imp", &"lich", &"witch", &"wraith"]
	for id in ids:
		var monster := _find_monster(id)
		assert_not_null(monster, "monster %s should load" % String(id))
		assert_not_null(monster.battle_texture,
			"monster %s should resolve a non-null battle texture" % String(id))
