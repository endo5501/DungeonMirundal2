class_name DungeonCreateDialog
extends Control

signal confirmed(dungeon_name: String, size_category: int)
signal cancelled

const SIZE_LABELS: Array[String] = ["小", "中", "大"]
const FONT_SIZE := 18

var size_category: int = DungeonRegistry.SIZE_MEDIUM
var dungeon_name: String

var _name_generator: DungeonNameGenerator
var _name_edit: LineEdit
var _size_label: Label
var _focus_index: int = 0  # 0=size, 1=name, 2=confirm, 3=cancel

func _init() -> void:
	_name_generator = DungeonNameGenerator.new()
	dungeon_name = _name_generator.generate()

func _ready() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(PRESET_CENTER)
	panel.custom_minimum_size = Vector2(400, 250)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "ダンジョン新規生成"
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Size selection
	var size_hbox := HBoxContainer.new()
	size_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(size_hbox)

	var size_prefix := Label.new()
	size_prefix.text = "サイズ: "
	size_prefix.add_theme_font_size_override("font_size", FONT_SIZE)
	size_hbox.add_child(size_prefix)

	_size_label = Label.new()
	_size_label.add_theme_font_size_override("font_size", FONT_SIZE)
	size_hbox.add_child(_size_label)

	# Name edit
	var name_hbox := HBoxContainer.new()
	name_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(name_hbox)

	var name_prefix := Label.new()
	name_prefix.text = "名前: "
	name_prefix.add_theme_font_size_override("font_size", FONT_SIZE)
	name_hbox.add_child(name_prefix)

	_name_edit = LineEdit.new()
	_name_edit.text = dungeon_name
	_name_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	_name_edit.text_changed.connect(func(t): dungeon_name = t)
	name_hbox.add_child(_name_edit)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	vbox.add_child(spacer)

	# Buttons
	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 16)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_hbox)

	var confirm_btn := Button.new()
	confirm_btn.text = "生成"
	confirm_btn.pressed.connect(do_confirm)
	btn_hbox.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "やめる"
	cancel_btn.pressed.connect(do_cancel)
	btn_hbox.add_child(cancel_btn)

	_update_size_label()
	_name_edit.grab_focus()

func _update_size_label() -> void:
	if _size_label:
		_size_label.text = "< %s >" % get_size_label()

func _unhandled_input(event: InputEvent) -> void:
	var name_focused := _name_edit and _name_edit.has_focus()
	if not name_focused and event.is_action_pressed("ui_left"):
		cycle_size(-1)
		_update_size_label()
		get_viewport().set_input_as_handled()
	elif not name_focused and event.is_action_pressed("ui_right"):
		cycle_size(1)
		_update_size_label()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		do_cancel()
		get_viewport().set_input_as_handled()

func get_size_label() -> String:
	return SIZE_LABELS[size_category]

func cycle_size(direction: int) -> void:
	size_category = (size_category + direction) % SIZE_LABELS.size()
	if size_category < 0:
		size_category += SIZE_LABELS.size()

func do_confirm() -> void:
	if _name_edit:
		dungeon_name = _name_edit.text
	confirmed.emit(dungeon_name, size_category)

func do_cancel() -> void:
	cancelled.emit()
