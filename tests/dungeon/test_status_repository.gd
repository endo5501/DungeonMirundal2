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


# --- Bulk-load via DataLoader (no .tres files exist yet for statuses) ---

func test_bulk_load_returns_empty_repository_when_no_status_files():
	var loader := DataLoader.new()
	var repo := loader.load_status_repository()
	assert_not_null(repo)
	# This change does not add any data/statuses/*.tres files; the repo should be
	# empty until later changes ship concrete status resources.
	assert_eq(repo.size(), 0)
