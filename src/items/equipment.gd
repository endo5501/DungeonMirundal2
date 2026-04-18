class_name Equipment
extends RefCounted

enum EquipSlot { WEAPON, ARMOR, HELMET, SHIELD, GAUNTLET, ACCESSORY }
enum FailReason { NONE, SLOT_MISMATCH, JOB_NOT_ALLOWED }

const SLOT_KEYS: Dictionary = {
	EquipSlot.WEAPON: "weapon",
	EquipSlot.ARMOR: "armor",
	EquipSlot.HELMET: "helmet",
	EquipSlot.SHIELD: "shield",
	EquipSlot.GAUNTLET: "gauntlet",
	EquipSlot.ACCESSORY: "accessory",
}

const ALL_SLOTS: Array[int] = [
	EquipSlot.WEAPON,
	EquipSlot.ARMOR,
	EquipSlot.HELMET,
	EquipSlot.SHIELD,
	EquipSlot.GAUNTLET,
	EquipSlot.ACCESSORY,
]


class EquipResult extends RefCounted:
	var success: bool
	var previous: ItemInstance
	var reason: int

	func _init(p_success: bool, p_previous: ItemInstance, p_reason: int = FailReason.NONE) -> void:
		success = p_success
		previous = p_previous
		reason = p_reason


var _slots: Dictionary = {}  # EquipSlot -> ItemInstance


func _init() -> void:
	for slot in ALL_SLOTS:
		_slots[slot] = null


func get_equipped(slot: int) -> ItemInstance:
	return _slots.get(slot, null)


func equip(slot: int, instance: ItemInstance, character: Character) -> EquipResult:
	if instance == null or instance.item == null:
		return EquipResult.new(false, null, FailReason.SLOT_MISMATCH)
	if not _item_slot_matches(instance.item, slot):
		return EquipResult.new(false, null, FailReason.SLOT_MISMATCH)
	if not _job_allowed(instance.item, character):
		return EquipResult.new(false, null, FailReason.JOB_NOT_ALLOWED)
	var previous: ItemInstance = _slots.get(slot, null)
	_slots[slot] = instance
	return EquipResult.new(true, previous, FailReason.NONE)


func unequip(slot: int) -> ItemInstance:
	var previous: ItemInstance = _slots.get(slot, null)
	_slots[slot] = null
	return previous


func all_equipped() -> Array[ItemInstance]:
	var results: Array[ItemInstance] = []
	for slot in ALL_SLOTS:
		var inst: ItemInstance = _slots.get(slot, null)
		if inst != null:
			results.append(inst)
	return results


func to_dict(inventory: Inventory) -> Dictionary:
	var result: Dictionary = {}
	for slot in ALL_SLOTS:
		var key: String = SLOT_KEYS[slot]
		var inst: ItemInstance = _slots.get(slot, null)
		if inst == null:
			result[key] = null
		else:
			var idx := inventory.index_of(inst)
			result[key] = idx if idx >= 0 else null
	return result


static func from_dict(data: Dictionary, inventory: Inventory) -> Equipment:
	var eq := Equipment.new()
	var listed := inventory.list()
	for slot in ALL_SLOTS:
		var key: String = SLOT_KEYS[slot]
		if not data.has(key):
			continue
		var raw = data.get(key)
		if raw == null:
			continue
		var idx := int(raw)
		if idx < 0 or idx >= listed.size():
			continue
		eq._slots[slot] = listed[idx]
	return eq


func _item_slot_matches(item: Item, slot: int) -> bool:
	match slot:
		EquipSlot.WEAPON: return item.equip_slot == Item.EquipSlot.WEAPON
		EquipSlot.ARMOR: return item.equip_slot == Item.EquipSlot.ARMOR
		EquipSlot.HELMET: return item.equip_slot == Item.EquipSlot.HELMET
		EquipSlot.SHIELD: return item.equip_slot == Item.EquipSlot.SHIELD
		EquipSlot.GAUNTLET: return item.equip_slot == Item.EquipSlot.GAUNTLET
		EquipSlot.ACCESSORY: return item.equip_slot == Item.EquipSlot.ACCESSORY
	return false


func _job_allowed(item: Item, character: Character) -> bool:
	if character == null or character.job == null:
		return false
	var job_name_sn := StringName(character.job.job_name)
	return item.allowed_jobs.has(job_name_sn)
