class_name EncounterManager
extends RefCounted

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
	if _table == null or _table.entries.is_empty():
		return party
	var entry := _pick_weighted_entry(rng)
	if entry == null:
		return party
	_populate_party(party, entry.pattern, rng)
	return party


func _pick_weighted_entry(rng: RandomNumberGenerator) -> EncounterEntry:
	var total := _table.total_weight()
	if total <= 0:
		return null
	var roll := rng.randi_range(1, total)
	var cumulative := 0
	for entry in _table.entries:
		cumulative += entry.weight
		if roll <= cumulative:
			return entry
	return null


func _populate_party(party: MonsterParty, pattern: EncounterPattern, rng: RandomNumberGenerator) -> void:
	if pattern == null:
		return
	for group in pattern.groups:
		var source := _repository.find(group.monster_id)
		if source == null:
			push_warning("EncounterManager: monster_id %s not found in repository" % group.monster_id)
			continue
		var count := group.roll_count(rng)
		for i in range(count):
			party.add(Monster.new(source, rng))
