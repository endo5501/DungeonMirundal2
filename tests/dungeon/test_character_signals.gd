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


# --- from_dict suspension ---

func _make_full_character_dict() -> Dictionary:
	# Build a from_dict-compatible payload using real loaded race/job so
	# from_dict's resource resolution succeeds.
	var d: Dictionary = {
		"character_name": "Loaded",
		"race_id": "human",
		"job_id": "fighter",
		"level": 1,
		"base_stats": {"STR": 10, "INT": 8, "PIE": 8, "VIT": 10, "AGI": 8, "LUC": 8},
		"current_hp": 12,
		"max_hp": 12,
		"current_mp": 0,
		"max_mp": 0,
		"accumulated_exp": 0,
		"known_spells": [],
		"persistent_statuses": ["poison"],
	}
	return d


func test_from_dict_returns_character_with_suspension_flag_cleared():
	var data := _make_full_character_dict()
	var ch := Character.from_dict(data)
	assert_not_null(ch, "from_dict should resolve real race/job")
	assert_eq(ch._suspend_signals, false,
		"from_dict must restore _suspend_signals to false before returning")


func test_from_dict_post_load_mutations_emit_signals_normally():
	var data := _make_full_character_dict()
	var ch := Character.from_dict(data)
	assert_not_null(ch)
	# If from_dict failed to clear _suspend_signals, this mutation would be
	# silently swallowed and the assertion would fail.
	watch_signals(ch)
	ch.current_hp = ch.current_hp - 1
	assert_signal_emit_count(ch, "hp_changed", 1)


func test_from_dict_loaded_fields_match_payload():
	# Sanity check: from_dict still produces correct values even with the
	# suspension/restoration dance around field assignments.
	var data := _make_full_character_dict()
	var ch := Character.from_dict(data)
	assert_not_null(ch)
	assert_eq(ch.character_name, "Loaded")
	assert_eq(ch.current_hp, 12)
	assert_eq(ch.max_hp, 12)
	assert_eq(ch.persistent_statuses.size(), 1)
	assert_eq(ch.persistent_statuses[0], &"poison")


func test_from_dict_with_missing_race_returns_null_without_polluting_other_instances():
	# Early return on race resolution failure must not leave any global state
	# behind that affects other Characters' signal behavior.
	var bad_data := _make_full_character_dict()
	bad_data["race_id"] = "no_such_race_xyz"
	var ch_bad := Character.from_dict(bad_data)
	assert_null(ch_bad)

	# Independent Character should still emit normally.
	var ok := _make_character()
	watch_signals(ok)
	ok.current_hp = ok.current_hp - 1
	assert_signal_emit_count(ok, "hp_changed", 1)
