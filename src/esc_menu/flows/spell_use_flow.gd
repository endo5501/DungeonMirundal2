class_name SpellUseFlow
extends Control

signal flow_completed(message: String)

enum SubView { SELECT_CASTER, SELECT_SCHOOL, SELECT_SPELL, SELECT_TARGET, RESULT }

const SCHOOLS: Array[StringName] = [SpellData.SCHOOL_MAGE, SpellData.SCHOOL_PRIEST]
const SCHOOL_LABELS: Array[String] = ["魔術", "祈り"]

var _sub_view: int = SubView.SELECT_CASTER
var _party: Array[Character] = []
var _caster: Character = null
var _school: StringName = &""
var _spell: SpellData = null
var _target: Character = null
var _result_message: String = ""

var _caster_index: int = 0
var _school_index: int = 0
var _spell_index: int = 0
var _target_index: int = 0

# Cached entry lists for the current sub-view; populated on _switch_sub_view
# entry so cursor moves can update selection state without re-querying the
# SpellRepository or rebuilding rows.
var _caster_cache: Array[Character] = []
var _spell_cache: Array = []
var _target_cache: Array[Character] = []

var _select_caster_container: VBoxContainer
var _select_school_container: VBoxContainer
var _select_spell_container: VBoxContainer
var _select_target_container: VBoxContainer
var _result_container: VBoxContainer

var _caster_rows: Array[CursorMenuRow] = []
var _school_rows: Array[CursorMenuRow] = []
var _spell_rows: Array[CursorMenuRow] = []
var _target_rows: Array[CursorMenuRow] = []

var _spell_repo: SpellRepository = null
var _rng: RandomNumberGenerator = null


func _refresh_row_selection(rows: Array[CursorMenuRow]) -> void:
	var idx := _index_for_current_view()
	for i in range(rows.size()):
		rows[i].set_selected(i == idx)


func _index_for_current_view() -> int:
	match _sub_view:
		SubView.SELECT_CASTER:
			return _caster_index
		SubView.SELECT_SCHOOL:
			return _school_index
		SubView.SELECT_SPELL:
			return _spell_index
		SubView.SELECT_TARGET:
			return _target_index
	return 0


func _ready() -> void:
	_ensure_ui_built()
	_apply_visibility()


func setup(p_party: Array[Character]) -> void:
	_party = p_party
	_caster = null
	_school = &""
	_spell = null
	_target = null
	_caster_index = 0
	_school_index = 0
	_spell_index = 0
	_target_index = 0
	_result_message = ""
	_ensure_ui_built()
	# Default to first magic-capable caster.
	var casters := _list_casters()
	if not casters.is_empty():
		_caster_index = 0
	_switch_sub_view(SubView.SELECT_CASTER)


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_up"):
		_move_cursor(-1)
		return true
	if event.is_action_pressed("ui_down"):
		_move_cursor(1)
		return true
	if event.is_action_pressed("ui_accept"):
		_handle_accept()
		return true
	if event.is_action_pressed("ui_cancel"):
		_handle_cancel()
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if handle_input(event):
		get_viewport().set_input_as_handled()


# --- UI construction ---

func _ensure_ui_built() -> void:
	if _select_caster_container != null:
		return
	_build_ui()


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	_select_caster_container = TitledView.build("詠唱者を選択", 4)
	root.add_child(_select_caster_container)
	_select_school_container = TitledView.build("系統を選択", 4)
	root.add_child(_select_school_container)
	_select_spell_container = TitledView.build("呪文を選択", 4)
	root.add_child(_select_spell_container)
	_select_target_container = TitledView.build("対象を選択", 4)
	root.add_child(_select_target_container)
	_result_container = TitledView.build("結果", 6)
	root.add_child(_result_container)


# --- sub-view dispatch ---

func _switch_sub_view(view: int) -> void:
	_sub_view = view
	match view:
		SubView.SELECT_CASTER:
			_caster_cache = _list_casters()
			if _caster_index >= _caster_cache.size():
				_caster_index = 0
			_refresh_caster_view()
		SubView.SELECT_SCHOOL:
			_school_index = 0
			_refresh_school_view()
		SubView.SELECT_SPELL:
			_spell_cache = _list_spells()
			_spell_index = _first_usable_spell_index()
			_refresh_spell_view()
		SubView.SELECT_TARGET:
			_target_cache = _list_targets()
			_target_index = 0
			_refresh_target_view()
		SubView.RESULT:
			_refresh_result_view()
	_apply_visibility()


func _apply_visibility() -> void:
	if _select_caster_container == null:
		return
	_select_caster_container.visible = (_sub_view == SubView.SELECT_CASTER)
	_select_school_container.visible = (_sub_view == SubView.SELECT_SCHOOL)
	_select_spell_container.visible = (_sub_view == SubView.SELECT_SPELL)
	_select_target_container.visible = (_sub_view == SubView.SELECT_TARGET)
	_result_container.visible = (_sub_view == SubView.RESULT)


# --- input dispatch ---

