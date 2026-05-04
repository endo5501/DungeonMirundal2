extends GutTest

# End-to-end test for the original bug: casting heal from the ESC menu in the
# dungeon must update the dungeon-screen status bar (PartyMemberPanel) without
# any manual refresh call. Drives SpellUseFlow with simulated key input on a
# PartyDisplay bound to live Characters.


class _FixedRng extends SpellRng:
	var _next: int = 0
	func _init(p_next: int = 0) -> void:
		super._init(null)
		_next = p_next
	func roll(_low: int, _high: int) -> int:
		return _next


func _human() -> RaceData:
	return load("res://data/races/human.tres") as RaceData


func _job(filename: String) -> JobData:
	return load("res://data/jobs/" + filename + ".tres") as JobData


func _make_char(
	p_name: String,
	job_filename: String,
	known_spells: Array[StringName] = [],
	current_mp: int = 5,
	current_hp: int = 8,
	max_hp: int = 10,
) -> Character:
	var ch := Character.new()
	ch.character_name = p_name
	ch.level = 1
	ch.race = _human()
	ch.job = _job(job_filename)
	ch.base_stats = {&"STR": 10, &"INT": 12, &"PIE": 12, &"VIT": 10, &"AGI": 10, &"LUC": 10}
	ch.current_hp = current_hp
	ch.max_hp = max_hp
	ch.max_mp = max(current_mp, 5)
	ch.current_mp = current_mp
	ch.known_spells = known_spells.duplicate()
	return ch


func test_esc_menu_heal_refreshes_dungeon_status_bar():
	var priest := _make_char("Bob", "priest", [&"heal"], 5, 10, 10)
	var hurt := _make_char("Alice", "fighter", [], 0, 5, 12)
	var party: Array[Character] = [priest, hurt]

	# Mount a PartyDisplay bound to live Characters, mirroring DungeonScreen
	# entry. priest = front[0], hurt = front[1].
	var display := PartyDisplay.new()
	add_child_autofree(display)
	display.bind_party_characters([priest, hurt, null], [null, null, null])

	# Sanity: panel for hurt (slot 1) starts at 5 / 12.
	assert_eq(display._front_panels[1]._data.current_hp, 5)

	# Drive the spell flow exactly as the ESC menu would.
	var flow := SpellUseFlow.new()
	add_child_autofree(flow)
	flow.set_rng(_FixedRng.new(0))
	flow.setup(party)
	# SELECT_CASTER → priest
	flow.handle_input(TestHelpers.make_action_event(&"ui_accept"))
	# SELECT_SPELL → heal (only known spell)
	flow.handle_input(TestHelpers.make_action_event(&"ui_accept"))
	# SELECT_TARGET → move down to Alice (index 1) and accept
	flow.handle_input(TestHelpers.make_action_event(&"ui_down"))
	flow.handle_input(TestHelpers.make_action_event(&"ui_accept"))

	# Heal applied: Alice 5 + 8 = 13 clamped to max 12.
	assert_eq(hurt.current_hp, 12, "spell effect should mutate Character HP")
	# The bug: prior to this change, the panel still showed 5. Now it must
	# reflect 12 because the panel is bound to Alice's hp_changed signal.
	assert_eq(
		display._front_panels[1]._data.current_hp,
		12,
		"PartyMemberPanel must refresh after ESC menu heal mutates Character HP",
	)
	# Other panels unaffected.
	assert_eq(display._front_panels[0]._data.current_hp, 10, "Priest panel unchanged")
