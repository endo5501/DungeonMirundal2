class_name TableEncounterSource
extends EncounterSource

# Generates compositions from an EncounterTableData by delegating to the
# production EncounterManager.generate(). The walking-encounter trigger
# probability (should_trigger) is intentionally unused: every next() call
# yields a battle.

var _table: EncounterTableData
var _manager: EncounterManager


func _init(table: EncounterTableData, repository: MonsterRepository) -> void:
	_table = table
	_manager = EncounterManager.new(repository, 0)
	_manager.set_table(table)


func next(rng: RandomNumberGenerator) -> MonsterParty:
	return _manager.generate(rng)


func describe() -> String:
	if _table == null:
		return "table"
	return "floor_%d" % _table.floor
