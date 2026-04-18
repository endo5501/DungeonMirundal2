class_name EscMenu
extends CanvasLayer

signal quit_to_title
signal save_requested
signal load_requested

enum View { MAIN_MENU, PARTY_MENU, STATUS, QUIT_DIALOG, ITEMS, EQUIPMENT, EQUIPMENT_CHARACTER, EQUIPMENT_SLOT, EQUIPMENT_CANDIDATE }

const MAIN_MENU_ITEMS: Array[String] = ["パーティ", "ゲームを保存", "ゲームをロード", "設定", "終了"]
const MAIN_MENU_DISABLED: Array[int] = [3]
const MAIN_IDX_PARTY := 0
const MAIN_IDX_SAVE := 1
const MAIN_IDX_LOAD := 2
const MAIN_IDX_QUIT := 4

const PARTY_MENU_ITEMS: Array[String] = ["ステータス", "アイテム", "装備"]
const PARTY_MENU_DISABLED: Array[int] = []
const PARTY_IDX_STATUS := 0
const PARTY_IDX_ITEMS := 1
const PARTY_IDX_EQUIPMENT := 2

const EQUIPMENT_SLOT_LABELS: Array[String] = ["武器", "鎧", "兜", "盾", "籠手", "装身具"]
const EQUIPMENT_SLOT_VALUES: Array[int] = [
	Equipment.EquipSlot.WEAPON,
	Equipment.EquipSlot.ARMOR,
	Equipment.EquipSlot.HELMET,
	Equipment.EquipSlot.SHIELD,
	Equipment.EquipSlot.GAUNTLET,
	Equipment.EquipSlot.ACCESSORY,
]

const QUIT_ITEMS: Array[String] = ["はい", "いいえ"]
const QUIT_IDX_YES := 0
const QUIT_IDX_NO := 1

var _current_view: View = View.MAIN_MENU

var _main_menu: CursorMenu
var _party_menu: CursorMenu
var _quit_menu: CursorMenu

var _overlay: ColorRect
var _panel: PanelContainer
var _main_menu_container: VBoxContainer
var _party_menu_container: VBoxContainer
var _status_container: VBoxContainer
var _quit_dialog_container: VBoxContainer
var _items_container: VBoxContainer
var _equipment_character_container: VBoxContainer
var _equipment_slot_container: VBoxContainer
var _equipment_candidate_container: VBoxContainer

var _main_menu_labels: Array[Label] = []
var _party_menu_labels: Array[Label] = []
var _quit_labels: Array[Label] = []

# Equipment navigation state
var _equipment_character_index: int = 0
var _equipment_slot_index: int = 0
var _equipment_candidate_index: int = 0

func _init() -> void:
	layer = 10
	_main_menu = CursorMenu.new(MAIN_MENU_ITEMS, MAIN_MENU_DISABLED)
	_party_menu = CursorMenu.new(PARTY_MENU_ITEMS, PARTY_MENU_DISABLED)
	_quit_menu = CursorMenu.new(QUIT_ITEMS)

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
	_overlay.add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(350, 200)
	center.add_child(_panel)

	var root_vbox := VBoxContainer.new()
	_panel.add_child(root_vbox)

	_main_menu_container = _build_titled_view("メニュー")
	_build_menu_labels(_main_menu, _main_menu_labels, _main_menu_container)
	root_vbox.add_child(_main_menu_container)

	_party_menu_container = _build_titled_view("パーティ")
	_build_menu_labels(_party_menu, _party_menu_labels, _party_menu_container)
	root_vbox.add_child(_party_menu_container)

	_status_container = _build_titled_view("ステータス", 4)
	root_vbox.add_child(_status_container)

	_items_container = _build_titled_view("アイテム", 4)
	root_vbox.add_child(_items_container)

	_equipment_character_container = _build_titled_view("装備 - キャラクター選択", 4)
	root_vbox.add_child(_equipment_character_container)

	_equipment_slot_container = _build_titled_view("装備 - スロット選択", 4)
	root_vbox.add_child(_equipment_slot_container)

	_equipment_candidate_container = _build_titled_view("装備 - 候補", 4)
	root_vbox.add_child(_equipment_candidate_container)

	_quit_dialog_container = _build_titled_view("タイトルに戻りますか？", 8)
	_build_menu_labels(_quit_menu, _quit_labels, _quit_dialog_container)
	root_vbox.add_child(_quit_dialog_container)

