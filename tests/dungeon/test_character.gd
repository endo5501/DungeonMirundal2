extends GutTest

var _human: RaceData
var _elf: RaceData
var _fighter_job: JobData
var _mage_job: JobData

func before_each():
	_human = RaceData.new()
	_human.race_name = "Human"
	_human.base_str = 8
	_human.base_int = 8
	_human.base_pie = 8
	_human.base_vit = 8
	_human.base_agi = 8
	_human.base_luc = 8

	_elf = RaceData.new()
	_elf.race_name = "Elf"
	_elf.base_str = 7
	_elf.base_int = 10
	_elf.base_pie = 10
	_elf.base_vit = 6
	_elf.base_agi = 9
	_elf.base_luc = 6

	_fighter_job = JobData.new()
	_fighter_job.job_name = "Fighter"
	_fighter_job.base_hp = 10
	_fighter_job.has_magic = false
	_fighter_job.base_mp = 0
	_fighter_job.required_str = 0
	_fighter_job.required_int = 0
	_fighter_job.required_pie = 0
	_fighter_job.required_vit = 0
	_fighter_job.required_agi = 0
	_fighter_job.required_luc = 0

	_mage_job = JobData.new()
	_mage_job.job_name = "Mage"
	_mage_job.base_hp = 4
	_mage_job.has_magic = true
	_mage_job.base_mp = 5
	_mage_job.required_str = 0
	_mage_job.required_int = 11
	_mage_job.required_pie = 0
	_mage_job.required_vit = 0
	_mage_job.required_agi = 0
	_mage_job.required_luc = 0

func test_character_with_all_bonus_to_str():
	var allocation := {&"STR": 7, &"INT": 0, &"PIE": 0, &"VIT": 0, &"AGI": 0, &"LUC": 0}
	var ch := Character.create("Hero", _human, _fighter_job, allocation)
	assert_eq(ch.character_name, "Hero")
	assert_eq(ch.base_stats[&"STR"], 15)  # 8 + 7
	assert_eq(ch.base_stats[&"INT"], 8)
	assert_eq(ch.base_stats[&"PIE"], 8)
	assert_eq(ch.base_stats[&"VIT"], 8)
	assert_eq(ch.base_stats[&"AGI"], 8)
	assert_eq(ch.base_stats[&"LUC"], 8)

func test_character_with_distributed_bonus():
	var allocation := {&"STR": 2, &"INT": 0, &"PIE": 0, &"VIT": 3, &"AGI": 0, &"LUC": 2}
	var ch := Character.create("Archer", _elf, _fighter_job, allocation)
	assert_eq(ch.base_stats[&"STR"], 9)   # 7 + 2
	assert_eq(ch.base_stats[&"INT"], 10)  # Elf base
	assert_eq(ch.base_stats[&"VIT"], 9)   # 6 + 3
	assert_eq(ch.base_stats[&"LUC"], 8)   # 6 + 2

func test_character_level_starts_at_1():
	var allocation := {&"STR": 5, &"INT": 0, &"PIE": 0, &"VIT": 0, &"AGI": 0, &"LUC": 0}
	var ch := Character.create("Test", _human, _fighter_job, allocation)
	assert_eq(ch.level, 1)

func test_fighter_hp_with_vit_8():
	var allocation := {&"STR": 5, &"INT": 0, &"PIE": 0, &"VIT": 0, &"AGI": 0, &"LUC": 0}
	var ch := Character.create("Tank", _human, _fighter_job, allocation)
	# HP = base_hp(10) + VIT(8) / 3 = 10 + 2 = 12
	assert_eq(ch.max_hp, 12)
	assert_eq(ch.current_hp, 12)

func test_fighter_hp_with_vit_15():
	var allocation := {&"STR": 0, &"INT": 0, &"PIE": 0, &"VIT": 7, &"AGI": 0, &"LUC": 0}
	var ch := Character.create("Tank2", _human, _fighter_job, allocation)
	# HP = base_hp(10) + VIT(15) / 3 = 10 + 5 = 15
	assert_eq(ch.max_hp, 15)
	assert_eq(ch.current_hp, 15)

func test_fighter_has_no_mp():
	var allocation := {&"STR": 5, &"INT": 0, &"PIE": 0, &"VIT": 0, &"AGI": 0, &"LUC": 0}
	var ch := Character.create("Warrior", _human, _fighter_job, allocation)
	assert_eq(ch.max_mp, 0)
	assert_eq(ch.current_mp, 0)

func test_mage_has_initial_mp():
	var allocation := {&"STR": 0, &"INT": 3, &"PIE": 0, &"VIT": 0, &"AGI": 0, &"LUC": 2}
	var ch := Character.create("Wizard", _human, _mage_job, allocation)
	assert_eq(ch.max_mp, 5)  # base_mp from job
	assert_eq(ch.current_mp, 5)

func test_to_party_member_data():
	var allocation := {&"STR": 0, &"INT": 3, &"PIE": 0, &"VIT": 0, &"AGI": 0, &"LUC": 2}
	var ch := Character.create("Alice", _human, _mage_job, allocation)
	var pmd := ch.to_party_member_data()
	assert_eq(pmd.member_name, "Alice")
	assert_eq(pmd.level, 1)
	assert_eq(pmd.current_hp, ch.current_hp)
	assert_eq(pmd.max_hp, ch.max_hp)
	assert_eq(pmd.current_mp, ch.current_mp)
	assert_eq(pmd.max_mp, ch.max_mp)

