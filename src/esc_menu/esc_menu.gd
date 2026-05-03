class_name EscMenu
extends CanvasLayer

signal quit_to_title
signal save_requested
signal load_requested
signal return_to_town_requested

enum View { MAIN_MENU, PARTY_MENU, STATUS, QUIT_DIALOG, ITEMS, EQUIPMENT, EQUIPMENT_CHARACTER, EQUIPMENT_SLOT, EQUIPMENT_CANDIDATE, ITEM_USE_TARGET, ITEM_USE_CONFIRM }

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

var _main_menu_rows: Array[CursorMenuRow] = []
var _party_menu_rows: Array[CursorMenuRow] = []
var _quit_rows: Array[CursorMenuRow] = []

# Equipment navigation state
var _equipment_character_index: int = 0
var _equipment_slot_index: int = 0
var _equipment_candidate_index: int = 0

# Item use flow state
var _items_index: int = 0
var _item_use_instance: ItemInstance = null
var _item_use_target_index: int = 0
var _item_use_confirm_index: int = 0  # 0 = はい, 1 = いいえ
var _item_use_last_message: String = ""
var _item_use_target_container: VBoxContainer
var _item_use_confirm_container: VBoxContainer

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
	_build_menu_rows(_main_menu, _main_menu_rows, _main_menu_container)
	root_vbox.add_child(_main_menu_container)

	_party_menu_container = _build_titled_view("パーティ")
	_build_menu_rows(_party_menu, _party_menu_rows, _party_menu_container)
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
	_build_menu_rows(_quit_menu, _quit_rows, _quit_dialog_container)
	root_vbox.add_child(_quit_dialog_container)

	_item_use_target_container = _build_titled_view("対象を選択", 4)
	root_vbox.add_child(_item_use_target_container)

	_item_use_confirm_container = _build_titled_view("アイテム使用", 6)
	root_vbox.add_child(_item_use_confirm_container)

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

func _build_menu_rows(menu: CursorMenu, rows_out: Array[CursorMenuRow], parent: VBoxContainer) -> void:
	for i in range(menu.size()):
		rows_out.append(CursorMenuRow.create(parent, menu.items[i], 20))
	menu.update_rows(rows_out)

func is_menu_visible() -> bool:
	return visible

func show_menu() -> void:
	visible = true
	_main_menu.selected_index = 0
	_item_use_last_message = ""
	_item_use_instance = null
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
		View.ITEMS:
			_handle_items_select()
		View.ITEM_USE_TARGET:
			_handle_item_use_target_select()
		View.ITEM_USE_CONFIRM:
			_handle_item_use_confirm_select()
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
			_item_use_last_message = ""
			_switch_view(View.PARTY_MENU)
		View.ITEM_USE_TARGET:
			_item_use_instance = null
			_switch_view(View.ITEMS)
		View.ITEM_USE_CONFIRM:
			_item_use_instance = null
			_switch_view(View.ITEMS)
		View.EQUIPMENT_CHARACTER:
			_switch_view(View.PARTY_MENU)
		View.EQUIPMENT_SLOT:
			_switch_view(View.EQUIPMENT_CHARACTER)
		View.EQUIPMENT_CANDIDATE:
			_switch_view(View.EQUIPMENT_SLOT)
		View.QUIT_DIALOG:
			_switch_view(View.MAIN_MENU)

func handle_input(event: InputEvent) -> bool:
	var current_menu := _get_current_menu()
	if event.is_action_pressed(&"ui_up"):
		if current_menu:
			current_menu.move_cursor(-1)
			_update_current_labels()
		else:
			_cursor_move_in_view(-1)
		return true
	if event.is_action_pressed(&"ui_down"):
		if current_menu:
			current_menu.move_cursor(1)
			_update_current_labels()
		else:
			_cursor_move_in_view(1)
		return true
	if event.is_action_pressed(&"ui_accept"):
		select_current_item()
		return true
	if event.is_action_pressed(&"ui_cancel"):
		go_back()
		return true
	return false


