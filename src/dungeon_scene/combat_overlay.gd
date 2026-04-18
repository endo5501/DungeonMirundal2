class_name CombatOverlay
extends EncounterOverlay

enum Phase {
	IDLE,
	COMMAND_MENU,
	TARGET_SELECT,
	RESOLVING,
	RESULT,
}

signal party_state_changed

var _guild: Guild
var _equipment_provider: EquipmentProvider
var _rng: RandomNumberGenerator
var _turn_engine: TurnEngine
var _monster_party: MonsterParty
var _initial_monster_counts: Dictionary = {}
var _current_phase: Phase = Phase.IDLE
var _current_actor_index: int = 0

var _monster_panel: CombatMonsterPanel
var _command_menu: CombatCommandMenu
var _target_selector: CombatTargetSelector
var _combat_log: CombatLog
var _result_panel: CombatResultPanel
var _root_container: VBoxContainer
var _last_outcome: EncounterOutcome


func _ready() -> void:
	_build_combat_ui()
	visible = false


func setup_dependencies(guild: Guild, provider: EquipmentProvider, rng: RandomNumberGenerator) -> void:
	_guild = guild
	_equipment_provider = provider
	_rng = rng


func start_encounter(monster_party: MonsterParty) -> void:
	_monster_party = monster_party
	_capture_initial_monster_counts(monster_party)
	var party_combatants := _build_party_combatants()
	var monster_combatants := _build_monster_combatants(monster_party)
	_turn_engine = TurnEngine.new()
	_turn_engine.start_battle(party_combatants, monster_combatants)
	_is_active = true
	visible = true
	_last_outcome = null
	if _combat_log != null:
		_combat_log.clear_log()
	if _result_panel != null:
		_result_panel.visible = false
	_refresh_panels()
	_begin_command_phase()


func get_turn_engine() -> TurnEngine:
	return _turn_engine


func get_monster_party() -> MonsterParty:
	return _monster_party


func get_initial_monster_counts() -> Dictionary:
	return _initial_monster_counts.duplicate()


func get_current_phase() -> Phase:
	return _current_phase


func get_current_command_actor() -> CombatActor:
	if _turn_engine == null:
		return null
	if _current_actor_index < 0 or _current_actor_index >= _turn_engine.party.size():
		return null
	return _turn_engine.party[_current_actor_index]


func get_command_menu_options() -> Array[String]:
	if _command_menu == null:
		return []
	return _command_menu.get_options()


func command_menu_select(option_index: int) -> void:
	if _current_phase != Phase.COMMAND_MENU:
		return
	_handle_command_choice(option_index)


func target_select(target_index: int) -> void:
	if _current_phase != Phase.TARGET_SELECT:
		return
	var targets: Array = _target_selector.get_targets()
	if target_index < 0 or target_index >= targets.size():
		return
	_handle_target_choice(targets[target_index])


# --- phases ---

func _begin_command_phase() -> void:
	_current_actor_index = 0
	_prompt_next_actor()


func _prompt_next_actor() -> void:
	if _turn_engine == null:
		return
	while (
		_current_actor_index < _turn_engine.party.size()
		and not _turn_engine.party[_current_actor_index].is_alive()
	):
		_current_actor_index += 1
	if _current_actor_index >= _turn_engine.party.size():
		_resolve_turn_now()
		return
	_current_phase = Phase.COMMAND_MENU
	_command_menu.show_for(_turn_engine.party[_current_actor_index])
	if _target_selector != null:
		_target_selector.hide_selector()


func _handle_command_choice(option_index: int) -> void:
	match option_index:
		0:
			# Attack → go to target select
			_current_phase = Phase.TARGET_SELECT
			_command_menu.hide_menu()
			_target_selector.show_with(_turn_engine.monsters)
		1:
			# Defend
			_turn_engine.submit_command(_current_actor_index, DefendCommand.new())
			_advance_to_next_actor()
		2:
			# Escape
			_turn_engine.submit_command(_current_actor_index, EscapeCommand.new())
			_advance_to_next_actor()


func _handle_target_choice(target: CombatActor) -> void:
	_turn_engine.submit_command(_current_actor_index, AttackCommand.new(target))
	_target_selector.hide_selector()
	_advance_to_next_actor()


func _advance_to_next_actor() -> void:
	_command_menu.hide_menu()
	_current_actor_index += 1
	_prompt_next_actor()


func _resolve_turn_now() -> void:
	_current_phase = Phase.RESOLVING
	_command_menu.hide_menu()
	if _target_selector != null:
		_target_selector.hide_selector()
	var report := _turn_engine.resolve_turn(_rng)
	_refresh_panels()
	if _combat_log != null:
		_combat_log.append_from_report(report)
	if _turn_engine.state == TurnEngine.State.FINISHED:
		_finalize_battle()
	else:
		_begin_command_phase()


func _finalize_battle() -> void:
	var outcome := _turn_engine.outcome()
	var level_ups: Array = []
	if outcome != null and outcome.result == EncounterOutcome.Result.CLEARED:
		var participant_characters := _collect_participant_characters()
		var dead_monsters := _collect_dead_monsters()
		var levels_before: Array = []
		for ch in participant_characters:
			levels_before.append(ch.level)
		var share := ExperienceCalculator.award(participant_characters, dead_monsters)
		outcome.gained_experience = share
		for i in range(participant_characters.size()):
			var ch: Character = participant_characters[i]
			if ch.level > int(levels_before[i]):
				level_ups.append({"name": ch.character_name, "new_level": ch.level})
		party_state_changed.emit()
	show_result(outcome, level_ups)


