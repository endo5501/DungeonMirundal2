extends GutTest

# CombatActor base+modifier integration: get_attack/defense/agility return
# `_get_base_<stat>() + modifier_stack.sum(&"<stat>")`. hit/evasion totals
# clamp at ±MOD_CAP. has_blind_flag default is false.


class _BaseStubActor extends CombatActor:
	var _base_atk: int
	var _base_def: int
	var _base_agi: int

	func _init(p_atk: int, p_def: int, p_agi: int) -> void:
		_base_atk = p_atk
		_base_def = p_def
		_base_agi = p_agi

	func _get_base_attack() -> int:
		return _base_atk

	func _get_base_defense() -> int:
		return _base_def

	func _get_base_agility() -> int:
		return _base_agi


# --- structure ---

func test_combat_actor_has_modifier_stack_property():
	var a := CombatActor.new()
	assert_not_null(a.modifier_stack)
	assert_is(a.modifier_stack, StatModifierStack)


func test_combat_actor_has_mod_cap_constant():
	# MOD_CAP is exposed on the class for use by DamageCalculator.
	assert_eq(CombatActor.MOD_CAP, 0.40)


# --- base + modifier composition ---

func test_get_attack_includes_modifier_sum():
	var a := _BaseStubActor.new(10, 0, 0)
	a.modifier_stack.add(&"attack", 2, 3)
	assert_eq(a.get_attack(), 12)


func test_get_attack_with_negative_modifier():
	var a := _BaseStubActor.new(10, 0, 0)
	a.modifier_stack.add(&"attack", -3, 1)
	assert_eq(a.get_attack(), 7)


func test_get_attack_with_zero_modifier_equals_base():
	var a := _BaseStubActor.new(10, 0, 0)
	assert_eq(a.get_attack(), 10)


func test_get_defense_includes_modifier_sum():
	var a := _BaseStubActor.new(0, 5, 0)
	a.modifier_stack.add(&"defense", -2, 1)
	assert_eq(a.get_defense(), 3)


func test_get_agility_includes_modifier_sum():
	var a := _BaseStubActor.new(0, 0, 8)
	a.modifier_stack.add(&"agility", 4, 2)
	assert_eq(a.get_agility(), 12)


# --- hit/evasion totals with clamp ---

func test_get_hit_modifier_total_returns_zero_by_default():
	var a := CombatActor.new()
	assert_almost_eq(a.get_hit_modifier_total(), 0.0, 0.0001)


func test_get_hit_modifier_total_clamps_at_positive_cap():
	var a := CombatActor.new()
	a.modifier_stack.add(&"hit", 0.6, 3)
	assert_almost_eq(a.get_hit_modifier_total(), 0.4, 0.0001)


func test_get_hit_modifier_total_clamps_at_negative_cap():
	var a := CombatActor.new()
	a.modifier_stack.add(&"hit", -0.7, 3)
	assert_almost_eq(a.get_hit_modifier_total(), -0.4, 0.0001)


func test_get_evasion_modifier_total_clamps_at_positive_cap():
	var a := CombatActor.new()
	a.modifier_stack.add(&"evasion", 0.5, 3)
	assert_almost_eq(a.get_evasion_modifier_total(), 0.4, 0.0001)


func test_get_evasion_modifier_total_clamps_at_negative_cap():
	var a := CombatActor.new()
	a.modifier_stack.add(&"evasion", -0.6, 3)
	assert_almost_eq(a.get_evasion_modifier_total(), -0.4, 0.0001)


# --- blind flag ---

func test_has_blind_flag_default_is_false():
	var a := CombatActor.new()
	assert_false(a.has_blind_flag())
