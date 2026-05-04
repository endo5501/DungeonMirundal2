class_name CureAllStatusItemEffect
extends ItemEffect

# Sentinel for "remove regardless of scope".
const SCOPE_ALL := 2

@export var scope: int = SCOPE_ALL  # StatusData.Scope or SCOPE_ALL

var _status_repo_override: StatusRepository = null


func set_status_repo_for_testing(repo: StatusRepository) -> void:
	_status_repo_override = repo


func apply(targets: Array, _context) -> ItemEffectResult:
	if targets.is_empty():
		return ItemEffectResult.failure("対象がいません")
	var repo := StatusRepoLocator.resolve(_status_repo_override)
	if repo == null:
		return ItemEffectResult.failure("ステータス情報が見つかりません")
	var any_cured := false
	var cured_names: Array[String] = []
	for target in targets:
		if target == null:
			continue
		if target.has_method("is_alive") and not target.is_alive():
			continue
		if target is CombatActor:
			if _cure_combat_actor(target as CombatActor, repo):
				any_cured = true
				cured_names.append((target as CombatActor).actor_name)
		elif "persistent_statuses" in target:
			if _cure_character(target, repo):
				any_cured = true
				if "character_name" in target:
					cured_names.append(String(target.character_name))
	if not any_cured:
		return ItemEffectResult.failure("対象には効果がなかった")
	if cured_names.is_empty():
		return ItemEffectResult.ok("状態を治療した")
	return ItemEffectResult.ok("%s の状態を治療した" % ", ".join(cured_names))


func _cure_combat_actor(actor: CombatActor, repo: StatusRepository) -> bool:
	var to_cure: Array[StringName] = []
	for sid in actor.statuses.active_ids():
		var data: StatusData = repo.find(sid)
		if data == null:
			continue
		if scope == SCOPE_ALL or data.scope == scope:
			to_cure.append(sid)
	for sid in to_cure:
		actor.statuses.cure(sid)
	return not to_cure.is_empty()


func _cure_character(character, repo: StatusRepository) -> bool:
	# BATTLE_ONLY scope is meaningless on a Character (those ids aren't persisted),
	# so treat it as a no-op.
	if scope == StatusData.Scope.BATTLE_ONLY:
		return false
	var arr: Array = character.persistent_statuses
	var keep: Array[StringName] = []
	var any_removed := false
	for sid in arr:
		var data: StatusData = repo.find(sid)
		if data == null:
			keep.append(sid)
			continue
		if scope == SCOPE_ALL or data.scope == scope:
			any_removed = true
			continue
		keep.append(sid)
	if any_removed:
		character.persistent_statuses = keep
	return any_removed
