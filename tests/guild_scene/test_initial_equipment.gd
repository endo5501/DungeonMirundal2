extends GutTest


var _repo: ItemRepository
var _inventory: Inventory


func before_each():
	var loader := DataLoader.new()
	_repo = loader.load_all_items()
	_inventory = Inventory.new()


func _make_character_for_job(job_name: String) -> Character:
	# Load a fighter-compatible race/job to build a valid Character.
	var human := load("res://data/races/human.tres") as RaceData
	var job_path := "res://data/jobs/%s.tres" % job_name.to_lower()
	var job := load(job_path) as JobData
	assert_not_null(job, "job file missing for %s" % job_name)
	# Use bonus allocation that satisfies most requirements generically.
	var allocation := {&"STR": 4, &"INT": 4, &"PIE": 4, &"VIT": 4, &"AGI": 4, &"LUC": 3}
	# Loop allocating if needed — fallback to constructing directly if create fails.
	var ch := Character.create("Test" + job_name, human, job, allocation)
	if ch == null:
		# Build directly without qualification check for pure-equipment tests.
		ch = Character.new()
		ch.character_name = "Test" + job_name
		ch.race = human
		ch.job = job
		ch.level = 1
		ch.base_stats = {&"STR": 12, &"INT": 12, &"PIE": 12, &"VIT": 12, &"AGI": 12, &"LUC": 12}
		ch.max_hp = 10
		ch.current_hp = 10
	return ch


func test_fighter_receives_weapon_and_armor():
	var ch := _make_character_for_job("Fighter")
	InitialEquipment.grant(ch, _inventory, _repo)
	assert_not_null(ch.equipment.get_equipped(Item.EquipSlot.WEAPON))
	assert_not_null(ch.equipment.get_equipped(Item.EquipSlot.ARMOR))


func test_mage_receives_staff_and_robe():
	var ch := _make_character_for_job("Mage")
	InitialEquipment.grant(ch, _inventory, _repo)
	var weapon := ch.equipment.get_equipped(Item.EquipSlot.WEAPON)
	var armor := ch.equipment.get_equipped(Item.EquipSlot.ARMOR)
	assert_not_null(weapon)
	assert_not_null(armor)
	assert_true(weapon.item.allowed_jobs.has(&"Mage"))
	assert_true(armor.item.allowed_jobs.has(&"Mage"))


func test_initial_items_are_added_to_inventory():
	var ch := _make_character_for_job("Fighter")
	assert_eq(_inventory.list().size(), 0)
	InitialEquipment.grant(ch, _inventory, _repo)
	assert_eq(_inventory.list().size(), 2)


func test_initial_items_are_identified():
	var ch := _make_character_for_job("Fighter")
	InitialEquipment.grant(ch, _inventory, _repo)
	for inst in _inventory.list():
		assert_true(inst.identified)


func test_every_job_has_initial_loadout_non_empty():
	for job_name in ["Fighter", "Mage", "Priest", "Thief", "Bishop", "Samurai", "Lord", "Ninja"]:
		var inv := Inventory.new()
		var ch := _make_character_for_job(job_name)
		InitialEquipment.grant(ch, inv, _repo)
		assert_gt(ch.equipment.all_equipped().size(), 0, "%s has no initial equipment" % job_name)


func test_allowed_jobs_respected():
	var ch := _make_character_for_job("Mage")
	InitialEquipment.grant(ch, _inventory, _repo)
	# Mage should not end up equipped with long_sword (fighter-only)
	for inst in ch.equipment.all_equipped():
		assert_true(inst.item.allowed_jobs.has(&"Mage"), "%s not allowed for Mage" % inst.item.item_id)
