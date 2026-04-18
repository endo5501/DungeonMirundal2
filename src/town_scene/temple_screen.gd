class_name TempleScreen
extends Control

signal back_requested

const FONT_SIZE: int = 18
const REVIVE_COST_PER_LEVEL: int = 100

var _inventory: Inventory
var _guild: Guild
var _selected_index: int = 0
var _last_message: String = ""

var _root: VBoxContainer


func setup(inventory: Inventory, guild: Guild) -> void:
	_inventory = inventory
	_guild = guild


func _ready() -> void:
	_root = VBoxContainer.new()
	_root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_root.add_theme_constant_override("separation", 4)
	add_child(_root)
	_rebuild()


# ---- introspection API ----

func get_last_message() -> String:
	return _last_message


func get_party_members() -> Array:
	if _guild == null:
		return []
	return _guild.get_all_characters()


func revive_cost(character: Character) -> int:
	if character == null:
		return 0
	return character.level * REVIVE_COST_PER_LEVEL


func is_dead(character: Character) -> bool:
	return character != null and character.is_dead()


# ---- revive ----

func revive(character: Character) -> bool:
	_last_message = ""
	if character == null or _inventory == null:
		return false
	if not character.is_dead():
		_last_message = "蘇生対象がいません"
		return false
	var cost := revive_cost(character)
	if _inventory.gold < cost:
		_last_message = "ゴールドが足りません"
		return false
	if not _inventory.spend_gold(cost):
		_last_message = "ゴールドが足りません"
		return false
	character.current_hp = 1
	_last_message = "%s を蘇生しました" % character.character_name
	return true


# ---- rendering ----

func _rebuild() -> void:
	for child in _root.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "教会"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(title)

	var gold := Label.new()
	gold.text = "所持ゴールド: %d" % (_inventory.gold if _inventory != null else 0)
	gold.add_theme_font_size_override("font_size", FONT_SIZE)
	_root.add_child(gold)

	var members := get_party_members()
	if members.is_empty():
		var empty := Label.new()
		empty.text = "  (パーティにメンバーがいません)"
		_root.add_child(empty)
	else:
		for i in range(members.size()):
			var ch: Character = members[i]
			var status := "(死亡)" if is_dead(ch) else "(生存)"
			var row := CursorMenuRow.create(_root,
				"%s Lv%d  %s  蘇生費: %d G" % [ch.character_name, ch.level, status, revive_cost(ch)],
				FONT_SIZE)
			row.set_selected(i == _selected_index)
			row.set_disabled(not is_dead(ch))

	if _last_message != "":
		var msg := Label.new()
		msg.text = _last_message
		msg.add_theme_font_size_override("font_size", 14)
		msg.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4))
		_root.add_child(msg)

	var hint := Label.new()
	hint.text = "[↑↓] 選択  [Enter] 蘇生  [Esc] 戻る"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_root.add_child(hint)


# ---- input ----

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var members := get_party_members()
	if event.is_action_pressed("ui_down") and members.size() > 0:
		_selected_index = (_selected_index + 1) % members.size()
		_rebuild()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up") and members.size() > 0:
		_selected_index = (_selected_index - 1 + members.size()) % members.size()
		_rebuild()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") and members.size() > 0:
		revive(members[_selected_index])
		_rebuild()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		back_requested.emit()
		get_viewport().set_input_as_handled()