func _move_cursor(direction: int) -> void:
	match _sub_view:
		SubView.SELECT_CASTER:
			var n := _caster_cache.size()
			if n == 0:
				return
			_caster_index = (_caster_index + direction + n) % n
			_refresh_row_selection(_caster_rows)
		SubView.SELECT_SCHOOL:
			_school_index = (_school_index + direction + SCHOOLS.size()) % SCHOOLS.size()
			_refresh_row_selection(_school_rows)
		SubView.SELECT_SPELL:
			var n := _spell_cache.size()
			if n == 0:
				return
			_spell_index = (_spell_index + direction + n) % n
			_refresh_row_selection(_spell_rows)
		SubView.SELECT_TARGET:
			var n := _target_cache.size()
			if n == 0:
				return
			_target_index = (_target_index + direction + n) % n
			_refresh_row_selection(_target_rows)


func _handle_accept() -> void:
	match _sub_view:
		SubView.SELECT_CASTER:
			_on_caster_accept()
		SubView.SELECT_SCHOOL:
			_on_school_accept()
		SubView.SELECT_SPELL:
			_on_spell_accept()
		SubView.SELECT_TARGET:
			_on_target_accept()
		SubView.RESULT:
			flow_completed.emit(_result_message)


func _handle_cancel() -> void:
	match _sub_view:
		SubView.SELECT_CASTER:
			flow_completed.emit("")
		SubView.SELECT_SCHOOL:
			_caster = null
			_switch_sub_view(SubView.SELECT_CASTER)
		SubView.SELECT_SPELL:
			# Bishop returns to school selection; others return to caster selection.
			if _is_bishop_caster():
				_switch_sub_view(SubView.SELECT_SCHOOL)
			else:
				_caster = null
				_switch_sub_view(SubView.SELECT_CASTER)
		SubView.SELECT_TARGET:
			_target = null
			_switch_sub_view(SubView.SELECT_SPELL)
		SubView.RESULT:
			flow_completed.emit(_result_message)


# --- accept handlers ---

func _on_caster_accept() -> void:
	if _caster_index < 0 or _caster_index >= _caster_cache.size():
		return
	_caster = _caster_cache[_caster_index]
	if _is_bishop_caster():
		_switch_sub_view(SubView.SELECT_SCHOOL)
	else:
		_school = _sole_school_of(_caster)
		_switch_sub_view(SubView.SELECT_SPELL)


func _on_school_accept() -> void:
	_school = SCHOOLS[_school_index]
	_switch_sub_view(SubView.SELECT_SPELL)


func _on_spell_accept() -> void:
	if _spell_index < 0 or _spell_index >= _spell_cache.size():
		return
	var entry: Dictionary = _spell_cache[_spell_index]
	if not entry.get("usable", false):
		return
	_spell = entry.get("spell")
	if _spell.target_type == SpellData.TargetType.ALLY_ALL:
		_apply_cast_and_show_result()
		return
	_switch_sub_view(SubView.SELECT_TARGET)


func _on_target_accept() -> void:
	if _target_cache.is_empty() or _target_index >= _target_cache.size():
		return
	_target = _target_cache[_target_index]
	_apply_cast_and_show_result()


func _apply_cast_and_show_result() -> void:
	if _caster == null or _spell == null:
		_result_message = "詠唱に失敗した"
		_switch_sub_view(SubView.RESULT)
		return
	if _caster.current_mp < _spell.mp_cost:
		_result_message = "%s は MP が足りない" % _caster.character_name
		_switch_sub_view(SubView.RESULT)
		return
	_caster.current_mp = maxi(_caster.current_mp - _spell.mp_cost, 0)
	# Wrap Characters in PartyCombatants so SpellEffect.apply can read/write
	# current_hp / current_mp / max_hp uniformly.
	var provider := DummyEquipmentProvider.new()
	var caster_pc := PartyCombatant.new(_caster, provider)
	var targets: Array = []
	if _spell.target_type == SpellData.TargetType.ALLY_ALL:
		for ch in _party:
			if ch != null and not ch.is_dead():
				targets.append(PartyCombatant.new(ch, provider))
	else:
		if _target == null or _target.is_dead():
			_result_message = "対象がいない"
			_switch_sub_view(SubView.RESULT)
			return
		targets.append(PartyCombatant.new(_target, provider))
	var resolution: SpellResolution = _spell.effect.apply(caster_pc, targets, _get_rng()) if _spell.effect != null else SpellResolution.new()
	_result_message = _build_result_message(resolution)
	_switch_sub_view(SubView.RESULT)


func _build_result_message(resolution: SpellResolution) -> String:
	if resolution == null or resolution.entries.is_empty():
		return "%s は %s を唱えたが効果がなかった" % [_caster.character_name, _spell.display_name]
	var parts: Array[String] = ["%s は %s を唱えた" % [_caster.character_name, _spell.display_name]]
	parts.append_array(SpellResolution.format_entries(resolution.entries))
	return "\n".join(parts)


# --- helpers ---

func _list_casters() -> Array[Character]:
	var result: Array[Character] = []
	for ch in _party:
		if ch == null:
			continue
		if ch.job == null or not ch.job.is_magic_capable():
			continue
		if ch.is_dead():
			continue
		result.append(ch)
	return result


