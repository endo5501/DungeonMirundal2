class_name EncounterOverlay
extends CanvasLayer

signal encounter_resolved(outcome: EncounterOutcome)

var _overlay: ColorRect
var _panel: PanelContainer
var _message_label: Label
var _hint_label: Label
var _display_text: String = ""
var _is_active: bool = false


func _init() -> void:
	layer = 10


func _ready() -> void:
	_build_ui()
	visible = false


func _build_ui() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.6)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(360, 160)
	center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(vbox)

	var title := Label.new()
	title.text = "エンカウント！"
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_message_label = Label.new()
	_message_label.add_theme_font_size_override("font_size", 18)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_message_label)

	_hint_label = Label.new()
	_hint_label.text = "[Enter] 進む"
	_hint_label.add_theme_font_size_override("font_size", 14)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_hint_label)


func start_encounter(party: MonsterParty) -> void:
	_display_text = _format_party(party)
	if _message_label != null:
		_message_label.text = _display_text
	visible = true
	_is_active = true


func resolve() -> void:
	if not _is_active:
		return
	_is_active = false
	visible = false
	encounter_resolved.emit(EncounterOutcome.new(EncounterOutcome.Result.CLEARED))


func get_display_text() -> String:
	return _display_text


func is_active() -> bool:
	return _is_active


func _unhandled_input(event: InputEvent) -> void:
	if not _is_active:
		return
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			resolve()
			get_viewport().set_input_as_handled()


func _format_party(party: MonsterParty) -> String:
	if party == null or party.is_empty():
		return ""
	var entries: Dictionary = {}  # id -> {"name": String, "count": int}
	var ordered_ids: Array[StringName] = []
	for member in party.members:
		var id := member.data.monster_id
		if not entries.has(id):
			entries[id] = {"name": member.data.monster_name, "count": 0}
			ordered_ids.append(id)
		entries[id]["count"] += 1
	var lines: Array[String] = []
	for id in ordered_ids:
		lines.append("%s x%d" % [entries[id]["name"], entries[id]["count"]])
	return "\n".join(lines)