func _collect_participant_characters() -> Array:
	var result: Array = []
	for pc in _turn_engine.party:
		if pc is PartyCombatant and pc.character != null:
			result.append(pc.character)
	return result


func _collect_dead_monsters() -> Array:
	var result: Array = []
	for mc in _turn_engine.monsters:
		if mc is MonsterCombatant and not mc.is_alive() and mc.monster != null:
			result.append(mc.monster)
	return result


func show_result(outcome: EncounterOutcome, level_ups: Array) -> void:
	_last_outcome = outcome
	_current_phase = Phase.RESULT
	if _command_menu != null:
		_command_menu.hide_menu()
	if _target_selector != null:
		_target_selector.hide_selector()
	if _result_panel != null:
		_result_panel.show_result(outcome, level_ups)


func confirm_result() -> void:
	if _current_phase != Phase.RESULT:
		return
	_on_result_confirmed()


func _on_result_confirmed() -> void:
	if _last_outcome == null:
		_last_outcome = EncounterOutcome.new(EncounterOutcome.Result.CLEARED)
	_is_active = false
	visible = false
	if _result_panel != null:
		_result_panel.visible = false
	encounter_resolved.emit(_last_outcome)


func get_combat_log() -> CombatLog:
	return _combat_log


func get_combat_log_lines() -> Array[String]:
	if _combat_log == null:
		return []
	return _combat_log.get_lines()


func get_result_panel_text() -> String:
	if _result_panel == null:
		return ""
	return _result_panel.get_display_text()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_active:
		return
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	var handled := false
	match _current_phase:
		Phase.COMMAND_MENU:
			handled = _handle_command_menu_key(key)
		Phase.TARGET_SELECT:
			handled = _handle_target_select_key(key)
		Phase.RESULT:
			handled = _handle_result_key(key)
		_:
			handled = false
	if handled:
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()


func _handle_command_menu_key(key: InputEventKey) -> bool:
	match key.keycode:
		KEY_UP, KEY_W:
			_command_menu.move_up()
			return true
		KEY_DOWN, KEY_S:
			_command_menu.move_down()
			return true
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_command_menu.confirm_current()
			command_menu_select(_command_menu.get_selected_index())
			return true
	return false


func _handle_target_select_key(key: InputEventKey) -> bool:
	match key.keycode:
		KEY_UP, KEY_W:
			_target_selector.move_up()
			return true
		KEY_DOWN, KEY_S:
			_target_selector.move_down()
			return true
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			var targets: Array = _target_selector.get_targets()
			var idx: int = _target_selector._selected_index
			if idx >= 0 and idx < targets.size():
				_handle_target_choice(targets[idx])
			return true
	return false


func _handle_result_key(key: InputEventKey) -> bool:
	match key.keycode:
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			confirm_result()
			return true
	return false


# --- helpers ---

func _build_party_combatants() -> Array:
	var combatants: Array = []
	if _guild == null:
		return combatants
	var rows: Array = _guild.get_party_characters()
	for row in rows:
		for ch in row:
			if ch != null:
				combatants.append(PartyCombatant.new(ch, _equipment_provider))
	return combatants


func _build_monster_combatants(monster_party: MonsterParty) -> Array:
	var combatants: Array = []
	if monster_party == null:
		return combatants
	for m in monster_party.members:
		combatants.append(MonsterCombatant.new(m))
	return combatants


func _capture_initial_monster_counts(monster_party: MonsterParty) -> void:
	_initial_monster_counts.clear()
	if monster_party == null:
		return
	for m in monster_party.members:
		var id: StringName = m.data.monster_id
		_initial_monster_counts[id] = _initial_monster_counts.get(id, 0) + 1


func _build_combat_ui() -> void:
	_root_container = VBoxContainer.new()
	_root_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root_container.add_theme_constant_override("separation", 8)
	add_child(_root_container)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.7)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	move_child(backdrop, 0)

	_monster_panel = CombatMonsterPanel.new()
	_root_container.add_child(_monster_panel)

	_command_menu = CombatCommandMenu.new()
	_command_menu.visible = false
	_root_container.add_child(_command_menu)

	_target_selector = CombatTargetSelector.new()
	_target_selector.visible = false
	_root_container.add_child(_target_selector)

	_combat_log = CombatLog.new()
	_root_container.add_child(_combat_log)

	_result_panel = CombatResultPanel.new()
	_result_panel.visible = false
	_result_panel.confirmed.connect(_on_result_confirmed)
	_root_container.add_child(_result_panel)


func _refresh_panels() -> void:
	refresh_monster_panel()
	party_state_changed.emit()


func refresh_monster_panel() -> void:
	if _monster_panel != null:
		_monster_panel.refresh(_turn_engine.monsters if _turn_engine != null else [], _initial_monster_counts)


func get_monster_panel_text() -> String:
	if _monster_panel == null:
		return ""
	return _monster_panel.get_display_text()