func _build_titled_view(title_text: String, separation: int = 6) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", separation)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	vbox.add_child(spacer)
	return vbox

func _build_menu_labels(menu: CursorMenu, labels_out: Array[Label], parent: VBoxContainer) -> void:
	for i in range(menu.size()):
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 20)
		parent.add_child(label)
		labels_out.append(label)
	menu.update_labels(labels_out)

func is_menu_visible() -> bool:
	return visible

func show_menu() -> void:
	visible = true
	_main_menu.selected_index = 0
	_switch_view(View.MAIN_MENU)

func hide_menu() -> void:
	visible = false

func get_current_view() -> View:
	return _current_view

func get_main_menu() -> CursorMenu:
	return _main_menu

func get_party_menu() -> CursorMenu:
	return _party_menu

func get_quit_menu() -> CursorMenu:
	return _quit_menu

func select_current_item() -> void:
	match _current_view:
		View.MAIN_MENU:
			_handle_main_menu_select()
		View.PARTY_MENU:
			_handle_party_menu_select()
		View.EQUIPMENT_CHARACTER:
			_switch_view(View.EQUIPMENT_SLOT)
		View.EQUIPMENT_SLOT:
			_switch_view(View.EQUIPMENT_CANDIDATE)
		View.EQUIPMENT_CANDIDATE:
			_confirm_equipment_candidate()
		View.QUIT_DIALOG:
			_handle_quit_dialog_select()

func go_back() -> void:
	match _current_view:
		View.MAIN_MENU:
			hide_menu()
		View.PARTY_MENU:
			_switch_view(View.MAIN_MENU)
		View.STATUS:
			_switch_view(View.PARTY_MENU)
		View.ITEMS:
			_switch_view(View.PARTY_MENU)
		View.EQUIPMENT_CHARACTER:
			_switch_view(View.PARTY_MENU)
		View.EQUIPMENT_SLOT:
			_switch_view(View.EQUIPMENT_CHARACTER)
		View.EQUIPMENT_CANDIDATE:
			_switch_view(View.EQUIPMENT_SLOT)
		View.QUIT_DIALOG:
			_switch_view(View.MAIN_MENU)

