class_name Item
extends Resource

enum ItemCategory { WEAPON, ARMOR, HELMET, SHIELD, GAUNTLET, ACCESSORY, OTHER, CONSUMABLE }
enum EquipSlot { NONE, WEAPON, ARMOR, HELMET, SHIELD, GAUNTLET, ACCESSORY }

@export var item_id: StringName
@export var item_name: String
@export var unidentified_name: String
@export var category: ItemCategory = ItemCategory.OTHER
@export var equip_slot: EquipSlot = EquipSlot.NONE
@export var allowed_jobs: Array[StringName] = []
@export var attack_bonus: int = 0
@export var defense_bonus: int = 0
@export var agility_bonus: int = 0
@export var price: int = 0
@export var effect: ItemEffect = null
@export var context_conditions: Array[ContextCondition] = []
@export var target_conditions: Array[TargetCondition] = []


func is_consumable() -> bool:
	return category == ItemCategory.CONSUMABLE


func is_equipment() -> bool:
	return equip_slot != EquipSlot.NONE


func get_context_failure_reason(ctx: ItemUseContext) -> String:
	for cond in context_conditions:
		if not cond.is_satisfied(ctx):
			return cond.reason()
	return ""


func get_target_failure_reason(target, ctx: ItemUseContext) -> String:
	for cond in target_conditions:
		if not cond.is_satisfied(target, ctx):
			return cond.reason()
	return ""
