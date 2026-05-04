extends GutTest


class _FakeActor extends CombatActor:
	var _current: int
	var _max: int

	func _init(p_max: int, p_name: String = "Fake") -> void:
		_max = p_max
		_current = p_max
		actor_name = p_name

	func _read_current_hp() -> int:
		return _current

	func _write_current_hp(value: int) -> void:
		_current = value

	func _read_max_hp() -> int:
		return _max


class _FixedRng extends RandomNumberGenerator:
	# A minimal RNG stub: returns the next value from a queue for randi_range.
	# Falls back to 0 when queue empty.
	var _queue: Array[int] = []

	func enqueue(values: Array) -> void:
		for v in values:
			_queue.append(int(v))

	func randi_range(_from: int, _to: int) -> int:
		if _queue.is_empty():
			return 0
		return _queue.pop_front()


func _make_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	return rng


# --- DamageSpellEffect ---

func test_damage_zero_spread_uses_base_exactly():
	var effect := DamageSpellEffect.new()
	effect.base_damage = 6
	effect.spread = 0
	var target := _FakeActor.new(20, "T")
	var resolution := effect.apply(null, [target], _make_rng())
	assert_eq(target.current_hp, 14)
	assert_eq(resolution.size(), 1)
	assert_eq(resolution.entries[0]["hp_delta"], -6)
	assert_eq(resolution.entries[0]["actor"], target)


func test_damage_with_spread_uses_rng():
	var effect := DamageSpellEffect.new()
	effect.base_damage = 5
	effect.spread = 2
	var rng := _FixedRng.new()
	rng.enqueue([1])  # +1 over base
	var target := _FakeActor.new(20, "T")
	var resolution := effect.apply(null, [target], rng)
	# 5 + 1 = 6
	assert_eq(target.current_hp, 14)
	assert_eq(resolution.entries[0]["hp_delta"], -6)


func test_damage_minimum_floor_is_one():
	var effect := DamageSpellEffect.new()
	effect.base_damage = 1
	effect.spread = 5
	var rng := _FixedRng.new()
	rng.enqueue([-5])  # base 1 + (-5) = -4 → floor to 1
	var target := _FakeActor.new(20, "T")
	effect.apply(null, [target], rng)
	assert_eq(target.current_hp, 19)


func test_damage_applies_to_multiple_targets_independently():
	var effect := DamageSpellEffect.new()
	effect.base_damage = 5
	effect.spread = 1
	var rng := _FixedRng.new()
	rng.enqueue([1, 0, -1])
	var t1 := _FakeActor.new(20, "T1")
	var t2 := _FakeActor.new(20, "T2")
	var t3 := _FakeActor.new(20, "T3")
	var resolution := effect.apply(null, [t1, t2, t3], rng)
	assert_eq(resolution.size(), 3)
	assert_eq(resolution.entries[0]["actor"], t1)
	assert_eq(resolution.entries[1]["actor"], t2)
	assert_eq(resolution.entries[2]["actor"], t3)
	assert_eq(t1.current_hp, 14)  # 6 dmg
	assert_eq(t2.current_hp, 15)  # 5 dmg
	assert_eq(t3.current_hp, 16)  # 4 dmg


# --- HealSpellEffect ---

func test_heal_zero_spread_restores_up_to_max():
	var effect := HealSpellEffect.new()
	effect.base_heal = 8
	effect.spread = 0
	var target := _FakeActor.new(12, "T")
	target.take_damage(7)  # current_hp = 5
	var resolution := effect.apply(null, [target], _make_rng())
	# 5 + 8 = 13, clamped to max 12
	assert_eq(target.current_hp, 12)
	assert_eq(resolution.entries[0]["hp_delta"], 7)


func test_heal_at_full_hp_is_no_op():
	var effect := HealSpellEffect.new()
	effect.base_heal = 8
	effect.spread = 0
	var target := _FakeActor.new(10, "T")
	var resolution := effect.apply(null, [target], _make_rng())
	assert_eq(target.current_hp, 10)
	assert_eq(resolution.size(), 1)
	assert_eq(resolution.entries[0]["hp_delta"], 0)


func test_heal_skips_dead_targets():
	var effect := HealSpellEffect.new()
	effect.base_heal = 8
	effect.spread = 0
	var alive_a := _FakeActor.new(20, "A")
	alive_a.take_damage(5)
	var dead := _FakeActor.new(15, "D")
	dead.take_damage(15)  # current_hp = 0
	var alive_b := _FakeActor.new(20, "B")
	alive_b.take_damage(5)
	var resolution := effect.apply(null, [alive_a, dead, alive_b], _make_rng())
	# Only living entries; dead actor's current_hp must remain 0
	assert_eq(resolution.size(), 2)
	assert_eq(dead.current_hp, 0)
	# Actors in resolution should be A and B, in that order
	assert_eq(resolution.entries[0]["actor"], alive_a)
	assert_eq(resolution.entries[1]["actor"], alive_b)


func test_heal_minimum_floor_is_one():
	var effect := HealSpellEffect.new()
	effect.base_heal = 1
	effect.spread = 5
	var rng := _FixedRng.new()
	rng.enqueue([-5])
	var target := _FakeActor.new(20, "T")
	target.take_damage(10)  # current_hp = 10
	var resolution := effect.apply(null, [target], rng)
	# 10 + max(1+(-5), 1) = 10 + 1 = 11
	assert_eq(target.current_hp, 11)
	assert_eq(resolution.entries[0]["hp_delta"], 1)


# --- SpellEffect base default ---

func test_base_spell_effect_returns_empty_resolution():
	var effect := SpellEffect.new()
	var target := _FakeActor.new(10)
	var resolution := effect.apply(null, [target], _make_rng())
	assert_eq(resolution.size(), 0)
