class_name StatusTickService
extends RefCounted

# Applies dungeon-step status ticks to a Character. The HP floor (1) ensures
# dungeon ticks NEVER kill — characters can only die from battle damage.


# Returns { "total_loss": int, "ticks": [{ "status_id": StringName, "amount": int }] }
static func tick_character_step(character: Character, repo: StatusRepository) -> Dictionary:
	var result: Dictionary = {"total_loss": 0, "ticks": []}
	if character == null or repo == null:
		return result
	if character.is_dead():
		return result
	for sid in character.persistent_statuses:
		var data: StatusData = repo.find(sid)
		if data == null:
			continue
		if data.scope != StatusData.Scope.PERSISTENT:
			continue
		var requested: int = 0
		if data.tick_in_dungeon_ratio > 0:
			requested = maxi(1, character.max_hp / data.tick_in_dungeon_ratio)
		elif data.tick_in_dungeon > 0:
			requested = data.tick_in_dungeon
		else:
			continue
		var loss: int = mini(requested, max(0, character.current_hp - 1))
		if loss > 0:
			character.current_hp -= loss
		result["total_loss"] = int(result["total_loss"]) + loss
		(result["ticks"] as Array).append({"status_id": sid, "amount": loss})
	return result
