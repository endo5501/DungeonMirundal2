extends GutTest

# Verifies the StatusView (split-pane: cursor list on the left, character
# detail on the right) used inside the ESC menu's PARTY > STATUS sub-flow.

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
	_fighter_job.job_name = "Fighter"
	_fighter_job.base_hp = 10
	_fighter_job.mage_school = false
	_fighter_job.priest_school = false
	_fighter_job.base_mp = 0
	_fighter_job.required_str = 0
	_fighter_job.required_int = 0
	_fighter_job.required_pie = 0
	_fighter_job.required_vit = 0
	_fighter_job.required_agi = 0
	_fighter_job.required_luc = 0


func _make_character(char_name: String) -> Character:
	var allocation := {&"STR": 5, &"INT": 5, &"PIE": 0, &"VIT": 0, &"AGI": 0, &"LUC": 0}
	return Character.create(char_name, _human, _fighter_job, allocation)


func _open_status_with_party(members: Array) -> StatusView:
	# members: Array[Character], slot order: front 0..2, back 0..2
	GameState.new_game()
	for i in range(min(members.size(), 6)):
		var ch: Character = members[i]
		if ch == null:
			continue
		GameState.guild.register(ch)
		var row := 0 if i < 3 else 1
		var pos := i if i < 3 else (i - 3)
		GameState.guild.assign_to_party(ch, row, pos)
	var menu := EscMenu.new()
	add_child_autofree(menu)
	menu.show_menu()
	menu.select_current_item()  # → party menu
	menu.select_current_item()  # → status
	return menu.get_status_view()


func test_status_view_shows_party_members():
	var ch := _make_character("Hero")
	var view := _open_status_with_party([ch])
	assert_eq(view.get_member_count(), 1)
	assert_eq(view.get_selected_character(), ch)


func test_status_view_shows_empty_message_when_no_party():
	GameState.new_game()
	var menu := EscMenu.new()
	add_child_autofree(menu)
	menu.show_menu()
	menu.select_current_item()  # → party menu
	menu.select_current_item()  # → status
	var view := menu.get_status_view()
	assert_eq(view.get_member_count(), 0)
	assert_true(view.is_empty_message_visible(),
		"Empty pane should show 'パーティが編成されていません'")


# --- persistent_statuses status line on the detail pane ---


func test_clean_character_status_line_says_normal():
	var ch := _make_character("Clean")
	var view := _open_status_with_party([ch])
	assert_eq(view.get_status_line_text(), "状態: 通常")


func test_poisoned_character_shows_status_name():
	var ch := _make_character("Toxic")
	ch.persistent_statuses = [&"poison"]
	var view := _open_status_with_party([ch])
	assert_eq(view.get_status_line_text(), "状態: 毒")


func test_multi_status_character_shows_comma_separated():
	var ch := _make_character("Doomed")
	ch.persistent_statuses = [&"poison", &"petrify"]
	var view := _open_status_with_party([ch])
	assert_eq(view.get_status_line_text(), "状態: 毒, 石化")
