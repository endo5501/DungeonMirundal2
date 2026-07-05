class_name TableEncounterSource
extends EncounterSource

var _table: EncounterTableData
var _repository: MonsterRepository


func _init(table: EncounterTableData, repository: MonsterRepository) -> void:
	_table = table
	_repository = repository


func next(_rng: RandomNumberGenerator) -> MonsterParty:
	return MonsterParty.new()


func describe() -> String:
	return ""
