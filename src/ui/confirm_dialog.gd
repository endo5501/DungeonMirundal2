class_name ConfirmDialog
extends Control

signal confirmed
signal cancelled

const OPTIONS: Array[String] = ["はい", "いいえ"]
const DEFAULT_NO_INDEX := 1
const DEFAULT_YES_INDEX := 0

var _menu: CursorMenu
var _menu_rows: Array[CursorMenuRow] = []
var _container: CenterContainer
var _message_label: Label

func _init() -> void:
	_menu = CursorMenu.new(OPTIONS)
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

func _ready() -> void:
	_build_ui()
	visible = false
	set_process_unhandled_input(false)

func _build_ui() -> void:
	_container = CenterContainer.new()
	_container.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_container)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 120)
	_container.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	_message_label = Label.new()
	_message_label.add_theme_font_size_override("font_size", 20)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_message_label)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	vbox.add_child(spacer)

	_menu_rows.clear()
	for i in range(OPTIONS.size()):
		_menu_rows.append(CursorMenuRow.create(vbox, OPTIONS[i], 18))

func setup(message: String, default_index: int = DEFAULT_NO_INDEX) -> void:
	_message_label.text = message
	_menu.selected_index = default_index
	_menu.update_rows(_menu_rows)
	visible = true
	set_process_unhandled_input(true)

func get_message() -> String:
	return _message_label.text if _message_label != null else ""

func get_selected_index() -> int:
	return _menu.selected_index

# Public test helpers — let tests drive the dialog without poking _menu.
func confirm() -> void:
	_menu.selected_index = DEFAULT_YES_INDEX
	_on_accept()

func cancel() -> void:
	_on_cancel()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var consumed := MenuController.route(
		event, _menu, _menu_rows,
		_on_accept,
		_on_cancel,
	)
	if consumed:
		get_viewport().set_input_as_handled()

func _hide() -> void:
	visible = false
	set_process_unhandled_input(false)

func _on_accept() -> void:
	var was_yes := _menu.selected_index == DEFAULT_YES_INDEX
	_hide()
	if was_yes:
		confirmed.emit()
	else:
		cancelled.emit()

func _on_cancel() -> void:
	_hide()
	cancelled.emit()
