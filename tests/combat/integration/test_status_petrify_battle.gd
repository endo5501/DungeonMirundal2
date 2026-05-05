extends GutTest


# Integration: petrify status flow.
#
# Asserts:
#   - petrified actors skip their turn (action_locked event in TurnReport).
#   - petrify is committed to Character.persistent_statuses post-battle.
#   - The TownScreen auto-cure clears petrify on town arrival.

const TEST_SEED: int = 49


class _StubMonster extends CombatActor:
	var _hp: int
	var _max: int
	var _attack: int

	func _init(p_name: String, p_hp: int, p_attack: int = 0) -> void:
		actor_name = p_name
		_hp = p_hp
		_max = p_hp
		_attack = p_attack

	func _read_current_hp() -> int:
		return _hp

	func _write_current_hp(value: int) -> void:
		_hp = value

	func _read_max_hp() -> int:
		return _max

	func get_attack() -> int:
		return _attack


func _load_repo() -> StatusRepository:
	DataLoader._status_repo_cache = null
	return DataLoader.new().load_status_repository()


func _make_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = TEST_SEED
	return rng


func _make_character(name: String) -> Character:
	var human := load("res://data/races/human.tres") as RaceData
	var fighter_job := load("res://data/jobs/fighter.tres") as JobData
	var ch := Character.new()
	ch.character_name = name
	ch.race = human
	ch.job = fighter_job
	ch.level = 1
	ch.base_stats = {&"STR": 8, &"INT": 8, &"PIE": 8, &"VIT": 8, &"AGI": 8, &"LUC": 8}
	ch.max_hp = 20
	ch.current_hp = 20
	ch.max_mp = 0
	ch.current_mp = 0
	return ch


# --- petrify locks action ---

func test_petrified_monster_skips_turn():
	var engine := TurnEngine.new()
	var fighter := _StubMonster.new("Fighter", 30, 0)  # acts as the party stub
	var slime := _StubMonster.new("Slime", 30, 5)
	engine.start_battle([fighter], [slime])
	engine.status_repo = _load_repo()
	for a in engine.party + engine.monsters:
		if a != null:
			a.set_status_repo_for_testing(engine.status_repo)
	slime.statuses.apply(&"petrify", StatusTrack.PERSISTENT_DURATION)
	engine.submit_command(0, DefendCommand.new())
	var report := engine.resolve_turn(_make_rng())
	var locked := []
	for a in report.actions:
		if a.get("type") == "action_locked":
			locked.append(a)
	assert_gte(locked.size(), 1, "petrified actors should be skipped via action_locked")


# --- petrify persists post-battle ---

func test_commit_persistent_writes_petrify_back_to_character():
	var ch := _make_character("Stoned")
	var combatant := PartyCombatant.new(ch, null)
	combatant.statuses.apply(&"petrify", StatusTrack.PERSISTENT_DURATION)
	combatant.commit_persistent_to_character(_load_repo())
	assert_true(ch.persistent_statuses.has(&"petrify"),
		"petrify must persist back to Character.persistent_statuses (cures_on_battle_end=false)")


# --- town arrival cures petrify ---

func test_town_arrival_cures_petrify():
	var ch := _make_character("Stoned")
	ch.persistent_statuses = [&"petrify"]
	var guild := Guild.new()
	guild.register(ch)
	guild.assign_to_party(ch, 0, 0)
	var screen := TownScreen.new()
	add_child_autofree(screen)
	screen.setup(guild)
	screen.notify_arrival()
	assert_eq(ch.persistent_statuses.size(), 0)