func _list_targets() -> Array[Character]:
	# Both ALLY_ONE and ALLY_ALL list every living party member; the spell type
	# determines whether SELECT_TARGET is visited at all.
	var result: Array[Character] = []
	if _spell == null:
		return result
	for ch in _party:
		if ch != null and not ch.is_dead():
			result.append(ch)
	return result


# Returns the list of {spell, usable} entries for the current caster + school.
func _list_spells() -> Array:
	var result: Array = []
	if _caster == null:
		return result
	var repo := _get_spell_repo()
	if repo == null:
		return result
	for sid in _caster.known_spells:
		var spell: SpellData = repo.find(sid)
		if spell == null:
			continue
		if spell.scope != SpellData.Scope.OUTSIDE_OK:
			continue
		if _school != &"" and spell.school != _school:
			continue
		result.append({
			"spell": spell,
			"usable": _caster.current_mp >= spell.mp_cost,
		})
	return result


func _first_usable_spell_index() -> int:
	for i in range(_spell_cache.size()):
		if _spell_cache[i].get("usable", false):
			return i
	return 0


func _is_bishop_caster() -> bool:
	if _caster == null or _caster.job == null:
		return false
	return _caster.job.mage_school and _caster.job.priest_school


func _sole_school_of(ch: Character) -> StringName:
	if ch == null or ch.job == null:
		return &""
	if ch.job.mage_school:
		return SpellData.SCHOOL_MAGE
	if ch.job.priest_school:
		return SpellData.SCHOOL_PRIEST
	return &""


func _get_spell_repo() -> SpellRepository:
	if _spell_repo == null:
		var loader := DataLoader.new()
		_spell_repo = loader.load_spell_repository()
	return _spell_repo


func _get_rng() -> RandomNumberGenerator:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	return _rng


# --- refresh views (called once per view entry; cursor moves use _refresh_row_selection) ---

func _refresh_caster_view() -> void:
	TitledView.clear_extras(_select_caster_container)
	_caster_rows.clear()
	if _caster_cache.is_empty():
		var empty := Label.new()
		empty.text = "  (詠唱可能なキャラがいません)"
		empty.add_theme_font_size_override("font_size", 14)
		_select_caster_container.add_child(empty)
		return
	for ch in _caster_cache:
		var label := "  %s  Lv.%d  HP:%d/%d  MP:%d/%d" % [
			ch.character_name, ch.level, ch.current_hp, ch.max_hp, ch.current_mp, ch.max_mp
		]
		_caster_rows.append(CursorMenuRow.create(_select_caster_container, label, 14))
	_refresh_row_selection(_caster_rows)


func _refresh_school_view() -> void:
	TitledView.clear_extras(_select_school_container)
	_school_rows.clear()
	for label_text in SCHOOL_LABELS:
		_school_rows.append(CursorMenuRow.create(_select_school_container, label_text, 16))
	_refresh_row_selection(_school_rows)


func _refresh_spell_view() -> void:
	TitledView.clear_extras(_select_spell_container)
	_spell_rows.clear()
	if _spell_cache.is_empty():
		var empty := Label.new()
		empty.text = "  (詠唱できる呪文がありません)"
		empty.add_theme_font_size_override("font_size", 14)
		_select_spell_container.add_child(empty)
		return
	for entry in _spell_cache:
		var spell: SpellData = entry.get("spell")
		var usable: bool = entry.get("usable", false)
		var text := "  %s  (MP %d)" % [spell.display_name, spell.mp_cost]
		if not usable:
			text += "  (MP不足)"
		var row := CursorMenuRow.create(_select_spell_container, text, 14)
		if not usable:
			row.set_disabled(true)
		_spell_rows.append(row)
	_refresh_row_selection(_spell_rows)


func _refresh_target_view() -> void:
	TitledView.clear_extras(_select_target_container)
	_target_rows.clear()
	if _target_cache.is_empty():
		var empty := Label.new()
		empty.text = "  (対象がいません)"
		empty.add_theme_font_size_override("font_size", 14)
		_select_target_container.add_child(empty)
		return
	for ch in _target_cache:
		var line := "  %s  HP:%d/%d MP:%d/%d" % [ch.character_name, ch.current_hp, ch.max_hp, ch.current_mp, ch.max_mp]
		_target_rows.append(CursorMenuRow.create(_select_target_container, line, 14))
	_refresh_row_selection(_target_rows)


func _refresh_result_view() -> void:
	TitledView.clear_extras(_result_container)
	var label := Label.new()
	label.text = _result_message
	label.add_theme_font_size_override("font_size", 14)
	_result_container.add_child(label)


# Test seam: pre-set the RNG to make damage/heal deterministic.
func set_rng(rng: RandomNumberGenerator) -> void:
	_rng = rng


# Test seam: query state.
func get_sub_view() -> int:
	return _sub_view


func get_caster() -> Character:
	return _caster


func get_spell() -> SpellData:
	return _spell


func get_result_message() -> String:
	return _result_message
