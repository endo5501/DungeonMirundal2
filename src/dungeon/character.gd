class_name Character
extends RefCounted

const STAT_KEYS: Array[StringName] = [&"STR", &"INT", &"PIE", &"VIT", &"AGI", &"LUC"]

var character_name: String
var race: RaceData
var job: JobData
var level: int
var base_stats: Dictionary  # {&"STR": int, ...}
var current_hp: int
var max_hp: int
var current_mp: int
var max_mp: int

static func create(
	p_name: String,
	p_race: RaceData,
	p_job: JobData,
	allocation: Dictionary,
	bonus_total: int = -1
) -> Character:
	# Validate allocation sum if bonus_total is provided
	var alloc_sum := 0
	for key in STAT_KEYS:
		alloc_sum += allocation.get(key, 0)
	if bonus_total >= 0 and alloc_sum != bonus_total:
		return null

	# Calculate final stats
	var stats: Dictionary = {}
	stats[&"STR"] = p_race.base_str + allocation.get(&"STR", 0)
	stats[&"INT"] = p_race.base_int + allocation.get(&"INT", 0)
	stats[&"PIE"] = p_race.base_pie + allocation.get(&"PIE", 0)
	stats[&"VIT"] = p_race.base_vit + allocation.get(&"VIT", 0)
	stats[&"AGI"] = p_race.base_agi + allocation.get(&"AGI", 0)
	stats[&"LUC"] = p_race.base_luc + allocation.get(&"LUC", 0)

	# Check job qualification
	if not p_job.can_qualify(stats):
		return null

	var ch := Character.new()
	ch.character_name = p_name
	ch.race = p_race
	ch.job = p_job
	ch.level = 1
	ch.base_stats = stats
	ch.max_hp = p_job.base_hp + stats[&"VIT"] / 3
	ch.current_hp = ch.max_hp
	if p_job.has_magic:
		ch.max_mp = p_job.base_mp
		ch.current_mp = ch.max_mp
	else:
		ch.max_mp = 0
		ch.current_mp = 0
	return ch

func to_party_member_data() -> PartyMemberData:
	return PartyMemberData.new(
		character_name, level, current_hp, max_hp, current_mp, max_mp
	)