func handle_input(event: InputEventKey) -> void:
	var current_menu := _get_current_menu()
	match event.keycode:
		KEY_UP, KEY_W:
			if current_menu:
				current_menu.move_cursor(-1)
				_update_current_labels()
			else:
				_cursor_move_in_view(-1)
		KEY_DOWN, KEY_S:
			if current_menu:
				current_menu.move_cursor(1)
				_update_current_labels()
			else:
				_cursor_move_in_view(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			select_current_item()
		KEY_ESCAPE:
			go_back()


func _cursor_move_in_view(direction: int) -> void:
	match _current_view:
		View.EQUIPMENT_CHARACTER:
			var members := _get_guild_members()
			if members.size() == 0: return
			_equipment_character_index = (_equipment_character_index + direction + members.size()) % members.size()
			_refresh_equipment_character_view()
		View.EQUIPMENT_SLOT:
			_equipment_slot_index = (_equipment_slot_index + direction + EQUIPMENT_SLOT_VALUES.size()) % EQUIPMENT_SLOT_VALUES.size()
			_refresh_equipment_slot_view()
		View.EQUIPMENT_CANDIDATE:
			# Total rows = candidates + 1 [はずす] entry at index 0
			var rows := get_equipment_candidates().size() + 1
			_equipment_candidate_index = (_equipment_candidate_index + direction + rows) % rows
			_refresh_equipment_candidate_view()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	handle_input(event as InputEventKey)
	get_viewport().set_input_as_handled()

func _switch_view(view: View) -> void:
	_current_view = view
	_main_menu_container.visible = (view == View.MAIN_MENU)
	_party_menu_container.visible = (view == View.PARTY_MENU)
	_status_container.visible = (view == View.STATUS)
	_items_container.visible = (view == View.ITEMS)
	_equipment_character_container.visible = (view == View.EQUIPMENT_CHARACTER)
	_equipment_slot_container.visible = (view == View.EQUIPMENT_SLOT)
	_equipment_candidate_container.visible = (view == View.EQUIPMENT_CANDIDATE)
	_quit_dialog_container.visible = (view == View.QUIT_DIALOG)

	match view:
		View.PARTY_MENU:
			_party_menu.selected_index = 0
			_party_menu.update_labels(_party_menu_labels)
		View.QUIT_DIALOG:
			_quit_menu.selected_index = QUIT_IDX_NO
			_quit_menu.update_labels(_quit_labels)
		View.STATUS:
			_refresh_status_view()
		View.ITEMS:
			_refresh_items_view()
		View.EQUIPMENT_CHARACTER:
			_equipment_character_index = 0
			_refresh_equipment_character_view()
		View.EQUIPMENT_SLOT:
			_equipment_slot_index = 0
			_refresh_equipment_slot_view()
		View.EQUIPMENT_CANDIDATE:
			_equipment_candidate_index = 0
			_refresh_equipment_candidate_view()
		View.MAIN_MENU:
			_main_menu.update_labels(_main_menu_labels)

func _get_current_menu() -> CursorMenu:
	match _current_view:
		View.MAIN_MENU:
			return _main_menu
		View.PARTY_MENU:
			return _party_menu
		View.QUIT_DIALOG:
			return _quit_menu
	return null

func _update_current_labels() -> void:
	match _current_view:
		View.MAIN_MENU:
			_main_menu.update_labels(_main_menu_labels)
		View.PARTY_MENU:
			_party_menu.update_labels(_party_menu_labels)
		View.QUIT_DIALOG:
			_quit_menu.update_labels(_quit_labels)

func _handle_main_menu_select() -> void:
	match _main_menu.selected_index:
		MAIN_IDX_PARTY:
			_switch_view(View.PARTY_MENU)
		MAIN_IDX_SAVE:
			hide_menu()
			save_requested.emit()
		MAIN_IDX_LOAD:
			hide_menu()
			load_requested.emit()
		MAIN_IDX_QUIT:
			_switch_view(View.QUIT_DIALOG)

func on_save_completed() -> void:
	hide_menu()

func _handle_party_menu_select() -> void:
	match _party_menu.selected_index:
		PARTY_IDX_STATUS:
			_switch_view(View.STATUS)
		PARTY_IDX_ITEMS:
			_switch_view(View.ITEMS)
		PARTY_IDX_EQUIPMENT:
			_switch_view(View.EQUIPMENT_CHARACTER)

func _handle_quit_dialog_select() -> void:
	match _quit_menu.selected_index:
		QUIT_IDX_YES:
			quit_to_title.emit()
		QUIT_IDX_NO:
			_switch_view(View.MAIN_MENU)

func _refresh_status_view() -> void:
	while _status_container.get_child_count() > 2:
		var child := _status_container.get_child(_status_container.get_child_count() - 1)
		_status_container.remove_child(child)
		child.queue_free()

	var guild: Guild = GameState.guild if GameState != null else null
	if guild == null or not guild.has_party_members():
		var empty := Label.new()
		empty.text = "パーティが編成されていません"
		empty.add_theme_font_size_override("font_size", 16)
		_status_container.add_child(empty)
		return

	for row in range(2):
		for pos in range(3):
			var ch: Character = guild.get_character_at(row, pos)
			if ch == null:
				continue
			var entry := _build_character_entry(ch)
			_status_container.add_child(entry)

func _build_character_entry(ch: Character) -> VBoxContainer:
	var entry := VBoxContainer.new()
	entry.add_theme_constant_override("separation", 2)

	var separator := HSeparator.new()
	entry.add_child(separator)

	var name_label := Label.new()
	name_label.text = "%s  %s / %s  Lv.%d" % [ch.character_name, ch.race.race_name, ch.job.job_name, ch.level]
	name_label.add_theme_font_size_override("font_size", 18)
	entry.add_child(name_label)

	var hp_mp := Label.new()
	hp_mp.text = "  HP: %d/%d  MP: %d/%d" % [ch.current_hp, ch.max_hp, ch.current_mp, ch.max_mp]
	hp_mp.add_theme_font_size_override("font_size", 16)
	entry.add_child(hp_mp)

	var stats := ch.base_stats
	var stat_parts: Array[String] = []
	for key in Character.STAT_KEYS:
		stat_parts.append("%s:%d" % [key, stats.get(key, 0)])
	var stats_label := Label.new()
	stats_label.text = "  " + " ".join(stat_parts)
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	entry.add_child(stats_label)

	return entry


# --- items / equipment views ---

func _get_guild_members() -> Array:
	if GameState == null or GameState.guild == null:
		return []
	return GameState.guild.get_all_characters()


func _get_inventory() -> Inventory:
	if GameState == null:
		return null
	return GameState.inventory


func _refresh_items_view() -> void:
	_clear_extra_children(_items_container)
	var inv := _get_inventory()
	var gold := inv.gold if inv != null else 0
	var gold_label := Label.new()
	gold_label.text = "所持金: %d G" % gold
	gold_label.add_theme_font_size_override("font_size", 16)
	_items_container.add_child(gold_label)

	if inv == null or inv.list().is_empty():
		var empty := Label.new()
		empty.text = "  (アイテムなし)"
		empty.add_theme_font_size_override("font_size", 14)
		_items_container.add_child(empty)
		return

	var equipped_by := _map_equipped_to_character()
	for inst in inv.list():
		var line := Label.new()
		var marker := ""
		if equipped_by.has(inst):
			marker = " [装備中: %s]" % equipped_by[inst]
		var display_name: String = inst.item.item_name if inst.identified else inst.item.unidentified_name
		line.text = "  %s%s" % [display_name, marker]
		line.add_theme_font_size_override("font_size", 14)
		_items_container.add_child(line)


func _map_equipped_to_character() -> Dictionary:
	var result: Dictionary = {}
	for ch in _get_guild_members():
		if ch.equipment == null:
			continue
		for inst in ch.equipment.all_equipped():
			result[inst] = ch.character_name
	return result


func _refresh_equipment_character_view() -> void:
	_clear_extra_children(_equipment_character_container)
	var members := _get_guild_members()
	if members.is_empty():
		var empty := Label.new()
		empty.text = "  (パーティが編成されていません)"
		_equipment_character_container.add_child(empty)
		return
	for i in range(members.size()):
		var ch: Character = members[i]
		var line := Label.new()
		var prefix := "> " if i == _equipment_character_index else "  "
		line.text = "%s%s (Lv%d %s)" % [prefix, ch.character_name, ch.level, ch.job.job_name]
		line.add_theme_font_size_override("font_size", 16)
		_equipment_character_container.add_child(line)


func _refresh_equipment_slot_view() -> void:
	_clear_extra_children(_equipment_slot_container)
	var ch := _get_selected_character()
	if ch == null:
		return
	for i in range(EQUIPMENT_SLOT_LABELS.size()):
		var slot_value := EQUIPMENT_SLOT_VALUES[i]
		var equipped := ch.equipment.get_equipped(slot_value)
		var equipped_name := "なし"
		if equipped != null and equipped.item != null:
			equipped_name = equipped.item.item_name
		var line := Label.new()
		var prefix := "> " if i == _equipment_slot_index else "  "
		line.text = "%s%s: %s" % [prefix, EQUIPMENT_SLOT_LABELS[i], equipped_name]
		line.add_theme_font_size_override("font_size", 16)
		_equipment_slot_container.add_child(line)


func _refresh_equipment_candidate_view() -> void:
	_clear_extra_children(_equipment_candidate_container)
	var candidates := get_equipment_candidates()
	var unequip_label := Label.new()
	var unequip_prefix := "> " if _equipment_candidate_index == 0 else "  "
	unequip_label.text = "%s[はずす]" % unequip_prefix
	unequip_label.add_theme_font_size_override("font_size", 16)
	_equipment_candidate_container.add_child(unequip_label)

	var equipped_by := _map_equipped_to_character()
	var self_ch := _get_selected_character()
	for i in range(candidates.size()):
		var inst: ItemInstance = candidates[i]
		var line := Label.new()
		var prefix := "> " if (i + 1) == _equipment_candidate_index else "  "
		var marker := ""
		if equipped_by.has(inst):
			var holder: String = equipped_by[inst]
			if self_ch != null and holder == self_ch.character_name:
				marker = " [装備中]"
			else:
				marker = " [装備中: %s]" % holder
		line.text = "%s%s%s" % [prefix, inst.item.item_name, marker]
		line.add_theme_font_size_override("font_size", 16)
		_equipment_candidate_container.add_child(line)


func _clear_extra_children(container: VBoxContainer) -> void:
	# Keep the first 2 children (title + spacer) and remove the rest.
	while container.get_child_count() > 2:
		var child := container.get_child(container.get_child_count() - 1)
		container.remove_child(child)
		child.queue_free()


func _get_selected_character() -> Character:
	var members := _get_guild_members()
	if _equipment_character_index < 0 or _equipment_character_index >= members.size():
		return null
	return members[_equipment_character_index]


func get_equipment_candidates() -> Array[ItemInstance]:
	# Candidates: inventory items whose equip_slot matches the selected slot
	# and whose allowed_jobs include the selected character's job.
	var results: Array[ItemInstance] = []
	var ch := _get_selected_character()
	var inv := _get_inventory()
	if ch == null or inv == null or ch.job == null:
		return results
	if _equipment_slot_index < 0 or _equipment_slot_index >= EQUIPMENT_SLOT_VALUES.size():
		return results
	var slot_value := EQUIPMENT_SLOT_VALUES[_equipment_slot_index]
	var job_name := StringName(ch.job.job_name)
	for inst in inv.list():
		if inst.item == null:
			continue
		if _slot_matches_item(slot_value, inst.item):
			if inst.item.allowed_jobs.has(job_name):
				results.append(inst)
	return results


func _slot_matches_item(equipment_slot: int, item: Item) -> bool:
	match equipment_slot:
		Equipment.EquipSlot.WEAPON: return item.equip_slot == Item.EquipSlot.WEAPON
		Equipment.EquipSlot.ARMOR: return item.equip_slot == Item.EquipSlot.ARMOR
		Equipment.EquipSlot.HELMET: return item.equip_slot == Item.EquipSlot.HELMET
		Equipment.EquipSlot.SHIELD: return item.equip_slot == Item.EquipSlot.SHIELD
		Equipment.EquipSlot.GAUNTLET: return item.equip_slot == Item.EquipSlot.GAUNTLET
		Equipment.EquipSlot.ACCESSORY: return item.equip_slot == Item.EquipSlot.ACCESSORY
	return false


func _confirm_equipment_candidate() -> void:
	var ch := _get_selected_character()
	if ch == null:
		return
	var slot_value := EQUIPMENT_SLOT_VALUES[_equipment_slot_index]
	if _equipment_candidate_index == 0:
		# "はずす"
		ch.equipment.unequip(slot_value)
	else:
		var candidates := get_equipment_candidates()
		var idx := _equipment_candidate_index - 1
		if idx >= 0 and idx < candidates.size():
			var instance: ItemInstance = candidates[idx]
			_unequip_from_other_holders(instance, ch)
			ch.equipment.equip(slot_value, instance, ch)
	_switch_view(View.EQUIPMENT_SLOT)


func _unequip_from_other_holders(instance: ItemInstance, exclude: Character) -> void:
	# If another character currently has this ItemInstance equipped, unequip
	# it there first so two characters don't share the same instance.
	for other in _get_guild_members():
		if other == exclude or other == null or other.equipment == null:
			continue
		for slot in Equipment.ALL_SLOTS:
			if other.equipment.get_equipped(slot) == instance:
				other.equipment.unequip(slot)
