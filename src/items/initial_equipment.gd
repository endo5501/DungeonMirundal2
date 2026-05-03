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
		character.equipment.equip(item.equip_slot, instance, character)
