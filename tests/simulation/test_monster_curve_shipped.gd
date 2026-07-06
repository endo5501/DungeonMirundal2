extends GutTest

# Task 2.2: the shipped balance definition data/balance/monster_curve.json
# must load with zero errors and cover every shipped monster species.
# Normalization warnings are allowed (bat / skeleton / witch / wraith
# intentionally deviate), so nothing here asserts on `warnings`.

const SHIPPED_PATH := "res://data/balance/monster_curve.json"
const SHIPPED_SPECIES: Array[String] = [
	"slime",
	"bat",
	"goblin",
	"skeleton",
	"imp",
	"goblin_shaman",
	"ghost",
	"dark_priest",
	"witch",
	"wraith",
	"lich",
	"dragon",
]
# Shipped monster id -> tier, mirrored from data/monsters/*.tres.
const SHIPPED_TIERS := {
	"slime": 1,
	"bat": 1,
	"goblin": 2,
	"skeleton": 2,
	"imp": 3,
	"goblin_shaman": 3,
	"ghost": 3,
	"dark_priest": 4,
	"witch": 4,
	"wraith": 4,
	"lich": 5,
	"dragon": 5,
}


func _load_shipped() -> MonsterCurve:
	return MonsterCurve.load_from_file(SHIPPED_PATH)


func test_shipped_definition_loads():
	assert_not_null(_load_shipped(), "expected %s to load as JSON" % SHIPPED_PATH)


func test_shipped_definition_has_zero_errors():
	var curve := _load_shipped()
	assert_not_null(curve)
	assert_true(
		curve.errors.is_empty(),
		"expected no errors, got: %s" % "\n".join(curve.errors)
	)


func test_every_shipped_monster_is_covered_by_species_or_overrides():
	var curve := _load_shipped()
	assert_not_null(curve)
	for species_id in SHIPPED_SPECIES:
		assert_true(
			curve.species.has(species_id) or curve.overrides.has(species_id),
			"%s is missing from both species and overrides" % species_id
		)


func test_shipped_definition_computes_sane_stats_for_all_monsters():
	var curve := _load_shipped()
	assert_not_null(curve)
	for species_id in SHIPPED_TIERS:
		var stats: Dictionary = curve.compute_stats(species_id, int(SHIPPED_TIERS[species_id]))
		assert_gte(int(stats["hp_min"]), 1, "%s: hp_min below 1" % species_id)
		assert_lte(
			int(stats["hp_min"]),
			int(stats["hp_max"]),
			"%s: hp_min exceeds hp_max" % species_id
		)
		assert_gte(int(stats["attack"]), 1, "%s: attack below 1" % species_id)
		assert_gte(int(stats["defense"]), 0, "%s: defense below 0" % species_id)
		assert_gte(int(stats["agility"]), 0, "%s: agility below 0" % species_id)
