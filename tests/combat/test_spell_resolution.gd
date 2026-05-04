extends GutTest


class _StubActor extends CombatActor:
	func _init(p_name: String) -> void:
		actor_name = p_name


# --- structure changes for events list ---

func test_add_entry_returns_dictionary():
	var res := SpellResolution.new()
	var actor := _StubActor.new("Alice")
	var entry: Dictionary = res.add_entry(actor, -3)
	assert_typeof(entry, TYPE_DICTIONARY)


func test_add_entry_returned_dict_is_same_as_appended_one():
	var res := SpellResolution.new()
	var actor := _StubActor.new("Alice")
	var returned: Dictionary = res.add_entry(actor, -3)
	assert_eq(res.entries.size(), 1)
	# The returned dictionary should be the same instance as the one appended
	# so callers can mutate `events` directly.
	returned["events"].append({"type": "damage", "amount": 3})
	var stored: Dictionary = res.entries[0]
	assert_eq((stored["events"] as Array).size(), 1)


func test_entry_has_events_key_initialized_to_empty_array():
	var res := SpellResolution.new()
	var actor := _StubActor.new("Alice")
	var entry: Dictionary = res.add_entry(actor, 0)
	assert_true(entry.has("events"))
	assert_typeof(entry["events"], TYPE_ARRAY)
	assert_eq((entry["events"] as Array).size(), 0)


func test_entry_has_existing_keys_preserved():
	var res := SpellResolution.new()
	var actor := _StubActor.new("Bob")
	var entry: Dictionary = res.add_entry(actor, -5)
	assert_eq(entry["actor"], actor)
	assert_eq(entry["actor_name"], "Bob")
	assert_eq(entry["hp_delta"], -5)


# --- format_entries unchanged behavior ---

func test_format_entries_renders_damage_negative_delta():
	var res := SpellResolution.new()
	var actor := _StubActor.new("Slime")
	res.add_entry(actor, -7)
	var lines := SpellResolution.format_entries(res.entries)
	assert_eq(lines.size(), 1)
	assert_true(lines[0].contains("Slime"))
	assert_true(lines[0].contains("7"))


func test_format_entries_renders_heal_positive_delta():
	var res := SpellResolution.new()
	var actor := _StubActor.new("Hero")
	res.add_entry(actor, 5)
	var lines := SpellResolution.format_entries(res.entries)
	assert_true(lines[0].contains("Hero"))
	assert_true(lines[0].contains("5"))


func test_format_entries_renders_zero_delta_as_no_effect():
	var res := SpellResolution.new()
	var actor := _StubActor.new("Hero")
	res.add_entry(actor, 0)
	var lines := SpellResolution.format_entries(res.entries)
	assert_true(lines[0].contains("Hero"))
	assert_true(lines[0].contains("効果はなかった"))


func test_size_and_is_empty_unchanged():
	var res := SpellResolution.new()
	assert_true(res.is_empty())
	assert_eq(res.size(), 0)
	res.add_entry(_StubActor.new("X"), 0)
	assert_false(res.is_empty())
	assert_eq(res.size(), 1)