func _cursor_move_in_view(direction: int) -> void:
	match _current_view:
		View.EQUIPMENT_CHARACTER:
			var members := _get_guild_members()
			if members.size() == 0: return
			_equipment_character_index = (_equipment_character_index + direction + members.size()) % members.size()
			_refresh_equipment_character_view()
		View.EQUIPMENT_SLOT:
			_equipment_slot_index = (_equipment_slot_index + direction + Equipment.ALL_SLOTS.size()) % Equipment.ALL_SLOTS.size()
			_refresh_equipment_slot_view()
		View.EQUIPMENT_CANDIDATE:
			var rows := get_equipment_candidates().size() + 1
			_equipment_candidate_index = (_equipment_candidate_index + direction + rows) % rows
			_refresh_equipment_candidate_view()
		View.ITEMS:
			var inv := _get_inventory()
			var count := inv.list().size() if inv != null else 0
			if count == 0:
				return
			_items_index = (_items_index + direction + count) % count
			_refresh_items_view()
		View.ITEM_USE_TARGET:
			var members2 := _get_guild_members()
			if members2.is_empty():
				return
			_item_use_target_index = (_item_use_target_index + direction + members2.size()) % members2.size()
			_refresh_item_use_target_view()
		View.ITEM_USE_CONFIRM:
			_item_use_confirm_index = (_item_use_confirm_index + direction + 2) % 2
			_refresh_item_use_confirm_view()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if handle_input(event):
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
	_item_use_target_container.visible = (view == View.ITEM_USE_TARGET)
	_item_use_confirm_container.visible = (view == View.ITEM_USE_CONFIRM)

	match view:
		View.PARTY_MENU:
			_party_menu.selected_index = 0
			_party_menu.update_rows(_party_menu_rows)
		View.QUIT_DIALOG:
			_quit_menu.selected_index = QUIT_IDX_NO
			_quit_menu.update_rows(_quit_rows)
		View.STATUS:
			_refresh_status_view()
		View.ITEMS:
			_refresh_items_view()
		View.ITEM_USE_TARGET:
			_item_use_target_index = _first_valid_target_index()
			_refresh_item_use_target_view()
		View.ITEM_USE_CONFIRM:
			_item_use_confirm_index = 0
			_refresh_item_use_confirm_view()
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
			_main_menu.update_rows(_main_menu_rows)

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
			_main_menu.update_rows(_main_menu_rows)
		View.PARTY_MENU:
			_party_menu.update_rows(_party_menu_rows)
		View.QUIT_DIALOG:
			_quit_menu.update_rows(_quit_rows)

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
	_clear_extra_children(_status_container)

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

	if _item_use_last_message != "":
		var msg := Label.new()
		msg.text = _item_use_last_message
		msg.add_theme_font_size_override("font_size", 12)
		msg.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4))
		_items_container.add_child(msg)

	if inv == null or inv.list().is_empty():
		var empty := Label.new()
		empty.text = "  (アイテムなし)"
		empty.add_theme_font_size_override("font_size", 14)
		_items_container.add_child(empty)
		return

	var instances := inv.list()
	if _items_index >= instances.size():
		_items_index = maxi(0, instances.size() - 1)

	var ctx := make_item_use_context()
	var equipped_by := _map_equipped_to_character_names()
	for i in range(instances.size()):
		var inst: ItemInstance = instances[i]
		var marker := ""
		if equipped_by.has(inst):
			marker = " [装備中: %s]" % equipped_by[inst]
		var display_name: String = inst.item.item_name if inst.identified else inst.item.unidentified_name
		var usable: bool = inst.item.is_consumable()
		var context_failure := ""
		if usable:
			context_failure = inst.item.get_context_failure_reason(ctx)
		var text: String
		if usable and context_failure == "":
			text = "  %s%s" % [display_name, marker]
		elif usable:
			text = "  %s%s  (%s)" % [display_name, marker, context_failure]
		else:
			text = "  %s%s" % [display_name, marker]
		var row := CursorMenuRow.create(_items_container, text, 14)
		row.set_selected(i == _items_index)
		if usable and context_failure != "":
			row.set_disabled(true)

	var hint := Label.new()
	var current_inst: ItemInstance = instances[_items_index] if _items_index < instances.size() else null
	if current_inst != null and current_inst.item.is_consumable():
		var fail := current_inst.item.get_context_failure_reason(ctx)
		if fail == "":
			hint.text = "Enter: 使う  ESC: 戻る"
		else:
			hint.text = "このアイテムは %s" % fail
	else:
		hint.text = "ESC: 戻る"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	_items_container.add_child(hint)


