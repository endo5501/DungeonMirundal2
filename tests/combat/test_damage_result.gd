extends GutTest


func test_damage_result_is_refcounted():
	var r := DamageResult.new()
	assert_is(r, RefCounted)


func test_damage_result_default_is_zero_hit_true():
	var r := DamageResult.new()
	assert_true(r.hit)
	assert_eq(r.amount, 0)


func test_damage_result_construct_hit_with_amount():
	var r := DamageResult.new(true, 5)
	assert_true(r.hit)
	assert_eq(r.amount, 5)


func test_damage_result_construct_miss_with_zero():
	var r := DamageResult.new(false, 0)
	assert_false(r.hit)
	assert_eq(r.amount, 0)


func test_damage_result_instances_are_independent():
	var a := DamageResult.new(true, 5)
	var b := DamageResult.new(false, 0)
	a.amount = 99
	assert_eq(a.amount, 99)
	assert_eq(b.amount, 0)
	assert_false(b.hit)
