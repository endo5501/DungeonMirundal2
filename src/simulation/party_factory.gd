class_name PartyFactory
extends RefCounted

# Builds simulation parties through the same code paths the game uses:
#   1. Character.create(...) at level 1 (grants level-1 spells and derives
#      base HP/MP deterministically from job/stats — no random rolls —
#      exactly like guild character creation).
#   2. gain_experience(job.exp_to_reach_level(target_level)) — the same API
#      ExperienceCalculator.award drives — so HP/MP growth and
#      spell_progression-derived known_spells match real play.
#   3. InitialEquipment.grant(...) into a shared Inventory, with an
#      InventoryEquipmentProvider wired into each PartyCombatant (mirrors
#      src/main.gd + combat_overlay._build_party_combatants).
#
# Default stat template when a member spec omits "stats": start from the
# race's base stats, raise each stat to the job's requirement for that stat,
# then add PRIMARY_STAT_BONUS to the job's primary stat (the stat with the
# highest requirement; STR for jobs with no requirements). This guarantees
# Character.create's can_qualify check passes while keeping the party at a
# plausible fresh-recruit power level.
const PRIMARY_STAT_BONUS: int = 4


# Returns {"combatants": Array[PartyCombatant], "characters": Array[Character],
# "errors": Array[String]}. Unknown job/race (or disqualifying stats) append an
# error naming the offending field and value; callers must treat a non-empty
# errors array as fatal. `rng` is accepted for future growth rolls — the
# current production level-up path (Character.level_up) is deterministic, so
# no rolls consume it yet.
@warning_ignore("unused_parameter")
static func build(member_specs: Array, rng: RandomNumberGenerator) -> Dictionary:
	var errors: Array[String] = []
	var characters: Array = []
	var combatants: Array = []
	var loader := DataLoader.new()
	var races := loader.load_all_races()
	var jobs := loader.load_all_jobs()
	var item_repo := loader.load_all_items()
	var inventory := Inventory.new()
	var provider := InventoryEquipmentProvider.new()
	for i in range(member_specs.size()):
		var spec: Dictionary = member_specs[i]
		var race_name := String(spec.get("race", ""))
		var race := _find_race(races, race_name)
		if race == null:
			errors.append("party[%d].race: unknown race '%s'" % [i, race_name])
			continue
		var job_name := String(spec.get("job", ""))
		var job := _find_job(jobs, job_name)
		if job == null:
			errors.append("party[%d].job: unknown job '%s'" % [i, job_name])
			continue
		var stats := _resolve_stats(spec, race, job)
		var allocation := _allocation_from_stats(stats, race)
		var member_name := String(spec.get("name", "P%d" % (i + 1)))
		var ch := Character.create(member_name, race, job, allocation)
		if ch == null:
			errors.append(
				"party[%d].stats: stats %s do not qualify for job '%s'" % [i, stats, job_name]
			)
			continue
		var target_level := int(spec.get("level", 1))
		if target_level > 1:
			# Production level-up path: the same gain_experience API that
			# ExperienceCalculator.award calls after each cleared battle.
			ch.gain_experience(job.exp_to_reach_level(target_level))
		InitialEquipment.grant(ch, inventory, item_repo)
		var row := Row.BACK if String(spec.get("row", "front")) == "back" else Row.FRONT
		characters.append(ch)
		combatants.append(PartyCombatant.new(ch, provider, row))
	return {"combatants": combatants, "characters": characters, "errors": errors}


static func _find_race(races: Array[RaceData], race_name: String) -> RaceData:
	for race in races:
		if race != null and String(race.id) == race_name:
			return race
	return null


static func _find_job(jobs: Array[JobData], job_name: String) -> JobData:
	for job in jobs:
		if job != null and String(job.id) == job_name:
			return job
	return null


# Final base stats for the member: explicit "stats" entries override the
# default template on a per-stat basis (missing keys fall back to the
# template value for that stat).
static func _resolve_stats(spec: Dictionary, race: RaceData, job: JobData) -> Dictionary:
	var stats := _default_stats(race, job)
	var raw: Variant = spec.get("stats", {})
	if raw is Dictionary:
		for key in Character.STAT_KEYS:
			var provided: Dictionary = raw
			if provided.has(String(key)):
				stats[key] = int(provided[String(key)])
	return stats


static func _default_stats(race: RaceData, job: JobData) -> Dictionary:
	var stats := race.get_base_stats()
	var requirements := _job_requirements(job)
	for key in Character.STAT_KEYS:
		stats[key] = maxi(int(stats[key]), int(requirements[key]))
	stats[_primary_stat(requirements)] = int(stats[_primary_stat(requirements)]) + PRIMARY_STAT_BONUS
	return stats


static func _job_requirements(job: JobData) -> Dictionary:
	return {
		&"STR": job.required_str,
		&"INT": job.required_int,
		&"PIE": job.required_pie,
		&"VIT": job.required_vit,
		&"AGI": job.required_agi,
		&"LUC": job.required_luc,
	}


static func _primary_stat(requirements: Dictionary) -> StringName:
	var primary: StringName = &"STR"
	var best := 0
	for key in Character.STAT_KEYS:
		if int(requirements[key]) > best:
			best = int(requirements[key])
			primary = key
	return primary


# Character.create adds `allocation` on top of the race base stats, so the
# allocation is simply the delta from race base to the resolved target stats.
static func _allocation_from_stats(stats: Dictionary, race: RaceData) -> Dictionary:
	var race_base := race.get_base_stats()
	var allocation := {}
	for key in Character.STAT_KEYS:
		allocation[key] = int(stats[key]) - int(race_base[key])
	return allocation
