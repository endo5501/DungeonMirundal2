extends GutTest

const GameStateScript = preload("res://src/game_state.gd")

var _human: RaceData
var _fighter_job: JobData
var _mage_job: JobData

func before_each():
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

	_mage_job = JobData.new()
	_mage_job.job_name = "Mage"
	_mage_job.base_hp = 6
	_mage_job.has_magic = true
	_mage_job.base_mp = 5
	_mage_job.required_str = 0
	_mage_job.required_int = 10
	_mage_job.required_pie = 0
	_mage_job.required_vit = 0
	_mage_job.required_agi = 0
	_mage_job.required_luc = 0

func _make_character(char_name: String, job: JobData = null) -> Character:
	if job == null:
		job = _fighter_job
	var allocation := {&"STR": 5, &"INT": 5, &"PIE": 0, &"VIT": 0, &"AGI": 0, &"LUC": 0}
	return Character.create(char_name, _human, job, allocation)

# --- new_game ---

func test_new_game_creates_fresh_guild():
	var gs := GameStateScript.new()
	gs.new_game()
	assert_not_null(gs.guild)
	assert_eq(gs.guild.get_all_characters().size(), 0)

func test_new_game_creates_fresh_dungeon_registry():
	var gs := GameStateScript.new()
	gs.new_game()
	assert_not_null(gs.dungeon_registry)
	assert_eq(gs.dungeon_registry.size(), 0)

func test_new_game_resets_existing_state():
	var gs := GameStateScript.new()
	gs.new_game()
	gs.guild.register(_make_character("Old"))
	gs.dungeon_registry.create("Old dungeon", DungeonRegistry.SIZE_SMALL)
	gs.new_game()
	assert_eq(gs.guild.get_all_characters().size(), 0)
	assert_eq(gs.dungeon_registry.size(), 0)

# --- heal_party ---

func test_heal_party_restores_hp():
	var gs := GameStateScript.new()
	gs.new_game()
	var ch := _make_character("Hero")
	gs.guild.register(ch)
	gs.guild.assign_to_party(ch, 0, 0)
	ch.current_hp = 5
	gs.heal_party()
	assert_eq(ch.current_hp, ch.max_hp)

func test_heal_party_restores_mp():
	var gs := GameStateScript.new()
	gs.new_game()
	var mage := _make_character("Mage", _mage_job)
	gs.guild.register(mage)
	gs.guild.assign_to_party(mage, 0, 0)
	mage.current_mp = 0
	gs.heal_party()
	assert_eq(mage.current_mp, mage.max_mp)

func test_heal_party_affects_all_members():
	var gs := GameStateScript.new()
	gs.new_game()
	var a := _make_character("A")
	var b := _make_character("B")
	var c := _make_character("C")
	gs.guild.register(a)
	gs.guild.register(b)
	gs.guild.register(c)
	gs.guild.assign_to_party(a, 0, 0)
	gs.guild.assign_to_party(b, 0, 1)
	gs.guild.assign_to_party(c, 1, 0)
	a.current_hp = 1
	b.current_hp = 2
	c.current_hp = 3
	gs.heal_party()
	assert_eq(a.current_hp, a.max_hp)
	assert_eq(b.current_hp, b.max_hp)
	assert_eq(c.current_hp, c.max_hp)

func test_heal_party_skips_empty_slots():
	var gs := GameStateScript.new()
	gs.new_game()
	var ch := _make_character("Solo")
	gs.guild.register(ch)
	gs.guild.assign_to_party(ch, 0, 0)
	ch.current_hp = 1
	gs.heal_party()  # should not crash with empty slots
	assert_eq(ch.current_hp, ch.max_hp)
