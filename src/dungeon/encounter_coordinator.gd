class_name EncounterCoordinator
extends Node

signal encounter_finished(outcome: EncounterOutcome)

var _repository: MonsterRepository
var _manager: EncounterManager
var _rng: RandomNumberGenerator
var _overlay: EncounterOverlay
var _current_screen: DungeonScreen
var _last_outcome: EncounterOutcome


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
	_manager.set_table(table)


func attach_screen(screen: DungeonScreen) -> void:
	detach_screen()
	_current_screen = screen
	_current_screen.step_taken.connect(_on_step_taken)


func detach_screen() -> void:
	if _current_screen == null:
		return
	if _current_screen.step_taken.is_connected(_on_step_taken):
		_current_screen.step_taken.disconnect(_on_step_taken)
	_current_screen = null


func get_overlay() -> EncounterOverlay:
	return _overlay


func is_encounter_active() -> bool:
	return _overlay != null and _overlay.is_active()


func _on_step_taken(_position: Vector2i) -> void:
	if _current_screen == null:
		return
	if not _manager.should_trigger(_rng):
		return
	var party := _manager.generate(_rng)
	if party.is_empty():
		return
	_current_screen.set_encounter_active(true)
	_overlay.start_encounter(party)


func _on_encounter_resolved(outcome: EncounterOutcome) -> void:
	_last_outcome = outcome
	_manager.notify_encounter_occurred()
	if _current_screen != null:
		_current_screen.set_encounter_active(false)
		_current_screen.check_start_tile_return()
	encounter_finished.emit(outcome)


func last_outcome() -> EncounterOutcome:
	return _last_outcome
