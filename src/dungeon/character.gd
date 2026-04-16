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

	var race_base := p_race.get_base_stats()
	var stats: Dictionary = {}
	for key in STAT_KEYS:
		stats[key] = race_base[key] + allocation.get(key, 0)

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

func to_dict() -> Dictionary:
	var stats_str := {}
	for key in STAT_KEYS:
		stats_str[String(key)] = base_stats.get(key, 0)
	return {
		"character_name": character_name,
		"race_id": race.resource_path.get_file().get_basename(),
		"job_id": job.resource_path.get_file().get_basename(),
		"level": level,
		"base_stats": stats_str,
		"current_hp": current_hp,
		"max_hp": max_hp,
		"current_mp": current_mp,
		"max_mp": max_mp,
	}

static func from_dict(data: Dictionary) -> Character:
	var ch := Character.new()
	ch.character_name = data.get("character_name", "")
	ch.level = data.get("level", 1)
	ch.current_hp = data.get("current_hp", 0)
	ch.max_hp = data.get("max_hp", 0)
	ch.current_mp = data.get("current_mp", 0)
	ch.max_mp = data.get("max_mp", 0)
	var race_id: String = data.get("race_id", "human")
	ch.race = load("res://data/races/" + race_id + ".tres") as RaceData
	var job_id: String = data.get("job_id", "fighter")
	ch.job = load("res://data/jobs/" + job_id + ".tres") as JobData
	var stats_raw: Dictionary = data.get("base_stats", {})
	ch.base_stats = {}
	for key in STAT_KEYS:
		ch.base_stats[key] = int(stats_raw.get(String(key), 0))
	return ch

func to_party_member_data() -> PartyMemberData:
	return PartyMemberData.new(
		character_name, level, current_hp, max_hp, current_mp, max_mp
	)
