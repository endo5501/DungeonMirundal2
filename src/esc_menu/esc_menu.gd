class_name EscMenu
extends CanvasLayer

signal quit_to_title
signal save_requested
signal load_requested
signal return_to_town_requested

enum View { MAIN_MENU, PARTY_MENU, STATUS, QUIT_DIALOG, ITEMS_FLOW, EQUIPMENT_FLOW }

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

var _main_menu_rows: Array[CursorMenuRow] = []
var _party_menu_rows: Array[CursorMenuRow] = []
var _quit_rows: Array[CursorMenuRow] = []

var _item_use_flow: ItemUseFlow
var _equipment_flow: EquipmentFlow

func _init() -> void:
	layer = 10
	_main_menu = CursorMenu.new(MAIN_MENU_ITEMS, MAIN_MENU_DISABLED)
	_party_menu = CursorMenu.new(PARTY_MENU_ITEMS, PARTY_MENU_DISABLED)
	_quit_menu = CursorMenu.new(QUIT_ITEMS)

func _ready() -> void:
	_build_ui()
	# CanvasLayer.visible does not propagate to Control children's `visible`
	# property, so the flows' _unhandled_input would keep firing while the
	# menu is hidden. Switch to MAIN_MENU to set every container's visible
	# flag explicitly before hiding the layer.
	_switch_view(View.MAIN_MENU)
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

	_main_menu_container = TitledView.build("メニュー")
	_build_menu_rows(_main_menu, _main_menu_rows, _main_menu_container)
	root_vbox.add_child(_main_menu_container)

	_party_menu_container = TitledView.build("パーティ")
	_build_menu_rows(_party_menu, _party_menu_rows, _party_menu_container)
	root_vbox.add_child(_party_menu_container)

	_status_container = TitledView.build("ステータス", 4)
	root_vbox.add_child(_status_container)

	_quit_dialog_container = TitledView.build("タイトルに戻りますか？", 8)
	_build_menu_rows(_quit_menu, _quit_rows, _quit_dialog_container)
	root_vbox.add_child(_quit_dialog_container)

	_item_use_flow = ItemUseFlow.new()
	_item_use_flow.flow_completed.connect(_on_item_use_flow_completed)
	_item_use_flow.town_return_requested.connect(_on_item_use_town_return)
	root_vbox.add_child(_item_use_flow)

	_equipment_flow = EquipmentFlow.new()
	_equipment_flow.flow_completed.connect(_on_equipment_flow_completed)
	root_vbox.add_child(_equipment_flow)

func _build_menu_rows(menu: CursorMenu, rows_out: Array[CursorMenuRow], parent: VBoxContainer) -> void:
	for i in range(menu.size()):
		rows_out.append(CursorMenuRow.create(parent, menu.items[i], 20))
	menu.update_rows(rows_out)

func is_menu_visible() -> bool:
	return visible

func show_menu() -> void:
	visible = true
	_main_menu.selected_index = 0
	_switch_view(View.MAIN_MENU)

func hide_menu() -> void:
	# Reset to MAIN_MENU so the flow Controls' `visible` flag is cleared —
	# otherwise their _unhandled_input would keep consuming events on the
	# next screen. CanvasLayer.visible alone does not propagate.
	_switch_view(View.MAIN_MENU)
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
		View.QUIT_DIALOG:
			_switch_view(View.MAIN_MENU)

func handle_input(event: InputEvent) -> bool:
	if _current_view == View.ITEMS_FLOW or _current_view == View.EQUIPMENT_FLOW:
		return false
	if event.is_action_pressed("ui_up"):
		_move_cursor(-1)
		return true
	if event.is_action_pressed("ui_down"):
		_move_cursor(1)
		return true
	if event.is_action_pressed("ui_accept"):
		select_current_item()
		return true
	if event.is_action_pressed("ui_cancel"):
		go_back()
		return true
	return false


func _move_cursor(direction: int) -> void:
	var current_menu := _get_current_menu()
	if current_menu == null:
		return
	current_menu.move_cursor(direction)
	_update_current_labels()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _current_view == View.ITEMS_FLOW or _current_view == View.EQUIPMENT_FLOW:
		return
	if handle_input(event):
		get_viewport().set_input_as_handled()

func _switch_view(view: View) -> void:
	_current_view = view
	_main_menu_container.visible = (view == View.MAIN_MENU)
	_party_menu_container.visible = (view == View.PARTY_MENU)
	_status_container.visible = (view == View.STATUS)
	_quit_dialog_container.visible = (view == View.QUIT_DIALOG)
	_item_use_flow.visible = (view == View.ITEMS_FLOW)
	_equipment_flow.visible = (view == View.EQUIPMENT_FLOW)

	match view:
		View.PARTY_MENU:
			_party_menu.selected_index = 0
			_party_menu.update_rows(_party_menu_rows)
		View.QUIT_DIALOG:
			_quit_menu.selected_index = QUIT_IDX_NO
			_quit_menu.update_rows(_quit_rows)
		View.STATUS:
			_refresh_status_view()
		View.ITEMS_FLOW:
			_item_use_flow.setup(make_item_use_context(), _get_inventory(), _get_guild_members())
		View.EQUIPMENT_FLOW:
			_equipment_flow.setup(_get_guild_members(), _get_inventory())
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
			_switch_view(View.ITEMS_FLOW)
		PARTY_IDX_EQUIPMENT:
			_switch_view(View.EQUIPMENT_FLOW)

func _handle_quit_dialog_select() -> void:
	match _quit_menu.selected_index:
		QUIT_IDX_YES:
			quit_to_title.emit()
		QUIT_IDX_NO:
			_switch_view(View.MAIN_MENU)


func _on_item_use_flow_completed(_message: String) -> void:
	_switch_view(View.PARTY_MENU)


func _on_item_use_town_return() -> void:
	hide_menu()
	return_to_town_requested.emit()


func _on_equipment_flow_completed() -> void:
	_switch_view(View.PARTY_MENU)


func _refresh_status_view() -> void:
	TitledView.clear_extras(_status_container)

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


func _get_guild_members() -> Array[Character]:
	if GameState == null or GameState.guild == null:
		return [] as Array[Character]
	return GameState.guild.get_all_characters()


func _get_inventory() -> Inventory:
	if GameState == null:
		return null
	return GameState.inventory


func make_item_use_context() -> ItemUseContext:
	var in_dungeon: bool = false
	var in_combat: bool = false
	var party: Array = _get_guild_members()
	if GameState != null:
		in_dungeon = (GameState.game_location == GameState.LOCATION_DUNGEON)
	return ItemUseContext.make(in_dungeon, in_combat, party)


