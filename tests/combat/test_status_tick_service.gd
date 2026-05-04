extends GutTest

# StatusTickService.tick_character_step(character, repo) -> Dictionary
# Floors HP at 1 (dungeon ticks must not kill).


var _human: RaceData
var _fighter_job: JobData


func before_each():
	var loader := DataLoader.new()
	for race in loader.load_all_races():
		if race.race_name == "Human":
			_human = race
	for job in loader.load_all_jobs():
		if job.job_name == "Fighter":
			_fighter_job = job


func _make_status(
	id: StringName,
	scope: int,
	tick_in_dungeon: int = 0
) -> StatusData:
	var s := StatusData.new()
	s.id = id
	s.display_name = String(id)
	s.scope = scope
	s.tick_in_dungeon = tick_in_dungeon
	return s


func _seed_repo() -> StatusRepository:
	var repo := StatusRepository.new()
	repo.register(_make_status(&"poison", StatusData.Scope.PERSISTENT, 3))
	repo.register(_make_status(&"sleep", StatusData.Scope.BATTLE_ONLY, 2))  # ignored in dungeon
	repo.register(_make_status(&"bleed", StatusData.Scope.PERSISTENT, 1))
	return repo


func _make_character(hp: int) -> Character:
	var ch := Character.new()
	ch.character_name = "Tester"
	ch.race = _human
	ch.job = _fighter_job
	ch.level = 1
	ch.base_stats = {&"STR": 8, &"INT": 8, &"PIE": 8, &"VIT": 8, &"AGI": 8, &"LUC": 8}
	ch.max_hp = max(hp, 10)
	ch.current_hp = hp
	ch.max_mp = 0
	ch.current_mp = 0
	return ch


# --- skip dead characters ---

func test_tick_skips_dead_character():
	var ch := _make_character(0)
	ch.persistent_statuses = [&"poison"]
	var result := StatusTickService.tick_character_step(ch, _seed_repo())
	assert_eq(result.get("total_loss", -1), 0)
	assert_eq((result.get("ticks", []) as Array).size(), 0)
	assert_eq(ch.current_hp, 0)


# --- BATTLE_ONLY ignored ---

func test_tick_ignores_battle_only_statuses():
	var ch := _make_character(10)
	ch.persistent_statuses = [&"sleep"]  # BATTLE_ONLY (would never normally be persisted, but the
	#                                     service must defensively ignore them)
	var result := StatusTickService.tick_character_step(ch, _seed_repo())
	assert_eq(result.get("total_loss"), 0)
	assert_eq(ch.current_hp, 10)


# --- normal tick ---

func test_tick_3_on_hp_5_yields_loss_3_hp_2():
	var ch := _make_character(5)
	ch.persistent_statuses = [&"poison"]  # tick_in_dungeon = 3
	var result := StatusTickService.tick_character_step(ch, _seed_repo())
	assert_eq(result.get("total_loss"), 3)
	assert_eq(ch.current_hp, 2)
	var ticks: Array = result.get("ticks")
	assert_eq(ticks.size(), 1)
	var entry: Dictionary = ticks[0]
	assert_eq(entry.get("status_id"), &"poison")
	assert_eq(entry.get("amount"), 3)


# --- floor at HP=1 ---

func test_tick_3_on_hp_2_floors_at_1():
	var ch := _make_character(2)
	ch.persistent_statuses = [&"poison"]
	var result := StatusTickService.tick_character_step(ch, _seed_repo())
	assert_eq(result.get("total_loss"), 1)
	assert_eq(ch.current_hp, 1)


func test_tick_3_on_hp_1_yields_no_loss():
	var ch := _make_character(1)
	ch.persistent_statuses = [&"poison"]
	var result := StatusTickService.tick_character_step(ch, _seed_repo())
	assert_eq(result.get("total_loss"), 0)
	assert_eq(ch.current_hp, 1)


# --- multiple statuses sum ---

func test_multiple_status_ticks_sum_total_loss():
	var ch := _make_character(10)
	ch.persistent_statuses = [&"poison", &"bleed"]  # 3 + 1 = 4
	var result := StatusTickService.tick_character_step(ch, _seed_repo())
	assert_eq(result.get("total_loss"), 4)
	assert_eq(ch.current_hp, 6)
	var ticks: Array = result.get("ticks")
	assert_eq(ticks.size(), 2)


func test_multiple_status_ticks_respect_floor_collectively():
	# Two statuses summing to 5 against hp=3: only loss=2 (cap at HP=1).
	var ch := _make_character(3)
	ch.persistent_statuses = [&"poison", &"bleed"]
	var result := StatusTickService.tick_character_step(ch, _seed_repo())
	# poison runs first (3 -> floor at 1, applies 2). bleed runs second (hp=1, applies 0).
	assert_eq(ch.current_hp, 1)
	assert_eq(result.get("total_loss"), 2)


# --- unknown status ids ---

func test_tick_ignores_unknown_status_ids():
	var ch := _make_character(10)
	ch.persistent_statuses = [&"unknown_status_xyz"]
	var result := StatusTickService.tick_character_step(ch, _seed_repo())
	assert_eq(result.get("total_loss"), 0)
	assert_eq(ch.current_hp, 10)
