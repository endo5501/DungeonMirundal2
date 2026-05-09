extends GutTest

const TEST_SAVE_DIR := "user://test_dev_console/"

var _session: SaveSession


func before_each() -> void:
	_clean_test_dir()
	_session = SaveSession.new(TEST_SAVE_DIR)


func after_each() -> void:
	_clean_test_dir()


func _clean_test_dir() -> void:
	var root := DirAccess.open("user://")
	if root and root.dir_exists("test_dev_console"):
		var d := DirAccess.open(TEST_SAVE_DIR)
		if d:
			d.list_dir_begin()
			var f := d.get_next()
			while f != "":
				d.remove(f)
				f = d.get_next()
			d.list_dir_end()
		root.remove("test_dev_console")


# Build a fixture save with one Fighter "Hero" Lv1 and one Mage "Mira" Lv1.
# Both share an inventory holding a long_sword (idx 0) and healing_potion (idx 1).
# Hero equips the long_sword; Mira holds nothing.
func _write_fixture_save(slot: int) -> Dictionary:
	if not DirAccess.dir_exists_absolute(TEST_SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(TEST_SAVE_DIR)
	var data := {
		"version": 1,
		"last_saved": "2026-05-09 12:00:00",
		"game_location": "town",
		"current_dungeon_index": -1,
		"inventory": {
			"gold": 100,
			"items": [
				{"item_id": "long_sword", "identified": true},
				{"item_id": "healing_potion", "identified": true},
			],
		},
		"guild": {
			"party_name": "Heroes",
			"characters": [
				_make_fighter_dict("Hero"),
				_make_mage_dict("Mira"),
			],
			"front_row": [0, null, null],
			"back_row": [1, null, null],
		},
		"dungeons": [],
	}
	# Hero (index 0) equips inventory item 0 (long_sword)
	data["guild"]["characters"][0]["equipment"] = {
		"weapon": 0, "armor": null, "helmet": null,
		"shield": null, "gauntlet": null, "accessory": null,
	}
	var path := TEST_SAVE_DIR + "save_%03d.json" % slot
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	return data


func _make_fighter_dict(name: String) -> Dictionary:
	return {
		"character_name": name,
		"race_id": "human",
		"job_id": "fighter",
		"level": 1,
		"base_stats": {"STR": 12, "INT": 8, "PIE": 8, "VIT": 12, "AGI": 10, "LUC": 10},
		"current_hp": 14, "max_hp": 14,
		"current_mp": 0, "max_mp": 0,
		"accumulated_exp": 0,
		"known_spells": [],
		"persistent_statuses": [],
	}


func _make_mage_dict(name: String) -> Dictionary:
	return {
		"character_name": name,
		"race_id": "elf",
		"job_id": "mage",
		"level": 1,
		"base_stats": {"STR": 8, "INT": 14, "PIE": 10, "VIT": 8, "AGI": 12, "LUC": 10},
		"current_hp": 6, "max_hp": 6,
		"current_mp": 5, "max_mp": 5,
		"accumulated_exp": 0,
		"known_spells": ["fire", "frost", "dazil"],
		"persistent_statuses": [],
	}


func _read_save_json(slot: int) -> Dictionary:
	var path := TEST_SAVE_DIR + "save_%03d.json" % slot
	var f := FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	json.parse(f.get_as_text())
	f.close()
	return json.data


# --- 2.1 Loading non-existent slot ---

func test_load_nonexistent_slot_returns_file_not_found() -> void:
	var result: int = _session.load_slot(999)
	assert_eq(result, SaveSession.LoadResult.FILE_NOT_FOUND)


func test_load_corrupt_slot_returns_parse_error() -> void:
	if not DirAccess.dir_exists_absolute(TEST_SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(TEST_SAVE_DIR)
	var f := FileAccess.open(TEST_SAVE_DIR + "save_001.json", FileAccess.WRITE)
	f.store_string("{ not valid json")
	f.close()
	var result: int = _session.load_slot(1)
	assert_eq(result, SaveSession.LoadResult.PARSE_ERROR)


# --- 2.3 load_slot populates characters ---

func test_load_populates_characters() -> void:
	_write_fixture_save(1)
	var result: int = _session.load_slot(1)
	assert_eq(result, SaveSession.LoadResult.OK)
	var chars := _session.list_characters()
	assert_eq(chars.size(), 2)
	assert_eq(chars[0]["name"], "Hero")
	assert_eq(chars[1]["name"], "Mira")


func test_load_populates_inventory() -> void:
	_write_fixture_save(1)
	_session.load_slot(1)
	var inv := _session.list_inventory()
	assert_eq(inv.size(), 2)
	assert_eq(inv[0].item.item_id, &"long_sword")
	assert_eq(inv[1].item.item_id, &"healing_potion")


# --- 2.4 round-trip preserves data ---

func test_round_trip_preserves_save_data() -> void:
	_write_fixture_save(1)
	_session.load_slot(1)
	_session.save_to_slot(1)
	var fresh := SaveSession.new(TEST_SAVE_DIR)
	fresh.load_slot(1)
	assert_eq(fresh.list_characters().size(), 2)
	assert_eq(fresh.list_inventory().size(), 2)
	var ch0 := fresh.get_character(0)
	assert_eq(ch0.character_name, "Hero")
	# Equipment preserved across round trip
	var weapon: ItemInstance = ch0.equipment.get_equipped(Item.EquipSlot.WEAPON)
	assert_not_null(weapon)
	assert_eq(weapon.item.item_id, &"long_sword")


func test_round_trip_preserves_guild_party_assignments() -> void:
	_write_fixture_save(1)
	_session.load_slot(1)
	_session.save_to_slot(1)
	var data := _read_save_json(1)
	assert_eq(data["guild"]["party_name"], "Heroes")
	assert_eq(int(data["guild"]["front_row"][0]), 0)
	assert_eq(int(data["guild"]["back_row"][0]), 1)


func test_round_trip_preserves_top_level_fields() -> void:
	_write_fixture_save(1)
	_session.load_slot(1)
	_session.save_to_slot(1)
	var data := _read_save_json(1)
	assert_eq(data["game_location"], "town")
	assert_eq(int(data["current_dungeon_index"]), -1)
	assert_eq(int(data["version"]), 1)


# --- 2.5 set_character_name / set_race / set_job ---

func test_set_character_name() -> void:
	_write_fixture_save(1)
	_session.load_slot(1)
	_session.set_character_name(0, "Renamed")
	_session.save_to_slot(1)
	var data := _read_save_json(1)
	assert_eq(data["guild"]["characters"][0]["character_name"], "Renamed")


func test_set_race() -> void:
	_write_fixture_save(1)
	_session.load_slot(1)
	var ok: bool = _session.set_race(0, &"dwarf")
	assert_true(ok)
	_session.save_to_slot(1)
	var data := _read_save_json(1)
	assert_eq(data["guild"]["characters"][0]["race_id"], "dwarf")


func test_set_race_unknown_returns_false() -> void:
	_write_fixture_save(1)
	_session.load_slot(1)
	var ok: bool = _session.set_race(0, &"nonexistent_race_xyz")
	assert_false(ok)


func test_set_job() -> void:
	_write_fixture_save(1)
	_session.load_slot(1)
	var ok: bool = _session.set_job(0, &"mage")
	assert_true(ok)
	_session.save_to_slot(1)
	var data := _read_save_json(1)
	assert_eq(data["guild"]["characters"][0]["job_id"], "mage")


# --- 2.6 HP / MP setters ---

func test_set_hp_mp_allows_inconsistent_state() -> void:
	_write_fixture_save(1)
	_session.load_slot(1)
	_session.set_current_hp(0, 999)
	_session.set_max_hp(0, 1)
	_session.set_current_mp(0, 500)
	_session.set_max_mp(0, 0)
	_session.save_to_slot(1)
	var data := _read_save_json(1)
	var ch_data: Dictionary = data["guild"]["characters"][0]
	assert_eq(int(ch_data["current_hp"]), 999)
	assert_eq(int(ch_data["max_hp"]), 1)
	assert_eq(int(ch_data["current_mp"]), 500)
	assert_eq(int(ch_data["max_mp"]), 0)


# --- 2.7 set_base_stat ---

func test_set_base_stat_arbitrary_value() -> void:
	_write_fixture_save(1)
	_session.load_slot(1)
	_session.set_base_stat(0, &"STR", 25)
	_session.save_to_slot(1)
	var data := _read_save_json(1)
	assert_eq(int(data["guild"]["characters"][0]["base_stats"]["STR"]), 25)


func test_set_base_stat_unknown_key_ignored() -> void:
	_write_fixture_save(1)
	_session.load_slot(1)
	_session.set_base_stat(0, &"BOGUS", 99)
	_session.save_to_slot(1)
	var data := _read_save_json(1)
	# STAT_KEYS are present and BOGUS not added
	assert_false(data["guild"]["characters"][0]["base_stats"].has("BOGUS"))


# --- 2.8 set_accumulated_exp ---

func test_set_accumulated_exp() -> void:
	_write_fixture_save(1)
	_session.load_slot(1)
	_session.set_accumulated_exp(0, 50000)
	_session.save_to_slot(1)
	var data := _read_save_json(1)
	assert_eq(int(data["guild"]["characters"][0]["accumulated_exp"]), 50000)


# --- 2.9 set_level matches level_up loop ---

func test_set_level_matches_level_up_loop() -> void:
	_write_fixture_save(1)
	_session.load_slot(1)
	# Reference: build a parallel Mage and call level_up 4 times
	var race: RaceData = load("res://data/races/elf.tres") as RaceData
	var job: JobData = load("res://data/jobs/mage.tres") as JobData
	var ref_ch := Character.new()
	ref_ch.character_name = "Mira"
	ref_ch.race = race
	ref_ch.job = job
	ref_ch.level = 1
	ref_ch.base_stats = {&"STR": 8, &"INT": 14, &"PIE": 10, &"VIT": 8, &"AGI": 12, &"LUC": 10}
	ref_ch.max_hp = job.base_hp + ref_ch.base_stats[&"VIT"] / 3
	ref_ch.max_mp = job.base_mp
	ref_ch.known_spells = []
	ref_ch._rebuild_known_spells_through_level(1)
	for i in range(4):
		ref_ch.level_up()
	# Now apply set_level(5) on session's Mira (idx 1)
	var ok: bool = _session.set_level(1, 5)
	assert_true(ok)
	var ch := _session.get_character(1)
	assert_eq(ch.level, 5)
	assert_eq(ch.max_hp, ref_ch.max_hp)
	assert_eq(ch.max_mp, ref_ch.max_mp)
	# known_spells: same set (order-insensitive comparison via sorted)
	var got := _stringify_spells(ch.known_spells)
	var ref := _stringify_spells(ref_ch.known_spells)
	got.sort()
	ref.sort()
	assert_eq(got, ref)
	# accumulated_exp at boundary
	assert_eq(ch.accumulated_exp, job.exp_to_reach_level(5))
	# Full heal
	assert_eq(ch.current_hp, ch.max_hp)
	assert_eq(ch.current_mp, ch.max_mp)


func _stringify_spells(spells: Array[StringName]) -> Array[String]:
	var out: Array[String] = []
	for s in spells:
		out.append(String(s))
	return out


# --- set_level_value: write only the integer, no rebuild ---
# Used by the UI's level spinbox so direct ch.level mutation stays out of
# UI scripts (R4: all mutations route through SaveSession).

func test_set_level_value_only_changes_level_field() -> void:
	_write_fixture_save(1)
	_session.load_slot(1)
	# Establish a baseline at Lv5 so HP/MP/spells are non-trivial.
	_session.set_level(1, 5)
	var ch_before := _session.get_character(1)
	var max_hp_before := ch_before.max_hp
	var max_mp_before := ch_before.max_mp
	var spells_before := ch_before.known_spells.duplicate()
	# Now bump only the level integer.
	var ok: bool = _session.set_level_value(1, 13)
	assert_true(ok)
	var ch := _session.get_character(1)
	assert_eq(ch.level, 13)
	# HP/MP/spells must NOT have been recomputed by this method.
	assert_eq(ch.max_hp, max_hp_before)
	assert_eq(ch.max_mp, max_mp_before)
	assert_eq(ch.known_spells, spells_before)


func test_set_level_value_invalid_idx_returns_false() -> void:
	_write_fixture_save(1)
	_session.load_slot(1)
	assert_false(_session.set_level_value(99, 5))


# --- 2.10 set_level boundaries ---

func test_set_level_n1_resets_to_baseline() -> void:
	_write_fixture_save(1)
	_session.load_slot(1)
	# First raise Mira to Lv5, then back to Lv1 — should reset to baseline
	_session.set_level(1, 5)
	var ok: bool = _session.set_level(1, 1)
	assert_true(ok)
	var ch := _session.get_character(1)
	assert_eq(ch.level, 1)
	var job: JobData = ch.job
	var vit: int = ch.base_stats[&"VIT"]
	assert_eq(ch.max_hp, job.base_hp + vit / 3)
	assert_eq(ch.max_mp, job.base_mp)
	assert_eq(ch.accumulated_exp, 0)
	# At Lv1, mage gets fire/frost/dazil per spell_progression
	var spells := _stringify_spells(ch.known_spells)
	spells.sort()
	assert_eq(spells, ["dazil", "fire", "frost"])


func test_set_level_clamps_to_max() -> void:
	_write_fixture_save(1)
	_session.load_slot(1)
	var ch := _session.get_character(1)
	var max_level: int = ch.job.exp_table.size() + 1  # 13 for mage
	var ok: bool = _session.set_level(1, max_level + 5)
	assert_true(ok)
	ch = _session.get_character(1)
	assert_eq(ch.level, max_level)


func test_set_level_zero_returns_false() -> void:
	_write_fixture_save(1)
	_session.load_slot(1)
	var ok: bool = _session.set_level(1, 0)
	assert_false(ok)


func test_set_level_negative_returns_false() -> void:
	_write_fixture_save(1)
	_session.load_slot(1)
	var ok: bool = _session.set_level(1, -3)
	assert_false(ok)


# --- 2.11 recompute helpers ---

func test_recompute_hp_mp_from_level_does_not_change_spells() -> void:
	_write_fixture_save(1)
	_session.load_slot(1)
	# Set Mira to Lv5 (gains many spells)
	_session.set_level(1, 5)
	var ch_before := _session.get_character(1)
	var spells_before := ch_before.known_spells.duplicate()
	# Toggle a custom spell that wouldn't be granted by progression
	_session.toggle_known_spell(1, &"allheal", true)
	# Now corrupt HP/MP and recompute
	_session.set_max_hp(1, 1)
	_session.set_max_mp(1, 1)
	var ok: bool = _session.recompute_hp_mp_from_level(1)
	assert_true(ok)
	var ch := _session.get_character(1)
	# HP/MP rebuilt
	assert_gt(ch.max_hp, 1)
	assert_gt(ch.max_mp, 1)
	# Spells unchanged: still has allheal we added
	assert_true(ch.known_spells.has(&"allheal"),
		"recompute_hp_mp_from_level must not strip manually-added spells")


func test_recompute_spells_from_level_does_not_change_hp_mp() -> void:
	_write_fixture_save(1)
	_session.load_slot(1)
	_session.set_level(1, 5)
	# Manually scribble different HP and add a spurious spell
	_session.set_max_hp(1, 99)
	_session.set_max_mp(1, 99)
	_session.toggle_known_spell(1, &"allheal", true)
	var ok: bool = _session.recompute_spells_from_level(1)
	assert_true(ok)
	var ch := _session.get_character(1)
	# HP/MP unchanged
	assert_eq(ch.max_hp, 99)
	assert_eq(ch.max_mp, 99)
	# Spurious spell removed (re-derived from progression)
	assert_false(ch.known_spells.has(&"allheal"))


# --- 2.12 toggle_known_spell ---

func test_toggle_known_spell_adds_off_progression_spell() -> void:
	_write_fixture_save(1)
	_session.load_slot(1)
	# Mira is mage; allheal is priest-school spell (not in mage progression)
	_session.toggle_known_spell(1, &"allheal", true)
	_session.save_to_slot(1)
	var data := _read_save_json(1)
	var spells: Array = data["guild"]["characters"][1]["known_spells"]
	assert_true(spells.has("allheal"))


func test_toggle_known_spell_removes() -> void:
	_write_fixture_save(1)
	_session.load_slot(1)
	# Mira starts with fire/frost/dazil (per fixture)
	_session.toggle_known_spell(1, &"fire", false)
	_session.save_to_slot(1)
	var data := _read_save_json(1)
	var spells: Array = data["guild"]["characters"][1]["known_spells"]
	assert_false(spells.has("fire"))


# --- 2.13 set_gold ---

func test_set_gold_negative_allowed() -> void:
	_write_fixture_save(1)
	_session.load_slot(1)
	_session.set_gold(-100)
	_session.save_to_slot(1)
	var data := _read_save_json(1)
	assert_eq(int(data["inventory"]["gold"]), -100)


# --- 2.14 add_item ---

func test_add_item_appends_to_inventory() -> void:
	_write_fixture_save(1)
	_session.load_slot(1)
	var ok: bool = _session.add_item(&"mace", true)
	assert_true(ok)
	var inv := _session.list_inventory()
	assert_eq(inv.size(), 3)
	assert_eq(inv[2].item.item_id, &"mace")


func test_add_item_unknown_returns_false() -> void:
	_write_fixture_save(1)
	_session.load_slot(1)
	var ok: bool = _session.add_item(&"nonexistent_item_xyz", true)
	assert_false(ok)


# --- 2.15 remove_item with equipment auto-clear ---

func test_remove_item_clears_equipment_slot() -> void:
	_write_fixture_save(1)
	_session.load_slot(1)
	# Hero equips long_sword (inv idx 0). Remove it.
	var ok: bool = _session.remove_item(0)
	assert_true(ok)
	var ch := _session.get_character(0)
	# Weapon slot should be cleared
	assert_null(ch.equipment.get_equipped(Item.EquipSlot.WEAPON))


func test_remove_item_keeps_other_equipment_correct_after_index_shift() -> void:
	# Setup: two equipped items; remove the first; confirm the second is still
	# equipped post-save (re-loaded inventory).
	if not DirAccess.dir_exists_absolute(TEST_SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(TEST_SAVE_DIR)
	var data := {
		"version": 1,
		"last_saved": "2026-05-09 12:00:00",
		"game_location": "town",
		"current_dungeon_index": -1,
		"inventory": {
			"gold": 0,
			"items": [
				{"item_id": "long_sword", "identified": true},
				{"item_id": "healing_potion", "identified": true},
				{"item_id": "leather_armor", "identified": true},
			],
		},
		"guild": {
			"party_name": "Heroes",
			"characters": [
				_make_fighter_dict("Hero1"),
				_make_fighter_dict("Hero2"),
			],
			"front_row": [0, 1, null],
			"back_row": [null, null, null],
		},
		"dungeons": [],
	}
	# Hero1 equips long_sword (idx 0); Hero2 equips leather_armor (idx 2)
	data["guild"]["characters"][0]["equipment"] = {
		"weapon": 0, "armor": null, "helmet": null,
		"shield": null, "gauntlet": null, "accessory": null,
	}
	data["guild"]["characters"][1]["equipment"] = {
		"weapon": null, "armor": 2, "helmet": null,
		"shield": null, "gauntlet": null, "accessory": null,
	}
	var path := TEST_SAVE_DIR + "save_001.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	_session.load_slot(1)
	# Remove long_sword (idx 0)
	_session.remove_item(0)
	_session.save_to_slot(1)
	# Reload and verify Hero2 still has leather_armor (now at idx 1)
	var fresh := SaveSession.new(TEST_SAVE_DIR)
	fresh.load_slot(1)
	var armor: ItemInstance = fresh.get_character(1).equipment.get_equipped(Item.EquipSlot.ARMOR)
	assert_not_null(armor)
	assert_eq(armor.item.item_id, &"leather_armor")


# --- 2.16 equip without validation ---

func test_equip_bypasses_slot_type_check() -> void:
	_write_fixture_save(1)
	_session.load_slot(1)
	# Mira (mage) — equip a long_sword (idx 0) into the weapon slot
	# Mage is NOT in long_sword.allowed_jobs, but we expect this to succeed.
	var ok: bool = _session.equip(1, Item.EquipSlot.WEAPON, 0)
	assert_true(ok)
	var ch := _session.get_character(1)
	var weapon: ItemInstance = ch.equipment.get_equipped(Item.EquipSlot.WEAPON)
	assert_not_null(weapon)
	assert_eq(weapon.item.item_id, &"long_sword")


func test_equip_can_place_armor_into_weapon_slot() -> void:
	_write_fixture_save(1)
	_session.load_slot(1)
	_session.add_item(&"leather_armor", true)
	# leather_armor is at the end of inventory (idx 2 for the fixture)
	var inv := _session.list_inventory()
	var armor_idx: int = -1
	for i in range(inv.size()):
		if inv[i].item.item_id == &"leather_armor":
			armor_idx = i
	assert_gt(armor_idx, -1)
	var ok: bool = _session.equip(0, Item.EquipSlot.WEAPON, armor_idx)
	assert_true(ok)
	var ch := _session.get_character(0)
	var w: ItemInstance = ch.equipment.get_equipped(Item.EquipSlot.WEAPON)
	assert_eq(w.item.item_id, &"leather_armor")


# --- Equipment ownership: one instance, one holder ---
# Mirrors equipment_flow._unequip_from_other_holders: a given ItemInstance
# can only be equipped on one character at a time. The dev console's free-
# editing policy bypasses slot-type and job-allow checks, but it must still
# preserve this data-integrity invariant (otherwise two characters reference
# the same instance, which the game's runtime never produces and which leads
# to confusing bugs at load).

func test_equip_unequips_from_other_character_first() -> void:
	_write_fixture_save(1)
	_session.load_slot(1)
	# Hero (idx 0) starts with long_sword (inv idx 0) in WEAPON. Equip the
	# same instance to Mira (idx 1)'s WEAPON slot — Hero must lose it.
	_session.equip(1, Item.EquipSlot.WEAPON, 0)
	var hero := _session.get_character(0)
	var mira := _session.get_character(1)
	assert_null(hero.equipment.get_equipped(Item.EquipSlot.WEAPON),
		"Hero must lose long_sword when Mira equips the same instance")
	var miras_weapon: ItemInstance = mira.equipment.get_equipped(Item.EquipSlot.WEAPON)
	assert_not_null(miras_weapon)
	assert_eq(miras_weapon.item.item_id, &"long_sword")


func test_equip_unequips_from_same_character_other_slot() -> void:
	_write_fixture_save(1)
	_session.load_slot(1)
	# Hero already has long_sword in WEAPON. Move the same instance to ARMOR
	# slot (validation-bypass case). The previous WEAPON slot must clear so
	# the instance is referenced exactly once.
	_session.equip(0, Item.EquipSlot.ARMOR, 0)
	var hero := _session.get_character(0)
	assert_null(hero.equipment.get_equipped(Item.EquipSlot.WEAPON),
		"Hero's WEAPON must clear when same instance moves to ARMOR")
	var hero_armor: ItemInstance = hero.equipment.get_equipped(Item.EquipSlot.ARMOR)
	assert_not_null(hero_armor)
	assert_eq(hero_armor.item.item_id, &"long_sword")


func test_equip_to_same_slot_is_idempotent() -> void:
	_write_fixture_save(1)
	_session.load_slot(1)
	_session.equip(0, Item.EquipSlot.WEAPON, 0)
	var hero := _session.get_character(0)
	var w: ItemInstance = hero.equipment.get_equipped(Item.EquipSlot.WEAPON)
	assert_eq(w.item.item_id, &"long_sword")


# --- 2.17 unequip ---

func test_unequip_clears_slot() -> void:
	_write_fixture_save(1)
	_session.load_slot(1)
	var ok: bool = _session.unequip(0, Item.EquipSlot.WEAPON)
	assert_true(ok)
	var ch := _session.get_character(0)
	assert_null(ch.equipment.get_equipped(Item.EquipSlot.WEAPON))


# --- 2.18 round-trip integration: SaveManager compatible ---

func test_save_manager_can_load_dev_console_output() -> void:
	_write_fixture_save(1)
	_session.load_slot(1)
	# Make several edits
	_session.set_level(1, 4)
	_session.add_item(&"mace", true)
	_session.set_gold(9999)
	_session.equip(0, Item.EquipSlot.SHIELD, 1)  # Hero equips healing_potion to shield (validation off)
	_session.save_to_slot(1)
	# Now load via SaveManager (the production loader). It reads from the same
	# directory as our session, so we point a SaveManager there.
	if GameState.item_repository == null:
		GameState.item_repository = DataLoader.new().load_all_items()
	GameState.new_game()
	var sm := SaveManager.new(TEST_SAVE_DIR)
	var result: int = sm.load(1)
	assert_eq(result, SaveManager.LoadResult.OK)
	assert_eq(GameState.guild.get_all_characters().size(), 2)
	# Mage should be Lv4 now
	var loaded_mira: Character = null
	for ch in GameState.guild.get_all_characters():
		if ch.character_name == "Mira":
			loaded_mira = ch
	assert_not_null(loaded_mira)
	assert_eq(loaded_mira.level, 4)
	# Inventory should have 3 items now (long_sword, healing_potion, mace)
	assert_eq(GameState.inventory.list().size(), 3)
	assert_eq(GameState.inventory.gold, 9999)
