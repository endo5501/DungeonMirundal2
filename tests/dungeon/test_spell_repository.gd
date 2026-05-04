extends GutTest


func _make_spell(id: StringName, school: StringName = SpellData.SCHOOL_MAGE) -> SpellData:
	var s := SpellData.new()
	s.id = id
	s.display_name = String(id)
	s.school = school
	s.level = 1
	s.mp_cost = 1
	s.target_type = SpellData.TargetType.ENEMY_ONE
	s.scope = SpellData.Scope.BATTLE_ONLY
	return s


func test_register_then_find():
	var repo := SpellRepository.new()
	var fire := _make_spell(&"fire")
	repo.register(fire)
	assert_eq(repo.find(&"fire"), fire)


func test_find_missing_returns_null():
	var repo := SpellRepository.new()
	assert_null(repo.find(&"nonexistent"))


func test_register_null_is_safe():
	var repo := SpellRepository.new()
	repo.register(null)
	assert_eq(repo.size(), 0)


func test_register_empty_id_is_skipped_with_warning():
	var repo := SpellRepository.new()
	var s := SpellData.new()  # no id
	repo.register(s)
	assert_eq(repo.size(), 0)
	assert_push_warning("id is empty")


func test_size_reflects_registrations():
	var repo := SpellRepository.new()
	repo.register(_make_spell(&"fire"))
	repo.register(_make_spell(&"frost"))
	assert_eq(repo.size(), 2)


func test_has_id_returns_true_for_registered():
	var repo := SpellRepository.new()
	repo.register(_make_spell(&"fire"))
	assert_true(repo.has_id(&"fire"))
	assert_false(repo.has_id(&"frost"))


# --- Bulk-load via DataLoader ---

func test_bulk_load_populates_eight_v1_spells():
	var loader := DataLoader.new()
	var repo := loader.load_spell_repository()
	assert_eq(repo.size(), 8, "v1 must have exactly 8 spells")
	for sid in [&"fire", &"frost", &"flame", &"blizzard", &"heal", &"holy", &"heala", &"allheal"]:
		assert_true(repo.has_id(sid), "missing spell id: %s" % sid)
