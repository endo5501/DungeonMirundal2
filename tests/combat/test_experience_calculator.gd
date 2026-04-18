extends GutTest

const TEST_SEED: int = 12345


func _make_monster_data(id: StringName, exp: int) -> MonsterData:
	var data := MonsterData.new()
	data.monster_id = id
	data.monster_name = String(id).capitalize()
	data.max_hp_min = 5
	data.max_hp_max = 5
	data.attack = 1
	data.defense = 0
	data.agility = 1
	data.experience = exp
	return data


func _make_monster(id: StringName, exp: int) -> Monster:
	var rng := RandomNumberGenerator.new()
	rng.seed = TEST_SEED
	return Monster.new(_make_monster_data(id, exp), rng)


func _make_character(name: String) -> Character:
	var loader := DataLoader.new()
	var human: RaceData
	var fighter_job: JobData
	for r in loader.load_all_races():
		if r.race_name == "Human":
			human = r
	for j in loader.load_all_jobs():
		if j.job_name == "Fighter":
			fighter_job = j
	var ch := Character.new()
	ch.character_name = name
	ch.race = human
	ch.job = fighter_job
	ch.level = 1
	ch.base_stats = {&"STR": 12, &"INT": 8, &"PIE": 8, &"VIT": 12, &"AGI": 10, &"LUC": 10}
	ch.max_hp = 15
	ch.current_hp = 15
	ch.max_mp = 0
	ch.current_mp = 0
	ch.accumulated_exp = 0
	return ch


# --- sum_experience ---

func test_sum_experience_of_two_monsters():
	var m1 := _make_monster(&"slime", 40)
	var m2 := _make_monster(&"goblin", 60)
	assert_eq(ExperienceCalculator.sum_experience([m1, m2]), 100)


func test_sum_experience_of_empty_list():
	assert_eq(ExperienceCalculator.sum_experience([]), 0)


func test_sum_experience_ignores_null():
	var m1 := _make_monster(&"slime", 40)
	assert_eq(ExperienceCalculator.sum_experience([m1, null]), 40)


# --- per_member_share ---

func test_per_member_share_even_division():
	assert_eq(ExperienceCalculator.per_member_share(100, 4), 25)


func test_per_member_share_floor_division_drops_remainder():
	assert_eq(ExperienceCalculator.per_member_share(10, 3), 3)


func test_per_member_share_zero_participants():
	assert_eq(ExperienceCalculator.per_member_share(100, 0), 0)


# --- award ---

func test_award_distributes_to_all_characters_including_dead():
	var chars: Array = []
	for i in range(4):
		var ch := _make_character("C%d" % i)
		chars.append(ch)
	# Kill two of them
	chars[2].current_hp = 0
	chars[3].current_hp = 0
	var monsters: Array = [
		_make_monster(&"slime", 40),
		_make_monster(&"goblin", 60),
	]
	var share := ExperienceCalculator.award(chars, monsters)
	assert_eq(share, 25)
	for ch in chars:
		assert_eq(ch.accumulated_exp, 25, ch.character_name)


func test_award_returns_zero_when_no_monsters():
	var chars: Array = [_make_character("A")]
	var share := ExperienceCalculator.award(chars, [])
	assert_eq(share, 0)
	assert_eq(chars[0].accumulated_exp, 0)


# --- EncounterOutcome integration ---

func test_gained_experience_on_cleared_outcome_reflects_share():
	var chars: Array = [_make_character("A"), _make_character("B")]
	var monsters: Array = [_make_monster(&"slime", 100)]
	var outcome := EncounterOutcome.new(EncounterOutcome.Result.CLEARED)
	var share := ExperienceCalculator.award(chars, monsters)
	outcome.gained_experience = share
	assert_eq(outcome.gained_experience, 50)


func test_gained_experience_zero_on_wiped_outcome():
	var outcome := EncounterOutcome.new(EncounterOutcome.Result.WIPED)
	# Caller does not award on WIPED; experience remains 0.
	assert_eq(outcome.gained_experience, 0)


func test_gained_experience_zero_on_escaped_outcome():
	var outcome := EncounterOutcome.new(EncounterOutcome.Result.ESCAPED)
	assert_eq(outcome.gained_experience, 0)
