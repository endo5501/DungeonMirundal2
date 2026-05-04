class_name EncounterCoordinator
extends Node

signal encounter_finished(outcome: EncounterOutcome)

var _repository: MonsterRepository
var _manager: EncounterManager
var _rng: RandomNumberGenerator
var _overlay: EncounterOverlay
var _current_screen: DungeonScreen
var _last_outcome: EncounterOutcome
var _tables_by_floor: Dictionary = {}
var _active_table: EncounterTableData


func _init(repository: MonsterRepository, rng: RandomNumberGenerator, cooldown_steps: int = 3) -> void:
	_repository = repository
	_rng = rng
	_manager = EncounterManager.new(_repository, cooldown_steps)


func set_overlay(overlay: EncounterOverlay) -> void:
	# Must be called before the coordinator enters the tree.
	_overlay = overlay


func _ready() -> void:
	if _overlay == null:
		_overlay = SimpleEncounterOverlay.new()
	_overlay.encounter_resolved.connect(_on_encounter_resolved)
	add_child(_overlay)


func set_table(table: EncounterTableData) -> void:
	_active_table = table
	_manager.set_table(table)


func set_tables_by_floor(tables: Dictionary) -> void:
	_tables_by_floor = tables.duplicate()


func set_floor(floor: int) -> void:
	# floor is 1-based to align with EncounterTableData.floor.
	var table := _resolve_table_for_floor(floor)
	if table == null:
		_active_table = null
		_manager.set_table(null)
	else:
		set_table(table)


func _resolve_table_for_floor(floor: int) -> EncounterTableData:
	if _tables_by_floor.is_empty():
		push_warning("No encounter tables registered; encounters disabled")
		return null
	if _tables_by_floor.has(floor):
		return _tables_by_floor[floor]
	# Fall back to the deepest registered floor that is <= requested floor.
	var best_floor := -1
	for key in _tables_by_floor.keys():
		var k := int(key)
		if k <= floor and k > best_floor:
			best_floor = k
	if best_floor < 0:
		# All registered floors are above the requested one; pick the smallest.
		for key in _tables_by_floor.keys():
			var k := int(key)
			if best_floor < 0 or k < best_floor:
				best_floor = k
	push_warning("No encounter table for floor %d, using floor %d" % [floor, best_floor])
	return _tables_by_floor[best_floor]


func get_active_table() -> EncounterTableData:
	return _active_table


func attach_screen(screen: DungeonScreen) -> void:
	detach_screen()
	_current_screen = screen
	_current_screen.step_taken.connect(_on_step_taken)
	if _current_screen.has_signal("floor_changed"):
		_current_screen.floor_changed.connect(_on_floor_changed)


func detach_screen() -> void:
	if _current_screen == null:
		return
	if _current_screen.step_taken.is_connected(_on_step_taken):
		_current_screen.step_taken.disconnect(_on_step_taken)
	if _current_screen.has_signal("floor_changed") and _current_screen.floor_changed.is_connected(_on_floor_changed):
		_current_screen.floor_changed.disconnect(_on_floor_changed)
	_current_screen = null


func get_overlay() -> EncounterOverlay:
	return _overlay


func is_encounter_active() -> bool:
	return _overlay != null and _overlay.is_active()


func _on_step_taken(_position: Vector2i) -> void:
	if _current_screen == null:
		return
	if _active_table == null:
		return
	if not _manager.should_trigger(_rng):
		return
	var party := _manager.generate(_rng)
	if party.is_empty():
		return
	_current_screen.set_encounter_active(true)
	_overlay.start_encounter(party)


func _on_floor_changed(new_floor: int) -> void:
	# new_floor is 0-based (floor index); EncounterTableData.floor is 1-based.
	set_floor(new_floor + 1)


func _on_encounter_resolved(outcome: EncounterOutcome) -> void:
	_last_outcome = outcome
	_manager.notify_encounter_occurred()
	if _current_screen != null:
		_current_screen.set_encounter_active(false)
		_current_screen.check_start_tile_return()
	encounter_finished.emit(outcome)


func last_outcome() -> EncounterOutcome:
	return _last_outcome
