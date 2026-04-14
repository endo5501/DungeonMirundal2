class_name CharacterCreation
extends Control

signal back_requested

var current_step: int = 1
var total_steps: int = 5

var _guild: Guild
var _races: Array[RaceData]
var _jobs: Array[JobData]

var _name_input: String = ""
var _selected_race_index: int = -1
var _selected_job_index: int = -1

var _bonus_total: int = 0
var _allocation: Dictionary = {}
var _bonus_generator: BonusPointGenerator

func setup(guild: Guild, races: Array[RaceData], jobs: Array[JobData]) -> void:
	_guild = guild
	_races = races
	_jobs = jobs
	_bonus_generator = BonusPointGenerator.new()

func set_name_input(value: String) -> void:
	_name_input = value

func get_available_races() -> Array[RaceData]:
	return _races

func select_race(index: int) -> void:
	_selected_race_index = index

func select_job(index: int) -> void:
	_selected_job_index = index

func get_bonus_total() -> int:
	return _bonus_total

func get_remaining_points() -> int:
	var used := 0
	for key in _allocation:
		used += _allocation[key]
	return _bonus_total - used

func get_stat_value(stat: StringName) -> int:
	if _selected_race_index < 0:
		return 0
	var base_stats := _races[_selected_race_index].get_base_stats()
	return base_stats.get(stat, 0) + _allocation.get(stat, 0)

func increment_stat(stat: StringName) -> void:
	if get_remaining_points() <= 0:
		return
	_allocation[stat] = _allocation.get(stat, 0) + 1

func decrement_stat(stat: StringName) -> void:
	if _allocation.get(stat, 0) <= 0:
		return
	_allocation[stat] = _allocation[stat] - 1

func reroll_bonus() -> void:
	_bonus_total = _bonus_generator.generate()
	_reset_allocation()

func get_qualified_jobs() -> Dictionary:
	var result := {}
	var stats := _build_current_stats()
	for i in range(_jobs.size()):
		result[i] = _jobs[i].can_qualify(stats)
	return result

func get_summary() -> Dictionary:
	var race := _races[_selected_race_index]
	var job := _jobs[_selected_job_index]
	var ch := Character.create(_name_input, race, job, _allocation, _bonus_total)
	if ch == null:
		return {}
	return {
		"name": ch.character_name,
		"race": race,
		"job": job,
		"level": ch.level,
		"hp": ch.max_hp,
		"mp": ch.max_mp,
		"stats": ch.base_stats.duplicate(),
	}

func advance() -> void:
	match current_step:
		1:
			if _name_input.strip_edges() == "":
				return
			current_step = 2
		2:
			if _selected_race_index < 0:
				return
			_bonus_total = _bonus_generator.generate()
			_reset_allocation()
			current_step = 3
		3:
			if get_remaining_points() != 0:
				return
			current_step = 4
		4:
			if _selected_job_index < 0:
				return
			current_step = 5
		5:
			pass

func go_back() -> void:
	match current_step:
		1:
			return
		3:
			_reset_allocation()
			_selected_race_index = -1
			current_step = 2
		_:
			current_step -= 1

func cancel() -> void:
	back_requested.emit()

func confirm_creation() -> void:
	var race := _races[_selected_race_index]
	var job := _jobs[_selected_job_index]
	var ch := Character.create(_name_input, race, job, _allocation, _bonus_total)
	if ch != null:
		_guild.register(ch)
	back_requested.emit()

func _reset_allocation() -> void:
	_allocation = {}
	for key in Character.STAT_KEYS:
		_allocation[key] = 0

func _build_current_stats() -> Dictionary:
	var stats := {}
	for key in Character.STAT_KEYS:
		stats[key] = get_stat_value(key)
	return stats
