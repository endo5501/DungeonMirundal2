extends GutTest


class _StubMonster extends CombatActor:
	func _init(p_name: String, p_hp: int = 10) -> void:
		super()
		actor_name = p_name
		_hp = p_hp
		_max = p_hp
	var _hp: int
	var _max: int

	func _read_current_hp() -> int:
		return _hp

	func _write_current_hp(value: int) -> void:
		_hp = value

	func _read_max_hp() -> int:
		return _max


func _make_selector() -> CombatTargetSelector:
	var selector := CombatTargetSelector.new()
	add_child_autofree(selector)
	return selector


func test_show_with_no_flags_marks_all_reachable():
	var selector := _make_selector()
	var m1 := _StubMonster.new("M1")
	var m2 := _StubMonster.new("M2")
	selector.show_with([m1, m2])
	assert_true(selector.is_row_reachable(0))
	assert_true(selector.is_row_reachable(1))


func test_show_with_flags_marks_unreachable_rows():
	var selector := _make_selector()
	var m1 := _StubMonster.new("M1")
	var m2 := _StubMonster.new("M2")
	selector.show_with([m1, m2], [true, false])
	assert_true(selector.is_row_reachable(0))
	assert_false(selector.is_row_reachable(1))


func test_confirm_on_unreachable_row_does_not_emit():
	var selector := _make_selector()
	var m1 := _StubMonster.new("M1")
	var m2 := _StubMonster.new("M2")
	selector.show_with([m1, m2], [false, true])
	# After show_with, _selected_index should jump to first reachable (index 1)
	watch_signals(selector)
	# Force cursor onto the unreachable row
	selector.move_up()  # wraps to last; depending on init this may differ
	# Be explicit: navigate to index 0 by direct position check
	# (Test simulates a user using move_up/move_down, so just check via move_up wrapping)
	# Easier: since first reachable is index 1, currently at 1. Call move_up.
	# Actually we want a deterministic test; emulate cursor at row 0.
	# The simpler test: select_at(0) on an unreachable row should not emit.
	selector.select_at(0)
	assert_signal_not_emitted(selector, "target_selected")


func test_confirm_on_reachable_row_emits():
	var selector := _make_selector()
	var m1 := _StubMonster.new("M1")
	var m2 := _StubMonster.new("M2")
	selector.show_with([m1, m2], [false, true])
	watch_signals(selector)
	selector.select_at(1)
	assert_signal_emitted(selector, "target_selected")
