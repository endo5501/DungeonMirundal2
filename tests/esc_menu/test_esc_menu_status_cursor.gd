extends GutTest

# Verifies cursor navigation on the StatusView left pane updates the
# right pane and wraps per CursorMenu defaults.

var _human: RaceData
var _fighter_job: JobData


func before_each():
	_human = RaceData.new()
	_human.race_name = "Human"
	_human.base_str = 8
	_human.base_int = 8
	_human.base_pie = 8
	_human.base_vit = 8
	_human.base_agi = 8
	_human.base_luc = 8

	_fighter_job = JobData.new()
	_fighter_job.id = &"fighter"
	_fighter_job.job_name = "Fighter"
	_fighter_job.base_hp = 10
	_fighter_job.required_str = 0
	_fighter_job.required_int = 0
	_fighter_job.required_pie = 0
	_fighter_job.required_vit = 0
	_fighter_job.required_agi = 0
	_fighter_job.required_luc = 0


func _make_character(char_name: String) -> Character:
	var allocation := {&"STR": 5, &"INT": 5, &"PIE": 0, &"VIT": 0, &"AGI": 0, &"LUC": 0}
	return Character.create(char_name, _human, _fighter_job, allocation)


func _open_three_member_view() -> StatusView:
	GameState.new_game()
	var names := ["Alice", "Bob", "Carol"]
	for i in range(3):
		var ch := _make_character(names[i])
		GameState.guild.register(ch)
		GameState.guild.assign_to_party(ch, 0, i)
	var menu := EscMenu.new()
	add_child_autofree(menu)
	menu.show_menu()
	menu.select_current_item()  # → party menu
	menu.select_current_item()  # → status
	return menu.get_status_view()


func test_initial_cursor_is_first_member():
	var view := _open_three_member_view()
	assert_eq(view.get_selected_character().character_name, "Alice")
	assert_string_contains(view.get_header_line(), "Alice")


func test_ui_down_advances_to_next_member():
	var view := _open_three_member_view()
	var consumed: bool = view.handle_input(TestHelpers.make_action_event(&"ui_down"))
	assert_true(consumed)
	assert_eq(view.get_selected_character().character_name, "Bob")
	assert_string_contains(view.get_header_line(), "Bob")


func test_ui_up_returns_to_previous_member():
	var view := _open_three_member_view()
	view.handle_input(TestHelpers.make_action_event(&"ui_down"))
	view.handle_input(TestHelpers.make_action_event(&"ui_up"))
	assert_eq(view.get_selected_character().character_name, "Alice")


func test_ui_down_wraps_at_end():
	var view := _open_three_member_view()
	view.handle_input(TestHelpers.make_action_event(&"ui_down"))
	view.handle_input(TestHelpers.make_action_event(&"ui_down"))
	view.handle_input(TestHelpers.make_action_event(&"ui_down"))
	# Default CursorMenu wraps; expect to land back on first.
	assert_eq(view.get_selected_character().character_name, "Alice")


func test_ui_cancel_emits_back_requested():
	var view := _open_three_member_view()
	var emitted := [false]
	view.back_requested.connect(func(): emitted[0] = true)
	var consumed: bool = view.handle_input(TestHelpers.make_action_event(&"ui_cancel"))
	assert_true(consumed)
	assert_true(emitted[0])


func test_ui_accept_is_no_op_view_only():
	var view := _open_three_member_view()
	var name_before: String = view.get_selected_character().character_name
	var emitted := [false]
	view.back_requested.connect(func(): emitted[0] = true)
	view.handle_input(TestHelpers.make_action_event(&"ui_accept"))
	assert_eq(view.get_selected_character().character_name, name_before)
	assert_false(emitted[0], "ui_accept must not emit back_requested")
