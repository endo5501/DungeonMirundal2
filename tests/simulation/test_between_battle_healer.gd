extends GutTest

const TEST_SEED: int = 12345


var _loader: DataLoader


func before_each():
	_loader = DataLoader.new()


func _make_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = TEST_SEED
	return rng


func _find_job(name: String) -> JobData:
	for j in _loader.load_all_jobs():
		if j.job_name == name:
			return j
	return null


func _find_human() -> RaceData:
	for r in _loader.load_all_races():
		if r.race_name == "Human":
			return r
	return null


func _make_character(
	name: String,
	job_name: String,
	hp: int,
	max_hp: int,
	mp: int,
	max_mp: int,
	spells: Array = []
) -> Character:
	var ch := Character.new()
	ch.character_name = name
	ch.race = _find_human()
	ch.job = _find_job(job_name)
	ch.level = 1
	ch.base_stats = {&"STR": 14, &"INT": 10, &"PIE": 10, &"VIT": 14, &"AGI": 10, &"LUC": 10}
	ch.max_hp = max_hp
	ch.current_hp = hp
	ch.max_mp = max_mp
	ch.current_mp = mp
	var typed: Array[StringName] = []
	for sid in spells:
		typed.append(StringName(sid))
	ch.known_spells = typed
	return ch


func _make_heal_spell(
	id: StringName,
	mp_cost: int,
	base_heal: int,
	scope: int = SpellData.Scope.OUTSIDE_OK
) -> SpellData:
	var effect := HealSpellEffect.new()
	effect.base_heal = base_heal
	effect.spread = 0
	var spell := SpellData.new()
	spell.id = id
	spell.display_name = String(id)
	spell.school = SpellData.SCHOOL_PRIEST
	spell.level = 1
	spell.mp_cost = mp_cost
	spell.target_type = SpellData.TargetType.ALLY_ONE
	spell.scope = scope
	spell.effect = effect
	return spell


func _make_cure_spell(id: StringName, mp_cost: int) -> SpellData:
	var effect := CureStatusSpellEffect.new()
	effect.status_id = &"sleep"
	var spell := SpellData.new()
	spell.id = id
	spell.display_name = String(id)
	spell.school = SpellData.SCHOOL_PRIEST
	spell.level = 1
	spell.mp_cost = mp_cost
	spell.target_type = SpellData.TargetType.ALLY_ONE
	spell.scope = SpellData.Scope.OUTSIDE_OK
	spell.effect = effect
	return spell


func _make_repo(spells: Array) -> SpellRepository:
	var repo := SpellRepository.new()
	for s in spells:
		repo.register(s)
	return repo


# --- target priority ---

func test_most_injured_member_is_healed_first():
	var repo := _make_repo([_make_heal_spell(&"heal", 2, 8)])
	var f1 := _make_character("F1", "Fighter", 20, 30, 0, 0)
	var f2 := _make_character("F2", "Fighter", 10, 30, 0, 0)
	var priest := _make_character("P1", "Priest", 25, 25, 2, 10, [&"heal"])
	var casts: Array = BetweenBattleHealer.heal_party([f1, f2, priest], repo, _make_rng())
	assert_eq(casts.size(), 1)
	assert_eq(casts[0]["target"], f2, "lowest HP-ratio member is healed first")
	assert_eq(casts[0]["caster"], priest)
	assert_eq(casts[0]["spell_id"], &"heal")
	assert_eq(casts[0]["healed"], 8)
	assert_eq(f2.current_hp, 18)
	assert_eq(f1.current_hp, 20, "second-most injured member is left as-is when MP runs out")


# --- minimal-overheal spell selection ---

func test_smallest_sufficient_spell_is_chosen():
	var repo := _make_repo([
		_make_heal_spell(&"heal", 2, 8),
		_make_heal_spell(&"heala", 3, 14),
	])
	var fighter := _make_character("F1", "Fighter", 25, 30, 0, 0)
	var priest := _make_character("P1", "Priest", 25, 25, 10, 10, [&"heal", &"heala"])
	var casts: Array = BetweenBattleHealer.heal_party([fighter, priest], repo, _make_rng())
	assert_eq(casts.size(), 1)
	assert_eq(casts[0]["spell_id"], &"heal", "missing 5 HP: heal(8) overheals less than heala(14)")
	assert_eq(casts[0]["healed"], 5, "heal is capped at max_hp")
	assert_eq(fighter.current_hp, 30)
	assert_eq(priest.current_mp, 8)


func test_larger_spell_is_chosen_when_smaller_is_insufficient():
	var repo := _make_repo([
		_make_heal_spell(&"heal", 2, 8),
		_make_heal_spell(&"heala", 3, 14),
	])
	var fighter := _make_character("F1", "Fighter", 21, 30, 0, 0)
	var priest := _make_character("P1", "Priest", 25, 25, 10, 10, [&"heal", &"heala"])
	var casts: Array = BetweenBattleHealer.heal_party([fighter, priest], repo, _make_rng())
	assert_eq(casts.size(), 1)
	assert_eq(casts[0]["spell_id"], &"heala", "missing 9 HP: heal(8) is insufficient, heala(14) fills")
	assert_eq(casts[0]["healed"], 9)
	assert_eq(fighter.current_hp, 30)
	assert_eq(priest.current_mp, 7)


