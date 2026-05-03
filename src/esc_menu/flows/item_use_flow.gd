class_name ItemUseFlow
extends Control

signal flow_completed(message: String)
signal town_return_requested

enum SubView { SELECT_ITEM, SELECT_TARGET, CONFIRM, RESULT }

var _sub_view: int = SubView.SELECT_ITEM
var _context: ItemUseContext
var _inventory: Inventory
var _party: Array[Character] = []


func setup(_p_context: ItemUseContext, _p_inventory: Inventory, _p_party: Array[Character]) -> void:
	pass


func handle_input(_event: InputEvent) -> bool:
	return false
