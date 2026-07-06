extends GutTest


func _curve(base: float, growth: float) -> Dictionary:
	return {"base": base, "growth": growth}


# growth 1.0 keeps every tier identical, isolating the knob under test.
func _flat_curves(
	hp: float = 10.0,
	attack: float = 2.0,
	defense: float = 1.0,
	agility: float = 4.0
) -> Dictionary:
	return {
		"hp": _curve(hp, 1.0),
		"attack": _curve(attack, 1.0),
		"defense": _curve(defense, 1.0),
		"agility": _curve(agility, 1.0),
	}


func _flat_dict(
	hp: float = 10.0,
	attack: float = 2.0,
	defense: float = 1.0,
	agility: float = 4.0
) -> Dictionary:
	return {
		"curves": _flat_curves(hp, attack, defense, agility),
		"hp_spread": 0.25,
		"species": {},
		"overrides": {},
	}


func _full_dict() -> Dictionary:
	return {
		"curves": {
			"hp": _curve(6.0, 1.75),
			"attack": _curve(2.5, 1.6),
			"defense": _curve(0.8, 1.7),
			"agility": _curve(4.0, 1.35),
		},
		"hp_spread": 0.25,
		"species": {
			"bat": {"hp": 0.6, "attack": 0.8, "agility": 2.0},
			"skeleton": {"hp": 1.2, "attack": 1.1, "agility": 0.9},
		},
		"overrides": {"dragon": {"attack": 25}},
	}