func test_largest_spell_is_chosen_when_none_is_sufficient():
	var repo := _make_repo([
		_make_heal_spell(&"heal", 2, 8),
		_make_heal_spell(&"heala", 3, 14),
	])
	var fighter := _make_character("F1", "Fighter", 5, 30, 0, 0)
	var priest := _make_character("P1", "Priest", 25, 25, 3, 10, [&"heal", &"heala"])
	var casts: Array = BetweenBattleHealer.heal_party([fighter, priest], repo, _make_rng())
	assert_eq(casts.size(), 1)
	assert_eq(casts[0]["spell_id"], &"heala", "missing 25 HP: neither fills, pick the largest heal")
	assert_eq(casts[0]["healed"], 14)
	assert_eq(fighter.current_hp, 19)
	assert_eq(priest.current_mp, 0)


func test_healing_repeats_until_target_is_full():
	var repo := _make_repo([_make_heal_spell(&"heal", 2, 8)])
	var fighter := _make_character("F1", "Fighter", 14, 30, 0, 0)
	var priest := _make_character("P1", "Priest", 25, 25, 10, 10, [&"heal"])
	var casts: Array = BetweenBattleHealer.heal_party([fighter, priest], repo, _make_rng())
	assert_eq(casts.size(), 2)
	assert_eq(fighter.current_hp, 30)
	assert_eq(priest.current_mp, 6)


# --- MP exhaustion ---

func test_healing_stops_when_mp_runs_out():
	var repo := _make_repo([_make_heal_spell(&"heal", 2, 8)])
	var f1 := _make_character("F1", "Fighter", 15, 30, 0, 0)
	var f2 := _make_character("F2", "Fighter", 10, 30, 0, 0)
	var priest := _make_character("P1", "Priest", 25, 25, 2, 10, [&"heal"])
	var casts: Array = BetweenBattleHealer.heal_party([f1, f2, priest], repo, _make_rng())
	assert_eq(casts.size(), 1, "only one cast is affordable")
	assert_eq(f2.current_hp, 18, "most injured member got the single heal")
	assert_eq(f1.current_hp, 15, "partially-healed party is left as-is")
	assert_eq(priest.current_mp, 0)


func test_mp_is_deducted_from_the_caster():
	var repo := _make_repo([_make_heal_spell(&"heal", 2, 8)])
	var fighter := _make_character("F1", "Fighter", 22, 30, 0, 0)
	var priest := _make_character("P1", "Priest", 25, 25, 10, 10, [&"heal"])
	var casts: Array = BetweenBattleHealer.heal_party([fighter, priest], repo, _make_rng())
	assert_eq(casts.size(), 1)
	assert_eq(priest.current_mp, 8, "one heal at MP 2 leaves 8 of 10")


# --- no-op cases ---

func test_nothing_happens_when_everyone_is_at_full_hp():
	var repo := _make_repo([_make_heal_spell(&"heal", 2, 8)])
	var fighter := _make_character("F1", "Fighter", 30, 30, 0, 0)
	var priest := _make_character("P1", "Priest", 25, 25, 10, 10, [&"heal"])
	var casts: Array = BetweenBattleHealer.heal_party([fighter, priest], repo, _make_rng())
	assert_eq(casts.size(), 0)
	assert_eq(priest.current_mp, 10, "no MP is spent when nobody is injured")


func test_battle_only_and_non_heal_spells_are_never_used():
	var repo := _make_repo([
		_make_heal_spell(&"battle_heal", 2, 8, SpellData.Scope.BATTLE_ONLY),
		_make_cure_spell(&"dios", 2),
	])
	var fighter := _make_character("F1", "Fighter", 10, 30, 0, 0)
	var priest := _make_character("P1", "Priest", 25, 25, 10, 10, [&"battle_heal", &"dios"])
	var casts: Array = BetweenBattleHealer.heal_party([fighter, priest], repo, _make_rng())
	assert_eq(casts.size(), 0)
	assert_eq(fighter.current_hp, 10)
	assert_eq(priest.current_mp, 10)


# --- dead members ---

func test_dead_members_are_never_healed_or_used_as_casters():
	var repo := _make_repo([_make_heal_spell(&"heal", 2, 8)])
	var dead_fighter := _make_character("DF", "Fighter", 0, 30, 0, 0)
	var dead_priest := _make_character("DP", "Priest", 0, 25, 10, 10, [&"heal"])
	var fighter := _make_character("F1", "Fighter", 22, 30, 0, 0)
	var priest := _make_character("P1", "Priest", 25, 25, 4, 10, [&"heal"])
	var casts: Array = BetweenBattleHealer.heal_party(
		[dead_fighter, dead_priest, fighter, priest], repo, _make_rng()
	)
	assert_eq(casts.size(), 1)
	assert_eq(casts[0]["caster"], priest, "dead priest is not used as a caster")
	assert_eq(casts[0]["target"], fighter, "dead fighter is not healed despite 0% HP")
	assert_eq(dead_fighter.current_hp, 0)
	assert_eq(dead_priest.current_mp, 10, "dead caster's MP is untouched")
	assert_eq(fighter.current_hp, 30)
