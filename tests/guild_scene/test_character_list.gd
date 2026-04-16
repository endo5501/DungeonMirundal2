extends GutTest

var _list
var _guild: Guild
var _human: RaceData
var _fighter_job: JobData

func _make_character(char_name: String) -> Character:
	var allocation := {&"STR": 5, &"INT": 0, &"PIE": 0, &"VIT": 0, &"AGI": 0, &"LUC": 0}
	return Character.create(char_name, _human, _fighter_job, allocation)

func before_each():
	_guild = Guild.new()

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

	_list = CharacterList.new()
	_list.setup(_guild)
	add_child_autofree(_list)

# --- Signals ---

func test_has_back_requested_signal():
	assert_has_signal(_list, "back_requested")

# --- Character listing ---

func test_empty_list():
	assert_eq(_list.get_character_entries().size(), 0)

func test_list_registered_characters():
	_guild.register(_make_character("Hero"))
	_guild.register(_make_character("Mage"))
	_list.refresh()
	assert_eq(_list.get_character_entries().size(), 2)

func test_list_entry_has_all_fields():
	_guild.register(_make_character("Hero"))
	_list.refresh()
	var entries = _list.get_character_entries()
	assert_eq(entries[0].character_name, "Hero")
	assert_eq(entries[0].level, 1)
	assert_eq(entries[0].race_name, "Human")
	assert_eq(entries[0].job_name, "Fighter")

func test_list_entry_has_status_waiting():
	_guild.register(_make_character("Hero"))
	_list.refresh()
	var entries = _list.get_character_entries()
	assert_eq(entries[0].status, "待機中")

func test_list_entry_has_status_party():
	var ch := _make_character("Hero")
	_guild.register(ch)
	_guild.assign_to_party(ch, 0, 0)
	_list.refresh()
	var entries = _list.get_character_entries()
	assert_eq(entries[0].status, "パーティ")

# --- Detail view ---

func test_get_character_detail():
	var ch := _make_character("Hero")
	_guild.register(ch)
	_list.refresh()
	var detail = _list.get_character_detail(0)
	assert_eq(detail.character_name, "Hero")
	assert_eq(detail.race_name, "Human")
	assert_eq(detail.job_name, "Fighter")
	assert_eq(detail.level, 1)
	assert_true(detail.current_hp > 0)
	assert_eq(detail.current_hp, detail.max_hp)
	assert_eq(detail.current_mp, 0)
	assert_eq(detail.max_mp, 0)
	assert_true(detail.stats.has(&"STR"))
	assert_eq(detail.stats[&"STR"], 13)  # Human base 8 + allocation 5

# --- Deletion ---

func test_can_delete_waiting_character():
	_guild.register(_make_character("Hero"))
	_list.refresh()
	assert_true(_list.can_delete(0))

func test_cannot_delete_party_character():
	var ch := _make_character("Hero")
	_guild.register(ch)
	_guild.assign_to_party(ch, 0, 0)
	_list.refresh()
	assert_false(_list.can_delete(0))

func test_request_delete_sets_pending():
	_guild.register(_make_character("Hero"))
	_list.refresh()
	_list.request_delete(0)
	assert_eq(_list.get_pending_delete_index(), 0)

func test_confirm_delete_removes_character():
	_guild.register(_make_character("Hero"))
	_list.refresh()
	_list.request_delete(0)
	_list.confirm_delete()
	_list.refresh()
	assert_eq(_list.get_character_entries().size(), 0)
	assert_eq(_guild.get_all_characters().size(), 0)

func test_cancel_delete_keeps_character():
	_guild.register(_make_character("Hero"))
	_list.refresh()
	_list.request_delete(0)
	_list.cancel_delete()
	assert_eq(_list.get_pending_delete_index(), -1)
	assert_eq(_list.get_character_entries().size(), 1)

func test_confirm_delete_without_request_does_nothing():
	_guild.register(_make_character("Hero"))
	_list.refresh()
	_list.confirm_delete()
	assert_eq(_list.get_character_entries().size(), 1)

# --- Back ---

func test_go_back_emits_signal():
	watch_signals(_list)
	_list.go_back()
	assert_signal_emitted(_list, "back_requested")

# --- Layout centering ---

func _find_center_container(node: Node) -> CenterContainer:
	for child in node.get_children():
		if child is CenterContainer:
			return child as CenterContainer
	return null

func test_uses_center_container_for_layout():
	assert_not_null(_find_center_container(_list), "CharacterList should use CenterContainer for centering")

func test_center_container_covers_full_rect():
	var center := _find_center_container(_list)
	assert_not_null(center)
	assert_eq(center.anchor_right, 1.0, "CenterContainer should span full width")
	assert_eq(center.anchor_bottom, 1.0, "CenterContainer should span full height")
