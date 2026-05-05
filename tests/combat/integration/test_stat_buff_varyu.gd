extends GutTest


# Integration: varyu (HIT +0.2 / 4 turns) raises a target ally's hit modifier
# so their hit_chance against any defender rises by 0.2.

class _StubActor extends CombatActor:
	var _base_atk: int
	var _base_def: int
	var _base_agi: int
	var _hp: int
	var _max: int

	func _init(p_atk: int, p_def: int, p_agi: int, p_hp: int = 30) -> void:
		_base_atk = p_atk
		_base_def = p_def
		_base_agi = p_agi
		_hp = p_hp
		_max = p_hp
		actor_name = "Stub"

	func _get_base_attack() -> int:
		return _base_atk

	func _get_base_defense() -> int:
		return _base_def

	func _get_base_agility() -> int:
		return _base_agi

	func _read_current_hp() -> int:
		return _hp

	func _write_current_hp(value: int) -> void:
		_hp = value

	func _read_max_hp() -> int:
		return _max


func test_varyu_loads_and_raises_hit_modifier_to_plus_zero_point_two():
	var varyu := load("res://data/spells/varyu.tres") as SpellData
	assert_not_null(varyu)
	var fighter := _StubActor.new(10, 0, 5)
	varyu.effect.apply(null, [fighter], null)
	assert_almost_eq(float(fighter.modifier_stack.sum(&"hit")), 0.2, 0.0001)
	assert_almost_eq(fighter.get_hit_modifier_total(), 0.2, 0.0001)


func test_varyu_raises_attacker_hit_chance_by_zero_point_two():
	var varyu := load("res://data/spells/varyu.tres") as SpellData
	# DamageCalculator.hit_chance clamps at 0.99. With BASE_HIT 0.85 and equal
	# AGI, an unmodified attacker is already at 0.85, so a naive +0.2 buff would
	# saturate at 0.99 (visible delta 0.14). Pre-applying +0.2 evasion to the
	# defender pulls the unbuffed hit_chance down to 0.65, leaving room for the
	# full +0.2 delta to land within the [0.05, 0.99] window.
	var fighter_a := _StubActor.new(10, 0, 5)
	var slime := _StubActor.new(0, 0, 5)
	slime.modifier_stack.add(&"evasion", 0.2, 99)
	var fighter_b := _StubActor.new(10, 0, 5)
	var hit_no_buff := DamageCalculator.hit_chance(fighter_a, slime)
	varyu.effect.apply(null, [fighter_b], null)
	var hit_buffed := DamageCalculator.hit_chance(fighter_b, slime)
	assert_almost_eq(hit_buffed - hit_no_buff, 0.2, 0.0001,
		"varyu (+0.2 HIT) should raise attacker hit_chance by exactly 0.2")