# Safety net for the file-loading tests below: they clean up after themselves
# on the happy path, but a mid-test script error would otherwise leak the
# user:// fixture into later runs.
func after_each():
	for path in [
		"user://test_monster_curve_valid.json",
		"user://test_monster_curve_broken.json",
		"user://test_monster_curve_array.json",
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _errors_joined(curve: MonsterCurve) -> String:
	return "\n".join(curve.errors)


func _warnings_joined(curve: MonsterCurve) -> String:
	return "\n".join(curve.warnings)


# --- 1.1 Definition loading and validation ---

func test_full_dict_parses_without_errors():
	var curve := MonsterCurve.parse(_full_dict())
	assert_not_null(curve)
	assert_true(curve.errors.is_empty(), "expected no errors, got: %s" % _errors_joined(curve))
	assert_almost_eq(float(curve.curves["hp"]["base"]), 6.0, 0.0001)
	assert_almost_eq(float(curve.curves["hp"]["growth"]), 1.75, 0.0001)
	assert_almost_eq(float(curve.curves["attack"]["base"]), 2.5, 0.0001)
	assert_almost_eq(float(curve.curves["defense"]["growth"]), 1.7, 0.0001)
	assert_almost_eq(float(curve.curves["agility"]["base"]), 4.0, 0.0001)
	assert_almost_eq(curve.hp_spread, 0.25, 0.0001)
	assert_true(curve.species.has("bat"))
	assert_almost_eq(float(curve.species["bat"]["hp"]), 0.6, 0.0001)
	assert_true(curve.overrides.has("dragon"))
	assert_eq(int(curve.overrides["dragon"]["attack"]), 25)


func test_missing_curve_key_is_error_naming_field():
	var dict := _full_dict()
	dict["curves"].erase("defense")
	var curve := MonsterCurve.parse(dict)
	assert_false(curve.errors.is_empty())
	assert_string_contains(_errors_joined(curve), "curves.defense")


func test_non_positive_growth_is_error_naming_field():
	var dict := _full_dict()
	dict["curves"]["attack"]["growth"] = 0.0
	var curve := MonsterCurve.parse(dict)
	assert_false(curve.errors.is_empty())
	assert_string_contains(_errors_joined(curve), "curves.attack.growth")


func test_non_positive_base_is_error_naming_field():
	var dict := _full_dict()
	dict["curves"]["hp"]["base"] = 0.0
	var curve := MonsterCurve.parse(dict)
	assert_false(curve.errors.is_empty())
	assert_string_contains(_errors_joined(curve), "curves.hp.base")


func test_hp_spread_at_or_above_one_is_error_naming_field():
	var dict := _full_dict()
	dict["hp_spread"] = 1.0
	var curve := MonsterCurve.parse(dict)
	assert_false(curve.errors.is_empty())
	assert_string_contains(_errors_joined(curve), "hp_spread")


func test_negative_hp_spread_is_error_naming_field():
	var dict := _full_dict()
	dict["hp_spread"] = -0.1
	var curve := MonsterCurve.parse(dict)
	assert_false(curve.errors.is_empty())
	assert_string_contains(_errors_joined(curve), "hp_spread")


func test_non_positive_species_modifier_is_error_naming_field():
	var dict := _full_dict()
	dict["species"]["bat"]["attack"] = 0.0
	var curve := MonsterCurve.parse(dict)
	assert_false(curve.errors.is_empty())
	assert_string_contains(_errors_joined(curve), "species.bat.attack")


func test_unknown_keys_are_errors_naming_field():
	var dict := _full_dict()
	dict["species"]["bat"]["speed"] = 1.0
	dict["overrides"]["dragon"]["hp"] = 30
	var curve := MonsterCurve.parse(dict)
	assert_false(curve.errors.is_empty())
	assert_string_contains(_errors_joined(curve), "species.bat.speed")
	assert_string_contains(_errors_joined(curve), "overrides.dragon.hp")


func test_multiple_problems_are_all_collected():
	var dict := _full_dict()
	dict["curves"].erase("defense")
	dict["curves"]["attack"]["growth"] = 0.0
	dict["hp_spread"] = 1.5
	dict["species"]["bat"]["attack"] = -1.0
	var curve := MonsterCurve.parse(dict)
	assert_gte(curve.errors.size(), 4)
	assert_string_contains(_errors_joined(curve), "curves.defense")
	assert_string_contains(_errors_joined(curve), "curves.attack.growth")
	assert_string_contains(_errors_joined(curve), "hp_spread")
	assert_string_contains(_errors_joined(curve), "species.bat.attack")


# --- 1.1 File loading ---

func test_valid_file_loads_and_parses():
	var path := "user://test_monster_curve_valid.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(_full_dict()))
	f.close()
	var curve := MonsterCurve.load_from_file(path)
	assert_not_null(curve)
	assert_true(curve.errors.is_empty(), "expected no errors, got: %s" % _errors_joined(curve))
	assert_almost_eq(float(curve.curves["hp"]["base"]), 6.0, 0.0001)
	assert_true(curve.species.has("skeleton"))
	DirAccess.remove_absolute(path)


func test_invalid_json_file_returns_null():
	var path := "user://test_monster_curve_broken.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	assert_null(MonsterCurve.load_from_file(path))
	DirAccess.remove_absolute(path)


func test_missing_file_returns_null():
	assert_null(MonsterCurve.load_from_file("user://test_monster_curve_missing_nope.json"))


func test_json_array_root_returns_null():
	var path := "user://test_monster_curve_array.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("[1, 2, 3]")
	f.close()
	assert_null(MonsterCurve.load_from_file(path))
	DirAccess.remove_absolute(path)


# --- 1.2 Curve calculator ---

func test_attack_grows_geometrically_with_tier():
	var dict := _flat_dict()
	dict["curves"]["attack"] = _curve(2.0, 2.0)
	dict["species"] = {"grunt": {"attack": 1.0}}
	var curve := MonsterCurve.parse(dict)
	assert_true(curve.errors.is_empty(), "expected no errors, got: %s" % _errors_joined(curve))
	assert_eq(curve.compute_stats("grunt", 1)["attack"], 2)
	assert_eq(curve.compute_stats("grunt", 2)["attack"], 4)
	assert_eq(curve.compute_stats("grunt", 3)["attack"], 8)


func test_role_modifier_scales_curve_value():
	var dict := _flat_dict()
	dict["curves"]["agility"] = _curve(4.0, 1.0)
	dict["species"] = {"bat": {"agility": 2.0}}
	var curve := MonsterCurve.parse(dict)
	assert_eq(curve.compute_stats("bat", 1)["agility"], 8)
	assert_eq(curve.compute_stats("bat", 3)["agility"], 8)
	assert_eq(curve.compute_stats("bat", 7)["agility"], 8)


func test_missing_modifier_keys_default_to_one():
	var dict := _flat_dict(10.0, 2.0, 1.0, 4.0)
	dict["species"] = {"slime": {"hp": 0.6}}
	var curve := MonsterCurve.parse(dict)
	var stats: Dictionary = curve.compute_stats("slime", 1)
	# hp modifier applies: mid = 6.0 -> 4.5 / 7.5 -> round-half-up 5 / 8.
	assert_eq(stats["hp_min"], 5)
	assert_eq(stats["hp_max"], 8)
	# The other stats use modifier 1.0 (plain curve values).
	assert_eq(stats["attack"], 2)
	assert_eq(stats["defense"], 1)
	assert_eq(stats["agility"], 4)


func test_hp_range_derives_from_spread():
	var dict := _flat_dict(20.0)
	dict["species"] = {"goblin": {}}
	var curve := MonsterCurve.parse(dict)
	var stats: Dictionary = curve.compute_stats("goblin", 1)
	assert_eq(stats["hp_min"], 15)
	assert_eq(stats["hp_max"], 25)


func test_species_hp_spread_override_wins_over_global():
	var dict := _flat_dict(20.0)
	dict["species"] = {"tank": {"hp_spread": 0.5}}
	var curve := MonsterCurve.parse(dict)
	assert_true(curve.errors.is_empty(), "expected no errors, got: %s" % _errors_joined(curve))
	var stats: Dictionary = curve.compute_stats("tank", 1)
	assert_eq(stats["hp_min"], 10)
	assert_eq(stats["hp_max"], 30)


func test_rounding_is_half_up():
	var dict := _flat_dict(10.0, 2.5, 0.5, 4.0)
	dict["species"] = {"goblin": {}}
	var curve := MonsterCurve.parse(dict)
	var stats: Dictionary = curve.compute_stats("goblin", 1)
	assert_eq(stats["attack"], 3)
	assert_eq(stats["defense"], 1)
	# hp mid 10, spread 0.25 -> raw 7.5 / 12.5 -> half-up 8 / 13.
	assert_eq(stats["hp_min"], 8)
	assert_eq(stats["hp_max"], 13)


func test_hp_and_attack_clamp_to_minimum_one():
	var dict := _flat_dict(0.2, 0.3)
	dict["hp_spread"] = 0.0
	dict["species"] = {"gnat": {}}
	var curve := MonsterCurve.parse(dict)
	var stats: Dictionary = curve.compute_stats("gnat", 1)
	assert_eq(stats["hp_min"], 1)
	assert_eq(stats["hp_max"], 1)
	assert_eq(stats["attack"], 1)


func test_defense_can_round_down_to_zero():
	var dict := _flat_dict(10.0, 2.0, 0.3)
	dict["species"] = {"bat": {}}
	var curve := MonsterCurve.parse(dict)
	assert_eq(curve.compute_stats("bat", 1)["defense"], 0)


func test_agility_can_round_down_to_zero():
	var dict := _flat_dict(10.0, 2.0, 1.0, 0.2)
	dict["species"] = {"slug": {}}
	var curve := MonsterCurve.parse(dict)
	assert_eq(curve.compute_stats("slug", 1)["agility"], 0)


func test_hp_min_never_exceeds_hp_max():
	var tiny := _flat_dict(0.4)
	tiny["hp_spread"] = 0.9
	tiny["species"] = {"mote": {}}
	var tiny_curve := MonsterCurve.parse(tiny)
	var tiny_stats: Dictionary = tiny_curve.compute_stats("mote", 1)
	assert_lte(tiny_stats["hp_min"], tiny_stats["hp_max"])
	var curve := MonsterCurve.parse(_full_dict())
	for species_id in ["bat", "skeleton"]:
		for tier in range(1, 9):
			var stats: Dictionary = curve.compute_stats(species_id, tier)
			assert_lte(
				stats["hp_min"],
				stats["hp_max"],
				"%s tier %d: hp_min > hp_max" % [species_id, tier]
			)


func test_compute_stats_is_deterministic():
	var first := MonsterCurve.parse(_full_dict())
	var second := MonsterCurve.parse(_full_dict())
	var a: Dictionary = first.compute_stats("skeleton", 4)
	var b: Dictionary = first.compute_stats("skeleton", 4)
	var c: Dictionary = second.compute_stats("skeleton", 4)
	assert_eq(a, b)
	assert_eq(a, c)


# --- 1.3 Overrides take precedence ---

func test_overridden_stat_ignores_curve_and_modifiers():
	var dict := _flat_dict(10.0, 4.0)
	dict["species"] = {"dragon": {"attack": 1.5}}
	dict["overrides"] = {"dragon": {"attack": 25}}
	var curve := MonsterCurve.parse(dict)
	assert_true(curve.errors.is_empty(), "expected no errors, got: %s" % _errors_joined(curve))
	assert_eq(curve.compute_stats("dragon", 1)["attack"], 25)
	assert_eq(curve.compute_stats("dragon", 5)["attack"], 25)


func test_non_overridden_stats_still_follow_curve():
	var dict := _flat_dict(10.0, 4.0, 3.0)
	dict["species"] = {"dragon": {"attack": 1.5}}
	dict["overrides"] = {"dragon": {"attack": 25}}
	var curve := MonsterCurve.parse(dict)
	var stats: Dictionary = curve.compute_stats("dragon", 1)
	assert_eq(stats["defense"], 3)
	assert_eq(stats["agility"], 4)
	assert_eq(stats["hp_min"], 8)
	assert_eq(stats["hp_max"], 13)


func test_hp_override_uses_hp_min_and_hp_max_keys():
	var dict := _flat_dict(10.0)
	dict["species"] = {"golem": {}}
	dict["overrides"] = {"golem": {"hp_min": 40, "hp_max": 44}}
	var curve := MonsterCurve.parse(dict)
	assert_true(curve.errors.is_empty(), "expected no errors, got: %s" % _errors_joined(curve))
	var stats: Dictionary = curve.compute_stats("golem", 1)
	assert_eq(stats["hp_min"], 40)
	assert_eq(stats["hp_max"], 44)
	# Attack remains curve-driven.
	assert_eq(stats["attack"], 2)


# --- 1.3 Normalization warnings ---

func test_balanced_modifiers_produce_no_warning():
	var dict := _flat_dict()
	# Geometric mean = (0.6 * 0.9 * 1.0 * 2.0)^(1/4) ~= 1.02, within 0.15.
	dict["species"] = {"bat": {"hp": 0.6, "agility": 2.0, "attack": 0.9}}
	var curve := MonsterCurve.parse(dict)
	assert_true(curve.errors.is_empty(), "expected no errors, got: %s" % _errors_joined(curve))
	assert_true(
		curve.warnings.is_empty(),
		"expected no warnings, got: %s" % _warnings_joined(curve)
	)


func test_lopsided_modifiers_produce_warning_but_remain_usable():
	var dict := _flat_dict(10.0, 2.0)
	# Geometric mean = 2.0, deviates from 1.0 by more than 0.15.
	dict["species"] = {
		"big_boy": {"hp": 2.0, "attack": 2.0, "defense": 2.0, "agility": 2.0},
	}
	var curve := MonsterCurve.parse(dict)
	assert_true(curve.errors.is_empty(), "expected no errors, got: %s" % _errors_joined(curve))
	assert_false(curve.warnings.is_empty())
	assert_string_contains(_warnings_joined(curve), "big_boy")
	assert_string_contains(_warnings_joined(curve), "2.0")
	# Warnings never block: stats are still computed.
	assert_eq(curve.compute_stats("big_boy", 1)["attack"], 4)


# --- Override value validation ---

func test_negative_override_value_is_error_naming_field():
	var dict := _full_dict()
	dict["overrides"]["dragon"]["attack"] = -5
	var curve := MonsterCurve.parse(dict)
	assert_false(curve.errors.is_empty())
	assert_string_contains(_errors_joined(curve), "overrides.dragon.attack")


func test_inverted_override_hp_range_is_error_naming_field():
	var dict := _full_dict()
	dict["overrides"] = {"golem": {"hp_min": 40, "hp_max": 10}}
	var curve := MonsterCurve.parse(dict)
	assert_false(curve.errors.is_empty())
	assert_string_contains(_errors_joined(curve), "overrides.golem")
	assert_string_contains(_errors_joined(curve), "hp_min")


func test_fractional_override_value_is_error_naming_field():
	var dict := _full_dict()
	dict["overrides"]["dragon"]["attack"] = 25.7
	var curve := MonsterCurve.parse(dict)
	assert_false(curve.errors.is_empty())
	assert_string_contains(_errors_joined(curve), "overrides.dragon.attack")


# JSON numbers arrive as floats, so whole floats must stay accepted.
func test_whole_float_override_value_is_accepted():
	var dict := _full_dict()
	dict["overrides"]["dragon"]["attack"] = 25.0
	var curve := MonsterCurve.parse(dict)
	assert_true(curve.errors.is_empty(), "expected no errors, got: %s" % _errors_joined(curve))
	assert_eq(int(curve.overrides["dragon"]["attack"]), 25)
	assert_eq(curve.compute_stats("dragon", 3)["attack"], 25)
