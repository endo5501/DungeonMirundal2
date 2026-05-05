extends GutTest

# CombatActor.stat_modifiers_changed signal emission rules
# (per combat-actor spec / combat-party-reactions design D6)
# - add() new entry → emit once
# - add() stronger replacement → emit once
# - add() equal magnitude (duration-only) → no emit
# - add() weaker (no-op) → no emit
# - tick removing entry (duration → 0) → emit once
# - tick that keeps entry → no emit


class _Counter:
	extends RefCounted
	var count: int = 0
	func bump() -> void:
		count += 1


func _make_actor_and_counter() -> Array:
	var a := CombatActor.new()
	var c := _Counter.new()
	a.stat_modifiers_changed.connect(c.bump)
	return [a, c]


# --- signal exists ---

func test_combat_actor_has_stat_modifiers_changed_signal():
	var a := CombatActor.new()
	assert_true(a.has_signal("stat_modifiers_changed"))


# --- add() emission rules ---

func test_add_new_entry_emits_signal():
	var a := CombatActor.new()
	var c := _Counter.new()
	a.stat_modifiers_changed.connect(c.bump)
	a.modifier_stack.add(&"attack", 2, 3)
	assert_eq(c.count, 1)


func test_add_stronger_replacement_emits_signal():
	var a := CombatActor.new()
	a.modifier_stack.add(&"attack", 1, 2)
	var c := _Counter.new()
	a.stat_modifiers_changed.connect(c.bump)
	a.modifier_stack.add(&"attack", 3, 4)
	assert_eq(c.count, 1)


func test_add_weaker_is_noop_does_not_emit():
	var a := CombatActor.new()
	a.modifier_stack.add(&"attack", 3, 4)
	var c := _Counter.new()
	a.stat_modifiers_changed.connect(c.bump)
	a.modifier_stack.add(&"attack", 1, 2)
	assert_eq(c.count, 0)


func test_add_equal_magnitude_duration_only_does_not_emit():
	var a := CombatActor.new()
	a.modifier_stack.add(&"attack", 2, 3)
	var c := _Counter.new()
	a.stat_modifiers_changed.connect(c.bump)
	a.modifier_stack.add(&"attack", 2, 5)
	assert_eq(c.count, 0)


# --- tick emission rules ---

func test_tick_removing_entry_emits_signal():
	var a := CombatActor.new()
	a.modifier_stack.add(&"attack", 2, 1)
	var c := _Counter.new()
	a.stat_modifiers_changed.connect(c.bump)
	a.modifier_stack.tick_battle_turn()
	assert_eq(c.count, 1)
	assert_true(a.modifier_stack.is_empty())


func test_tick_keeping_entry_does_not_emit():
	var a := CombatActor.new()
	a.modifier_stack.add(&"attack", 2, 3)
	var c := _Counter.new()
	a.stat_modifiers_changed.connect(c.bump)
	a.modifier_stack.tick_battle_turn()
	assert_eq(c.count, 0)


# --- regression: stack callback must not keep actor alive (cycle leak) ---

func test_actor_is_freeable_when_modifier_stack_holds_callback():
	# A CombatActor with its modifier_stack callback wired in _init must be
	# fully released when the local reference drops. Earlier versions used a
	# Callable that captured `self`, forming a cycle that RefCounted can't
	# break — actors leaked at game exit.
	var a := CombatActor.new()
	var weak: WeakRef = weakref(a)
	a = null  # drop our strong ref
	assert_null(weak.get_ref(), "CombatActor must be freed when external refs drop")
