extends GutTest

# Tests for BalanceRepoBuilder (task 4.2): the dashboard applies a balance
# definition by registering duplicate() copies of the base MonsterData with the
# five combat values overwritten from MonsterCurve.compute_stats. Original
# resources and .tres files must never change; species not covered by the
# balance definition keep their .tres values (generator skip semantics); a null
# curve (no --balance) registers the shipped values as-is.


func _make_monster(
	id: StringName, tier: int, hp_min: int, hp_max: int, atk: int, defn: int, agi: int
) -> MonsterData:
	var data := MonsterData.new()
	data.monster_id = id
	data.monster_name = String(id)
	data.tier = tier
	data.max_hp_min = hp_min
	data.max_hp_max = hp_max
	data.attack = atk
	data.defense = defn
	data.agility = agi
	data.experience = 77
	data.gold_min = 3
	data.gold_max = 9
	return data


func _make_curve() -> MonsterCurve:
	var curve := MonsterCurve.parse({
		"curves": {
			"hp": {"base": 6.0, "growth": 1.5},
			"attack": {"base": 3.0, "growth": 1.3},
			"defense": {"base": 1.0, "growth": 1.6},
			"agility": {"base": 4.0, "growth": 1.3},
		},
		"hp_spread": 0.2,
		"species": {"goblin": {"hp": 1.2, "attack": 1.1}},
		"overrides": {
			"dragon": {"hp_min": 60, "hp_max": 100, "attack": 25, "defense": 10, "agility": 8},
		},
	})
	assert_true(curve.errors.is_empty(), "fixture curve must be valid: %s" % "\n".join(curve.errors))
	return curve


# --- null curve (no --balance) ---

func test_null_curve_registers_base_values_unchanged():
	var goblin := _make_monster(&"goblin", 2, 10, 14, 5, 2, 4)
	var repo := BalanceRepoBuilder.build([goblin], null)
	assert_eq(repo.size(), 1)
	var entry := repo.find(&"goblin")
	assert_not_null(entry, "base monster must be registered")
	if entry == null:
		return
	assert_eq(entry.max_hp_min, 10)
	assert_eq(entry.max_hp_max, 14)
	assert_eq(entry.attack, 5)
	assert_eq(entry.defense, 2)
	assert_eq(entry.agility, 4)


# --- curve application ---

func test_covered_species_gets_curve_stats_on_a_copy():
	var goblin := _make_monster(&"goblin", 2, 10, 14, 5, 2, 4)
	var curve := _make_curve()
	var repo := BalanceRepoBuilder.build([goblin], curve)
	var entry := repo.find(&"goblin")
	assert_not_null(entry, "covered species must be registered")
	if entry == null:
		return
	var expected := curve.compute_stats("goblin", 2)
	assert_eq(entry.max_hp_min, int(expected["hp_min"]))
	assert_eq(entry.max_hp_max, int(expected["hp_max"]))
	assert_eq(entry.attack, int(expected["attack"]))
	assert_eq(entry.defense, int(expected["defense"]))
	assert_eq(entry.agility, int(expected["agility"]))
	assert_true(entry != goblin, "repo must hold a duplicate, not the original resource")
	# The original resource is untouched (spec: dashboard never modifies data).
	assert_eq(goblin.max_hp_min, 10)
	assert_eq(goblin.max_hp_max, 14)
	assert_eq(goblin.attack, 5)
	assert_eq(goblin.defense, 2)
	assert_eq(goblin.agility, 4)


func test_override_species_uses_override_values():
	var dragon := _make_monster(&"dragon", 5, 200, 300, 40, 20, 12)
	var repo := BalanceRepoBuilder.build([dragon], _make_curve())
	var entry := repo.find(&"dragon")
	assert_not_null(entry)
	if entry == null:
		return
	assert_eq(entry.max_hp_min, 60)
	assert_eq(entry.max_hp_max, 100)
	assert_eq(entry.attack, 25)
	assert_eq(entry.defense, 10)
	assert_eq(entry.agility, 8)
	assert_eq(dragon.attack, 40, "original resource keeps its .tres value")


func test_uncovered_species_keeps_tres_values():
	var slime := _make_monster(&"slime", 1, 4, 6, 3, 1, 2)
	var repo := BalanceRepoBuilder.build([slime], _make_curve())
	var entry := repo.find(&"slime")
	assert_not_null(entry)
	if entry == null:
		return
	assert_eq(entry.max_hp_min, 4, "species absent from the definition keeps .tres HP")
	assert_eq(entry.max_hp_max, 6)
	assert_eq(entry.attack, 3)
	assert_eq(entry.defense, 1)
	assert_eq(entry.agility, 2)


func test_non_combat_fields_are_preserved_on_the_copy():
	var goblin := _make_monster(&"goblin", 2, 10, 14, 5, 2, 4)
	goblin.known_spells.append(&"fireball")
	var repo := BalanceRepoBuilder.build([goblin], _make_curve())
	var entry := repo.find(&"goblin")
	assert_not_null(entry)
	if entry == null:
		return
	assert_eq(entry.monster_id, &"goblin")
	assert_eq(entry.monster_name, "goblin")
	assert_eq(entry.tier, 2)
	assert_eq(entry.experience, 77)
	assert_eq(entry.gold_min, 3)
	assert_eq(entry.gold_max, 9)
	assert_true(entry.known_spells.has(&"fireball"))


# --- real data: .tres files stay byte-identical (spec: Data files untouched) ---

func test_building_from_real_data_never_touches_tres_files():
	var monsters_dir := ProjectSettings.globalize_path("res://data/monsters")
	var before := _snapshot_dir(monsters_dir)
	assert_gt(before.size(), 0, "there must be monster .tres files to protect")

	var loader := DataLoader.new()
	var base_monsters := loader.load_all_monsters()
	var curve := MonsterCurve.load_from_file("res://data/balance/monster_curve.json")
	assert_not_null(curve, "shipped balance definition must load")
	if curve == null:
		return
	var repo := BalanceRepoBuilder.build(base_monsters, curve)
	assert_eq(repo.size(), base_monsters.size(), "every shipped monster must be registered")

	var after := _snapshot_dir(monsters_dir)
	assert_eq(before, after, "every data/monsters file must be byte-identical")


func _snapshot_dir(absolute_dir: String) -> Dictionary:
	var snapshot := {}
	var dir := DirAccess.open(absolute_dir)
	if dir == null:
		return snapshot
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			snapshot[file_name] = FileAccess.get_file_as_bytes(absolute_dir.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()
	return snapshot
