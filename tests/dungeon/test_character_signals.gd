extends GutTest

# Verifies the change-notification signals on Character: hp_changed,
# mp_changed, statuses_changed. Also covers _suspend_signals behavior
# (used by Character.from_dict to avoid spurious emissions during load).


func _make_character() -> Character:
	# Build a Character without going through Character.create() so the
	# tests focus narrowly on signal emission from field setters.
	var ch := Character.new()
	ch.character_name = "Tester"
	ch.level = 1
	ch.max_hp = 30
	ch.current_hp = 20
	ch.max_mp = 10
	ch.current_mp = 5
	return ch


# --- hp_changed ---

func test_hp_changed_fires_on_current_hp_change():
	var ch := _make_character()
	watch_signals(ch)
	ch.current_hp = 15
	assert_signal_emit_count(ch, "hp_changed", 1)
	assert_signal_emitted_with_parameters(ch, "hp_changed", [15, 30])


func test_hp_changed_fires_on_max_hp_change():
	var ch := _make_character()
	watch_signals(ch)
	ch.max_hp = 35
	assert_signal_emit_count(ch, "hp_changed", 1)
	assert_signal_emitted_with_parameters(ch, "hp_changed", [20, 35])


func test_hp_changed_does_not_fire_on_equal_current_hp():
	var ch := _make_character()
	watch_signals(ch)
	ch.current_hp = 20  # same as current value
	assert_signal_emit_count(ch, "hp_changed", 0)


func test_hp_changed_does_not_fire_on_equal_max_hp():
	var ch := _make_character()
	watch_signals(ch)
	ch.max_hp = 30  # same as current value
	assert_signal_emit_count(ch, "hp_changed", 0)


# --- mp_changed ---

func test_mp_changed_fires_on_current_mp_change():
	var ch := _make_character()
	watch_signals(ch)
	ch.current_mp = 3
	assert_signal_emit_count(ch, "mp_changed", 1)
	assert_signal_emitted_with_parameters(ch, "mp_changed", [3, 10])


func test_mp_changed_fires_on_max_mp_change():
	var ch := _make_character()
	watch_signals(ch)
	ch.max_mp = 12
	assert_signal_emit_count(ch, "mp_changed", 1)
	assert_signal_emitted_with_parameters(ch, "mp_changed", [5, 12])


func test_mp_changed_does_not_fire_on_equal_value():
	var ch := _make_character()
	watch_signals(ch)
	ch.current_mp = 5
	ch.max_mp = 10
	assert_signal_emit_count(ch, "mp_changed", 0)


# --- statuses_changed ---

func test_statuses_changed_fires_when_array_content_differs():
	var ch := _make_character()
	watch_signals(ch)
	var new_arr: Array[StringName] = [&"poison"]
	ch.persistent_statuses = new_arr
	assert_signal_emit_count(ch, "statuses_changed", 1)


func test_statuses_changed_fires_on_removal():
	var ch := _make_character()
	var seeded: Array[StringName] = [&"poison"]
	ch.persistent_statuses = seeded
	watch_signals(ch)
	var empty: Array[StringName] = []
	ch.persistent_statuses = empty
	assert_signal_emit_count(ch, "statuses_changed", 1)


func test_statuses_changed_does_not_fire_when_array_content_equal():
	var ch := _make_character()
	var seeded: Array[StringName] = [&"poison"]
	ch.persistent_statuses = seeded
	watch_signals(ch)
	var same: Array[StringName] = [&"poison"]
	ch.persistent_statuses = same
	assert_signal_emit_count(ch, "statuses_changed", 0)


# --- _suspend_signals ---

func test_suspend_signals_blocks_all_emissions():
	var ch := _make_character()
	ch._suspend_signals = true
	watch_signals(ch)
	ch.current_hp = 5
	ch.max_hp = 25
	ch.current_mp = 1
	ch.max_mp = 8
	var arr: Array[StringName] = [&"poison"]
	ch.persistent_statuses = arr
	assert_signal_emit_count(ch, "hp_changed", 0)
	assert_signal_emit_count(ch, "mp_changed", 0)
	assert_signal_emit_count(ch, "statuses_changed", 0)


func test_signals_resume_after_suspend_cleared():
	var ch := _make_character()
	ch._suspend_signals = true
	ch.current_hp = 5  # silently mutated
	ch._suspend_signals = false
	watch_signals(ch)
	ch.current_hp = 4
	assert_signal_emit_count(ch, "hp_changed", 1)
	assert_signal_emitted_with_parameters(ch, "hp_changed", [4, 30])
