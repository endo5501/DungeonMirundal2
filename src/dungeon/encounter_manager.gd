class_name EncounterManager
extends RefCounted

const ROW_CAP: int = 5

var _repository: MonsterRepository
var _cooldown_steps: int
var _table: EncounterTableData
var _steps_since_last_encounter: int


func _init(repository: MonsterRepository, cooldown_steps: int = 3) -> void:
	_repository = repository
	_cooldown_steps = cooldown_steps
	_steps_since_last_encounter = cooldown_steps


func set_table(table: EncounterTableData) -> void:
	_table = table


func should_trigger(rng: RandomNumberGenerator) -> bool:
	if _table == null:
		return false
	if _steps_since_last_encounter < _cooldown_steps:
		_steps_since_last_encounter += 1
		return false
	if rng.randf() < _table.probability_per_step:
		_steps_since_last_encounter = 0
		return true
	_steps_since_last_encounter += 1
	return false


func notify_encounter_occurred() -> void:
	_steps_since_last_encounter = 0


func generate(rng: RandomNumberGenerator) -> MonsterParty:
	var party := MonsterParty.new()
	if _table == null:
		return party
	var tier_weights := _table.normalized_tier_weights()
	if tier_weights.is_empty():
		return party
	var n_species: int = rng.randi_range(_table.species_count_min, _table.species_count_max)
	var spawned_per_row: Dictionary = {Row.FRONT: 0, Row.BACK: 0}
	for i in range(n_species):
		var tier: int = _pick_tier_weighted(tier_weights, rng)
		if tier == -1:
			continue
		var candidates := _repository.find_by_tier(tier)
		if candidates.is_empty():
			push_warning("EncounterManager: no monsters registered for tier %d; skipping slot" % tier)
			continue
		var monster_data: MonsterData = candidates[rng.randi() % candidates.size()]
		var count: int = rng.randi_range(_table.count_per_species_min, _table.count_per_species_max)
		_spawn_with_truncation(party, monster_data, count, spawned_per_row, rng)
	return party


func _pick_tier_weighted(tier_weights: Dictionary, rng: RandomNumberGenerator) -> int:
	# Sort keys so the cumulative scan is deterministic regardless of how the
	# caller built the dictionary.
	var sorted_keys := tier_weights.keys()
	sorted_keys.sort()
	var total := 0
	for k in sorted_keys:
		total += int(tier_weights[k])
	if total <= 0:
		return -1
	var roll := rng.randi_range(1, total)
	var cumulative := 0
	for key in sorted_keys:
		cumulative += int(tier_weights[key])
		if roll <= cumulative:
			return int(key)
	return -1


func _spawn_with_truncation(
		party: MonsterParty,
		source: MonsterData,
		count: int,
		spawned_per_row: Dictionary,
		rng: RandomNumberGenerator,
) -> void:
	var row: int = source.default_row
	var bucket: int = spawned_per_row.get(row, 0)
	var dropped := 0
	for i in range(count):
		if bucket >= ROW_CAP:
			dropped += 1
			continue
		party.add(Monster.new(source, rng))
		bucket += 1
	spawned_per_row[row] = bucket
	if dropped > 0:
		var row_name: String = "FRONT" if row == Row.FRONT else "BACK"
		push_warning("EncounterManager: %d %s instance(s) dropped from %s row (cap %d)"
			% [dropped, source.monster_id, row_name, ROW_CAP])
