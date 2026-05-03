class_name CharacterCreation
extends Control

signal back_requested
signal character_created

const FONT_SIZE := 18
const TITLE_SIZE := 24

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
var _cached_character: Character

var _content: VBoxContainer
var _step_label: Label
var _cursor_index: int = 0
var _step_changed_frame: int = -1

var _steps: Array[CharacterCreationStep] = [
	NameInputStep.new(),
	RaceSelectionStep.new(),
	BonusAllocationStep.new(),
	JobSelectionStep.new(),
	ConfirmationStep.new(),
]


func setup(guild: Guild, races: Array[RaceData], jobs: Array[JobData]) -> void:
	_guild = guild
	_races = races
	_jobs = jobs
	_bonus_generator = BonusPointGenerator.new(randi())


func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	center.add_child(root)

	_step_label = Label.new()
	_step_label.add_theme_font_size_override("font_size", TITLE_SIZE)
	_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_step_label)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 12
	root.add_child(spacer)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 4)
	root.add_child(_content)

	_build_step_ui()


func _build_step_ui() -> void:
	_step_changed_frame = Engine.get_process_frames()
	while _content.get_child_count() > 0:
		var child := _content.get_child(0)
		_content.remove_child(child)
		child.queue_free()
	var step := _steps[current_step - 1]
	_step_label.text = step.get_title()
	step.build(_content, self)


func _unhandled_input(event: InputEvent) -> void:
	if _step_changed_frame == Engine.get_process_frames():
		return
	var step := _steps[current_step - 1]
	var transition: int = step.handle_input(event, self)
	if transition == CharacterCreationStep.StepTransition.STAY:
		return
	match transition:
		CharacterCreationStep.StepTransition.ADVANCE:
			if current_step == total_steps:
				confirm_creation()
			else:
				_transition(advance)
		CharacterCreationStep.StepTransition.BACK:
			_transition(go_back)
		CharacterCreationStep.StepTransition.CANCEL:
			cancel()
	get_viewport().set_input_as_handled()


func _transition(action: Callable) -> void:
	var before := current_step
	action.call()
	if current_step != before:
		_build_step_ui()


# --- Context API used by step classes ---

func get_name_input() -> String:
	return _name_input


func get_cursor_index() -> int:
	return _cursor_index


func set_cursor_index(value: int) -> void:
	_cursor_index = value


func get_available_jobs() -> Array[JobData]:
	return _jobs


func get_selected_race_index() -> int:
	return _selected_race_index


func get_selected_job_index() -> int:
	return _selected_job_index


var _name_edit: LineEdit:
	get:
		return (_steps[0] as NameInputStep).get_line_edit()


# --- Wizard API ---

func set_name_input(value: String) -> void:
	_name_input = value


# Sets the frame guard via _build_step_ui so the same Enter key cannot
# propagate as ui_accept into the next step.
func submit_name(value: String) -> void:
	_name_input = value
	_transition(advance)


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
	_cached_character = Character.create(_name_input, race, job, _allocation, _bonus_total)
	if _cached_character == null:
		return {}
	return {
		"name": _cached_character.character_name,
		"race": race,
		"job": job,
		"level": _cached_character.level,
		"hp": _cached_character.max_hp,
		"mp": _cached_character.max_mp,
		"stats": _cached_character.base_stats.duplicate(),
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
			var stats := _build_current_stats()
			if not _jobs[_selected_job_index].can_qualify(stats):
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
		4:
			_selected_job_index = -1
			current_step = 3
		_:
			current_step -= 1


func cancel() -> void:
	back_requested.emit()


func confirm_creation() -> void:
	if _cached_character == null:
		var race := _races[_selected_race_index]
		var job := _jobs[_selected_job_index]
		_cached_character = Character.create(_name_input, race, job, _allocation, _bonus_total)
	if _cached_character != null:
		_guild.register(_cached_character)
		if GameState.inventory != null and GameState.item_repository != null:
			InitialEquipment.grant(_cached_character, GameState.inventory, GameState.item_repository)
		character_created.emit()
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
