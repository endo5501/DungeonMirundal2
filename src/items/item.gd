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


func is_slot_consistent() -> bool:
	match category:
		ItemCategory.WEAPON:
			return equip_slot == EquipSlot.WEAPON
		ItemCategory.ARMOR:
			return equip_slot == EquipSlot.ARMOR
		ItemCategory.HELMET:
			return equip_slot == EquipSlot.HELMET
		ItemCategory.SHIELD:
			return equip_slot == EquipSlot.SHIELD
		ItemCategory.GAUNTLET:
			return equip_slot == EquipSlot.GAUNTLET
		ItemCategory.ACCESSORY:
			return equip_slot == EquipSlot.ACCESSORY
		ItemCategory.OTHER:
			return equip_slot == EquipSlot.NONE
		ItemCategory.CONSUMABLE:
			return equip_slot == EquipSlot.NONE
	return false


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
