extends GutTest

# Sanity test for the CombatTestRng helper itself: certain-hit/miss seeds must
# actually behave that way at the FINAL_HIT_MIN/MAX clamps.


func test_certain_hit_rng_first_randf_is_below_floor():
	var rng := CombatTestRng.make_certain_hit_rng()
	assert_not_null(rng)
	var r := rng.randf()
	assert_true(r < DamageCalculator.FINAL_HIT_MIN, "randf=%f should be < %f" % [r, DamageCalculator.FINAL_HIT_MIN])


func test_certain_miss_rng_first_randf_is_above_ceiling():
	var rng := CombatTestRng.make_certain_miss_rng()
	assert_not_null(rng)
	var r := rng.randf()
	assert_true(r > DamageCalculator.FINAL_HIT_MAX, "randf=%f should be > %f" % [r, DamageCalculator.FINAL_HIT_MAX])


func test_certain_hit_rng_with_two_extra_consumes():
	# After two randi_range tiebreaks (typical for a 2-actor turn order), the
	# next randf must still be below the hit floor.
	var rng := CombatTestRng.make_certain_hit_rng(2)
	assert_not_null(rng)
	rng.randi_range(0, 999999)
	rng.randi_range(0, 999999)
	var r := rng.randf()
	assert_true(r < DamageCalculator.FINAL_HIT_MIN, "post-tiebreak randf=%f should be < %f" % [r, DamageCalculator.FINAL_HIT_MIN])


func test_certain_miss_rng_with_two_extra_consumes():
	var rng := CombatTestRng.make_certain_miss_rng(2)
	assert_not_null(rng)
	rng.randi_range(0, 999999)
	rng.randi_range(0, 999999)
	var r := rng.randf()
	assert_true(r > DamageCalculator.FINAL_HIT_MAX, "post-tiebreak randf=%f should be > %f" % [r, DamageCalculator.FINAL_HIT_MAX])