func test_mage_creation_succeeds_with_sufficient_int():
	var allocation := {&"STR": 0, &"INT": 3, &"PIE": 0, &"VIT": 0, &"AGI": 0, &"LUC": 2}
	# Human INT=8 + 3 = 11, meets Mage requirement
	var ch := Character.create("Mage1", _human, _mage_job, allocation)
	assert_not_null(ch)

func test_mage_creation_fails_with_insufficient_int():
	var allocation := {&"STR": 0, &"INT": 2, &"PIE": 0, &"VIT": 0, &"AGI": 0, &"LUC": 3}
	# Human INT=8 + 2 = 10, does NOT meet Mage requirement of 11
	var ch := Character.create("Mage2", _human, _mage_job, allocation)
	assert_null(ch)

func test_create_fails_if_allocation_sum_mismatches():
	# Total bonus = 5+0+0+0+0+0 = 5, but trying to allocate more than given
	# We pass allocation that sums to wrong amount — but we need a bonus_total param
	# The create method should validate allocation sum equals bonus total
	var allocation := {&"STR": 3, &"INT": 3, &"PIE": 3, &"VIT": 0, &"AGI": 0, &"LUC": 0}
	# Sum = 9, but let's say bonus was 5 — we need to pass bonus_total
	var ch := Character.create("Bad", _human, _fighter_job, allocation, 5)
	assert_null(ch)

func test_character_race_and_job_references():
	var allocation := {&"STR": 5, &"INT": 0, &"PIE": 0, &"VIT": 0, &"AGI": 0, &"LUC": 0}
	var ch := Character.create("Test", _human, _fighter_job, allocation)
	assert_eq(ch.race, _human)
	assert_eq(ch.job, _fighter_job)


# --- items-and-economy: equipment field ---

func test_new_character_has_empty_equipment():
	var allocation := {&"STR": 5, &"INT": 0, &"PIE": 0, &"VIT": 0, &"AGI": 0, &"LUC": 0}
	var ch := Character.create("Test", _human, _fighter_job, allocation)
	assert_not_null(ch.equipment)
	assert_is(ch.equipment, Equipment)
	assert_eq(ch.equipment.all_equipped().size(), 0)


func test_to_dict_with_inventory_includes_equipment():
	var allocation := {&"STR": 5, &"INT": 0, &"PIE": 0, &"VIT": 0, &"AGI": 0, &"LUC": 0}
	var ch := Character.create("Test", _human, _fighter_job, allocation)

	var sword_item := Item.new()
	sword_item.item_id = &"long_sword"
	sword_item.equip_slot = Item.EquipSlot.WEAPON
	sword_item.category = Item.ItemCategory.WEAPON
	sword_item.allowed_jobs = [&"Fighter"]

	var inv := Inventory.new()
	var inst := ItemInstance.new(sword_item, true)
	inv.add(inst)
	ch.equipment.equip(Item.EquipSlot.WEAPON, inst, ch)

	var d := ch.to_dict(inv)
	assert_true(d.has("equipment"))
	assert_eq(d["equipment"].get("weapon"), 0)


func test_from_dict_without_inventory_yields_empty_equipment():
	# Use real loaded race/job so resource_path round-trips correctly.
	var human_loaded := load("res://data/races/human.tres") as RaceData
	var fighter_loaded := load("res://data/jobs/fighter.tres") as JobData
	var allocation := {&"STR": 5, &"INT": 0, &"PIE": 0, &"VIT": 0, &"AGI": 0, &"LUC": 0}
	var ch := Character.create("Test", human_loaded, fighter_loaded, allocation)
	var d := ch.to_dict()  # no inventory
	var restored := Character.from_dict(d)
	assert_not_null(restored.equipment)
	assert_eq(restored.equipment.all_equipped().size(), 0)


# --- tighten-types-and-contracts: to_dict uses RaceData.id / JobData.id ---

func test_to_dict_race_id_comes_from_id_field_not_resource_path():
	_human.id = &"custom_race"
	_fighter_job.id = &"custom_job"
	var allocation := {&"STR": 5, &"INT": 0, &"PIE": 0, &"VIT": 0, &"AGI": 0, &"LUC": 0}
	var ch := Character.create("Test", _human, _fighter_job, allocation)
	var d := ch.to_dict()
	assert_eq(d["race_id"], "custom_race")
	assert_eq(d["job_id"], "custom_job")


func test_to_dict_falls_back_to_resource_path_when_race_id_empty():
	# Simulate legacy data: id is empty, but resource_path points to a real file.
	# Build standalone resources so we don't mutate Godot's cached singletons.
	var legacy_race := RaceData.new()
	legacy_race.race_name = "Human"
	legacy_race.base_str = 8
	legacy_race.base_int = 8
	legacy_race.base_pie = 8
	legacy_race.base_vit = 8
	legacy_race.base_agi = 8
	legacy_race.base_luc = 8
	legacy_race.take_over_path("res://data/races/human.tres")
	var legacy_job := JobData.new()
	legacy_job.job_name = "Fighter"
	legacy_job.base_hp = 10
	legacy_job.take_over_path("res://data/jobs/fighter.tres")
	var allocation := {&"STR": 5, &"INT": 0, &"PIE": 0, &"VIT": 0, &"AGI": 0, &"LUC": 0}
	var ch := Character.create("Test", legacy_race, legacy_job, allocation)
	var d := ch.to_dict()
	assert_eq(d["race_id"], "human")
	assert_eq(d["job_id"], "fighter")
