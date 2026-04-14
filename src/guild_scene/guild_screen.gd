class_name GuildScreen
extends Control

var guild: Guild
var data_loader: DataLoader
var _current_view: Control

func _ready() -> void:
	guild = Guild.new()
	data_loader = DataLoader.new()
	_show_menu()

func _show_menu() -> void:
	var menu := GuildMenu.new()
	menu.create_character_selected.connect(_on_create_character)
	menu.party_formation_selected.connect(_on_party_formation)
	menu.character_list_selected.connect(_on_character_list)
	menu.leave_selected.connect(_on_leave)
	_switch_view(menu)

func _on_create_character() -> void:
	var creation := CharacterCreation.new()
	creation.setup(guild, data_loader.load_all_races(), data_loader.load_all_jobs())
	creation.back_requested.connect(_show_menu)
	_switch_view(creation)

func _on_party_formation() -> void:
	var formation := PartyFormation.new()
	formation.setup(guild)
	formation.back_requested.connect(_show_menu)
	_switch_view(formation)

func _on_character_list() -> void:
	var char_list := CharacterList.new()
	char_list.setup(guild)
	char_list.back_requested.connect(_show_menu)
	_switch_view(char_list)

func _on_leave() -> void:
	pass

func _switch_view(new_view: Control) -> void:
	if _current_view != null:
		_current_view.queue_free()
	_current_view = new_view
	new_view.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(new_view)
