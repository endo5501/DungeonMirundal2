extends GutTest

const TEST_SEED: int = 424242


func _make_rng(seed_value: int = TEST_SEED) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _spec(
	name: String,
	race: String,
	job: String,
	level: int,
	row: String = "front"
) -> Dictionary:
	return {"name": name, "race": race, "job": job, "level": level, "row": row}


func _errors_joined(result: Dictionary) -> String:
	return "\n".join(result["errors"])


# --- Spells via production progression ---

func test_level_3_priest_knows_exactly_spells_through_level_3():
	var result := PartyFactory.build([_spec("Pr", "human", "priest", 3, "back")], _make_rng())
	assert_true(result["errors"].is_empty(), "expected no errors, got: %s" % _errors_joined(result))
	var ch: Character = result["characters"][0]
	assert_eq(ch.level, 3)
	var expected: Array[StringName] = []
	for lv in [1, 2, 3]:
		for sid in ch.job.spell_progression.get(lv, []):
			expected.append(StringName(sid))
	assert_gt(expected.size(), 0, "priest.tres should grant spells through level 3")
	for sid in expected:
		assert_true(ch.known_spells.has(sid), "missing spell %s" % sid)
	assert_eq(ch.known_spells.size(), expected.size())
	# Level-5 spells must NOT be known yet.
	for sid in ch.job.spell_progression.get(5, []):
		assert_false(ch.known_spells.has(StringName(sid)), "should not know level-5 spell %s" % sid)


# --- HP/MP growth through production level-up path ---

func test_level_3_priest_hp_mp_reflect_growth():
	var result := PartyFactory.build([_spec("Pr", "human", "priest", 3, "back")], _make_rng())
	assert_true(result["errors"].is_empty(), "expected no errors, got: %s" % _errors_joined(result))
	var ch: Character = result["characters"][0]
	var vit: int = int(ch.base_stats[&"VIT"])
	var expected_hp: int = ch.job.base_hp + vit / 3 + 2 * maxi(ch.job.hp_per_level + vit / 3, 1)
	assert_eq(ch.max_hp, expected_hp)
	assert_eq(ch.current_hp, expected_hp)
	var expected_mp: int = ch.job.base_mp + 2 * ch.job.mp_per_level
	assert_eq(ch.max_mp, expected_mp)
	assert_eq(ch.current_mp, expected_mp)


func test_level_1_member_gets_no_growth():
	var result := PartyFactory.build([_spec("F1", "human", "fighter", 1)], _make_rng())
	assert_true(result["errors"].is_empty(), "expected no errors, got: %s" % _errors_joined(result))
	var ch: Character = result["characters"][0]
	assert_eq(ch.level, 1)
	var vit: int = int(ch.base_stats[&"VIT"])
	assert_eq(ch.max_hp, ch.job.base_hp + vit / 3)
	assert_eq(ch.max_mp, 0)


# --- Row wiring ---

func test_row_is_applied_to_party_combatant_original_row():
	var result := PartyFactory.build([
		_spec("F1", "human", "fighter", 1, "front"),
		_spec("M1", "elf", "mage", 1, "back"),
	], _make_rng())
	assert_true(result["errors"].is_empty(), "expected no errors, got: %s" % _errors_joined(result))
	var combatants: Array = result["combatants"]
	assert_eq(combatants.size(), 2)
	assert_eq(combatants[0].original_row, Row.FRONT)
	assert_eq(combatants[1].original_row, Row.BACK)


func test_combatants_wrap_characters_in_spec_order():
	var result := PartyFactory.build([
		_spec("Alpha", "human", "fighter", 1),
		_spec("Beta", "human", "priest", 1, "back"),
	], _make_rng())
	assert_true(result["errors"].is_empty(), "expected no errors, got: %s" % _errors_joined(result))
	assert_eq(result["characters"][0].character_name, "Alpha")
	assert_eq(result["characters"][1].character_name, "Beta")
	assert_eq(result["combatants"][0].character, result["characters"][0])
	assert_eq(result["combatants"][1].character, result["characters"][1])


