extends GutTest


var _inventory: Inventory
var _guild: Guild


func _make_character(name: String, level: int = 1, hp: int = 10) -> Character:
	var human := load("res://data/races/human.tres") as RaceData
	var fighter := load("res://data/jobs/fighter.tres") as JobData
	var ch := Character.new()
	ch.character_name = name
	ch.race = human
	ch.job = fighter
	ch.level = level
	ch.base_stats = {&"STR": 12, &"INT": 10, &"PIE": 10, &"VIT": 12, &"AGI": 10, &"LUC": 10}
	ch.max_hp = 20
	ch.current_hp = hp
	ch.max_mp = 0
	ch.current_mp = 0
	return ch


func before_each():
	_inventory = Inventory.new()
	_guild = Guild.new()


func _make_screen() -> TempleScreen:
	var s := TempleScreen.new()
	s.setup(_inventory, _guild)
	add_child_autofree(s)
	return s


# --- cost ---

func test_revive_cost_per_level_constant():
	assert_eq(TempleScreen.REVIVE_COST_PER_LEVEL, 100)


func test_revive_cost_level_1():
	var s := _make_screen()
	var ch := _make_character("L1", 1)
	assert_eq(s.revive_cost(ch), 100)


func test_revive_cost_level_5():
	var s := _make_screen()
	var ch := _make_character("L5", 5)
	assert_eq(s.revive_cost(ch), 500)


# --- member display ---

func test_is_dead_when_hp_zero():
	var s := _make_screen()
	var ch := _make_character("Dead", 1, 0)
	assert_true(s.is_dead(ch))


func test_is_alive_when_hp_positive():
	var s := _make_screen()
	var ch := _make_character("Alive", 1, 5)
	assert_false(s.is_dead(ch))


func test_get_party_members_returns_guild_characters():
	_guild.register(_make_character("A"))
	_guild.register(_make_character("B"))
	var s := _make_screen()
	assert_eq(s.get_party_members().size(), 2)


# --- revive ---

func test_revive_succeeds_with_enough_gold():
	var dead := _make_character("Dead", 2, 0)
	_guild.register(dead)
	_inventory.gold = 500
	var s := _make_screen()
	assert_true(s.revive(dead))
	assert_eq(dead.current_hp, 1)
	assert_eq(_inventory.gold, 500 - 200)  # level 2 * 100


func test_revive_does_not_restore_mp():
	var dead := _make_character("Mage", 1, 0)
	dead.max_mp = 10
	dead.current_mp = 3
	_guild.register(dead)
	_inventory.gold = 200
	var s := _make_screen()
	s.revive(dead)
	assert_eq(dead.current_mp, 3)


func test_revive_blocked_when_insufficient_gold():
	var dead := _make_character("Dead", 1, 0)
	_guild.register(dead)
	_inventory.gold = 50
	var s := _make_screen()
	assert_false(s.revive(dead))
	assert_eq(_inventory.gold, 50)
	assert_eq(dead.current_hp, 0)
	assert_true(s.get_last_message().contains("ゴールド"))


func test_revive_rejects_living_character():
	var alive := _make_character("Alive", 1, 10)
	_guild.register(alive)
	_inventory.gold = 500
	var s := _make_screen()
	assert_false(s.revive(alive))
	assert_eq(_inventory.gold, 500)
	assert_true(s.get_last_message().contains("蘇生対象"))


func test_revive_is_100_percent_success():
	# No RNG involved: succeeds every time, deterministically.
	for _i in range(20):
		var inv := Inventory.new()
		inv.gold = 500
		var guild := Guild.new()
		var dead := _make_character("Dead", 1, 0)
		guild.register(dead)
		var s := TempleScreen.new()
		s.setup(inv, guild)
		add_child_autofree(s)
		assert_true(s.revive(dead))
		assert_eq(dead.current_hp, 1)
