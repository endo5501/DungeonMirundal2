extends GutTest


class _MpHaver:
	extends RefCounted
	var max_mp: int = 0


class _NoMpField:
	extends RefCounted
	var hp: int = 5


func _ctx() -> ItemUseContext:
	return ItemUseContext.make(false, false)


func test_satisfied_when_max_mp_positive():
	var cond := HasMpSlot.new()
	var t := _MpHaver.new()
	t.max_mp = 5
	assert_true(cond.is_satisfied(t, _ctx()))


func test_not_satisfied_when_max_mp_zero():
	var cond := HasMpSlot.new()
	var t := _MpHaver.new()
	t.max_mp = 0
	assert_false(cond.is_satisfied(t, _ctx()))


func test_not_satisfied_when_target_has_no_max_mp_property():
	var cond := HasMpSlot.new()
	var t := _NoMpField.new()
	assert_false(cond.is_satisfied(t, _ctx()))


func test_not_satisfied_when_target_is_null():
	var cond := HasMpSlot.new()
	assert_false(cond.is_satisfied(null, _ctx()))


func test_reason_is_no_mp_class_message():
	var cond := HasMpSlot.new()
	assert_eq(cond.reason(), "MP を持たない職業")