# --- Initial equipment via production path ---

func test_fighter_gets_initial_weapon_visible_through_provider():
	var result := PartyFactory.build([_spec("F1", "human", "fighter", 1)], _make_rng())
	assert_true(result["errors"].is_empty(), "expected no errors, got: %s" % _errors_joined(result))
	var ch: Character = result["characters"][0]
	var pc: PartyCombatant = result["combatants"][0]
	var weapon: ItemInstance = ch.equipment.get_equipped(Item.EquipSlot.WEAPON)
	assert_not_null(weapon, "fighter should have a weapon equipped from InitialEquipment")
	assert_not_null(pc.equipment_provider)
	var unarmed_attack: int = int(ch.base_stats[&"STR"]) / 2
	assert_gt(pc.equipment_provider.get_attack(ch), unarmed_attack,
		"equipped weapon should raise attack above the unarmed STR/2 baseline")


# --- Custom stats ---

func test_explicit_stats_override_default_template():
	var spec := _spec("F1", "human", "fighter", 1)
	spec["stats"] = {"STR": 15, "INT": 8, "PIE": 8, "VIT": 12, "AGI": 9, "LUC": 8}
	var result := PartyFactory.build([spec], _make_rng())
	assert_true(result["errors"].is_empty(), "expected no errors, got: %s" % _errors_joined(result))
	var ch: Character = result["characters"][0]
	assert_eq(int(ch.base_stats[&"STR"]), 15)
	assert_eq(int(ch.base_stats[&"VIT"]), 12)
	assert_eq(int(ch.base_stats[&"AGI"]), 9)


func test_default_stats_meet_job_requirements():
	# Priest requires PIE; the default template must qualify (Character.create
	# would return null otherwise).
	var result := PartyFactory.build([_spec("Pr", "human", "priest", 1, "back")], _make_rng())
	assert_true(result["errors"].is_empty(), "expected no errors, got: %s" % _errors_joined(result))
	var ch: Character = result["characters"][0]
	assert_true(ch.job.can_qualify(ch.base_stats))


# --- Error paths ---

func test_unknown_job_produces_error_naming_field_and_value():
	var result := PartyFactory.build([_spec("F1", "human", "paladin", 1)], _make_rng())
	assert_false(result["errors"].is_empty())
	assert_string_contains(_errors_joined(result), "job")
	assert_string_contains(_errors_joined(result), "paladin")


func test_unknown_race_produces_error_naming_field_and_value():
	var result := PartyFactory.build([_spec("F1", "orc", "fighter", 1)], _make_rng())
	assert_false(result["errors"].is_empty())
	assert_string_contains(_errors_joined(result), "race")
	assert_string_contains(_errors_joined(result), "orc")


# --- Determinism ---

func test_same_seed_produces_identical_hp_mp_rolls():
	var specs := [
		_spec("F1", "human", "fighter", 3),
		_spec("Pr", "human", "priest", 3, "back"),
		_spec("M1", "elf", "mage", 3, "back"),
	]
	var first := PartyFactory.build(specs, _make_rng())
	var second := PartyFactory.build(specs, _make_rng())
	assert_true(first["errors"].is_empty(), "expected no errors, got: %s" % _errors_joined(first))
	assert_true(second["errors"].is_empty(), "expected no errors, got: %s" % _errors_joined(second))
	for i in range(specs.size()):
		var a: Character = first["characters"][i]
		var b: Character = second["characters"][i]
		assert_eq(a.max_hp, b.max_hp, "max_hp mismatch for member %d" % i)
		assert_eq(a.max_mp, b.max_mp, "max_mp mismatch for member %d" % i)
		assert_eq(a.current_hp, b.current_hp, "current_hp mismatch for member %d" % i)
		assert_eq(a.current_mp, b.current_mp, "current_mp mismatch for member %d" % i)
