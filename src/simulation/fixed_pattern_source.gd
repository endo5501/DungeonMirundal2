class_name FixedPatternSource
extends EncounterSource

var _patterns: Array = []
var _repository: MonsterRepository


func _init(patterns: Array, repository: MonsterRepository) -> void:
	_patterns = patterns
	_repository = repository


func next(_rng: RandomNumberGenerator) -> MonsterParty:
	return MonsterParty.new()


func describe() -> String:
	return ""
