class_name InitialEquipment
extends RefCounted

const JOB_LOADOUTS: Dictionary = {
	"Fighter":  [&"long_sword", &"leather_armor"],
	"Mage":     [&"staff", &"robe"],
	"Priest":   [&"mace", &"robe"],
	"Thief":    [&"short_sword", &"leather_armor"],
	"Bishop":   [&"staff", &"robe"],
	"Samurai":  [&"long_sword", &"leather_armor"],
	"Lord":     [&"long_sword", &"leather_armor"],
	"Ninja":    [&"short_sword", &"leather_armor"],
}


static func grant(character: Character, inventory: Inventory, repository: ItemRepository) -> void:
	if character == null or inventory == null or repository == null:
		return
	if character.job == null:
		return
	var loadout: Array = JOB_LOADOUTS.get(character.job.job_name, [])
	for item_id in loadout:
		var item: Item = repository.find(item_id)
		if item == null:
			continue
		var instance := ItemInstance.new(item, true)
		inventory.add(instance)
		var slot := _map_item_slot_to_equipment_slot(item.equip_slot)
		if slot < 0:
			continue
		character.equipment.equip(slot, instance, character)


static func _map_item_slot_to_equipment_slot(item_slot: int) -> int:
	match item_slot:
		Item.EquipSlot.WEAPON: return Equipment.EquipSlot.WEAPON
		Item.EquipSlot.ARMOR: return Equipment.EquipSlot.ARMOR
		Item.EquipSlot.HELMET: return Equipment.EquipSlot.HELMET
		Item.EquipSlot.SHIELD: return Equipment.EquipSlot.SHIELD
		Item.EquipSlot.GAUNTLET: return Equipment.EquipSlot.GAUNTLET
		Item.EquipSlot.ACCESSORY: return Equipment.EquipSlot.ACCESSORY
	return -1
