class_name FixedPatternSource
extends EncounterSource

# Cycles through fixed composition patterns in order, wrapping around.
# Each pattern is a Dictionary mapping a species id (StringName or String)
# to an instance count. Unknown species ids push_error and are skipped, so
# a pattern made entirely of unknown ids yields an empty (detectable) party.

var _patterns: Array = []
var _repository: MonsterRepository
var _last_index: int = -1


func _init(patterns: Array, repository: MonsterRepository) -> void:
	_patterns = patterns
	_repository = repository


func next(rng: RandomNumberGenerator) -> MonsterParty:
	var party := MonsterParty.new()
	if _patterns.is_empty():
		push_error("FixedPatternSource: no patterns configured")
		return party
	_last_index = (_last_index + 1) % _patterns.size()
	var pattern: Dictionary = _patterns[_last_index]
	for species_key in pattern.keys():
		var species_id := StringName(species_key)
		var data: MonsterData = _repository.find(species_id)
		if data == null:
			push_error("FixedPatternSource: unknown species '%s' in pattern %d; skipping"
				% [species_id, _last_index])
			continue
		var count := int(pattern[species_key])
		for i in range(count):
			party.add(Monster.new(data, rng))
	return party


func describe() -> String:
	if _last_index == -1:
		return "fixed"
	var parts: PackedStringArray = []
	var pattern: Dictionary = _patterns[_last_index]
	for species_key in pattern.keys():
		parts.append("%s_x%d" % [species_key, int(pattern[species_key])])
	return "pattern_%d:%s" % [_last_index, "+".join(parts)]
