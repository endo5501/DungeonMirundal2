extends GutTest


func _make_status(id: StringName, scope: int = StatusData.Scope.BATTLE_ONLY) -> StatusData:
	var s := StatusData.new()
	s.id = id
	s.display_name = String(id)
	s.scope = scope
	return s


func test_register_then_find():
	var repo := StatusRepository.new()
	var poison := _make_status(&"poison", StatusData.Scope.PERSISTENT)
	repo.register(poison)
	assert_eq(repo.find(&"poison"), poison)


func test_find_missing_returns_null():
	var repo := StatusRepository.new()
	assert_null(repo.find(&"nonexistent"))


func test_register_null_is_safe():
	var repo := StatusRepository.new()
	repo.register(null)
	assert_eq(repo.size(), 0)


func test_register_empty_id_is_skipped_with_warning():
	var repo := StatusRepository.new()
	var s := StatusData.new()  # no id
	repo.register(s)
	assert_eq(repo.size(), 0)
	assert_push_warning("id is empty")


func test_size_reflects_registrations():
	var repo := StatusRepository.new()
	repo.register(_make_status(&"poison", StatusData.Scope.PERSISTENT))
	repo.register(_make_status(&"sleep", StatusData.Scope.BATTLE_ONLY))
	assert_eq(repo.size(), 2)


func test_has_id_returns_true_for_registered():
	var repo := StatusRepository.new()
	repo.register(_make_status(&"poison", StatusData.Scope.PERSISTENT))
	assert_true(repo.has_id(&"poison"))
	assert_false(repo.has_id(&"sleep"))


# --- Bulk-load via DataLoader: sleep / silence ship in this change ---

func test_bulk_load_includes_sleep_and_silence():
	# Reset cache so add-status-sleep-and-silence loads fresh on every run.
	DataLoader._status_repo_cache = null
	var loader := DataLoader.new()
	var repo := loader.load_status_repository()
	assert_not_null(repo)
	assert_true(repo.has_id(&"sleep"), "sleep should be loaded")
	assert_true(repo.has_id(&"silence"), "silence should be loaded")
	assert_eq(repo.size(), 2, "exactly sleep and silence should ship in this change")


func test_loaded_sleep_fields_match_spec():
	DataLoader._status_repo_cache = null
	var repo := DataLoader.new().load_status_repository()
	var s := repo.find(&"sleep")
	assert_not_null(s)
	assert_eq(s.id, &"sleep")
	assert_eq(s.display_name, "睡眠")
	assert_eq(s.scope, StatusData.Scope.BATTLE_ONLY)
	assert_true(s.prevents_action)
	assert_false(s.randomizes_target)
	assert_false(s.blocks_cast)
	assert_eq(s.hit_penalty, 0.0)
	assert_eq(s.default_duration, 3)
	assert_eq(s.tick_in_battle, 0)
	assert_eq(s.tick_in_dungeon, 0)
	assert_true(s.cures_on_damage)
	assert_true(s.cures_on_battle_end)
	assert_eq(s.resist_key, &"sleep")


func test_loaded_silence_fields_match_spec():
	DataLoader._status_repo_cache = null
	var repo := DataLoader.new().load_status_repository()
	var s := repo.find(&"silence")
	assert_not_null(s)
	assert_eq(s.id, &"silence")
	assert_eq(s.display_name, "沈黙")
	assert_eq(s.scope, StatusData.Scope.BATTLE_ONLY)
	assert_false(s.prevents_action)
	assert_false(s.randomizes_target)
	assert_true(s.blocks_cast)
	assert_eq(s.hit_penalty, 0.0)
	assert_eq(s.default_duration, 4)
	assert_eq(s.tick_in_battle, 0)
	assert_eq(s.tick_in_dungeon, 0)
	assert_false(s.cures_on_damage)
	assert_true(s.cures_on_battle_end)
	assert_eq(s.resist_key, &"silence")
