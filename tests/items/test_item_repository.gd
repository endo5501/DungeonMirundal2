extends GutTest


func _make_item(id: StringName) -> Item:
	var item := Item.new()
	item.item_id = id
	item.item_name = String(id)
	return item


func test_empty_repository_find_returns_null():
	var repo := ItemRepository.new()
	assert_null(repo.find(&"anything"))


func test_register_and_find_existing_item():
	var repo := ItemRepository.new()
	var item := _make_item(&"long_sword")
	repo.register(item)
	assert_eq(repo.find(&"long_sword"), item)


func test_find_missing_item_returns_null():
	var repo := ItemRepository.new()
	repo.register(_make_item(&"long_sword"))
	assert_null(repo.find(&"nonexistent"))


func test_all_returns_registered_items():
	var repo := ItemRepository.new()
	var a := _make_item(&"a")
	var b := _make_item(&"b")
	repo.register(a)
	repo.register(b)
	var listed := repo.all()
	assert_eq(listed.size(), 2)
	assert_true(listed.has(a))
	assert_true(listed.has(b))


func test_from_array_builds_repository():
	var a := _make_item(&"a")
	var b := _make_item(&"b")
	var repo := ItemRepository.from_array([a, b])
	assert_eq(repo.find(&"a"), a)
	assert_eq(repo.find(&"b"), b)
	assert_eq(repo.all().size(), 2)


func test_duplicate_id_replaces_existing():
	var repo := ItemRepository.new()
	var original := _make_item(&"dup")
	var replacement := _make_item(&"dup")
	repo.register(original)
	repo.register(replacement)
	assert_eq(repo.find(&"dup"), replacement)
	assert_eq(repo.all().size(), 1)
