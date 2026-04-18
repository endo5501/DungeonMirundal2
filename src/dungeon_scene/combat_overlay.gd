class_name CombatOverlay
extends EncounterOverlay

enum Phase {
	IDLE,
	COMMAND_MENU,
	TARGET_SELECT,
	RESOLVING,
	RESULT,
}

const _OPT_ATTACK: int = 0
const _OPT_DEFEND: int = 1
const _OPT_ESCAPE: int = 2

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
# Cached separately from TurnEngine._outcome because unit tests call
# show_result() with a hand-built EncounterOutcome that never passed through
# a TurnEngine. Revisit if items-and-economy drops that test surface.
var _last_outcome: EncounterOutcome
var log_line_delay: float = 0.0


func _ready() -> void:
	_build_combat_ui()
	visible = false


func setup_dependencies(guild: Guild, provider: EquipmentProvider, rng: RandomNumberGenerator) -> void:
	_guild = guild
	_equipment_provider = provider
	_rng = rng


func start_encounter(monster_party: MonsterParty) -> void:
	_monster_party = monster_party
	_initial_monster_counts = monster_party.counts_by_species() if monster_party != null else {}
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
		_OPT_ATTACK:
			_current_phase = Phase.TARGET_SELECT
			_command_menu.hide_menu()
			_target_selector.show_with(_turn_engine.monsters)
		_OPT_DEFEND:
			_turn_engine.submit_command(_current_actor_index, DefendCommand.new())
			_advance_to_next_actor()
		_OPT_ESCAPE:
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
	_play_log_sequentially(report)


func _play_log_sequentially(report: TurnReport) -> void:
	if _combat_log != null and report != null:
		for action in report.actions:
			_combat_log.append_from_report_action(action)
			if log_line_delay > 0.0:
				await get_tree().create_timer(log_line_delay).timeout
	_on_log_playback_finished()


func _on_log_playback_finished() -> void:
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
		outcome.gained_gold = _compute_gold_drop(dead_monsters)
		for i in range(participant_characters.size()):
			var ch: Character = participant_characters[i]
			if ch.level > int(levels_before[i]):
				level_ups.append({"name": ch.character_name, "new_level": ch.level})
		party_state_changed.emit()
	show_result(outcome, level_ups)


func _compute_gold_drop(dead_monsters: Array) -> int:
	if _rng == null:
		return 0
	var total: int = 0
	for m in dead_monsters:
		if m is Monster and m.data != null:
			total += _rng.randi_range(m.data.gold_min, m.data.gold_max)
	return total


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
			target_select(_target_selector.get_selected_index())
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


func _build_combat_ui() -> void:
	_monster_panel = CombatMonsterPanel.new()
	_place(_monster_panel, 0.05, 0.02, 0.55, 0.28)
	add_child(_monster_panel)

	_combat_log = CombatLog.new()
	# CombatLog sits below the dungeon minimap (top-right). Use absolute
	# top offset so it clears the minimap at any viewport height.
	_combat_log.anchor_left = 0.60
	_combat_log.anchor_top = 0.0
	_combat_log.anchor_right = 0.98
	_combat_log.anchor_bottom = 0.60
	_combat_log.offset_left = 0
	_combat_log.offset_top = 160  # minimap 140 + margin 16 + small gap
	_combat_log.offset_right = 0
	_combat_log.offset_bottom = 0
	add_child(_combat_log)

	_command_menu = CombatCommandMenu.new()
	_place(_command_menu, 0.15, 0.32, 0.55, 0.62)
	_command_menu.visible = false
	add_child(_command_menu)

	_target_selector = CombatTargetSelector.new()
	_place(_target_selector, 0.15, 0.32, 0.55, 0.62)
	_target_selector.visible = false
	add_child(_target_selector)

	_result_panel = CombatResultPanel.new()
	_place(_result_panel, 0.20, 0.25, 0.80, 0.60)
	_result_panel.visible = false
	_result_panel.confirmed.connect(_on_result_confirmed)
	add_child(_result_panel)


func _place(ctrl: Control, left: float, top: float, right: float, bottom: float) -> void:
	ctrl.anchor_left = left
	ctrl.anchor_top = top
	ctrl.anchor_right = right
	ctrl.anchor_bottom = bottom
	ctrl.offset_left = 0
	ctrl.offset_top = 0
	ctrl.offset_right = 0
	ctrl.offset_bottom = 0


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
