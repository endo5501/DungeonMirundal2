class_name EncounterCoordinator
extends Node

signal encounter_finished(outcome: EncounterOutcome)
signal dungeon_status_tick(character_name: String, status_id: StringName, amount: int)

var _repository: MonsterRepository
var _manager: EncounterManager
var _rng: RandomNumberGenerator
var _overlay: EncounterOverlay
var _current_screen: DungeonScreen
var _last_outcome: EncounterOutcome
var _tables_by_floor: Dictionary = {}
var _active_table: EncounterTableData
var _status_repo: StatusRepository = null
var _guild: Guild = null

# Status ticks fire once every Nth dungeon step so poison etc. drains slowly
# enough to feel like exploration pressure, not chip-damage spam.
const STATUS_TICK_STEP_INTERVAL := 5
var _steps_since_status_tick: int = 0


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
	# Pick the deepest registered floor <= requested; if none qualifies (all
	# registered floors are deeper than requested), fall back to the shallowest.
	var keys: Array = []
	for key in _tables_by_floor.keys():
		keys.append(int(key))
	var below: Array = keys.filter(func(k: int) -> bool: return k <= floor)
	var fallback_floor: int = below.max() if not below.is_empty() else keys.min()
	push_warning("No encounter table for floor %d, using floor %d" % [floor, fallback_floor])
	return _tables_by_floor[fallback_floor]


func get_active_table() -> EncounterTableData:
	return _active_table


func attach_screen(screen: DungeonScreen) -> void:
	detach_screen()
	_current_screen = screen
	_current_screen.step_taken.connect(_on_step_taken)
	_current_screen.floor_changed.connect(_on_floor_changed)
	if not dungeon_status_tick.is_connected(_current_screen.show_status_tick):
		dungeon_status_tick.connect(_current_screen.show_status_tick)


func detach_screen() -> void:
	if _current_screen == null:
		return
	if _current_screen.step_taken.is_connected(_on_step_taken):
		_current_screen.step_taken.disconnect(_on_step_taken)
	if _current_screen.floor_changed.is_connected(_on_floor_changed):
		_current_screen.floor_changed.disconnect(_on_floor_changed)
	if dungeon_status_tick.is_connected(_current_screen.show_status_tick):
		dungeon_status_tick.disconnect(_current_screen.show_status_tick)
	_current_screen = null


func get_overlay() -> EncounterOverlay:
	return _overlay


func is_encounter_active() -> bool:
	return _overlay != null and _overlay.is_active()


func set_status_repo(repo: StatusRepository) -> void:
	_status_repo = repo


func set_guild(guild: Guild) -> void:
	_guild = guild


func _on_step_taken(_position: Vector2i) -> void:
	if _current_screen == null:
		return
	_steps_since_status_tick += 1
	if _steps_since_status_tick >= STATUS_TICK_STEP_INTERVAL:
		_steps_since_status_tick = 0
		_tick_party_step()
	if _active_table == null:
		return
	if not _manager.should_trigger(_rng):
		return
	var party := _manager.generate(_rng)
	if party.is_empty():
		return
	_current_screen.set_encounter_active(true)
	_overlay.start_encounter(party)


func _tick_party_step() -> void:
	if _guild == null:
		return
	var repo: StatusRepository = _status_repo
	if repo == null:
		repo = DataLoader.new().load_status_repository()
	if repo == null:
		return
	for ch in _guild.get_all_characters():
		if ch == null or ch.is_dead():
			continue
		var result := StatusTickService.tick_character_step(ch, repo)
		var ticks: Array = result.get("ticks", [])
		for tick in ticks:
			var amount: int = int((tick as Dictionary).get("amount", 0))
			if amount <= 0:
				continue
			dungeon_status_tick.emit(
				String(ch.character_name),
				StringName((tick as Dictionary).get("status_id", &"")),
				amount,
			)


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
