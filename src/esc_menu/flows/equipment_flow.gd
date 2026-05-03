class_name EquipmentFlow
extends Control

signal flow_completed

enum SubView { CHARACTER, SLOT, CANDIDATE }

var _sub_view: int = SubView.CHARACTER
var _party: Array[Character] = []
var _inventory: Inventory
var _character_index: int = 0
var _slot_index: int = 0
var _candidate_index: int = 0


func setup(_p_party: Array[Character], _p_inventory: Inventory) -> void:
	pass


func handle_input(_event: InputEvent) -> bool:
	return false


func get_equipment_candidates() -> Array[ItemInstance]:
	return [] as Array[ItemInstance]