func make_item_use_context() -> ItemUseContext:
	var in_dungeon: bool = false
	var in_combat: bool = false
	var party: Array = _get_guild_members()
	if GameState != null:
		in_dungeon = (GameState.game_location == GameState.LOCATION_DUNGEON)
	return ItemUseContext.make(in_dungeon, in_combat, party)


func _handle_items_select() -> void:
	_item_use_last_message = ""
	var inv := _get_inventory()
	if inv == null or inv.list().is_empty():
		return
	if _items_index < 0 or _items_index >= inv.list().size():
		return
	var inst: ItemInstance = inv.list()[_items_index]
	if not inst.item.is_consumable():
		return
	var ctx := make_item_use_context()
	var failure := inst.item.get_context_failure_reason(ctx)
	if failure != "":
		_item_use_last_message = "使えない: %s" % failure
		_refresh_items_view()
		return
	_item_use_instance = inst
	if inst.item.target_conditions.is_empty():
		_switch_view(View.ITEM_USE_CONFIRM)
	else:
		_switch_view(View.ITEM_USE_TARGET)


# --- Item use target view ---

func _refresh_item_use_target_view() -> void:
	_clear_extra_children(_item_use_target_container)
	if _item_use_instance == null:
		return
	var item_label := Label.new()
	item_label.text = "使用: %s" % _item_use_instance.item.item_name
	item_label.add_theme_font_size_override("font_size", 16)
	_item_use_target_container.add_child(item_label)

	var members := _get_guild_members()
	var ctx := make_item_use_context()
	for i in range(members.size()):
		var ch: Character = members[i]
		var reason := _item_use_instance.item.get_target_failure_reason(ch, ctx)
		var valid := reason == ""
		var line_text: String
		if valid:
			line_text = "  %s  HP:%d/%d MP:%d/%d" % [ch.character_name, ch.current_hp, ch.max_hp, ch.current_mp, ch.max_mp]
		else:
			line_text = "  %s  (%s)" % [ch.character_name, reason]
		var row := CursorMenuRow.create(_item_use_target_container, line_text, 14)
		row.set_selected(i == _item_use_target_index)
		if not valid:
			row.set_disabled(true)

	var hint := Label.new()
	hint.text = "Enter: 決定  ESC: 戻る"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	_item_use_target_container.add_child(hint)


func _first_valid_target_index() -> int:
	if _item_use_instance == null:
		return 0
	var members := _get_guild_members()
	var ctx := make_item_use_context()
	for i in range(members.size()):
		if _item_use_instance.item.get_target_failure_reason(members[i], ctx) == "":
			return i
	return 0


func _handle_item_use_target_select() -> void:
	if _item_use_instance == null:
		_switch_view(View.ITEMS)
		return
	var members := _get_guild_members()
	if _item_use_target_index < 0 or _item_use_target_index >= members.size():
		return
	var target: Character = members[_item_use_target_index]
	var ctx := make_item_use_context()
	var reason := _item_use_instance.item.get_target_failure_reason(target, ctx)
	if reason != "":
		_item_use_last_message = reason
		_refresh_item_use_target_view()
		return
	_resolve_use([target], ctx)


# --- Item use confirm view ---

func _refresh_item_use_confirm_view() -> void:
	_clear_extra_children(_item_use_confirm_container)
	if _item_use_instance == null:
		return
	var label := Label.new()
	label.text = "%s を使いますか？" % _item_use_instance.item.item_name
	label.add_theme_font_size_override("font_size", 16)
	_item_use_confirm_container.add_child(label)

	var options := ["はい", "いいえ"]
	for i in range(options.size()):
		var row := CursorMenuRow.create(_item_use_confirm_container, options[i], 16)
		row.set_selected(i == _item_use_confirm_index)


func _handle_item_use_confirm_select() -> void:
	if _item_use_confirm_index == 1:
		_item_use_instance = null
		_switch_view(View.ITEMS)
		return
	if _item_use_instance == null:
		_switch_view(View.ITEMS)
		return
	var ctx := make_item_use_context()
	_resolve_use([], ctx)


