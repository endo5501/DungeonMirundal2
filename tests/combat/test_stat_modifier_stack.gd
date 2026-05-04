extends GutTest

# StatModifierStack: β rule (stronger wins, equal magnitude → max duration,
# weaker is no-op), per-stat sum, per-turn tick, battle-only clear.


# --- structure ---

func test_modifier_stack_is_refcounted():
	var s := StatModifierStack.new()
	assert_is(s, RefCounted)


func test_new_stack_is_empty():
	var s := StatModifierStack.new()
	assert_true(s.is_empty())


# --- add: empty slot ---

func test_add_to_empty_slot_makes_value_visible_via_sum():
	var s := StatModifierStack.new()
	s.add(&"attack", 2, 3)
	assert_eq(s.sum(&"attack"), 2)
	assert_false(s.is_empty())


func test_add_float_to_empty_slot_for_hit_stat():
	var s := StatModifierStack.new()
	s.add(&"hit", 0.1, 3)
	assert_almost_eq(float(s.sum(&"hit")), 0.1, 0.0001)


# --- β rule: stronger overwrites delta and duration ---

func test_stronger_modifier_overwrites_existing_delta_and_duration():
	var s := StatModifierStack.new()
	s.add(&"attack", 2, 3)
	s.add(&"attack", -3, 1)
	assert_eq(s.sum(&"attack"), -3)


# --- β rule: weaker is no-op ---

func test_weaker_modifier_is_a_no_op():
	var s := StatModifierStack.new()
	s.add(&"attack", 2, 5)
	s.add(&"attack", 1, 99)
	assert_eq(s.sum(&"attack"), 2)


# --- β rule: equal magnitude → max(duration), keep existing delta ---

func test_equal_magnitude_extends_duration_only():
	var s := StatModifierStack.new()
	s.add(&"attack", 2, 3)
	s.add(&"attack", 2, 5)
	assert_eq(s.sum(&"attack"), 2)
	# duration is 5 → after 5 ticks should still hold; after a 6th tick, gone
	for i in range(5):
		s.tick_battle_turn()
	assert_eq(s.sum(&"attack"), 0)


func test_equal_magnitude_opposite_sign_keeps_existing_sign():
	var s := StatModifierStack.new()
	s.add(&"attack", 2, 3)
	s.add(&"attack", -2, 5)
	# β rule: equal magnitude is not "stronger", so existing entry keeps its sign
	assert_eq(s.sum(&"attack"), 2)


# --- different stats coexist ---

func test_different_stats_coexist_independently():
	var s := StatModifierStack.new()
	s.add(&"attack", 2, 3)
	s.add(&"defense", -1, 2)
	s.add(&"hit", 0.2, 4)
	assert_eq(s.sum(&"attack"), 2)
	assert_eq(s.sum(&"defense"), -1)
	assert_almost_eq(float(s.sum(&"hit")), 0.2, 0.0001)


# --- sum: empty stat returns 0 ---

func test_sum_on_unset_stat_returns_zero():
	var s := StatModifierStack.new()
	assert_eq(int(s.sum(&"attack")), 0)
	assert_eq(int(s.sum(&"defense")), 0)


# --- tick: decrements duration by 1 ---

func test_tick_battle_turn_decrements_duration_by_one():
	var s := StatModifierStack.new()
	s.add(&"attack", 2, 3)
	s.tick_battle_turn()
	# After 1 tick, duration is 2 → entry still present
	assert_eq(s.sum(&"attack"), 2)
	s.tick_battle_turn()
	# duration is 1 → still present
	assert_eq(s.sum(&"attack"), 2)
	s.tick_battle_turn()
	# duration becomes 0 → removed
	assert_eq(s.sum(&"attack"), 0)


func test_tick_removes_entry_when_duration_hits_zero():
	var s := StatModifierStack.new()
	s.add(&"attack", 2, 1)
	s.tick_battle_turn()
	assert_eq(s.sum(&"attack"), 0)
	assert_true(s.is_empty())


# --- clear_battle_only ---

func test_clear_battle_only_removes_all_entries():
	var s := StatModifierStack.new()
	s.add(&"attack", 2, 5)
	s.add(&"evasion", 0.1, 5)
	s.clear_battle_only()
	assert_eq(s.sum(&"attack"), 0)
	assert_almost_eq(float(s.sum(&"evasion")), 0.0, 0.0001)
	assert_true(s.is_empty())
