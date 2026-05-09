extends Control

# Dev Console shell. Holds a TabContainer; child tabs are instantiated from
# a scene path so adding a new editor (Items / Spells / Monsters / ...) is a
# matter of dropping its scene under tools/dev_console/tabs/<name>/ and
# registering it here. The shell deliberately knows nothing about each tab's
# domain logic — that lives in each tab's own scene.

const _TabSpec := {
	"Saves": "res://tools/dev_console/tabs/saves/save_editor.tscn",
	# Phase 2 entries will be added here, e.g.:
	# "Items":    "res://tools/dev_console/tabs/items/item_editor.tscn",
	# "Spells":   "res://tools/dev_console/tabs/spells/spell_editor.tscn",
	# "Monsters": "res://tools/dev_console/tabs/monsters/monster_editor.tscn",
}

@onready var _tabs: TabContainer = %Tabs


func _ready() -> void:
	# project.godot registers PartyHud as a CanvasLayer autoload, so it draws
	# over the dev console when we launch with `godot --path .`. The dev
	# console runs standalone and has no use for the in-game HUD; hide it.
	var hud: Node = get_tree().root.get_node_or_null("PartyHud")
	if hud != null and hud.has_method("hide_hud"):
		hud.hide_hud()
	_register_tabs()
	# Saves is the default-selected tab (it's the first entry registered, and
	# TabContainer defaults to current_tab=0).
	if _tabs.get_tab_count() > 0:
		_tabs.current_tab = 0


func _register_tabs() -> void:
	for tab_name in _TabSpec.keys():
		var scene_path: String = _TabSpec[tab_name]
		_register_tab(tab_name, scene_path)


# Public helper: future tabs (or external test harnesses) can register
# additional editors at runtime without modifying this script.
func _register_tab(tab_name: String, scene_path: String) -> void:
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("DevConsole: failed to load tab scene at %s" % scene_path)
		return
	var instance: Node = packed.instantiate()
	if instance == null:
		push_error("DevConsole: failed to instantiate tab scene at %s" % scene_path)
		return
	instance.name = tab_name
	_tabs.add_child(instance)
