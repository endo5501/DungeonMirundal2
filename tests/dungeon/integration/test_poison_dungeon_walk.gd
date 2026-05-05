extends GutTest


# Integration: poison dungeon-tick over multiple steps.
#
# Asserts:
#   - A poisoned character with max_hp=32 takes max_hp/16=2 damage per step.
#     After 8 steps, HP drops by ~16 (2*8) before any HP=1 floor is hit.
#   - The HP=1 floor prevents poison from killing the character.
#   - The TownScreen auto-cure clears poison on town arrival.


func _make_character(char_name: String, max_hp: int, statuses: Array[StringName]) -> Character:
	var human := load("res://data/races/human.tres") as RaceData
	var fighter := load("res://data/jobs/fighter.tres") as JobData
	var ch := Character.new()
	ch.character_name = char_name
	ch.race = human
	ch.job = fighter
	ch.level = 1
	ch.base_stats = {&"STR": 8, &"INT": 8, &"PIE": 8, &"VIT": 8, &"AGI": 8, &"LUC": 8}
	ch.max_hp = max_hp
	ch.current_hp = max_hp
	ch.max_mp = 0
	ch.current_mp = 0
	ch.persistent_statuses = statuses
	return ch


func _load_repo() -> StatusRepository:
	DataLoader._status_repo_cache = null
	return DataLoader.new().load_status_repository()


func test_poisoned_character_loses_one_hp_per_tick_regardless_of_max_hp():
	var ch := _make_character("Toxic", 32, [&"poison"])
	var repo := _load_repo()
	# Each StatusTickService call deals a flat 1 HP (poison.tick_in_dungeon = 1).
	for i in range(8):
		StatusTickService.tick_character_step(ch, repo)
	assert_eq(ch.current_hp, 32 - 8)


func test_poison_floors_hp_at_one_after_many_ticks():
	var ch := _make_character("Doomed", 32, [&"poison"])
	var repo := _load_repo()
	for i in range(50):
		StatusTickService.tick_character_step(ch, repo)
	assert_eq(ch.current_hp, 1, "dungeon ticks must never reduce HP below 1")
	assert_false(ch.is_dead(), "character must still be alive after dungeon ticks")


func test_low_max_hp_character_loses_one_hp_per_tick():
	var ch := _make_character("Frail", 10, [&"poison"])
	var repo := _load_repo()
	for i in range(3):
		StatusTickService.tick_character_step(ch, repo)
	assert_eq(ch.current_hp, 7)


func test_town_arrival_cures_poison_after_dungeon_walk():
	var ch := _make_character("Toxic", 32, [&"poison"])
	var repo := _load_repo()
	for i in range(4):
		StatusTickService.tick_character_step(ch, repo)
	assert_eq(ch.current_hp, 32 - 4)
	assert_true(ch.persistent_statuses.has(&"poison"))
	var guild := Guild.new()
	guild.register(ch)
	guild.assign_to_party(ch, 0, 0)
	var screen := TownScreen.new()
	add_child_autofree(screen)
	screen.setup(guild)
	screen.notify_arrival()
	assert_eq(ch.persistent_statuses.size(), 0,
		"persistent_statuses must be cleared on town arrival")
