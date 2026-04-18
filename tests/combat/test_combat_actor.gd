extends GutTest


class _FakeActor extends CombatActor:
	var _current: int
	var _max: int

	func _init(p_max: int) -> void:
		_max = p_max
		_current = p_max
		actor_name = "Fake"

	func _read_current_hp() -> int:
		return _current

	func _write_current_hp(value: int) -> void:
		_current = value

	func _read_max_hp() -> int:
		return _max


# --- interface shape ---

func test_combat_actor_is_refcounted():
	var a := _FakeActor.new(10)
	assert_is(a, RefCounted)


func test_combat_actor_exposes_required_methods():
	var a := _FakeActor.new(10)
	assert_true(a.has_method("get_attack"))
	assert_true(a.has_method("get_defense"))
	assert_true(a.has_method("get_agility"))
	assert_true(a.has_method("is_alive"))
	assert_true(a.has_method("take_damage"))
	assert_true(a.has_method("apply_defend"))
	assert_true(a.has_method("clear_turn_flags"))


func test_default_virtual_stats_return_zero():
	var a := _FakeActor.new(10)
	assert_eq(a.get_attack(), 0)
	assert_eq(a.get_defense(), 0)
	assert_eq(a.get_agility(), 0)


# --- is_alive ---

func test_is_alive_when_hp_positive():
	var a := _FakeActor.new(10)
	assert_true(a.is_alive())


func test_not_alive_when_hp_zero():
	var a := _FakeActor.new(10)
	a.take_damage(10)
	assert_false(a.is_alive())


# --- take_damage ---

func test_take_damage_reduces_current_hp():
	var a := _FakeActor.new(30)
	a.take_damage(5)
	assert_eq(a.current_hp, 25)


func test_take_damage_clamps_to_zero():
	var a := _FakeActor.new(10)
	a.take_damage(100)
	assert_eq(a.current_hp, 0)


func test_take_damage_zero_does_not_change_hp():
	var a := _FakeActor.new(10)
	a.take_damage(0)
	assert_eq(a.current_hp, 10)


# --- defend ---

func test_apply_defend_halves_incoming_damage():
	var a := _FakeActor.new(20)
	a.apply_defend()
	a.take_damage(8)
	assert_eq(a.current_hp, 16)  # 20 - 4


func test_defend_minimum_damage_is_one_when_positive():
	var a := _FakeActor.new(20)
	a.apply_defend()
	a.take_damage(1)  # 1/2 = 0, but min is 1
	assert_eq(a.current_hp, 19)


func test_defend_zero_damage_is_still_zero():
	var a := _FakeActor.new(20)
	a.apply_defend()
	a.take_damage(0)
	assert_eq(a.current_hp, 20)


func test_clear_turn_flags_removes_defend():
	var a := _FakeActor.new(20)
	a.apply_defend()
	a.clear_turn_flags()
	a.take_damage(8)
	assert_eq(a.current_hp, 12)


# --- properties ---

func test_current_hp_and_max_hp_are_readable_as_properties():
	var a := _FakeActor.new(15)
	assert_eq(a.current_hp, 15)
	assert_eq(a.max_hp, 15)