func _resolve_use(targets: Array, ctx: ItemUseContext) -> void:
	var inv := _get_inventory()
	if inv == null or _item_use_instance == null:
		_item_use_instance = null
		_switch_view(View.ITEMS)
		return
	var result: ItemEffectResult = inv.use_item(_item_use_instance, targets, ctx)
	var used_inst := _item_use_instance
	_item_use_instance = null
	if result != null and result.success:
		_item_use_last_message = "%s を使った" % used_inst.item.item_name
		if result.request_town_return:
			hide_menu()
			return_to_town_requested.emit()
			return
	else:
		var msg := result.message if result != null else "使用失敗"
		_item_use_last_message = "使用失敗: %s" % msg
	_switch_view(View.ITEMS)


func _map_equipped_to_character_names() -> Dictionary:
	if GameState == null or GameState.guild == null:
		return {}
	var result: Dictionary = {}
	var owners := GameState.guild.map_equipped_instances()
	for inst in owners:
		result[inst] = (owners[inst] as Character).character_name
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
		var row := CursorMenuRow.create(_equipment_character_container,
			"%s (Lv%d %s)" % [ch.character_name, ch.level, ch.job.job_name], 16)
		row.set_selected(i == _equipment_character_index)


func _refresh_equipment_slot_view() -> void:
	_clear_extra_children(_equipment_slot_container)
	var ch := _get_selected_character()
	if ch == null:
		return
	for i in range(EQUIPMENT_SLOT_LABELS.size()):
		var slot_value := Equipment.ALL_SLOTS[i]
		var equipped := ch.equipment.get_equipped(slot_value)
		var equipped_name := "なし"
		if equipped != null and equipped.item != null:
			equipped_name = equipped.item.item_name
		var row := CursorMenuRow.create(_equipment_slot_container,
			"%s: %s" % [EQUIPMENT_SLOT_LABELS[i], equipped_name], 16)
		row.set_selected(i == _equipment_slot_index)


func _refresh_equipment_candidate_view() -> void:
	_clear_extra_children(_equipment_candidate_container)
	var candidates := get_equipment_candidates()
	var unequip_row := CursorMenuRow.create(_equipment_candidate_container, "[はずす]", 16)
	unequip_row.set_selected(_equipment_candidate_index == 0)

	var equipped_by := _map_equipped_to_character_names()
	var self_ch := _get_selected_character()
	for i in range(candidates.size()):
		var inst: ItemInstance = candidates[i]
		var marker := ""
		if equipped_by.has(inst):
			var holder: String = equipped_by[inst]
			if self_ch != null and holder == self_ch.character_name:
				marker = " [装備中]"
			else:
				marker = " [装備中: %s]" % holder
		var row := CursorMenuRow.create(_equipment_candidate_container,
			"%s%s" % [inst.item.item_name, marker], 16)
		row.set_selected((i + 1) == _equipment_candidate_index)


const _HEADER_CHILD_COUNT: int = 2  # title + spacer; see _build_titled_view


func _clear_extra_children(container: VBoxContainer) -> void:
	while container.get_child_count() > _HEADER_CHILD_COUNT:
		var child := container.get_child(container.get_child_count() - 1)
		container.remove_child(child)
		child.queue_free()


func _get_selected_character() -> Character:
	var members := _get_guild_members()
	if _equipment_character_index < 0 or _equipment_character_index >= members.size():
		return null
	return members[_equipment_character_index]


func get_equipment_candidates() -> Array[ItemInstance]:
	var results: Array[ItemInstance] = []
	var ch := _get_selected_character()
	var inv := _get_inventory()
	if ch == null or inv == null:
		return results
	if _equipment_slot_index < 0 or _equipment_slot_index >= Equipment.ALL_SLOTS.size():
		return results
	var slot_value := Equipment.ALL_SLOTS[_equipment_slot_index]
	for inst in inv.list():
		if inst.item != null and Equipment.can_equip(inst.item, slot_value, ch):
			results.append(inst)
	return results


func _confirm_equipment_candidate() -> void:
	var ch := _get_selected_character()
	if ch == null:
		return
	var slot_value := Equipment.ALL_SLOTS[_equipment_slot_index]
	if _equipment_candidate_index == 0:
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
