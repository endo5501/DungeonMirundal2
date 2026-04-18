class_name Item
extends Resource

enum ItemCategory { WEAPON, ARMOR, HELMET, SHIELD, GAUNTLET, ACCESSORY, OTHER }
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
	return false
