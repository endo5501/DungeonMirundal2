extends GutTest

const GameStateScript = preload("res://src/game_state.gd")

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

func test_status_view_shows_party_members():
	# Setup GameState with party
	GameState.new_game()
	var ch := _make_character("Hero")
	GameState.guild.register(ch)
	GameState.guild.assign_to_party(ch, 0, 0)

	var menu := EscMenu.new()
	add_child_autofree(menu)
	menu.show_menu()
	menu.select_current_item()  # → party menu
	menu.select_current_item()  # → status

	# Status container should have title + spacer + 1 character entry
	var status_container := menu._status_container
	assert_true(status_container.get_child_count() > 2, "Should have character entries")

func test_status_view_shows_empty_message_when_no_party():
	GameState.new_game()

	var menu := EscMenu.new()
	add_child_autofree(menu)
	menu.show_menu()
	menu.select_current_item()  # → party menu
	menu.select_current_item()  # → status

	# Status container: title + spacer + empty message
	var status_container := menu._status_container
	assert_eq(status_container.get_child_count(), 3)
	var last_child := status_container.get_child(2) as Label
	assert_eq(last_child.text, "パーティが編成されていません")


# --- add-status-poison-and-petrify: persistent_statuses status line ---

func _find_status_line(node: Node) -> String:
	# Walk descendants and return the first Label whose text starts with "状態:".
	if node is Label:
		var text: String = (node as Label).text
		if text.begins_with("状態:"):
			return text
	for child in node.get_children():
		var found := _find_status_line(child)
		if found != "":
			return found
	return ""


func _open_status_view_for(ch: Character) -> EscMenu:
	GameState.new_game()
	GameState.guild.register(ch)
	GameState.guild.assign_to_party(ch, 0, 0)
	var menu := EscMenu.new()
	add_child_autofree(menu)
	menu.show_menu()
	menu.select_current_item()  # → party menu
	menu.select_current_item()  # → status
	return menu


func test_clean_character_status_line_says_normal():
	var ch := _make_character("Clean")
	var menu := _open_status_view_for(ch)
	var line := _find_status_line(menu._status_container)
	assert_eq(line, "状態: 通常")


func test_poisoned_character_shows_status_name():
	var ch := _make_character("Toxic")
	ch.persistent_statuses = [&"poison"]
	var menu := _open_status_view_for(ch)
	var line := _find_status_line(menu._status_container)
	assert_eq(line, "状態: 毒")


func test_multi_status_character_shows_comma_separated():
	var ch := _make_character("Doomed")
	ch.persistent_statuses = [&"poison", &"petrify"]
	var menu := _open_status_view_for(ch)
	var line := _find_status_line(menu._status_container)
	assert_eq(line, "状態: 毒, 石化")
