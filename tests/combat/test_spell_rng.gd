extends GutTest


# Test stub: extends SpellRng (project class) instead of RandomNumberGenerator
# (native class) so the override of roll() is a GDScript→GDScript override
# with no native_method_override warning. The fact that this file parses
# cleanly is itself part of the contract being verified.
class _StubRng extends SpellRng:
	var _value: int

	func _init(p_value: int = 7) -> void:
		super._init(null)
		_value = p_value

	func roll(_low: int, _high: int) -> int:
		return _value


func _seeded_rng(p_seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	return rng


# --- wrap & delegate ---

func test_roll_delegates_to_wrapped_rng() -> void:
	var rng := _seeded_rng(12345)
	var spell_rng := SpellRng.new(rng)
	# Recompute the expected value via the same rng state to confirm delegation
	# rather than asserting any specific number (which depends on Godot's RNG).
	var probe := _seeded_rng(12345)
	var expected: int = probe.randi_range(-3, 3)
	assert_eq(spell_rng.roll(-3, 3), expected,
		"SpellRng.roll(low, high) must equal wrapped rng.randi_range(low, high)")


func test_roll_consumes_wrapped_rng_state() -> void:
	# Two calls to roll() with the same args must produce the same sequence as
	# two calls to randi_range() on the same seeded rng.
	var spell_rng := SpellRng.new(_seeded_rng(99))
	var probe := _seeded_rng(99)
	assert_eq(spell_rng.roll(0, 100), probe.randi_range(0, 100))
	assert_eq(spell_rng.roll(0, 100), probe.randi_range(0, 100))
	assert_eq(spell_rng.roll(0, 100), probe.randi_range(0, 100))


# --- default construction ---

func test_default_construction_creates_internal_rng() -> void:
	# SpellRng.new() with no argument (or null) should still roll without errors.
	var spell_rng := SpellRng.new()
	var v: int = spell_rng.roll(-5, 5)
	assert_true(v >= -5 and v <= 5,
		"default SpellRng.roll must stay within the requested closed interval")


func test_explicit_null_construction_creates_internal_rng() -> void:
	var spell_rng := SpellRng.new(null)
	var v: int = spell_rng.roll(0, 0)
	assert_eq(v, 0, "roll(0, 0) is deterministic and must return 0")


# --- determinism through wrapper ---

func test_same_seed_yields_same_sequence_through_wrapper() -> void:
	var a := SpellRng.new(_seeded_rng(42))
	var b := SpellRng.new(_seeded_rng(42))
	for i in range(10):
		assert_eq(a.roll(-100, 100), b.roll(-100, 100),
			"identical seeds must produce identical roll sequences (iter %d)" % i)


# --- subclassability without native_method_override ---

func test_stub_subclass_overrides_roll_cleanly() -> void:
	# This test would not even reach run-time if the parse failed, so reaching
	# it implies _StubRng (defined at file top) parsed without
	# native_method_override warnings being escalated to errors.
	var stub := _StubRng.new(13)
	assert_eq(stub.roll(0, 999999), 13,
		"GDScript subclass override of SpellRng.roll must be honored")


func test_stub_can_be_passed_where_spell_rng_is_expected() -> void:
	# Verifies _StubRng IS-A SpellRng for type-system purposes (so production
	# code accepting `spell_rng: SpellRng` can be fed the stub directly).
	var stub: SpellRng = _StubRng.new(42)
	assert_eq(stub.roll(-1, 1), 42)
