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
var accumulated_exp: int = 0
var equipment: Equipment = Equipment.new()

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

func is_dead() -> bool:
	return current_hp <= 0


func gain_experience(amount: int) -> void:
	if amount <= 0:
		return
	accumulated_exp += amount
	if job == null:
		return
	# exp_table[i] is the threshold to reach level i + 2, so the maximum level
	# representable in the table is exp_table.size() + 1. Stop once we're there,
	# otherwise exp_to_reach_level clamps to the last entry and we'd loop forever.
	var max_level := job.exp_table.size() + 1
	while accumulated_exp >= job.exp_to_reach_level(level + 1):
		if level >= max_level:
			break
		level_up()


func level_up() -> void:
	level += 1
	if job == null:
		return
	var vit: int = int(base_stats.get(&"VIT", 0))
	var hp_growth := maxi(job.hp_per_level + vit / 3, 1)
	max_hp += hp_growth
	current_hp += hp_growth
	if job.has_magic:
		max_mp += job.mp_per_level
		current_mp += job.mp_per_level


func to_dict(inventory: Inventory = null) -> Dictionary:
	var stats_str := {}
	for key in STAT_KEYS:
		stats_str[String(key)] = base_stats.get(key, 0)
	var d := {
		"character_name": character_name,
		"race_id": race.resource_path.get_file().get_basename(),
		"job_id": job.resource_path.get_file().get_basename(),
		"level": level,
		"base_stats": stats_str,
		"current_hp": current_hp,
		"max_hp": max_hp,
		"current_mp": current_mp,
		"max_mp": max_mp,
		"accumulated_exp": accumulated_exp,
	}
	if inventory != null:
		d["equipment"] = equipment.to_dict(inventory)
	return d

static func from_dict(data: Dictionary, inventory: Inventory = null) -> Character:
	# ResourceLoader.exists() is load-bearing: calling load() on a missing path
	# emits engine-level "Condition 'found' is true" errors, which we want to
	# avoid for routine save-with-missing-resource cases.
	var race_id: String = data.get("race_id", "human")
	var race_path := "res://data/races/" + race_id + ".tres"
	var race_res: RaceData = null
	if ResourceLoader.exists(race_path):
		race_res = load(race_path) as RaceData
	if race_res == null:
		push_warning("Character.from_dict: race resource missing at %s (character_name=%s)" % [race_path, data.get("character_name", "")])
		return null
	var job_id: String = data.get("job_id", "fighter")
	var job_path := "res://data/jobs/" + job_id + ".tres"
	var job_res: JobData = null
	if ResourceLoader.exists(job_path):
		job_res = load(job_path) as JobData
	if job_res == null:
		push_warning("Character.from_dict: job resource missing at %s (character_name=%s)" % [job_path, data.get("character_name", "")])
		return null
	var ch := Character.new()
	ch.character_name = data.get("character_name", "")
	ch.level = data.get("level", 1)
	ch.current_hp = data.get("current_hp", 0)
	ch.max_hp = data.get("max_hp", 0)
	ch.current_mp = data.get("current_mp", 0)
	ch.max_mp = data.get("max_mp", 0)
	ch.accumulated_exp = data.get("accumulated_exp", 0)
	ch.race = race_res
	ch.job = job_res
	var stats_raw: Dictionary = data.get("base_stats", {})
	ch.base_stats = {}
	for key in STAT_KEYS:
		ch.base_stats[key] = int(stats_raw.get(String(key), 0))
	if inventory != null and data.has("equipment"):
		ch.equipment = Equipment.from_dict(data.get("equipment", {}), inventory)
	else:
		ch.equipment = Equipment.new()
	return ch

func to_party_member_data() -> PartyMemberData:
	return PartyMemberData.new(
		character_name, level, current_hp, max_hp, current_mp, max_mp
	)
