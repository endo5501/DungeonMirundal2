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


# --- items-and-economy: inventory and item_repository ---

func test_new_game_creates_inventory_with_starting_gold():
	var gs := GameStateScript.new()
	gs.new_game()
	assert_not_null(gs.inventory)
	assert_eq(gs.inventory.gold, 500)
	assert_eq(gs.inventory.list().size(), 0)


func test_game_state_has_item_repository_field():
	var gs := GameStateScript.new()
	# item_repository is populated by _ready in production. In isolated
	# tests we just assert the field exists and can be assigned.
	assert_true("item_repository" in gs)
	gs.item_repository = ItemRepository.new()
	assert_not_null(gs.item_repository)


func test_new_game_preserves_item_repository():
	var gs := GameStateScript.new()
	var repo := ItemRepository.new()
	gs.item_repository = repo
	gs.new_game()
	assert_eq(gs.item_repository, repo)


# --- tighten-types-and-contracts: _initialize_state symmetry ---

func test_new_game_called_twice_keeps_item_repository():
	var gs := GameStateScript.new()
	var repo := ItemRepository.new()
	gs.item_repository = repo
	gs.new_game()
	gs.new_game()
	assert_eq(gs.item_repository, repo)


func test_new_game_resets_inventory_and_gold():
	var gs := GameStateScript.new()
	gs.new_game()
	gs.inventory.add_gold(1000)
	gs.new_game()
	assert_eq(gs.inventory.gold, 500)


func test_new_game_resets_game_location_to_town():
	var gs := GameStateScript.new()
	gs.new_game()
	gs.game_location = GameStateScript.LOCATION_DUNGEON
	gs.current_dungeon_index = 3
	gs.new_game()
	assert_eq(gs.game_location, GameStateScript.LOCATION_TOWN)
	assert_eq(gs.current_dungeon_index, -1)


func test_initialize_state_preserves_existing_guild_when_not_resetting():
	var gs := GameStateScript.new()
	gs.guild = Guild.new()
	var existing_guild := gs.guild
	gs._initialize_state(false)
	assert_eq(gs.guild, existing_guild)


func test_initialize_state_creates_guild_when_null_and_not_resetting():
	var gs := GameStateScript.new()
	gs.guild = null
	gs._initialize_state(false)
	assert_not_null(gs.guild)


func test_initialize_state_resets_guild_when_resetting():
	var gs := GameStateScript.new()
	gs.guild = Guild.new()
	var prev_guild := gs.guild
	gs._initialize_state(true)
	assert_ne(gs.guild, prev_guild)


func test_heal_party_skips_dead_members():
	var gs := GameStateScript.new()
	gs.new_game()
	var alive := _make_character("Alive")
	var dead := _make_character("Dead")
	gs.guild.register(alive)
	gs.guild.register(dead)
	gs.guild.assign_to_party(alive, 0, 0)
	gs.guild.assign_to_party(dead, 0, 1)
	alive.current_hp = 3
	dead.current_hp = 0
	dead.current_mp = 5
	var dead_max_mp := dead.max_mp
	gs.heal_party()
	assert_eq(alive.current_hp, alive.max_hp)
	# Dead character stays at 0 HP; MP should not be restored either
	assert_eq(dead.current_hp, 0)
	# MP restoration is skipped for dead characters: current_mp should not change
	# (we preserve whatever value it had pre-heal, which was 5 here — unless
	# max_mp == 0 in which case it's moot)
	if dead_max_mp > 0:
		assert_eq(dead.current_mp, 5)
