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
	_fighter_job.has_magic = false
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
